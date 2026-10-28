using System.Text.Json;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.API.Controllers;

[ApiController]
public class TableOrdersController : ControllerBase
{
    private readonly AppDbContext _db;

    public TableOrdersController(AppDbContext db) => _db = db;

    /// <summary>Public endpoint for WebAR customer to submit a table order ticket.</summary>
    [HttpPost("api/public/orders/{slug}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<TableOrderResponse>>> PlaceOrder(
        string slug,
        [FromBody] PlaceTableOrderRequest request,
        CancellationToken ct)
    {
        // Resolve business by QR code slug, business ID, or business name
        var qr = await _db.QrCodes
            .AsNoTracking()
            .Include(q => q.Business)
            .FirstOrDefaultAsync(q => q.Slug == slug && q.IsActive, ct);

        Business? business = qr?.Business;
        if (business is null)
        {
            if (Guid.TryParse(slug, out var bId))
            {
                business = await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(b => b.Id == bId, ct);
            }
            business ??= await _db.Businesses.AsNoTracking()
                .FirstOrDefaultAsync(b => b.BusinessName.ToLower() == slug.ToLower(), ct)
                ?? await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(ct);
        }

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

        if (!string.IsNullOrWhiteSpace(request.CustomerPhone))
        {
            var digitsOnly = System.Text.RegularExpressions.Regex.Replace(request.CustomerPhone.Trim(), @"\D", "");
            if (digitsOnly.Length != 10)
                return BadRequest(ApiResponse<TableOrderResponse>.Fail("Customer mobile number must be exactly 10 numeric digits."));
        }

        var itemsJson = JsonSerializer.Serialize(request.Items ?? new List<TableOrderItemDto>());
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
        };

        _db.TableOrders.Add(order);
        await _db.SaveChangesAsync(ct);

        return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(order), "Order submitted to kitchen"));
    }

    /// <summary>Public live order status for diner tracking on their table.</summary>
    [HttpGet("api/public/orders/{slug}/table/{tableNumber}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<List<TableOrderResponse>>>> GetTableOrdersPublic(
        string slug,
        string tableNumber,
        [FromQuery] string? orderIds = null,
        CancellationToken ct = default)
    {
        var cleanSlug = slug.Trim().ToLowerInvariant();
        var qr = await _db.QrCodes
            .Include(q => q.Business)
            .FirstOrDefaultAsync(q => q.Slug.ToLower() == cleanSlug, ct);

        Guid businessId;
        if (qr != null)
        {
            businessId = qr.BusinessId;
        }
        else if (Guid.TryParse(cleanSlug, out var bId))
        {
            businessId = bId;
        }
        else
        {
            var business = await _db.Businesses
                .FirstOrDefaultAsync(b => b.BusinessName.ToLower() == cleanSlug, ct)
                ?? throw new NotFoundException("Restaurant not found.");
            businessId = business.Id;
        }

        var cleanTable = tableNumber.Trim().ToLowerInvariant();
        var altTable = cleanTable.StartsWith("table")
            ? cleanTable.Replace("table", "").Trim()
            : ("table " + cleanTable);
        var cutoff = DateTime.UtcNow.AddHours(-12);

        var query = _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= cutoff);

        List<Guid> parsedIds = new();
        if (!string.IsNullOrWhiteSpace(orderIds))
        {
            foreach (var part in orderIds.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                if (Guid.TryParse(part.Trim(), out var parsedId))
                    parsedIds.Add(parsedId);
            }
        }

        List<TableOrder> orders;
        if (parsedIds.Count > 0)
        {
            orders = await query
                .Where(o => parsedIds.Contains(o.Id) || o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable)
                .OrderBy(o => o.Round)
                .ThenBy(o => o.CreatedAt)
                .ToListAsync(ct);
        }
        else
        {
            orders = await query
                .Where(o => o.TableNumber.ToLower() == cleanTable || o.TableNumber.ToLower() == altTable)
                .OrderBy(o => o.Round)
                .ThenBy(o => o.CreatedAt)
                .ToListAsync(ct);
        }

        var list = orders.Select(ToResponse).ToList();
        return Ok(ApiResponse<List<TableOrderResponse>>.Ok(list));
    }

    /// <summary>Get table orders for a business (owner portal).</summary>
    [HttpGet("api/businesses/{businessId}/table-orders")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<List<TableOrderResponse>>>> GetOrders(
        Guid businessId,
        [FromQuery] string? status,
        CancellationToken ct)
    {
        var query = _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == businessId);

        if (!string.IsNullOrWhiteSpace(status))
        {
            var st = status.Trim().ToUpperInvariant();
            query = query.Where(o => o.Status == st);
        }

        var list = await query
            .OrderByDescending(o => o.CreatedAt)
            .Take(50)
            .ToListAsync(ct);

        var responses = list.Select(ToResponse).ToList();
        return Ok(ApiResponse<List<TableOrderResponse>>.Ok(responses));
    }

    [HttpPost("api/orders/{id}/accept")]
    [AllowAnonymous]
    public Task<ActionResult<ApiResponse<TableOrderResponse>>> AcceptOrder(Guid id, CancellationToken ct) =>
        UpdateStatusAsync(id, "ACCEPTED", ct);

    [HttpPost("api/orders/{id}/cancel")]
    [AllowAnonymous]
    public Task<ActionResult<ApiResponse<TableOrderResponse>>> CancelOrder(Guid id, CancellationToken ct) =>
        UpdateStatusAsync(id, "CANCELLED", ct);

    [HttpPost("api/orders/{id}/complete")]
    [AllowAnonymous]
    public Task<ActionResult<ApiResponse<TableOrderResponse>>> CompleteOrder(Guid id, CancellationToken ct) =>
        UpdateStatusAsync(id, "COMPLETED", ct);

    private async Task<ActionResult<ApiResponse<TableOrderResponse>>> UpdateStatusAsync(Guid id, string status, CancellationToken ct)
    {
        var order = await _db.TableOrders.FirstOrDefaultAsync(o => o.Id == id, ct);
        if (order == null) return NotFound(ApiResponse<TableOrderResponse>.Fail("Order not found"));

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
        order.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return Ok(ApiResponse<TableOrderResponse>.Ok(ToResponse(order), $"Order {status.ToLowerInvariant()}"));
    }

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
            CreatedAt = o.CreatedAt,
            AcceptedAt = o.AcceptedAt,
        };
    }
}

public class PlaceTableOrderRequest
{
    public string TableNumber { get; set; } = string.Empty;
    public int Round { get; set; } = 1;
    public string Instructions { get; set; } = string.Empty;
    public string CustomerPhone { get; set; } = string.Empty;
    public List<TableOrderItemDto> Items { get; set; } = new();
}

public class TableOrderItemDto
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public int Quantity { get; set; } = 1;
    public int UnitPrice { get; set; } = 0;
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
    public DateTime CreatedAt { get; set; }
    public DateTime? AcceptedAt { get; set; }
}
