using System.Data;
using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using System.Text.Json;
using System.Text.Json.Serialization;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace ARSmartMenu.API.Controllers;

[ApiController]
public class TableOrdersController : ControllerBase
{
    private static readonly ConcurrentDictionary<string, List<TableChatMessageDto>> _tableChatStore = new();
    private static readonly ConcurrentDictionary<string, TableWaiterCallDto> _waiterCallsStore = new();
    private static readonly ConcurrentDictionary<string, string> _activeTableSessionTokens = new();
    private static readonly ConcurrentDictionary<string, SharedCartState> _tableSharedCartStore = new(StringComparer.OrdinalIgnoreCase);

    private static readonly JsonSerializerOptions CompactJsonOptions = new()
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private static string GetChatKey(Guid businessId, string? tableNumber)
    {
        var clean = (tableNumber ?? string.Empty).Trim().ToLowerInvariant().Replace("table", "").Trim();
        return $"{businessId}:{clean}";
    }

    private readonly AppDbContext _db;
    private readonly AppLookupCacheService _lookupCache;
    private readonly IMemoryCache _cache;

    public TableOrdersController(AppDbContext db, AppLookupCacheService lookupCache, IMemoryCache cache)
    {
        _db = db;
        _lookupCache = lookupCache;
        _cache = cache;
    }

    private async Task<Guid?> ResolveBusinessIdAsync(
        string slug,
        bool requireActiveQr = false,
        bool fallbackToAnyBusiness = false,
        CancellationToken ct = default)
    {
        var target = await _lookupCache.ResolveSlugAsync(_db, slug, requireActiveQr, fallbackToAnyBusiness, ct);
        return target?.BusinessId;
    }

    private static (string CleanTable, string AltTable, string TableDigits, string AltTableNum) BuildTableVariants(string? tableNumber)
    {
        var cleanTable = (tableNumber ?? "dine-in").Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(cleanTable)) cleanTable = "dine-in";
        var altTable = cleanTable.StartsWith("table")
            ? cleanTable.Replace("table", "").Trim()
            : ("table " + cleanTable);
        var tableDigits = Regex.Match(cleanTable, @"\d+").Value;
        var altTableNum = !string.IsNullOrEmpty(tableDigits) ? ("table " + tableDigits) : altTable;
        return (cleanTable, altTable, tableDigits, altTableNum);
    }

    private static IQueryable<TableOrder> FilterByTable(IQueryable<TableOrder> query, string? tableNumber)
    {
        var (cleanTable, altTable, tableDigits, altTableNum) = BuildTableVariants(tableNumber);
        if (!string.IsNullOrEmpty(tableDigits))
        {
            return query.Where(o =>
                o.TableNumber == cleanTable ||
                o.TableNumber == altTable ||
                o.TableNumber == tableDigits ||
                o.TableNumber == altTableNum);
        }

        return query.Where(o => o.TableNumber == cleanTable || o.TableNumber == altTable);
    }

    private async Task<List<TableOrder>> LoadActiveTableOrdersAsync(
        Guid businessId,
        string tableNumber,
        CancellationToken ct)
    {
        var ver = TableSyncManager.GetTableVersion(businessId, tableNumber);
        var chatKey = GetChatKey(businessId, tableNumber);
        var cacheKey = $"tbl-active:{businessId:N}:{chatKey}:{ver}";
        if (_cache.TryGetValue(cacheKey, out List<TableOrder>? cached) && cached != null)
            return cached;

        var cutoff = DateTime.UtcNow.AddHours(-12);
        var latestSettlement = await FilterByTable(
                _db.TableOrders.AsNoTracking().Where(o =>
                    o.BusinessId == businessId &&
                    o.CreatedAt >= cutoff &&
                    (o.Status == "PAID" || o.Status == "SETTLED")),
                tableNumber)
            .OrderByDescending(o => o.UpdatedAt ?? o.CreatedAt)
            .Select(o => (DateTime?)(o.UpdatedAt ?? o.CreatedAt))
            .FirstOrDefaultAsync(ct);

        var query = FilterByTable(
            _db.TableOrders.AsNoTracking().Where(o =>
                o.BusinessId == businessId &&
                o.CreatedAt >= cutoff &&
                o.Status != "PAID" &&
                o.Status != "SETTLED"),
            tableNumber);

        if (latestSettlement != null)
            query = query.Where(o => o.CreatedAt > latestSettlement.Value);

        var result = await query
            .OrderBy(o => o.Round)
            .ThenBy(o => o.CreatedAt)
            .ToListAsync(ct);

        _cache.Set(cacheKey, result, TimeSpan.FromSeconds(15));
        return result;
    }

    private async Task<SharedCartResponse> BuildSharedCartResponseAsync(
        Guid businessId,
        string tableNumber,
        string? sessionToken,
        bool? knownHasActiveOrders = null,
        CancellationToken ct = default)
    {
        var key = GetChatKey(businessId, tableNumber);
        var state = _tableSharedCartStore.TryGetValue(key, out var s) ? s : new SharedCartState();
        var hasActiveOrders = knownHasActiveOrders ?? await HasActiveOrdersForTableAsync(businessId, tableNumber, ct);

        if (hasActiveOrders)
        {
            var isDinerSession = !string.IsNullOrWhiteSpace(sessionToken) &&
                                 _activeTableSessionTokens.TryGetValue(key, out var activeToken) &&
                                 activeToken == sessionToken.Trim();

            if (!isDinerSession)
            {
                return new SharedCartResponse
                {
                    TableNumber = tableNumber,
                    Items = new List<SharedCartItemDto>(),
                    TotalItems = 0,
                    TotalAmount = 0,
                    UpdatedAt = DateTime.UtcNow,
                };
            }
        }
        else if (state.Items.Count > 0)
        {
            var isExpired = (DateTime.UtcNow - state.UpdatedAt).TotalMinutes > 15;
            var isDifferentSession = !string.IsNullOrWhiteSpace(sessionToken) &&
                                     !string.IsNullOrWhiteSpace(state.SessionToken) &&
                                     !string.Equals(state.SessionToken, sessionToken.Trim(), StringComparison.OrdinalIgnoreCase);

            if (isExpired || isDifferentSession)
            {
                _tableSharedCartStore.TryRemove(key, out _);
                state = new SharedCartState();
            }
        }

        return new SharedCartResponse
        {
            TableNumber = tableNumber,
            Items = state.Items.ToList(),
            TotalItems = state.Items.Sum(i => i.Quantity),
            TotalAmount = state.Items.Sum(i => i.UnitPrice * i.Quantity),
            LastUpdatedBy = state.LastUpdatedBy,
            LastClientId = state.LastClientId,
            UpdatedAt = state.UpdatedAt,
        };
    }

    /// <summary>Public endpoint for WebAR customer to submit a table order ticket.</summary>
    [HttpPost("api/public/orders/{slug}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<TableOrderResponse>>> PlaceOrder(
        string slug,
        [FromBody] PlaceTableOrderRequest request,
        CancellationToken ct)
    {
        var resolvedTarget = await _lookupCache.ResolveSlugAsync(
            _db,
            slug,
            requireActiveQr: true,
            fallbackToAnyBusiness: true,
            ct);

        var business = resolvedTarget != null
            ? await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(b => b.Id == resolvedTarget.BusinessId, ct)
            : null;

        if (business == null)
            return NotFound(ApiResponse<TableOrderResponse>.Fail("Restaurant not found"));



        if (business.Status == ARSmartMenu.Domain.Enums.BusinessStatus.Deactivated)

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("This restaurant is currently closed or deactivated. Orders cannot be placed."));



        if (business.Status == ARSmartMenu.Domain.Enums.BusinessStatus.Suspended)

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("This restaurant account is currently suspended."));



        var hasActiveSub = await _db.Subscriptions

            .AnyAsync(s => s.BusinessId == business.Id && s.Status == ARSmartMenu.Domain.Enums.SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);

        if (!hasActiveSub)

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("This restaurant's smart menu subscription has expired. Orders cannot be accepted at this time."));



        var (isValidTable, validTables) = await ValidateTableForBusinessAsync(business.Id, request.TableNumber, ct);

        if (!isValidTable)

        {

            var rangeText = validTables.Count > 0

                ? $"This restaurant has configured Tables 1 to {validTables.Last()} ({string.Join(", ", validTables.Select(t => $"Table {t}"))})."

                : "Invalid table specified.";

            return BadRequest(ApiResponse<TableOrderResponse>.Fail(

                $"Table '{request.TableNumber}' is not a valid table at {business.BusinessName}. {rangeText} Please scan the QR code placed on your table."));

        }



        if (!string.IsNullOrWhiteSpace(request.CustomerPhone))
        {
            var digitsOnly = System.Text.RegularExpressions.Regex.Replace(request.CustomerPhone.Trim(), @"\D", "");
            if (digitsOnly.Length != 10)
                return BadRequest(ApiResponse<TableOrderResponse>.Fail("Customer mobile number must be exactly 10 numeric digits."));
        }

        // GPS Geofence Anti-Fraud Check for Dine-In orders
        if (business.RequireGeofence && business.Latitude.HasValue && business.Longitude.HasValue)
        {
            if (!request.CustomerLatitude.HasValue || !request.CustomerLongitude.HasValue)
            {
                return BadRequest(new ApiResponse<TableOrderResponse>
                {
                    Success = false,
                    Code = "GEOFENCE_REQUIRED",
                    Error = "Location permission required",
                    Message = "Please allow location access to verify you are physically at the table before placing a dine-in order."
                });
            }

            var distance = GeoUtils.CalculateDistanceMeters(
                request.CustomerLatitude.Value,
                request.CustomerLongitude.Value,
                business.Latitude.Value,
                business.Longitude.Value);

            var allowedMeters = business.GeofenceRadiusMeters > 0 ? business.GeofenceRadiusMeters : 200;

            if (distance > allowedMeters)
            {
                var distanceLabel = distance >= 1000
                    ? $"{Math.Round(distance / 1000.0, 1)}km"
                    : $"{Math.Round(distance)}m";

                return BadRequest(new ApiResponse<TableOrderResponse>
                {
                    Success = false,
                    Code = "OUTSIDE_GEOFENCE",
                    Error = $"You appear to be {distanceLabel} away from {business.BusinessName}.",
                    Message = $"Dine-in table ordering is only permitted within {allowedMeters}m of the restaurant. If you scanned a photo of this QR code from home or outside, table ordering is disabled."
                });
            }
        }

        var cleanTable = request.TableNumber.Trim().ToLowerInvariant();
        var altTable = cleanTable.StartsWith("table") ? cleanTable.Replace("table", "").Trim() : ("table " + cleanTable);
        var tableDigits = Regex.Match(cleanTable, @"\d+").Value;
        var altTableNum = !string.IsNullOrEmpty(tableDigits) ? ("table " + tableDigits) : altTable;

        // Serialized table lock ensures one-by-one execution with zero race conditions
        using var tableLock = await TableSyncManager.AcquireTableLockAsync(business.Id, request.TableNumber, ct);
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {
        var cutoff = DateTime.UtcNow.AddHours(-12);

        var latestSettlement = await _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == business.Id && o.CreatedAt >= cutoff &&
                        (o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable ||
                         (!string.IsNullOrEmpty(tableDigits) && (o.TableNumber.ToLower() == tableDigits || o.TableNumber.ToLower() == altTableNum))) &&
                        (o.Status == "PAID" || o.Status == "SETTLED"))
            .OrderByDescending(o => o.UpdatedAt ?? o.CreatedAt)
            .Select(o => (DateTime?)(o.UpdatedAt ?? o.CreatedAt))
            .FirstOrDefaultAsync(ct);

        var activeOrdersQuery = _db.TableOrders
            .Where(o => o.BusinessId == business.Id && o.CreatedAt >= cutoff &&
                        (o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable ||
                         (!string.IsNullOrEmpty(tableDigits) && (o.TableNumber.ToLower() == tableDigits || o.TableNumber.ToLower() == altTableNum))) &&
                        (o.Status == "PENDING" || o.Status == "ACCEPTED" || o.Status == "COMPLETED" || o.BillRequested));

        if (latestSettlement != null)
        {
            activeOrdersQuery = activeOrdersQuery.Where(o => o.CreatedAt > latestSettlement.Value);
        }

        var activeOrders = await activeOrdersQuery.OrderBy(o => o.CreatedAt).ToListAsync(ct);

        var chatKey = GetChatKey(business.Id, cleanTable);

        if (activeOrders.Count > 0)
        {
            // If final bill has already been requested, additional rounds cannot be ordered
            if (activeOrders.Any(o => o.BillRequested))
            {
                return BadRequest(ApiResponse<TableOrderResponse>.Fail(
                    $"A final bill has already been requested for {request.TableNumber}. Additional rounds cannot be ordered until the table is settled or cleared."));
            }

            // Multi-diner collaboration with 3-digit Table Party PIN
            var activePartyPin = activeOrders.FirstOrDefault(o => !string.IsNullOrEmpty(o.PartyPin))?.PartyPin;
            if (string.IsNullOrEmpty(activePartyPin))
            {
                activePartyPin = Random.Shared.Next(100, 1000).ToString();
            }

            var isSameSession = false;
            if (!string.IsNullOrWhiteSpace(request.SessionToken) &&
                _activeTableSessionTokens.TryGetValue(chatKey, out var existingToken) &&
                existingToken == request.SessionToken)
            {
                isSameSession = true;
            }

            if (!isSameSession && !string.IsNullOrWhiteSpace(request.PartyPin) && request.PartyPin.Trim() == activePartyPin)
            {
                isSameSession = true;
            }

            // If a different device tries to order without verified session or PIN:
            if (!isSameSession && _activeTableSessionTokens.ContainsKey(chatKey))
            {
                return BadRequest(new ApiResponse<TableOrderResponse>
                {
                    Success = false,
                    Code = "REQUIRE_PARTY_PIN",
                    Error = $"Table '{request.TableNumber}' has an active order.",
                    Message = $"Table '{request.TableNumber}' currently has an active order. If you are sitting with friends, please enter the 3-digit Table PIN to join."
                });
            }

            // Keep session token updated for this table
            if (!string.IsNullOrWhiteSpace(request.SessionToken))
            {
                _activeTableSessionTokens[chatKey] = request.SessionToken;
            }

            // Auto-increment round number accurately across all companion orders
            var maxRound = activeOrders.Max(o => o.Round);
            if (request.Round <= maxRound)
            {
                request.Round = maxRound + 1;
            }
        }
        else
        {
            // First order of a fresh table session: register session token if provided
            if (!string.IsNullOrWhiteSpace(request.SessionToken))
            {
                _activeTableSessionTokens[chatKey] = request.SessionToken;
            }
        }

        var assignedPartyPin = (activeOrders.Count > 0
            ? activeOrders.FirstOrDefault(o => !string.IsNullOrEmpty(o.PartyPin))?.PartyPin
            : null) ?? Random.Shared.Next(100, 1000).ToString();

        if (request.Items == null || request.Items.Count == 0)
        {
            return BadRequest(ApiResponse<TableOrderResponse>.Fail("Order cannot be empty. Please select dishes from the menu."));
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var productGuids = request.Items
            .Where(i => Guid.TryParse(i.Id, out _))
            .Select(i => Guid.Parse(i.Id))
            .ToList();
        var productNames = request.Items
            .Select(i => i.Name)
            .Where(n => !string.IsNullOrWhiteSpace(n))
            .ToList();

        var soldOutList = await _db.Products
            .AsNoTracking()
            .Where(p => p.BusinessId == business.Id &&
                        p.SoldOutToday &&
                        (p.SoldOutDate == null || p.SoldOutDate == today) &&
                        (productGuids.Contains(p.Id) || productNames.Contains(p.Name)))
            .Select(p => p.Name)
            .ToListAsync(ct);

        if (soldOutList.Count > 0)
        {
            return BadRequest(ApiResponse<TableOrderResponse>.Fail(
                $"The following item(s) are sold out for today and cannot be ordered: {string.Join(", ", soldOutList.Distinct())}. Please remove them from your cart."));
        }

        var itemsJson = JsonSerializer.Serialize(request.Items ?? new List<TableOrderItemDto>(), CompactJsonOptions);

        var totalAmount = (request.Items ?? new List<TableOrderItemDto>()).Sum(i => i.UnitPrice * i.Quantity);



        var order = new TableOrder

        {

            BusinessId = business.Id,

            TableNumber = string.IsNullOrWhiteSpace(request.TableNumber) ? "Dine-in" : request.TableNumber.Trim(),

            Round = request.Round > 0 ? request.Round : 1,

            Status = "PENDING",

            Instructions = request.Instructions?.Trim() ?? string.Empty,

            CustomerPhone = request.CustomerPhone?.Trim() ?? string.Empty,

            ItemsJson = itemsJson,

            TotalAmount = totalAmount,

            PartyPin = assignedPartyPin,

        };



        _db.TableOrders.Add(order);

        await _db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        _tableSharedCartStore.TryRemove(chatKey, out _);
        _tableSharedCartStore.TryRemove(GetChatKey(business.Id, request.TableNumber), out _);
        _tableSharedCartStore.TryRemove(GetChatKey(business.Id, cleanTable), out _);
        if (!string.IsNullOrEmpty(altTable)) _tableSharedCartStore.TryRemove(GetChatKey(business.Id, altTable), out _);
        if (!string.IsNullOrEmpty(altTableNum)) _tableSharedCartStore.TryRemove(GetChatKey(business.Id, altTableNum), out _);

        TableSyncManager.Broadcast(business.Id, order.TableNumber, "order_placed", new { orderId = order.Id, round = order.Round, table = order.TableNumber });
        TableSyncManager.Broadcast(business.Id, order.TableNumber, "shared_cart_cleared", new { table = order.TableNumber });
        if (!string.IsNullOrEmpty(altTable)) TableSyncManager.Broadcast(business.Id, altTable, "shared_cart_cleared", new { table = altTable });
        if (!string.IsNullOrEmpty(altTableNum)) TableSyncManager.Broadcast(business.Id, altTableNum, "shared_cart_cleared", new { table = altTableNum });
        return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(order), "Order submitted to kitchen"));
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }

    }

    private async Task<bool> HasActiveOrdersForTableAsync(Guid businessId, string tableNumber, CancellationToken ct = default)
    {
        var cutoff = DateTime.UtcNow.AddHours(-12);
        var latestSettlement = await FilterByTable(
                _db.TableOrders.AsNoTracking().Where(o =>
                    o.BusinessId == businessId &&
                    o.CreatedAt >= cutoff &&
                    (o.Status == "PAID" || o.Status == "SETTLED")),
                tableNumber)
            .OrderByDescending(o => o.UpdatedAt ?? o.CreatedAt)
            .Select(o => (DateTime?)(o.UpdatedAt ?? o.CreatedAt))
            .FirstOrDefaultAsync(ct);

        var query = FilterByTable(
            _db.TableOrders.AsNoTracking().Where(o =>
                o.BusinessId == businessId &&
                o.CreatedAt >= cutoff &&
                o.Status != "PAID" &&
                o.Status != "SETTLED" &&
                o.Status != "CANCELLED"),
            tableNumber);

        if (latestSettlement != null)
            query = query.Where(o => o.CreatedAt > latestSettlement.Value);

        return await query.AnyAsync(ct);
    }

    /// <summary>
    /// Phase 2.4: Multiplayer Collaborative Cart - Get current shared table cart.
    /// If no active orders exist and the session is new or cart expired (>15m), draft cart is cleared.
    /// </summary>
    [HttpGet("api/public/orders/{slug}/table/{tableNumber}/shared-cart")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<SharedCartResponse>>> GetSharedCart(
        string slug,
        string tableNumber,
        [FromQuery] string? sessionToken = null,
        CancellationToken ct = default)
    {
        var businessId = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!businessId.HasValue)
            return NotFound(ApiResponse<SharedCartResponse>.Fail("Restaurant not found"));

        var response = await BuildSharedCartResponseAsync(businessId.Value, tableNumber, sessionToken, ct: ct);
        return Ok(ApiResponse<SharedCartResponse>.Ok(response));
    }

    /// <summary>
    /// Phase 2.4: Multiplayer Collaborative Cart - Atomic upsert or remove a single item in table cart without wiping companions' items.
    /// </summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/shared-cart/item")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<SharedCartResponse>>> SetSharedCartItem(
        string slug,
        string tableNumber,
        [FromBody] SetSharedCartItemRequest request,
        CancellationToken ct = default)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<SharedCartResponse>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        if (request.TargetQuantity > 0)
        {
            var itemDishId = request.Item?.DishId;
            var itemName = request.Item?.Name;
            var today = DateOnly.FromDateTime(DateTime.UtcNow);

            var isSoldOut = false;
            if (Guid.TryParse(itemDishId, out var parsedDishGuid))
            {
                isSoldOut = await _db.Products.AsNoTracking().AnyAsync(p =>
                    p.BusinessId == businessId &&
                    p.Id == parsedDishGuid &&
                    p.SoldOutToday &&
                    (p.SoldOutDate == null || p.SoldOutDate == today), ct);
            }
            else if (!string.IsNullOrWhiteSpace(itemName))
            {
                isSoldOut = await _db.Products.AsNoTracking().AnyAsync(p =>
                    p.BusinessId == businessId &&
                    p.Name == itemName.Trim() &&
                    p.SoldOutToday &&
                    (p.SoldOutDate == null || p.SoldOutDate == today), ct);
            }

            if (isSoldOut)
            {
                return BadRequest(ApiResponse<SharedCartResponse>.Fail(
                    $"\"{request.Item?.Name ?? "This item"}\" is marked as sold out for today and cannot be added."));
            }
        }

        using var tableLock = await TableSyncManager.AcquireTableLockAsync(businessId, tableNumber, ct);
        var key = GetChatKey(businessId, tableNumber);
        var state = _tableSharedCartStore.GetOrAdd(key, _ => new SharedCartState());

        lock (state)
        {
            if (!string.IsNullOrWhiteSpace(request.SessionToken))
            {
                state.SessionToken = request.SessionToken.Trim();
            }
            var item = request.Item ?? new SharedCartItemDto();
            var clientName = string.IsNullOrWhiteSpace(request.ClientName) ? "Guest" : request.ClientName.Trim();
            var clientId = request.ClientId ?? string.Empty;

            var existingIndex = state.Items.FindIndex(i =>
                (!string.IsNullOrWhiteSpace(item.Id) && !string.IsNullOrWhiteSpace(i.Id) && i.Id == item.Id) ||
                (i.DishId == item.DishId &&
                 string.Join(",", i.Modifiers ?? new List<string>()) == string.Join(",", item.Modifiers ?? new List<string>()) &&
                 (i.Notes ?? string.Empty).Trim() == (item.Notes ?? string.Empty).Trim()));

            if (request.TargetQuantity <= 0)
            {
                if (existingIndex >= 0)
                {
                    state.Items.RemoveAt(existingIndex);
                }
            }
            else
            {
                if (existingIndex >= 0)
                {
                    var existing = state.Items[existingIndex];
                    if (!string.IsNullOrWhiteSpace(item.Id)) existing.Id = item.Id;
                    existing.Quantity = request.TargetQuantity;
                    if (item.UnitPrice > 0) existing.UnitPrice = item.UnitPrice;
                    if (item.Modifiers != null) existing.Modifiers = item.Modifiers;
                    existing.Notes = item.Notes;
                    existing.AddedBy = clientName;
                    existing.ClientId = clientId;
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    if (string.IsNullOrWhiteSpace(item.Id))
                    {
                        item.Id = Guid.NewGuid().ToString();
                    }
                    item.Quantity = request.TargetQuantity;
                    item.AddedBy = clientName;
                    item.ClientId = clientId;
                    item.UpdatedAt = DateTime.UtcNow;
                    state.Items.Add(item);
                }
            }

            state.LastUpdatedBy = clientName;
            state.LastClientId = clientId;
            state.UpdatedAt = DateTime.UtcNow;
        }

        var totalItems = state.Items.Sum(i => i.Quantity);
        var totalAmount = state.Items.Sum(i => i.UnitPrice * i.Quantity);

        TableSyncManager.Broadcast(businessId, tableNumber, "shared_cart_updated", new
        {
            table = tableNumber,
            totalItems,
            totalAmount,
            updatedBy = state.LastUpdatedBy,
            clientId = state.LastClientId,
            dishName = request.Item?.Name,
            targetQuantity = request.TargetQuantity,
        });

        var response = new SharedCartResponse
        {
            TableNumber = tableNumber,
            Items = state.Items.ToList(),
            TotalItems = totalItems,
            TotalAmount = totalAmount,
            LastUpdatedBy = state.LastUpdatedBy,
            LastClientId = state.LastClientId,
            UpdatedAt = state.UpdatedAt,
        };

        return Ok(ApiResponse<SharedCartResponse>.Ok(response, "Table cart updated"));
    }

    /// <summary>
    /// Phase 2.4: Multiplayer Collaborative Cart - Update table cart with smart merge (retains companions' items).
    /// </summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/shared-cart")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<SharedCartResponse>>> UpdateSharedCart(
        string slug,
        string tableNumber,
        [FromBody] UpdateSharedCartRequest request,
        CancellationToken ct = default)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<SharedCartResponse>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        if (request.Items != null && request.Items.Count > 0)
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var itemDishGuids = request.Items
                .Where(i => Guid.TryParse(i.DishId, out _))
                .Select(i => Guid.Parse(i.DishId))
                .ToList();
            var incomingNames = request.Items
                .Select(i => i.Name)
                .Where(n => !string.IsNullOrWhiteSpace(n))
                .ToList();

            var soldOutNames = await _db.Products.AsNoTracking()
                .Where(p => p.BusinessId == businessId &&
                            p.SoldOutToday &&
                            (p.SoldOutDate == null || p.SoldOutDate == today) &&
                            (itemDishGuids.Contains(p.Id) || incomingNames.Contains(p.Name)))
                .Select(p => p.Name)
                .ToListAsync(ct);

            if (soldOutNames.Count > 0)
            {
                return BadRequest(ApiResponse<SharedCartResponse>.Fail(
                    $"The following dish(es) are sold out for today: {string.Join(", ", soldOutNames.Distinct())}."));
            }
        }

        using var tableLock = await TableSyncManager.AcquireTableLockAsync(businessId, tableNumber, ct);
        var key = GetChatKey(businessId, tableNumber);
        var state = _tableSharedCartStore.GetOrAdd(key, _ => new SharedCartState());

        lock (state)
        {
            if (!string.IsNullOrWhiteSpace(request.SessionToken))
            {
                state.SessionToken = request.SessionToken.Trim();
            }
            var incomingItems = request.Items ?? new List<SharedCartItemDto>();
            var clientName = string.IsNullOrWhiteSpace(request.ClientName) ? "Guest" : request.ClientName.Trim();
            var clientId = request.ClientId ?? string.Empty;

            // Retain items added by OTHER companions (never wipe companions' items!)
            var otherItems = state.Items
                .Where(i => !string.IsNullOrEmpty(i.ClientId) && i.ClientId != clientId)
                .ToList();

            foreach (var item in incomingItems)
            {
                if (string.IsNullOrEmpty(item.ClientId)) item.ClientId = clientId;
                if (string.IsNullOrEmpty(item.AddedBy)) item.AddedBy = clientName;
            }

            var merged = new List<SharedCartItemDto>(otherItems);
            foreach (var item in incomingItems)
            {
                var idx = merged.FindIndex(m => m.DishId == item.DishId);
                if (idx >= 0)
                {
                    merged[idx].Quantity = item.Quantity;
                    merged[idx].AddedBy = item.AddedBy;
                    merged[idx].ClientId = item.ClientId;
                }
                else
                {
                    merged.Add(item);
                }
            }

            state.Items = merged;
            state.LastUpdatedBy = clientName;
            state.LastClientId = clientId;
            state.UpdatedAt = DateTime.UtcNow;
        }

        var totalItems = state.Items.Sum(i => i.Quantity);
        var totalAmount = state.Items.Sum(i => i.UnitPrice * i.Quantity);

        // Real-time broadcast to all diner phones listening on this table
        TableSyncManager.Broadcast(businessId, tableNumber, "shared_cart_updated", new
        {
            table = tableNumber,
            totalItems,
            totalAmount,
            updatedBy = state.LastUpdatedBy,
            clientId = state.LastClientId,
        });

        var response = new SharedCartResponse
        {
            TableNumber = tableNumber,
            Items = state.Items.ToList(),
            TotalItems = totalItems,
            TotalAmount = totalAmount,
            LastUpdatedBy = state.LastUpdatedBy,
            LastClientId = state.LastClientId,
            UpdatedAt = state.UpdatedAt,
        };

        return Ok(ApiResponse<SharedCartResponse>.Ok(response, "Table cart synchronized"));
    }

    /// <summary>
    /// Phase 2.4: Multiplayer Collaborative Cart - Clear table cart.
    /// </summary>
    [HttpDelete("api/public/orders/{slug}/table/{tableNumber}/shared-cart")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<bool>>> ClearSharedCart(
        string slug,
        string tableNumber,
        CancellationToken ct = default)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<bool>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var (cleanTable, altTable, _, altTableNum) = BuildTableVariants(tableNumber);

        var key = GetChatKey(businessId, tableNumber);
        _tableSharedCartStore.TryRemove(key, out _);
        _tableSharedCartStore.TryRemove(GetChatKey(businessId, cleanTable), out _);
        if (!string.IsNullOrEmpty(altTable)) _tableSharedCartStore.TryRemove(GetChatKey(businessId, altTable), out _);
        if (!string.IsNullOrEmpty(altTableNum)) _tableSharedCartStore.TryRemove(GetChatKey(businessId, altTableNum), out _);

        TableSyncManager.Broadcast(businessId, tableNumber, "shared_cart_cleared", new { table = tableNumber });
        if (!string.IsNullOrEmpty(altTable)) TableSyncManager.Broadcast(businessId, altTable, "shared_cart_cleared", new { table = altTable });
        if (!string.IsNullOrEmpty(altTableNum)) TableSyncManager.Broadcast(businessId, altTableNum, "shared_cart_cleared", new { table = altTableNum });

        return Ok(ApiResponse<bool>.Ok(true, "Table cart cleared"));
    }

    /// <summary>
    /// Phase 2.4: Instantly clear unplaced draft cart when diner leaves/closes browser tab.
    /// </summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/abandon-cart")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<bool>>> AbandonCart(
        string slug,
        string tableNumber,
        [FromQuery] string? sessionToken = null,
        CancellationToken ct = default)
    {
        var businessId = await ResolveBusinessIdAsync(slug, ct: ct);
        if (businessId.HasValue)
        {
            var key = GetChatKey(businessId.Value, tableNumber);
            if (_tableSharedCartStore.TryGetValue(key, out var state))
            {
                var hasActiveOrders = await HasActiveOrdersForTableAsync(businessId.Value, tableNumber, ct);
                if (!hasActiveOrders)
                {
                    if (string.IsNullOrWhiteSpace(sessionToken) ||
                        string.IsNullOrWhiteSpace(state.SessionToken) ||
                        string.Equals(state.SessionToken, sessionToken.Trim(), StringComparison.OrdinalIgnoreCase))
                    {
                        _tableSharedCartStore.TryRemove(key, out _);
                        TableSyncManager.Broadcast(businessId.Value, tableNumber, "shared_cart_cleared", new { table = tableNumber });
                    }
                }
            }
        }

        return Ok(ApiResponse<bool>.Ok(true, "Draft cart abandoned"));
    }

    private async Task<(bool TableInvalid, bool IsPartyBlocked, bool HasNonCancelledOrders, List<TableOrderResponse> Orders)> EvaluatePublicTableOrdersAsync(
        Guid businessId,
        string tableNumber,
        string? orderIds,
        string? sessionToken,
        CancellationToken ct)
    {
        var (isValidPublicTable, _) = await _lookupCache.ValidateTableForBusinessAsync(_db, businessId, tableNumber, ct);
        if (!isValidPublicTable)
            return (true, false, false, new List<TableOrderResponse>());

        var activeOrders = await LoadActiveTableOrdersAsync(businessId, tableNumber, ct);
        var (cleanTable, _, _, _) = BuildTableVariants(tableNumber);

        List<Guid> parsedIds = new();
        if (!string.IsNullOrWhiteSpace(orderIds))
        {
            foreach (var part in orderIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                if (Guid.TryParse(part.Trim(), out var parsedId))
                    parsedIds.Add(parsedId);
            }
        }

        var nonCancelledOrders = activeOrders.Where(o => o.Status != "CANCELLED").ToList();
        if (nonCancelledOrders.Count > 0)
        {
            var chatKey = GetChatKey(businessId, cleanTable);
            var isDinerSession = false;

            if (!string.IsNullOrWhiteSpace(sessionToken) &&
                _activeTableSessionTokens.TryGetValue(chatKey, out var activeToken) &&
                activeToken == sessionToken)
            {
                isDinerSession = true;
            }

            if (!isDinerSession && parsedIds.Count > 0 && activeOrders.Any(o => parsedIds.Contains(o.Id)))
            {
                isDinerSession = true;
            }

            if (!isDinerSession)
                return (false, true, true, new List<TableOrderResponse>());

            if (!string.IsNullOrWhiteSpace(sessionToken))
                _activeTableSessionTokens[chatKey] = sessionToken;
        }
        else if (parsedIds.Count == 0)
        {
            return (false, false, false, new List<TableOrderResponse>());
        }

        return (false, false, nonCancelledOrders.Count > 0, activeOrders.Select(ToResponse).ToList());
    }

    /// <summary>Public live order status for diner tracking on their table.</summary>
    [HttpGet("api/public/orders/{slug}/table/{tableNumber}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<List<TableOrderResponse>>>> GetTableOrdersPublic(
        string slug,
        string tableNumber,
        [FromQuery] string? orderIds = null,
        [FromQuery] string? sessionToken = null,
        [FromQuery] long? sinceVersion = null,
        CancellationToken ct = default)
    {
        var businessId = await ResolveBusinessIdAsync(slug, ct: ct)
            ?? throw new NotFoundException("Restaurant not found.");

        var currentTableVersion = TableSyncManager.GetTableVersion(businessId, tableNumber);
        Response.Headers["X-Table-Version"] = currentTableVersion.ToString();

        if (sinceVersion.HasValue && sinceVersion.Value == currentTableVersion)
        {
            return Ok(new ApiResponse<List<TableOrderResponse>>
            {
                Success = true,
                Code = "UNCHANGED",
                Message = currentTableVersion.ToString(),
                Data = new List<TableOrderResponse>()
            });
        }

        var (_, isPartyBlocked, _, orders) = await EvaluatePublicTableOrdersAsync(businessId, tableNumber, orderIds, sessionToken, ct);
        if (isPartyBlocked)
        {
            return Ok(new ApiResponse<List<TableOrderResponse>>
            {
                Success = false,
                Code = "TABLE_OCCUPIED",
                Error = $"Table '{tableNumber}' has an active order.",
                Message = $"Table '{tableNumber}' currently has an active order. If you are sitting with friends, please enter the 3-digit Table PIN to join.",
                Data = new List<TableOrderResponse>()
            });
        }

        return Ok(ApiResponse<List<TableOrderResponse>>.Ok(orders));
    }

    /// <summary>
    /// Combined single-roundtrip WebAR polling endpoint returning BOTH table orders and shared cart.
    /// Returns immediately with zero DB queries when sinceVersion matches the in-memory table version.
    /// </summary>
    [HttpGet("api/public/orders/{slug}/table/{tableNumber}/poll")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> PollTableStatePublic(
        string slug,
        string tableNumber,
        [FromQuery] string? orderIds = null,
        [FromQuery] string? sessionToken = null,
        [FromQuery] long? sinceVersion = null,
        CancellationToken ct = default)
    {
        var businessId = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!businessId.HasValue)
            return NotFound(ApiResponse<object>.Fail("Restaurant not found."));

        var currentTableVersion = TableSyncManager.GetTableVersion(businessId.Value, tableNumber);
        Response.Headers["X-Table-Version"] = currentTableVersion.ToString();

        if (sinceVersion.HasValue && sinceVersion.Value == currentTableVersion)
        {
            return Ok(ApiResponse<object>.Ok(new
            {
                version = currentTableVersion,
                unchanged = true
            }));
        }

        var (_, isPartyBlocked, hasNonCancelledOrders, orders) = await EvaluatePublicTableOrdersAsync(businessId.Value, tableNumber, orderIds, sessionToken, ct);
        if (isPartyBlocked)
        {
            return Ok(new ApiResponse<object>
            {
                Success = false,
                Code = "TABLE_OCCUPIED",
                Error = $"Table '{tableNumber}' has an active order.",
                Message = $"Table '{tableNumber}' currently has an active order. If you are sitting with friends, please enter the 3-digit Table PIN to join.",
                Data = new
                {
                    version = currentTableVersion,
                    unchanged = false,
                    orders = Array.Empty<TableOrderResponse>(),
                    sharedCart = (SharedCartResponse?)null
                }
            });
        }

        var sharedCart = await BuildSharedCartResponseAsync(
            businessId.Value,
            tableNumber,
            sessionToken,
            knownHasActiveOrders: hasNonCancelledOrders,
            ct: ct);

        return Ok(ApiResponse<object>.Ok(new
        {
            version = currentTableVersion,
            unchanged = false,
            orders,
            sharedCart
        }));
    }

    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/join")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<List<TableOrderResponse>>>> JoinTableParty(
        string slug,
        string tableNumber,
        [FromBody] JoinTablePartyRequest? request,
        CancellationToken ct)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<List<TableOrderResponse>>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var (cleanTable, _, _, _) = BuildTableVariants(tableNumber);
        var cutoff = DateTime.UtcNow.AddHours(-12);
        var activeOrders = await FilterByTable(
                _db.TableOrders.AsNoTracking().Where(o =>
                    o.BusinessId == businessId &&
                    o.CreatedAt >= cutoff &&
                    o.Status != "PAID" &&
                    o.Status != "SETTLED" &&
                    o.Status != "CANCELLED"),
                tableNumber)
            .OrderBy(o => o.Round)
            .ThenBy(o => o.CreatedAt)
            .ToListAsync(ct);

        if (activeOrders.Count > 0)
        {
            var activePartyPin = activeOrders.FirstOrDefault(o => !string.IsNullOrEmpty(o.PartyPin))?.PartyPin;
            if (!string.IsNullOrEmpty(activePartyPin))
            {
                if (string.IsNullOrWhiteSpace(request?.Pin) || request.Pin.Trim() != activePartyPin)
                {
                    return BadRequest(ApiResponse<List<TableOrderResponse>>.Fail("Invalid 3-digit Table PIN. Please ask your friend at the table for the PIN displayed on their screen."));
                }
            }
        }

        var chatKey = GetChatKey(businessId, cleanTable);
        if (!string.IsNullOrWhiteSpace(request?.SessionToken))
        {
            _activeTableSessionTokens[chatKey] = request.SessionToken.Trim();
        }

        var responses = activeOrders.Select(ToResponse).ToList();
        return Ok(ApiResponse<List<TableOrderResponse>>.Ok(responses, "Joined table party successfully!"));
    }

    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/claim-new-party")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> ClaimNewParty(
        string slug,
        string tableNumber,
        [FromBody] ClaimNewPartyRequest? request,
        CancellationToken ct)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<object>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var (isValid, _) = await ValidateTableForBusinessAsync(businessId, tableNumber, ct);
        if (!isValid)
        {
            return BadRequest(ApiResponse<object>.Fail($"Invalid table '{tableNumber}'."));
        }

        var note = $"New party seated at Table {tableNumber.Trim()}! Previous orders pending settlement. 1-Tap verify to start fresh session.";
        var call = new TableWaiterCallDto
        {
            Id = Guid.NewGuid().ToString(),
            BusinessId = businessId,
            TableNumber = tableNumber.Trim(),
            Note = note,
            CreatedAt = DateTime.UtcNow,
            IsAttended = false
        };

        var key = GetChatKey(businessId, tableNumber);
        _waiterCallsStore.AddOrUpdate(key, call, (_, _) => call);

        TableSyncManager.Broadcast(businessId, tableNumber, "new_party_claimed", call);
        TableSyncManager.Broadcast(businessId, tableNumber, "waiter_called", call);

        return Ok(ApiResponse<object>.Ok(new { tableNumber, note }, "Staff alerted! Please wait while table is verified and reset."));
    }



    /// <summary>Get table orders for a business (owner portal).</summary>

    [HttpGet("api/businesses/{businessId}/table-orders")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<List<TableOrderResponse>>>> GetOrders(
        Guid businessId,
        [FromQuery] string? status,
        [FromQuery] long? sinceVersion = null,
        CancellationToken ct = default)
    {
        var bizVersion = TableSyncManager.GetBusinessVersion(businessId);
        Response.Headers["X-Business-Version"] = bizVersion.ToString();

        if (sinceVersion.HasValue && sinceVersion.Value == bizVersion)
        {
            return Ok(new ApiResponse<List<TableOrderResponse>>
            {
                Success = true,
                Code = "UNCHANGED",
                Message = bizVersion.ToString(),
                Data = new List<TableOrderResponse>()
            });
        }

        var st = string.IsNullOrWhiteSpace(status) ? "ALL" : status.Trim().ToUpperInvariant();
        var cacheKey = $"biz-orders:{businessId:N}:{st}:{bizVersion}";
        if (_cache.TryGetValue(cacheKey, out List<TableOrderResponse>? cached) && cached != null)
            return Ok(ApiResponse<List<TableOrderResponse>>.Ok(cached));

        var cutoff = DateTime.UtcNow.AddHours(-18);
        var query = _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff);

        if (st == "ACTIVE" || st == "LIVE")
        {
            query = query.Where(o => o.Status != "CANCELLED" && o.Status != "PAID" && o.Status != "SETTLED");
        }
        else if (st == "TODAY" || st == "HISTORY")
        {
            var startOfToday = DateTime.UtcNow.Date;
            query = _db.TableOrders
                .AsNoTracking()
                .Where(o => o.BusinessId == businessId && o.CreatedAt >= startOfToday.AddHours(-6) && o.Status != "CANCELLED");
        }
        else if (st != "ALL")
        {
            query = query.Where(o => o.Status == st);
        }

        var list = await query
            .OrderByDescending(o => o.CreatedAt)
            .Take(80)
            .ToListAsync(ct);

        var responses = list.Select(ToResponse).ToList();
        _cache.Set(cacheKey, responses, TimeSpan.FromSeconds(15));
        return Ok(ApiResponse<List<TableOrderResponse>>.Ok(responses));
    }



    [HttpPost("api/orders/{id}/accept")]

    [AllowAnonymous]

    public Task<ActionResult<ApiResponse<TableOrderResponse>>> AcceptOrder(Guid id, CancellationToken ct) =>

        UpdateStatusAsync(id, "ACCEPTED", ct);



    [HttpPost("api/orders/{id}/cancel")]
    [HttpPost("api/public/orders/{id}/cancel")]
    [AllowAnonymous]
    public Task<ActionResult<ApiResponse<TableOrderResponse>>> CancelOrder(Guid id, CancellationToken ct) =>
        UpdateStatusAsync(id, "CANCELLED", ct);

    /// <summary>Clear/archive cancelled orders for a table so customer can start fresh.</summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/clear-cancelled")]
    [HttpPost("api/public/orders/{slug}/clear-cancelled")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<int>>> ClearCancelledOrders(
        string slug,
        string? tableNumber,
        [FromQuery] string? orderIds = null,
        CancellationToken ct = default)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<int>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var tNum = string.IsNullOrWhiteSpace(tableNumber) ? "dine-in" : tableNumber.Trim().ToLowerInvariant();
        var cutoff = DateTime.UtcNow.AddHours(-12);

        var query = _db.TableOrders
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff && o.Status == "CANCELLED");

        if (!string.IsNullOrWhiteSpace(orderIds))
        {
            var ids = orderIds.Split(',', StringSplitOptions.RemoveEmptyEntries)
                              .Select(s => Guid.TryParse(s.Trim(), out var g) ? g : Guid.Empty)
                              .Where(g => g != Guid.Empty).ToList();
            if (ids.Count > 0)
            {
                query = query.Where(o => ids.Contains(o.Id));
            }
        }
        else
        {
            query = FilterByTable(query, tNum);
        }

        var now = DateTime.UtcNow;
        var clearedCount = await query.ExecuteUpdateAsync(s => s
            .SetProperty(o => o.Status, "SETTLED")
            .SetProperty(o => o.UpdatedAt, now), ct);

        if (clearedCount > 0)
            TableSyncManager.Broadcast(businessId, tNum, "cancelled_cleared", new { table = tNum, clearedCount });

        return Ok(ApiResponse<int>.Ok(clearedCount, $"{clearedCount} cancelled order(s) cleared."));
    }

    [HttpPost("api/orders/{id}/complete")]
    [HttpPost("api/orders/{id}/serve")]
    [AllowAnonymous]
    public Task<ActionResult<ApiResponse<TableOrderResponse>>> CompleteOrder(Guid id, CancellationToken ct) =>
        UpdateStatusAsync(id, "COMPLETED", ct);

    /// <summary>Marks all accepted orders for a table as served/completed.</summary>
    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/serve-all")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<int>>> ServeAllForTable(Guid businessId, string tableNumber, CancellationToken ct)
    {
        var cutoff = DateTime.UtcNow.AddHours(-12);
        var now = DateTime.UtcNow;

        var updatedCount = await FilterByTable(
                _db.TableOrders.Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff && o.Status == "ACCEPTED"),
                tableNumber)
            .ExecuteUpdateAsync(s => s
                .SetProperty(o => o.Status, "COMPLETED")
                .SetProperty(o => o.CompletedAt, now)
                .SetProperty(o => o.UpdatedAt, now), ct);

        if (updatedCount > 0)
            TableSyncManager.Broadcast(businessId, tableNumber, "table_served", new { tableNumber, servedCount = updatedCount });

        return Ok(ApiResponse<int>.Ok(updatedCount, $"{updatedCount} items marked as served."));
    }

    /// <summary>Customer requests final bill from WebAR without needing WhatsApp.</summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/request-bill")]
    [HttpPost("api/public/orders/{slug}/request-bill")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<TableOrderResponse>>> RequestBill(
        string slug,
        string? tableNumber,
        [FromBody] RequestBillDto? body,
        CancellationToken ct)
    {
        var targetTable = !string.IsNullOrWhiteSpace(tableNumber) ? tableNumber : body?.TableNumber;
        if (string.IsNullOrWhiteSpace(targetTable))
            targetTable = "Dine-in";

        var businessId = await ResolveBusinessIdAsync(slug, ct: ct)
            ?? throw new NotFoundException("Restaurant not found.");



        var (isValidBillTable, validBillTables) = await ValidateTableForBusinessAsync(businessId, targetTable, ct);

        if (!isValidBillTable)

        {

            var rangeText = validBillTables.Count > 0

                ? $"This restaurant has configured Tables 1 to {validBillTables.Last()}."

                : "Invalid table specified.";

            return BadRequest(ApiResponse<TableOrderResponse>.Fail(

                $"Table '{targetTable}' is not a valid table at this restaurant. {rangeText} Please scan the QR code placed on your table."));

        }



        var cleanTable = targetTable.Trim().ToLowerInvariant();

        var altTable = cleanTable.StartsWith("table")

            ? cleanTable.Replace("table", "").Trim()

            : ("table " + cleanTable);

        var cutoff = DateTime.UtcNow.AddHours(-12);



        // Only query orders that belong to the current table session (exclude settled/paid history)

        var orders = await _db.TableOrders

            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff &&

                        o.Status != "PAID" && o.Status != "SETTLED" &&

                        (o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable))

            .ToListAsync(ct);



        var chatKey = GetChatKey(businessId, cleanTable);
        if (_activeTableSessionTokens.TryGetValue(chatKey, out var activeSessionToken) &&
            !string.IsNullOrWhiteSpace(activeSessionToken))
        {
            var isAuthorized = false;
            if (!string.IsNullOrWhiteSpace(body?.SessionToken) &&
                string.Equals(body.SessionToken.Trim(), activeSessionToken, StringComparison.OrdinalIgnoreCase))
            {
                isAuthorized = true;
            }

            if (!isAuthorized)
            {
                return BadRequest(ApiResponse<TableOrderResponse>.Fail("Unauthorized: Only diners seated at this table can request the bill."));
            }
        }



        if (orders.Count == 0)

        {

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("No active orders found for this table. Please place an order first."));

        }



        // Check if all active orders were declined/cancelled by the restaurant

        var nonCancelledOrders = orders.Where(o => o.Status != "CANCELLED").ToList();

        if (nonCancelledOrders.Count == 0)

        {

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("Cannot request bill because your order was declined by the restaurant. No bill is required."));

        }



        // Check if any order is still PENDING confirmation by the kitchen

        var pendingOrders = nonCancelledOrders.Where(o => o.Status == "PENDING").ToList();

        if (pendingOrders.Count > 0)

        {

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("Your order is still waiting for confirmation by the kitchen. The bill can only be requested once all dishes are accepted."));

        }



        // Ensure there is at least one ACCEPTED or COMPLETED (served) dish to bill

        var acceptedOrders = nonCancelledOrders.Where(o => o.Status == "ACCEPTED" || o.Status == "COMPLETED").ToList();

        if (acceptedOrders.Count == 0)

        {

            return BadRequest(ApiResponse<TableOrderResponse>.Fail("No accepted dishes found to bill. Please wait until your order is accepted by the kitchen."));

        }



        using var tableLock = await TableSyncManager.AcquireTableLockAsync(businessId, targetTable, ct);
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {
            foreach (var o in acceptedOrders)
            {
                o.BillRequested = true;
                o.BillRequestedAt = DateTime.UtcNow;
                o.UpdatedAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            TableSyncManager.Broadcast(businessId, targetTable, "bill_requested", new { table = targetTable });
            return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(acceptedOrders.Last()), "Bill requested successfully. Your server has been notified."));
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }

    }



    /// <summary>Closes table session and clears active orders and bill request.</summary>

    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/close")]
    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/verify-new-party")]

    [AllowAnonymous]

    public async Task<ActionResult<ApiResponse<int>>> CloseTable(Guid businessId, string tableNumber, CancellationToken ct)

    {

        var cleanTable = tableNumber.Trim().ToLowerInvariant();

        var altTable = cleanTable.StartsWith("table")

            ? cleanTable.Replace("table", "").Trim()

            : ("table " + cleanTable);

        var tableDigits = Regex.Match(cleanTable, @"\d+").Value;
        var altTableNum = !string.IsNullOrEmpty(tableDigits) ? ("table " + tableDigits) : altTable;

        using var tableLock = await TableSyncManager.AcquireTableLockAsync(businessId, tableNumber, ct);
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {
        var cutoff = DateTime.UtcNow.AddHours(-12);

        var orders = await _db.TableOrders
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff &&
                        (o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable ||
                         (!string.IsNullOrEmpty(tableDigits) && (o.TableNumber.ToLower() == tableDigits || o.TableNumber.ToLower() == altTableNum))) &&
                        o.Status != "PAID" && o.Status != "SETTLED")
            .ToListAsync(ct);

        foreach (var o in orders)
        {
            if (o.Status == "CANCELLED" || o.Status == "DECLINED")
            {
                o.Status = "SETTLED";
            }
            else
            {
                o.Status = "PAID";
            }

            o.BillRequested = false;

            o.CompletedAt ??= DateTime.UtcNow;

            o.UpdatedAt = DateTime.UtcNow;

        }



        await _db.SaveChangesAsync(ct);

        var chatKey = GetChatKey(businessId, cleanTable);
        _activeTableSessionTokens.TryRemove(chatKey, out _);
        if (!string.IsNullOrEmpty(altTable)) _activeTableSessionTokens.TryRemove(GetChatKey(businessId, altTable), out _);
        if (!string.IsNullOrEmpty(altTableNum)) _activeTableSessionTokens.TryRemove(GetChatKey(businessId, altTableNum), out _);

        _tableChatStore.TryRemove(chatKey, out _);
        _waiterCallsStore.TryRemove(chatKey, out _);
        _tableSharedCartStore.TryRemove(chatKey, out _);
        if (!string.IsNullOrEmpty(altTable)) _tableSharedCartStore.TryRemove(GetChatKey(businessId, altTable), out _);
        if (!string.IsNullOrEmpty(altTableNum)) _tableSharedCartStore.TryRemove(GetChatKey(businessId, altTableNum), out _);
        TableSyncManager.Broadcast(businessId, tableNumber, "shared_cart_cleared", new { table = tableNumber });

        await tx.CommitAsync(ct);
        TableSyncManager.Broadcast(businessId, tableNumber, "table_closed", new { tableNumber, closedCount = orders.Count });
        return Ok(ApiResponse<int>.Ok(orders.Count, "Table closed and dining session completed."));
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }

    }



    

    /// <summary>Public endpoint to get chat messages for a table.</summary>

    [HttpGet("api/public/orders/{slug}/table/{tableNumber}/chat")]

    [AllowAnonymous]

    public async Task<ActionResult<ApiResponse<List<TableChatMessageDto>>>> GetTableChatPublic(
        string slug,
        string tableNumber,
        CancellationToken ct)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<List<TableChatMessageDto>>.Fail("Restaurant not found"));
        var businessId = resolved.Value;



        var (isValidChatTable, _) = await ValidateTableForBusinessAsync(businessId, tableNumber, ct);

        if (!isValidChatTable)

        {

            return Ok(ApiResponse<List<TableChatMessageDto>>.Ok(new List<TableChatMessageDto>()));

        }



        var key = GetChatKey(businessId, tableNumber);

        var list = _tableChatStore.TryGetValue(key, out var msgs) ? msgs.ToList() : new List<TableChatMessageDto>();

        return Ok(ApiResponse<List<TableChatMessageDto>>.Ok(list));

    }



    /// <summary>Public endpoint for customer to post a chat message or service request.</summary>

    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/chat")]

    [AllowAnonymous]

    public async Task<ActionResult<ApiResponse<TableChatMessageDto>>> PostCustomerChatMessage(

        string slug,

        string tableNumber,

        [FromBody] SendChatMessageRequest request,

        CancellationToken ct)

    {

        if (string.IsNullOrWhiteSpace(request?.Text))

            return BadRequest(ApiResponse<TableChatMessageDto>.Fail("Message text cannot be empty"));



        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<TableChatMessageDto>.Fail("Restaurant not found"));
        var businessId = resolved.Value;



        var (isValidPostTable, _) = await ValidateTableForBusinessAsync(businessId, tableNumber, ct);

        if (!isValidPostTable)

        {

            return BadRequest(ApiResponse<TableChatMessageDto>.Fail(

                $"Table '{tableNumber}' is not a valid table at this restaurant."));

        }



        var key = GetChatKey(businessId, tableNumber);

        var msg = new TableChatMessageDto

        {

            Sender = "CUSTOMER",

            SenderName = string.IsNullOrWhiteSpace(request.SenderName) ? (tableNumber.StartsWith("Table", StringComparison.OrdinalIgnoreCase) ? tableNumber : $"Table {tableNumber}") : request.SenderName.Trim(),

            Text = request.Text.Trim(),

            Type = string.IsNullOrWhiteSpace(request.Type) ? "TEXT" : request.Type.Trim().ToUpperInvariant(),

            Timestamp = DateTime.UtcNow

        };



        _tableChatStore.AddOrUpdate(

            key,

            _ => new List<TableChatMessageDto> { msg },

            (_, list) =>

            {

                lock (list)

                {

                    list.Add(msg);

                    if (list.Count > 100) list.RemoveAt(0);

                }

                return list;

            });



        TableSyncManager.Broadcast(businessId, tableNumber, "chat_message", msg);
        TableSyncManager.Broadcast(businessId, tableNumber, "chat_message", msg);
        return Ok(ApiResponse<TableChatMessageDto>.Ok(msg, "Message sent"));

    }



    /// <summary>Owner endpoint to get chat messages for a table.</summary>

    [HttpGet("api/businesses/{businessId}/table/{tableNumber}/chat")]

    [AllowAnonymous]

    public ActionResult<ApiResponse<List<TableChatMessageDto>>> GetTableChatOwner(

        Guid businessId,

        string tableNumber)

    {

        var key = GetChatKey(businessId, tableNumber);

        var list = _tableChatStore.TryGetValue(key, out var msgs) ? msgs.ToList() : new List<TableChatMessageDto>();

        return Ok(ApiResponse<List<TableChatMessageDto>>.Ok(list));

    }



    /// <summary>Owner endpoint to reply with a chat message to a table.</summary>

    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/chat")]

    [AllowAnonymous]

    public ActionResult<ApiResponse<TableChatMessageDto>> PostOwnerChatMessage(

        Guid businessId,

        string tableNumber,

        [FromBody] SendChatMessageRequest request)

    {

        if (string.IsNullOrWhiteSpace(request?.Text))

            return BadRequest(ApiResponse<TableChatMessageDto>.Fail("Message text cannot be empty"));



        var key = GetChatKey(businessId, tableNumber);

        var msg = new TableChatMessageDto

        {

            Sender = "RESTAURANT",

            SenderName = string.IsNullOrWhiteSpace(request.SenderName) ? "Kitchen / Server" : request.SenderName.Trim(),

            Text = request.Text.Trim(),

            Type = string.IsNullOrWhiteSpace(request.Type) ? "TEXT" : request.Type.Trim().ToUpperInvariant(),

            Timestamp = DateTime.UtcNow

        };



        _tableChatStore.AddOrUpdate(

            key,

            _ => new List<TableChatMessageDto> { msg },

            (_, list) =>

            {

                lock (list)

                {

                    list.Add(msg);

                    if (list.Count > 100) list.RemoveAt(0);

                }

                return list;

            });



        return Ok(ApiResponse<TableChatMessageDto>.Ok(msg, "Message sent"));

    }

    /// <summary>Public endpoint for customer to ring waiter / request assistance (water or help).</summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/call-waiter")]
    [HttpPost("api/public/orders/{slug}/call-waiter")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<TableWaiterCallDto>>> CallWaiter(
        string slug,
        string? tableNumber,
        [FromBody] CallWaiterRequest? request,
        CancellationToken ct)
    {
        var targetTable = !string.IsNullOrWhiteSpace(tableNumber) ? tableNumber : request?.TableNumber;
        if (string.IsNullOrWhiteSpace(targetTable))
            targetTable = "Dine-in";

        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<TableWaiterCallDto>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var (isValidTable, validTables) = await ValidateTableForBusinessAsync(businessId, targetTable, ct);
        if (!isValidTable)
        {
            var rangeText = validTables.Count > 0 ? $"Valid tables are Tables 1 to {validTables.Last()}." : "Invalid table.";
            return BadRequest(ApiResponse<TableWaiterCallDto>.Fail($"Table '{targetTable}' is not valid at this restaurant. {rangeText}"));
        }

        var note = string.IsNullOrWhiteSpace(request?.Note) ? "Need water or help" : request.Note.Trim();
        var call = new TableWaiterCallDto
        {
            Id = Guid.NewGuid().ToString(),
            BusinessId = businessId,
            TableNumber = targetTable.Trim(),
            Note = note,
            CreatedAt = DateTime.UtcNow,
            IsAttended = false
        };

        var key = GetChatKey(businessId, targetTable);
        _waiterCallsStore.AddOrUpdate(key, call, (_, _) => call);

        // Also add a service request message to the table chat store
        var chatMsg = new TableChatMessageDto
        {
            Id = Guid.NewGuid().ToString(),
            Sender = "CUSTOMER",
            SenderName = targetTable.StartsWith("Table", StringComparison.OrdinalIgnoreCase) ? targetTable : $"Table {targetTable}",
            Text = $"🔔 Waiter Call: {note}",
            Type = "SERVICE_REQUEST",
            Timestamp = DateTime.UtcNow
        };
        _tableChatStore.AddOrUpdate(
            key,
            _ => new List<TableChatMessageDto> { chatMsg },
            (_, list) => { lock (list) { list.Add(chatMsg); if (list.Count > 100) list.RemoveAt(0); } return list; });

        TableSyncManager.Broadcast(businessId, targetTable, "waiter_called", call);
        return Ok(ApiResponse<TableWaiterCallDto>.Ok(call, "Waiter has been notified! A staff member is on the way."));
    }

    /// <summary>Owner endpoint to get all active waiter calls for a business.</summary>
    [HttpGet("api/businesses/{businessId}/waiter-calls")]
    [AllowAnonymous]
    public ActionResult<ApiResponse<List<TableWaiterCallDto>>> GetActiveWaiterCalls(Guid businessId)
    {
        var cutoff = DateTime.UtcNow.AddHours(-12);
        var prefix = $"{businessId}:";
        var calls = _waiterCallsStore
            .Where(kvp => kvp.Key.StartsWith(prefix) && !kvp.Value.IsAttended && kvp.Value.CreatedAt >= cutoff)
            .Select(kvp => kvp.Value)
            .OrderByDescending(c => c.CreatedAt)
            .ToList();

        return Ok(ApiResponse<List<TableWaiterCallDto>>.Ok(calls));
    }

    /// <summary>Owner endpoint to dismiss/attend a table waiter call.</summary>
    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/attend-waiter")]
    [AllowAnonymous]
    public ActionResult<ApiResponse<bool>> AttendWaiterCall(Guid businessId, string tableNumber)
    {
        var key = GetChatKey(businessId, tableNumber);
        _waiterCallsStore.TryRemove(key, out _);
        TableSyncManager.Broadcast(businessId, tableNumber, "waiter_attended", new { tableNumber });
        return Ok(ApiResponse<bool>.Ok(true, "Waiter call attended"));
    }

    /// <summary>Owner endpoint when customer clicks "I Have Paid" but no payment was received.</summary>
    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/reject-payment")]
    [AllowAnonymous]
    public ActionResult<ApiResponse<bool>> RejectPaymentClaim(Guid businessId, string tableNumber, [FromBody] RejectPaymentRequest? request)
    {
        var cleanTable = tableNumber.Trim().ToLowerInvariant();
        var key = GetChatKey(businessId, cleanTable);
        _waiterCallsStore.TryRemove(key, out _);

        var reason = !string.IsNullOrWhiteSpace(request?.Reason)
            ? request.Reason.Trim()
            : "Payment was not received in restaurant account.";

        var chatMsg = new TableChatMessageDto
        {
            Id = Guid.NewGuid().ToString(),
            Sender = "RESTAURANT",
            SenderName = "Cashier / Counter",
            Text = $"⚠️ Verification Alert: {reason} Please show transaction screenshot or pay at counter.",
            Timestamp = DateTime.UtcNow
        };
        _tableChatStore.AddOrUpdate(
            key,
            new List<TableChatMessageDto> { chatMsg },
            (_, list) => { lock (list) { list.Add(chatMsg); } return list; }
        );

        TableSyncManager.Broadcast(businessId, tableNumber, "payment_rejected", new {
            tableNumber,
            reason,
            timestamp = DateTime.UtcNow
        });

        return Ok(ApiResponse<bool>.Ok(true, "Payment claim rejected"));
    }

    /// <summary>Public endpoint for customer to notify restaurant that they paid via dynamic UPI.</summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/notify-upi")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> NotifyUpiPayment(
        string slug,
        string tableNumber,
        [FromBody] NotifyUpiPaymentRequest? request,
        CancellationToken ct)
    {
        var targetTable = !string.IsNullOrWhiteSpace(tableNumber) ? tableNumber : "Dine-in";
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<object>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var amount = request?.Amount ?? 0;
        var app = string.IsNullOrWhiteSpace(request?.UpiApp) ? "UPI" : request.UpiApp.Trim();
        var utrText = !string.IsNullOrWhiteSpace(request?.Utr) ? $" [UTR: {request.Utr.Trim()}]" : "";
        var note = $"💰 Paid ₹{amount} via {app}{utrText}";

        var call = new TableWaiterCallDto
        {
            Id = Guid.NewGuid().ToString(),
            BusinessId = businessId,
            TableNumber = targetTable.Trim(),
            Note = note,
            CreatedAt = DateTime.UtcNow,
            IsAttended = false
        };

        var key = GetChatKey(businessId, targetTable);
        _waiterCallsStore.AddOrUpdate(key, call, (_, _) => call);

        var chatMsg = new TableChatMessageDto
        {
            Id = Guid.NewGuid().ToString(),
            Sender = "CUSTOMER",
            SenderName = targetTable.StartsWith("Table", StringComparison.OrdinalIgnoreCase) ? targetTable : $"Table {targetTable}",
            Text = $"💰 Payment: {note}",
            Timestamp = DateTime.UtcNow
        };
        _tableChatStore.AddOrUpdate(
            key,
            new List<TableChatMessageDto> { chatMsg },
            (_, list) => { lock (list) { list.Add(chatMsg); } return list; }
        );

        TableSyncManager.Broadcast(businessId, targetTable, "upi_payment_submitted", new {
            tableNumber = targetTable,
            amount = amount,
            upiApp = app,
            utr = request?.Utr?.Trim(),
            timestamp = DateTime.UtcNow
        });

        return Ok(ApiResponse<object>.Ok(new { success = true }, "Payment notification sent to restaurant"));
    }

    /// <summary>Public endpoint for customer to submit feedback/rating after payment.</summary>
    [HttpPost("api/public/orders/{slug}/table/{tableNumber}/feedback")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> SubmitFeedback(
        string slug,
        string tableNumber,
        [FromBody] SubmitFeedbackRequest request,
        CancellationToken ct)
    {
        var targetTable = !string.IsNullOrWhiteSpace(tableNumber) ? tableNumber : "Dine-in";
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue) return NotFound(ApiResponse<object>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var rating = Math.Clamp(request?.Rating ?? 5, 1, 5);
        var comment = request?.Comment?.Trim();
        var tags = request?.Tags ?? new List<string>();
        var tagsJson = JsonSerializer.Serialize(tags);

        var cleanTable = targetTable.Trim().ToLowerInvariant();
        var altTable = cleanTable.StartsWith("table") ? cleanTable.Replace("table", "").Trim() : ("table " + cleanTable);
        var tableDigits = Regex.Match(cleanTable, @"\d+").Value;
        var altTableNum = !string.IsNullOrEmpty(tableDigits) ? ("table " + tableDigits) : altTable;

        var cutoff = DateTime.UtcNow.AddHours(-24);
        var orders = await _db.TableOrders
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff &&
                        (o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable ||
                         (!string.IsNullOrEmpty(tableDigits) && (o.TableNumber.ToLower() == tableDigits || o.TableNumber.ToLower() == altTableNum))))
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(ct);

        if (orders.Count > 0)
        {
            foreach (var o in orders)
            {
                o.Rating = rating;
                o.FeedbackComment = comment;
                o.FeedbackTagsJson = tagsJson;
                o.FeedbackSubmittedAt = DateTime.UtcNow;
                if (!string.IsNullOrWhiteSpace(request?.CustomerPhone) && string.IsNullOrWhiteSpace(o.CustomerPhone))
                {
                    o.CustomerPhone = request.CustomerPhone.Trim();
                }
            }
            await _db.SaveChangesAsync(ct);
        }

        // Notify restaurant staff and POS
        var ratingStars = new string('⭐', rating);
        var tagsText = tags.Count > 0 ? $" ({string.Join(", ", tags)})" : "";
        var chatNote = $"{ratingStars} Customer Feedback: {rating}/5{tagsText}{(string.IsNullOrWhiteSpace(comment) ? "" : $" - \"{comment}\"")}";

        var key = GetChatKey(businessId, targetTable);
        var chatMsg = new TableChatMessageDto
        {
            Id = Guid.NewGuid().ToString(),
            Sender = "CUSTOMER",
            SenderName = targetTable.StartsWith("Table", StringComparison.OrdinalIgnoreCase) ? targetTable : $"Table {targetTable}",
            Text = chatNote,
            Timestamp = DateTime.UtcNow
        };
        _tableChatStore.AddOrUpdate(
            key,
            new List<TableChatMessageDto> { chatMsg },
            (_, list) => { lock (list) { list.Add(chatMsg); } return list; }
        );

        TableSyncManager.Broadcast(businessId, targetTable, "customer_feedback_submitted", new {
            tableNumber = targetTable,
            rating = rating,
            comment = comment,
            tags = tags,
            timestamp = DateTime.UtcNow
        });

        return Ok(ApiResponse<object>.Ok(new { success = true }, "Thank you for your feedback!"));
    }



    private async Task<ActionResult<ApiResponse<TableOrderResponse>>> UpdateStatusAsync(Guid id, string status, CancellationToken ct)

    {

        var order = await _db.TableOrders.FirstOrDefaultAsync(o => o.Id == id, ct);

        if (order == null) return NotFound(ApiResponse<TableOrderResponse>.Fail("Order not found"));

        using var tableLock = await TableSyncManager.AcquireTableLockAsync(order.BusinessId, order.TableNumber, ct);
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {

        if (status == "CANCELLED" && order.Status != "PENDING")
        {
            return BadRequest(ApiResponse<TableOrderResponse>.Fail("Order has already been accepted by the kitchen and cannot be cancelled."));
        }

        if (status == "ACCEPTED")

        {

            var hasActiveSub = await _db.Subscriptions

                .AnyAsync(s => s.BusinessId == order.BusinessId && s.Status == ARSmartMenu.Domain.Enums.SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);

            if (!hasActiveSub)

                return BadRequest(ApiResponse<TableOrderResponse>.Fail("An active subscription plan or trial is required to accept table orders into the kitchen."));

        }



        order.Status = status;

        if (status == "ACCEPTED") order.AcceptedAt = DateTime.UtcNow;

        if (status == "COMPLETED") order.CompletedAt = DateTime.UtcNow;

        if (status == "CANCELLED")

        {

            order.BillRequested = false;

            order.BillRequestedAt = null;



            // Check if there are any remaining non-cancelled active orders for this table

            var cleanT = order.TableNumber.Trim().ToLowerInvariant();

            var altT = cleanT.StartsWith("table") ? cleanT.Replace("table", "").Trim() : ("table " + cleanT);

            var cutoffTime = DateTime.UtcNow.AddHours(-12);



            var remainingAccepted = await _db.TableOrders

                .Where(o => o.BusinessId == order.BusinessId &&

                            o.Id != order.Id &&

                            o.CreatedAt >= cutoffTime &&

                            o.Status != "PAID" && o.Status != "SETTLED" && o.Status != "CANCELLED" &&

                            (o.TableNumber.ToLower() == cleanT || o.TableNumber.ToLower() == altT) &&

                            (o.Status == "ACCEPTED" || o.Status == "COMPLETED"))

                .AnyAsync(ct);



            if (!remainingAccepted)

            {

                var tableOrders = await _db.TableOrders

                    .Where(o => o.BusinessId == order.BusinessId &&

                                o.CreatedAt >= cutoffTime &&

                                (o.TableNumber.ToLower() == cleanT || o.TableNumber.ToLower() == altT))

                    .ToListAsync(ct);

                foreach (var to in tableOrders)

                {

                    to.BillRequested = false;

                    to.BillRequestedAt = null;

                }

                _activeTableSessionTokens.TryRemove(GetChatKey(order.BusinessId, cleanT), out _);
                _activeTableSessionTokens.TryRemove(GetChatKey(order.BusinessId, altT), out _);
            }

        }

        order.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        TableSyncManager.Broadcast(order.BusinessId, order.TableNumber, $"order_{status.ToLowerInvariant()}", new { orderId = order.Id, status });
        return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(order), $"Order {status.ToLowerInvariant()}"));
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }



    private Task<(bool IsValid, List<string> ValidTables)> ValidateTableForBusinessAsync(
        Guid businessId,
        string? tableNumber,
        CancellationToken ct) =>
        _lookupCache.ValidateTableForBusinessAsync(_db, businessId, tableNumber, ct);

    private static TableOrderResponse ToResponse(TableOrder o)

    {

        List<TableOrderItemDto> items;

        try

        {

            items = JsonSerializer.Deserialize<List<TableOrderItemDto>>(o.ItemsJson) ?? new();

        }

        catch

        {

            items = new();

        }

        List<string> feedbackTags;
        try
        {
            feedbackTags = !string.IsNullOrWhiteSpace(o.FeedbackTagsJson)
                ? JsonSerializer.Deserialize<List<string>>(o.FeedbackTagsJson) ?? new()
                : new();
        }
        catch
        {
            feedbackTags = new();
        }

        return new TableOrderResponse

        {

            Id = o.Id,

            BusinessId = o.BusinessId,

            TableNumber = o.TableNumber,

            Round = o.Round,

            Status = o.Status,

            Instructions = o.Instructions,

            CustomerPhone = o.CustomerPhone,

            Items = items,

            TotalAmount = o.TotalAmount,

            BillRequested = o.BillRequested,

            BillRequestedAt = o.BillRequestedAt.HasValue ? DateTime.SpecifyKind(o.BillRequestedAt.Value, DateTimeKind.Utc) : null,

            CreatedAt = DateTime.SpecifyKind(o.CreatedAt, DateTimeKind.Utc),

            AcceptedAt = o.AcceptedAt.HasValue ? DateTime.SpecifyKind(o.AcceptedAt.Value, DateTimeKind.Utc) : null,

            CompletedAt = o.CompletedAt.HasValue ? DateTime.SpecifyKind(o.CompletedAt.Value, DateTimeKind.Utc) : null,

            PartyPin = o.PartyPin,

            Rating = o.Rating,

            FeedbackComment = o.FeedbackComment,

            FeedbackTags = feedbackTags,

            FeedbackSubmittedAt = o.FeedbackSubmittedAt.HasValue ? DateTime.SpecifyKind(o.FeedbackSubmittedAt.Value, DateTimeKind.Utc) : null,

        };

    }



    /// <summary>
    /// Fast reactive sync endpoint for customer WebAR menu.
    /// Responds immediately if there is a new table event, or long-polls with timeout for sub-second real-time sync.
    /// </summary>
    [HttpGet("api/public/orders/{slug}/table/{tableNumber}/sync")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> SyncTableOrdersPublic(
        string slug,
        string tableNumber,
        [FromQuery] long version = 0,
        [FromQuery] int timeoutSeconds = 8,
        CancellationToken ct = default)
    {
        var resolved = await ResolveBusinessIdAsync(slug, ct: ct);
        if (!resolved.HasValue)
            return NotFound(ApiResponse<object>.Fail("Restaurant not found"));
        var businessId = resolved.Value;

        var clampedTimeout = Math.Clamp(timeoutSeconds, 1, 15);
        var syncEvent = await TableSyncManager.WaitForTableUpdateAsync(
            businessId, tableNumber, version, TimeSpan.FromSeconds(clampedTimeout), ct);

        var currentTableVersion = TableSyncManager.GetTableVersion(businessId, tableNumber);
        var (cleanTable, _, _, _) = BuildTableVariants(tableNumber);

        var allActive = await LoadActiveTableOrdersAsync(businessId, tableNumber, ct);
        var orders = allActive
            .Where(o => o.Status == "PENDING" || o.Status == "ACCEPTED" || o.Status == "COMPLETED" || o.BillRequested)
            .ToList();

        var chatKey = GetChatKey(businessId, cleanTable);
        var chatMessages = _tableChatStore.TryGetValue(chatKey, out var msgs) ? msgs.ToList() : new List<TableChatMessageDto>();
        var sharedCart = _tableSharedCartStore.TryGetValue(chatKey, out var sc) ? sc : null;

        return Ok(ApiResponse<object>.Ok(new
        {
            version = currentTableVersion,
            eventType = syncEvent?.EventType ?? "sync",
            orders = orders.Select(ToResponse).ToList(),
            chat = chatMessages,
            sharedCart = sharedCart != null ? new
            {
                tableNumber,
                items = sharedCart.Items,
                totalItems = sharedCart.Items.Sum(i => i.Quantity),
                totalAmount = sharedCart.Items.Sum(i => i.UnitPrice * i.Quantity),
                lastUpdatedBy = sharedCart.LastUpdatedBy,
                lastClientId = sharedCart.LastClientId,
                updatedAt = sharedCart.UpdatedAt,
            } : null,
            billRequested = orders.Any(o => o.BillRequested),
            isOccupied = orders.Count > 0,
            serverTime = DateTime.UtcNow
        }));
    }

    /// <summary>
    /// Fast reactive sync endpoint for Owner app / Live kitchen.
    /// Responds immediately when any table in this business changes, or long-polls with timeout.
    /// </summary>
    [HttpGet("api/businesses/{businessId}/table-orders/sync")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<object>>> SyncBusinessOrders(
        Guid businessId,
        [FromQuery] long version = 0,
        [FromQuery] int timeoutSeconds = 8,
        CancellationToken ct = default)
    {
        var clampedTimeout = Math.Clamp(timeoutSeconds, 1, 15);
        var syncEvent = await TableSyncManager.WaitForBusinessUpdateAsync(
            businessId, version, TimeSpan.FromSeconds(clampedTimeout), ct);

        var currentBizVersion = TableSyncManager.GetBusinessVersion(businessId);

        var cutoff = DateTime.UtcNow.AddHours(-12);
        var activeOrders = await _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff &&
                        o.Status != "PAID" && o.Status != "SETTLED")
            .OrderByDescending(o => o.CreatedAt)
            .Take(80)
            .ToListAsync(ct);

        return Ok(ApiResponse<object>.Ok(new
        {
            version = currentBizVersion,
            eventType = syncEvent?.EventType ?? "sync",
            pendingCount = activeOrders.Count(o => o.Status == "PENDING"),
            billRequestedCount = activeOrders.Count(o => o.BillRequested),
            activeOrders = activeOrders.Select(ToResponse).ToList(),
            serverTime = DateTime.UtcNow
        }));
    }

    /// <summary>
    /// Owner/staff endpoint to append unlisted items (water bottle, extra roti, custom items)
    /// to the active table session. Guarantees atomic transaction, table lock, and immediate real-time sync with customer!
    /// </summary>
    [HttpPost("api/businesses/{businessId}/table/{tableNumber}/add-items")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<TableOrderResponse>>> AddItemsToTable(
        Guid businessId,
        string tableNumber,
        [FromBody] AddTableItemsRequest request,
        CancellationToken ct)
    {
        if (request.Items == null || request.Items.Count == 0)
        {
            return BadRequest(ApiResponse<TableOrderResponse>.Fail("No items provided to add."));
        }

        using var tableLock = await TableSyncManager.AcquireTableLockAsync(businessId, tableNumber, ct);
        using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
        try
        {
            var cutoff = DateTime.UtcNow.AddHours(-12);

            var latestSettlement = await FilterByTable(
                    _db.TableOrders.AsNoTracking().Where(o =>
                        o.BusinessId == businessId &&
                        o.CreatedAt >= cutoff &&
                        (o.Status == "PAID" || o.Status == "SETTLED")),
                    tableNumber)
                .OrderByDescending(o => o.UpdatedAt ?? o.CreatedAt)
                .Select(o => (DateTime?)(o.UpdatedAt ?? o.CreatedAt))
                .FirstOrDefaultAsync(ct);

            var activeOrdersQuery = FilterByTable(
                _db.TableOrders.Where(o =>
                    o.BusinessId == businessId &&
                    o.CreatedAt >= cutoff &&
                    (o.Status == "PENDING" || o.Status == "ACCEPTED" || o.Status == "COMPLETED" || o.BillRequested)),
                tableNumber);

            if (latestSettlement != null)
            {
                activeOrdersQuery = activeOrdersQuery.Where(o => o.CreatedAt > latestSettlement.Value);
            }

            var activeOrders = await activeOrdersQuery.OrderBy(o => o.CreatedAt).ToListAsync(ct);
            var nextRound = activeOrders.Count > 0 ? activeOrders.Max(o => o.Round) + 1 : 1;

            var itemsJson = JsonSerializer.Serialize(request.Items, CompactJsonOptions);
            var totalAmount = request.Items.Sum(i => i.UnitPrice * i.Quantity);

            var order = new TableOrder
            {
                BusinessId = businessId,
                TableNumber = string.IsNullOrWhiteSpace(tableNumber) ? "Dine-in" : tableNumber.Trim(),
                Round = nextRound,
                Status = "ACCEPTED",
                AcceptedAt = DateTime.UtcNow,
                Instructions = request.Instructions?.Trim() ?? "Added by Staff",
                CustomerPhone = activeOrders.FirstOrDefault()?.CustomerPhone ?? string.Empty,
                ItemsJson = itemsJson,
                TotalAmount = totalAmount,
            };

            _db.TableOrders.Add(order);
            await _db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);

            TableSyncManager.Broadcast(businessId, tableNumber, "items_added", new { orderId = order.Id, round = order.Round, itemsCount = request.Items.Count });
            return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(order), "Items added to table bill"));
        }
        catch
        {
            await tx.RollbackAsync(ct);
            throw;
        }
    }
}



public class PlaceTableOrderRequest

{

    public string TableNumber { get; set; } = string.Empty;

    public int Round { get; set; } = 1;

    public string Instructions { get; set; } = string.Empty;

    public string CustomerPhone { get; set; } = string.Empty;

    public List<TableOrderItemDto> Items { get; set; } = new();

    public string? SessionToken { get; set; }

    public string? PreviousOrderId { get; set; }

    public List<string>? PreviousOrderIds { get; set; }

    public double? CustomerLatitude { get; set; }
    public double? CustomerLongitude { get; set; }
    public string? PartyPin { get; set; }

}



public class TableOrderItemDto

{

    public string Id { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int Quantity { get; set; } = 1;

    public int UnitPrice { get; set; } = 0;

    public List<string>? Modifiers { get; set; } = new();

    public string? Notes { get; set; }

}

public class NotifyUpiPaymentRequest
{
    public int Amount { get; set; }
    public string? UpiApp { get; set; }
    public string? Utr { get; set; }
}

public class RejectPaymentRequest
{
    public string? Reason { get; set; }
}



public class TableOrderResponse

{

    public Guid Id { get; set; }

    public Guid BusinessId { get; set; }

    public string TableNumber { get; set; } = string.Empty;

    public int Round { get; set; } = 1;

    public string Status { get; set; } = string.Empty;

    public string Instructions { get; set; } = string.Empty;

    public string CustomerPhone { get; set; } = string.Empty;

    public List<TableOrderItemDto> Items { get; set; } = new();

    public int TotalAmount { get; set; }

    public bool BillRequested { get; set; }

    public DateTime? BillRequestedAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? AcceptedAt { get; set; }

    public DateTime? CompletedAt { get; set; }

    public string? PartyPin { get; set; }

    public int? Rating { get; set; }

    public string? FeedbackComment { get; set; }

    public List<string> FeedbackTags { get; set; } = new();

    public DateTime? FeedbackSubmittedAt { get; set; }

}

public class SubmitFeedbackRequest
{
    public int Rating { get; set; } = 5;
    public string? Comment { get; set; }
    public List<string>? Tags { get; set; }
    public string? CustomerPhone { get; set; }
    public string? SessionToken { get; set; }
}

public class JoinTablePartyRequest
{
    public string? SessionToken { get; set; }
    public string? DinerName { get; set; }
    public string? Pin { get; set; }
}

public class ClaimNewPartyRequest
{
    public string? SessionToken { get; set; }
    public string? CustomerPhone { get; set; }
}







public class RequestBillDto

{

    public string? TableNumber { get; set; }

    public string? CustomerPhone { get; set; }

    public string? SessionToken { get; set; }

}





public class TableChatMessageDto

{

    public string Id { get; set; } = Guid.NewGuid().ToString();

    public string Sender { get; set; } = "CUSTOMER"; // "CUSTOMER" or "RESTAURANT"

    public string SenderName { get; set; } = "Customer";

    public string Text { get; set; } = string.Empty;

    public string Type { get; set; } = "TEXT"; // "TEXT", "SERVICE_REQUEST", "SYSTEM"

    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

}



public class SendChatMessageRequest

{

    public string Text { get; set; } = string.Empty;

    public string? SenderName { get; set; }

    public string? Type { get; set; }

}

public class CallWaiterRequest
{
    public string? TableNumber { get; set; }
    public string? Note { get; set; }
}

public class TableWaiterCallDto
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public Guid BusinessId { get; set; }
    public string TableNumber { get; set; } = string.Empty;
    public string Note { get; set; } = "Need water or help";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsAttended { get; set; } = false;
    public DateTime? AttendedAt { get; set; }
}

public class AddTableItemsRequest
{
    public List<TableOrderItemDto> Items { get; set; } = new();
    public string? Instructions { get; set; }
}

public class SharedCartItemDto
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string DishId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; } = 1;
    public string? ImageUrl { get; set; }
    public List<string>? Modifiers { get; set; }
    public string? Notes { get; set; }
    public string? ClientId { get; set; }
    public string? AddedBy { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class SharedCartState
{
    public string? SessionToken { get; set; }
    public List<SharedCartItemDto> Items { get; set; } = new();
    public string? LastUpdatedBy { get; set; }
    public string? LastClientId { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class UpdateSharedCartRequest
{
    public string? SessionToken { get; set; }
    public string? ClientId { get; set; }
    public string? ClientName { get; set; }
    public List<SharedCartItemDto> Items { get; set; } = new();
}

public class SetSharedCartItemRequest
{
    public string? SessionToken { get; set; }
    public string? ClientId { get; set; }
    public string? ClientName { get; set; }
    public SharedCartItemDto Item { get; set; } = new();
    public int TargetQuantity { get; set; } = 1;
}

public class SharedCartResponse
{
    public string TableNumber { get; set; } = string.Empty;
    public List<SharedCartItemDto> Items { get; set; } = new();
    public int TotalItems { get; set; }
    public decimal TotalAmount { get; set; }
    public string? LastUpdatedBy { get; set; }
    public string? LastClientId { get; set; }
    public DateTime UpdatedAt { get; set; }
}

