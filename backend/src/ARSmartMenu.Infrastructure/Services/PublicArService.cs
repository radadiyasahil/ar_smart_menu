using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace ARSmartMenu.Infrastructure.Services;

public class PublicArService : IPublicArService
{
    private const int MaxOtherProducts = 6;

    private readonly AppDbContext _db;
    private readonly MediaUrlResolver _mediaUrls;
    private readonly AppLookupCacheService _lookupCache;

    public PublicArService(AppDbContext db, MediaUrlResolver mediaUrls, AppLookupCacheService lookupCache)
    {
        _db = db;
        _mediaUrls = mediaUrls;
        _lookupCache = lookupCache;
    }

    public async Task<PublicArResponse> GetBySlugAsync(string slug, CancellationToken ct = default)
    {
        var resolved = await ResolveExperienceAsync(slug, ct)
            ?? throw new NotFoundException("AR experience not found.");

        var product = resolved.Product;
        var isArActive = resolved.Business.ArViewEnabled && (resolved.Business.ArViewCredits > 0 || resolved.Business.ArPerViewChargePaise == 0);
        var glbUrl = isArActive
            ? ResolveModelUrl(product.Model3d?.GlbS3Key, product.Model3d?.GlbUrl, resolved.FallbackGlbUrl)
            : null;
        var usdzUrl = isArActive
            ? SanitizeUsdzUrl(product.Model3d?.UsdzUrl ?? resolved.FallbackUsdzUrl)
            : null;
        var orderingUrl = await ResolveOrderingUrlAsync(resolved.Business.Id, product.Id, ct);
        var otherProducts = await GetOtherProductsAsync(
            resolved.Business.Id,
            product.Id,
            ct);

        return new PublicArResponse(
            resolved.Slug,
            new PublicArProductDto(
                product.Id,
                product.Name,
                product.Description,
                product.PricePaise,
                product.VegStatus,
                product.IsSpicy,
                product.IsBestseller,
                product.SoldOutToday,
                null,
                product.Photos
                    .OrderBy(p => p.SortOrder)
                    .Select(p => _mediaUrls.Resolve(p.S3Key, p.PhotoUrl))
                    .ToList()),
            new PublicArBusinessDto(
                resolved.Business.BusinessName,
                resolved.Business.City,
                orderingUrl,
                resolved.Business.LogoUrl),
            new PublicArModelDto(glbUrl, usdzUrl),
            otherProducts);
    }

    public async Task<PublicMenuResponse> GetMenuBySlugAsync(string slug, CancellationToken ct = default)
    {
        var cachedMenu = _lookupCache.TryGetPublicMenu(slug);
        if (cachedMenu != null)
            return cachedMenu;

        var target = await _lookupCache.ResolveSlugAsync(
            _db,
            slug,
            requireActiveQr: true,
            fallbackToAnyBusiness: true,
            ct) ?? throw new NotFoundException("Restaurant menu not found.");

        // Load only display fields + owner WhatsApp/Mobile via SQL JOIN in one query
        var business = await _db.Businesses
            .AsNoTracking()
            .Where(b => b.Id == target.BusinessId)
            .Select(b => new
            {
                b.Id,
                b.BusinessName,
                b.LogoUrl,
                b.City,
                b.FullAddress,
                b.Status,
                b.WifiName,
                b.WifiPassword,
                b.UpiId,
                b.RequireGeofence,
                b.GeofenceRadiusMeters,
                b.Latitude,
                b.Longitude,
                b.GstRate,
                OwnerWhatsApp = b.Owner.WhatsAppNumber,
                OwnerMobile = b.Owner.MobileNumber
            })
            .FirstOrDefaultAsync(ct)
            ?? throw new NotFoundException("Restaurant menu not found.");

        // Load live products, photos, 3D model, and active product QR slug in one projected query
        var products = await _db.Products
            .AsNoTracking()
            .Where(p => p.BusinessId == business.Id && p.Status == ProductStatus.Live)
            .OrderBy(p => p.DisplayOrder)
            .ThenByDescending(p => p.CreatedAt)
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.Description,
                p.PricePaise,
                p.Category,
                p.VegStatus,
                p.IsSpicy,
                p.IsBestseller,
                p.IsNew,
                p.SoldOutToday,
                p.CustomizationJson,
                Photos = p.Photos
                    .OrderBy(ph => ph.SortOrder)
                    .Select(ph => new { ph.S3Key, ph.PhotoUrl })
                    .ToList(),
                GlbS3Key = p.Model3d != null ? p.Model3d.GlbS3Key : null,
                GlbUrl = p.Model3d != null ? p.Model3d.GlbUrl : null,
                UsdzUrl = p.Model3d != null ? p.Model3d.UsdzUrl : null,
                HasModel3d = p.Model3d != null,
                ActiveQrSlug = p.QrCodes
                    .Where(q => q.IsActive)
                    .Select(q => q.Slug)
                    .FirstOrDefault()
            })
            .ToListAsync(ct);

        var dishCategoryLookup = new Dictionary<Guid, ProductCategory?>();
        var allDishes = new List<PublicMenuDishDto>(products.Count);

        foreach (var p in products)
        {
            dishCategoryLookup[p.Id] = p.Category;
            var glbUrl = ResolveModelUrl(p.GlbS3Key, p.GlbUrl, null);
            var dishSlug = p.ActiveQrSlug ?? p.Id.ToString("N");
            var photos = p.Photos.Select(ph => _mediaUrls.Resolve(ph.S3Key, ph.PhotoUrl)).ToList();

            allDishes.Add(new PublicMenuDishDto(
                p.Id,
                p.Name,
                p.Description,
                p.PricePaise,
                (int)p.VegStatus,
                p.IsSpicy,
                p.IsBestseller,
                p.IsNew,
                p.SoldOutToday,
                photos.FirstOrDefault(),
                photos,
                glbUrl,
                SanitizeUsdzUrl(p.UsdzUrl),
                p.HasModel3d && !string.IsNullOrEmpty(glbUrl),
                dishSlug,
                p.CustomizationJson));
        }

        var categories = allDishes
            .GroupBy(d => dishCategoryLookup[d.Id]?.ToString() ?? "Main Course")
            .Select(g =>
            {
                var catEnum = dishCategoryLookup[g.First().Id] ?? ProductCategory.MainCourse;
                return new PublicMenuCategoryDto(g.Key, (int)catEnum, g.ToList());
            })
            .ToList();

        if (categories.Count == 0 && allDishes.Count > 0)
        {
            categories = [new PublicMenuCategoryDto("Menu", 1, allDishes)];
        }

        var orderingUrl = await ResolveOrderingUrlAsync(business.Id, Guid.Empty, ct);
        var orderedAvailableTables = await _lookupCache.GetValidTablesForBusinessAsync(_db, business.Id, ct);
        var platformGstRate = (double)await _lookupCache.GetGstRatePercentRawAsync(_db, ct);

        var effectiveGstRate = (business.GstRate > 0 && business.GstRate != 5.0)
            ? business.GstRate
            : platformGstRate;

        var menuResponse = new PublicMenuResponse(
            slug,
            business.BusinessName,
            business.LogoUrl,
            business.City,
            business.FullAddress,
            business.OwnerWhatsApp ?? business.OwnerMobile,
            orderingUrl,
            categories,
            business.Status == BusinessStatus.Active,
            business.Status == BusinessStatus.Active ? null : "This restaurant is temporarily paused / closed.",
            orderedAvailableTables,
            business.WifiName,
            business.WifiPassword,
            business.UpiId,
            business.RequireGeofence,
            business.GeofenceRadiusMeters > 0 ? business.GeofenceRadiusMeters : 200,
            business.Latitude,
            business.Longitude,
            effectiveGstRate
        );

        _lookupCache.SetPublicMenu(slug, business.Id, menuResponse);
        return menuResponse;
    }

    public async Task<LogEventResponse> LogScanAsync(
        string slug,
        LogScanRequest request,
        string? userAgent,
        string? ipAddress,
        CancellationToken ct = default)
    {
        var qr = await ResolveActiveQrAsync(slug, ct);

        var scan = new ArScanEvent
        {
            QrCodeId = qr.Id,
            BusinessId = qr.BusinessId,
            ProductId = qr.ProductId,
            SessionId = Truncate(request.SessionId, 100),
            UserAgent = Truncate(userAgent, 160),
            IpAddress = Truncate(ipAddress, 45),
            Referrer = Truncate(request.Referrer, 300),
        };

        _db.ArScanEvents.Add(scan);
        await _db.SaveChangesAsync(ct);

        return new LogEventResponse(scan.Id, "Scan logged.");
    }

    public async Task<LogEventResponse> LogViewEventAsync(
        string slug,
        LogViewEventRequest request,
        string? userAgent,
        CancellationToken ct = default)
    {
        var qr = await ResolveActiveQrAsync(slug, ct);

        var view = new ArViewEvent
        {
            QrCodeId = qr.Id,
            BusinessId = qr.BusinessId,
            ProductId = qr.ProductId,
            SessionId = Truncate(request.SessionId, 100),
            UserAgent = Truncate(userAgent, 160),
            ViewDurationSeconds = request.ViewDurationSeconds,
            ArLaunched = request.ArLaunched || request.Rotated || request.Resized,
        };

        // Note: SQL trigger [tr_ArViewEvents_TrackUsage] atomically increments Businesses.ArViewsUsed
        // and decrements Businesses.ArViewCredits when ArLaunched = 1.
        _db.ArViewEvents.Add(view);
        await _db.SaveChangesAsync(ct);

        return new LogEventResponse(view.Id, "View event logged.");
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrEmpty(value)) return value;
        return value.Length <= maxLength ? value : value[..maxLength];
    }

    private async Task<IReadOnlyList<PublicArOtherProductDto>> GetOtherProductsAsync(
        Guid businessId,
        Guid currentProductId,
        CancellationToken ct)
    {
        var others = await _db.Products
            .AsNoTracking()
            .Include(p => p.Model3d)
            .Include(p => p.QrCodes.Where(q => q.IsActive))
            .Where(p =>
                p.BusinessId == businessId
                && p.Id != currentProductId
                && p.Status == ProductStatus.Live)
            .OrderBy(p => p.DisplayOrder)
            .ThenBy(p => p.Name)
            .Take(MaxOtherProducts)
            .ToListAsync(ct);

        return others
            .Select(p =>
            {
                var qr = p.QrCodes.FirstOrDefault(q => q.IsActive);
                return new PublicArOtherProductDto(
                    p.Id,
                    p.Name,
                    p.PricePaise,
                    qr?.Slug ?? p.Id.ToString("N")[..12],
                    new PublicArModelDto(p.Model3d?.GlbUrl, SanitizeUsdzUrl(p.Model3d?.UsdzUrl)));
            })
            .ToList();
    }

    private async Task<string?> ResolveOrderingUrlAsync(
        Guid businessId,
        Guid productId,
        CancellationToken ct)
    {
        if (productId != Guid.Empty)
        {
            var productEmbed = await (
                from e in _db.EmbedLinks.AsNoTracking()
                join m in _db.ModelAssets on e.ModelAssetId equals m.Id
                join j in _db.ProcessingJobs on m.ProcessingJobId equals j.Id
                where e.IsActive && e.OrderDeepLink != null && j.ProductId == productId
                select e.OrderDeepLink)
                .FirstOrDefaultAsync(ct);

            if (!string.IsNullOrWhiteSpace(productEmbed))
                return productEmbed;
        }

        return await _db.EmbedLinks
            .AsNoTracking()
            .Where(e => e.BusinessId == businessId && e.IsActive && e.OrderDeepLink != null)
            .OrderByDescending(e => e.CreatedAt)
            .Select(e => e.OrderDeepLink)
            .FirstOrDefaultAsync(ct);
    }

    private async Task<ResolvedArExperience?> ResolveExperienceAsync(string slug, CancellationToken ct)
    {
        var qr = await _db.QrCodes
            .AsNoTracking()
            .Include(q => q.Product!)
                .ThenInclude(p => p.Photos)
            .Include(q => q.Product!)
                .ThenInclude(p => p.Model3d)
            .Include(q => q.Business)
            .FirstOrDefaultAsync(q => q.Slug == slug && q.IsActive, ct);

        if (qr?.Product is not null)
        {
            if (qr.Product.Status != ProductStatus.Live)
                throw new NotFoundException("This dish is currently unavailable or paused.");

            if (qr.Business.Status == BusinessStatus.Deactivated)
                throw new NotFoundException("This restaurant is currently closed or paused.");

            return new ResolvedArExperience(
                qr.Slug,
                qr.Product,
                qr.Business,
                null,
                null);
        }

        var embed = await _db.EmbedLinks
            .AsNoTracking()
            .Include(e => e.ModelAsset)
                .ThenInclude(m => m.ProcessingJob)
                    .ThenInclude(j => j.Product!)
                        .ThenInclude(p => p.Photos)
            .Include(e => e.ModelAsset)
                .ThenInclude(m => m.ProcessingJob)
                    .ThenInclude(j => j.Product!)
                        .ThenInclude(p => p.Model3d)
            .FirstOrDefaultAsync(e => e.Slug == slug && e.IsActive, ct);

        var product = embed?.ModelAsset?.ProcessingJob?.Product;
        if (product is null)
            return null;

        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == embed!.BusinessId, ct)
            ?? throw new NotFoundException("Business not found for this AR experience.");

        return new ResolvedArExperience(
            slug,
            product,
            business,
            embed!.ModelAsset.GlbCdnUrl,
            embed.ModelAsset.UsdzCdnUrl);
    }

    private async Task<QrCode> ResolveActiveQrAsync(string slug, CancellationToken ct)
    {
        var qr = await _db.QrCodes
            .AsNoTracking()
            .FirstOrDefaultAsync(q => q.Slug == slug && q.IsActive, ct);

        if (qr is not null)
            return qr;

        var embed = await _db.EmbedLinks
            .AsNoTracking()
            .Include(e => e.ModelAsset)
                .ThenInclude(m => m.ProcessingJob)
            .FirstOrDefaultAsync(e => e.Slug == slug && e.IsActive, ct);

        var productId = embed?.ModelAsset?.ProcessingJob?.ProductId;
        if (productId is not null)
        {
            qr = await _db.QrCodes
                .AsNoTracking()
                .FirstOrDefaultAsync(q => q.ProductId == productId && q.IsActive, ct);

            if (qr is not null)
                return qr;
        }

        throw new NotFoundException("AR experience not found.");
    }

    private string? ResolveModelUrl(string? storageKey, string? storedUrl, string? fallbackUrl)
    {
        if (!string.IsNullOrWhiteSpace(storageKey))
            return _mediaUrls.Resolve(storageKey);

        if (!string.IsNullOrWhiteSpace(storedUrl))
            return storedUrl;

        return fallbackUrl;
    }

    /// <summary>
    /// Drop the old sample Hamburger USDZ so iOS Quick Look uses the real dish GLB instead.
    /// </summary>
    private static string? SanitizeUsdzUrl(string? usdzUrl)
    {
        if (string.IsNullOrWhiteSpace(usdzUrl))
            return null;
        if (usdzUrl.Contains("Hamburger.usdz", StringComparison.OrdinalIgnoreCase))
            return null;
        return usdzUrl;
    }

    private sealed record ResolvedArExperience(
        string Slug,
        Product Product,
        Business Business,
        string? FallbackGlbUrl,
        string? FallbackUsdzUrl);
}
