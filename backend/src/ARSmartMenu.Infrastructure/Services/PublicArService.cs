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

    public PublicArService(AppDbContext db, MediaUrlResolver mediaUrls)
    {
        _db = db;
        _mediaUrls = mediaUrls;
    }

    public async Task<PublicArResponse> GetBySlugAsync(string slug, CancellationToken ct = default)
    {
        var resolved = await ResolveExperienceAsync(slug, ct)
            ?? throw new NotFoundException("AR experience not found.");

        var product = resolved.Product;
        var glbUrl = ResolveModelUrl(
            product.Model3d?.GlbS3Key,
            product.Model3d?.GlbUrl,
            resolved.FallbackGlbUrl);
        var usdzUrl = product.Model3d?.UsdzUrl ?? resolved.FallbackUsdzUrl;
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

        if (business is null)
            throw new NotFoundException("Restaurant menu not found.");

        var products = await _db.Products
            .AsNoTracking()
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .Where(p => p.BusinessId == business.Id && p.Status == ProductStatus.Live)
            .OrderBy(p => p.DisplayOrder)
            .ThenByDescending(p => p.CreatedAt)
            .ToListAsync(ct);

        var productQrs = await _db.QrCodes
            .AsNoTracking()
            .Where(q => q.BusinessId == business.Id && q.ProductId != null && q.IsActive)
            .ToDictionaryAsync(q => q.ProductId!.Value, q => q.Slug, ct);

        var allDishes = products.Select(p =>
        {
            var glbUrl = ResolveModelUrl(p.Model3d?.GlbS3Key, p.Model3d?.GlbUrl, null);
            var dishSlug = productQrs.TryGetValue(p.Id, out var s) ? s : p.Id.ToString("N");
            var thumb = p.Photos.OrderBy(ph => ph.SortOrder).FirstOrDefault();
            var thumbUrl = thumb != null ? _mediaUrls.Resolve(thumb.S3Key, thumb.PhotoUrl) : null;
            var photos = p.Photos.OrderBy(ph => ph.SortOrder).Select(ph => _mediaUrls.Resolve(ph.S3Key, ph.PhotoUrl)).ToList();

            return new PublicMenuDishDto(
                p.Id,
                p.Name,
                p.Description,
                p.PricePaise,
                (int)p.VegStatus,
                p.IsSpicy,
                p.IsBestseller,
                p.IsNew,
                p.SoldOutToday,
                thumbUrl,
                photos,
                glbUrl,
                p.Model3d?.UsdzUrl,
                p.Model3d is not null && !string.IsNullOrEmpty(glbUrl),
                dishSlug
            );
        }).ToList();

        var categories = allDishes
            .GroupBy(d =>
            {
                var prod = products.First(p => p.Id == d.Id);
                return prod.Category?.ToString() ?? "Main Course";
            })
            .Select(g => new PublicMenuCategoryDto(
                g.Key,
                (int)(products.First(p => (p.Category?.ToString() ?? "Main Course") == g.Key).Category ?? ProductCategory.MainCourse),
                g.ToList()
            ))
            .ToList();

        if (categories.Count == 0 && allDishes.Count > 0)
        {
            categories = [new PublicMenuCategoryDto("Menu", 1, allDishes)];
        }

        var orderingUrl = await ResolveOrderingUrlAsync(business.Id, Guid.Empty, ct);
        var owner = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == business.OwnerId, ct);

        return new PublicMenuResponse(
            slug,
            business.BusinessName,
            business.LogoUrl,
            business.City,
            business.FullAddress,
            owner?.WhatsAppNumber ?? owner?.MobileNumber,
            orderingUrl,
            categories,
            business.Status == BusinessStatus.Active,
            business.Status == BusinessStatus.Active ? null : "This restaurant is temporarily paused / closed."
        );
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
            SessionId = request.SessionId,
            UserAgent = userAgent,
            IpAddress = ipAddress,
            Referrer = request.Referrer,
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
            SessionId = request.SessionId,
            UserAgent = userAgent,
            ViewDurationSeconds = request.ViewDurationSeconds,
            ArLaunched = request.ArLaunched || request.Rotated || request.Resized,
        };

        _db.ArViewEvents.Add(view);
        await _db.SaveChangesAsync(ct);

        return new LogEventResponse(view.Id, "View event logged.");
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
                    new PublicArModelDto(p.Model3d?.GlbUrl, p.Model3d?.UsdzUrl));
            })
            .ToList();
    }

    private async Task<string?> ResolveOrderingUrlAsync(
        Guid businessId,
        Guid productId,
        CancellationToken ct)
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

    private sealed record ResolvedArExperience(
        string Slug,
        Product Product,
        Business Business,
        string? FallbackGlbUrl,
        string? FallbackUsdzUrl);
}
