using System.Text.RegularExpressions;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace ARSmartMenu.Infrastructure.Services;

public class QrCodeService : IQrCodeService
{
    private readonly AppDbContext _db;
    private readonly string _dishBaseUrl;

    public QrCodeService(AppDbContext db, IConfiguration config)
    {
        _db = db;
        var embedBase = config["Embed:BaseUrl"];
        var webArBase = config["WebAr:BaseUrl"] ?? "https://ar.ar-smartmenu.com";
        _dishBaseUrl = embedBase ?? $"{webArBase.TrimEnd('/')}/dish";
    }

    public string BuildDishWebUrl(string slug) =>
        $"{_dishBaseUrl.TrimEnd('/')}/{slug}";

    public string BuildMenuWebUrl(string slug, int? tableNumber = null)
    {
        var baseWeb = _dishBaseUrl.Replace("/dish", "");
        var url = $"{baseWeb.TrimEnd('/')}/menu/{slug}";
        if (tableNumber.HasValue && tableNumber.Value > 0)
            url += $"?table={tableNumber.Value}";
        return url;
    }

    public async Task<QrCodeDto> GetOrCreateMasterQrAsync(Guid businessId, CancellationToken ct = default)
    {
        var existing = await _db.QrCodes
            .Include(q => q.Product)
            .FirstOrDefaultAsync(q => q.BusinessId == businessId && q.QrType == QrType.Menu && q.IsActive, ct);

        if (existing is not null)
            return MapQr(existing, "Restaurant Master Menu");

        var business = await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        var slug = await GenerateUniqueSlugAsync(business.BusinessName + "-menu", ct);
        var webUrl = BuildMenuWebUrl(slug);
        var qrImageUrl = $"{_dishBaseUrl.TrimEnd('/')}/qr/{slug}.png";

        var qr = new QrCode
        {
            BusinessId = businessId,
            ProductId = null,
            QrType = QrType.Menu,
            Slug = slug,
            WebUrl = webUrl,
            QrImageUrl = qrImageUrl,
            QrImageS3Key = $"qr-codes/{businessId}/{slug}.png",
            IsActive = true,
        };

        _db.QrCodes.Add(qr);
        await _db.SaveChangesAsync(ct);

        return MapQr(qr, "Restaurant Master Menu");
    }

    public async Task<IReadOnlyList<QrCodeDto>> GenerateTableQrsAsync(Guid businessId, int tableCount, CancellationToken ct = default)
    {
        if (tableCount < 1 || tableCount > 100)
            throw new ValidationException("Table count must be between 1 and 100.");

        var master = await GetOrCreateMasterQrAsync(businessId, ct);
        var baseSlug = master.Slug;

        var existingTables = await _db.QrCodes
            .Where(q => q.BusinessId == businessId && q.QrType == QrType.Table)
            .ToListAsync(ct);

        var results = new List<QrCode>();
        for (var i = 1; i <= tableCount; i++)
        {
            var tableNo = i;
            var tableSlug = $"{baseSlug}-t{tableNo}";
            var webUrl = BuildMenuWebUrl(baseSlug, tableNo);

            var existing = existingTables.FirstOrDefault(q => q.Slug == tableSlug);
            if (existing is not null)
            {
                existing.IsActive = true;
                existing.WebUrl = webUrl;
                existing.UpdatedAt = DateTime.UtcNow;
                results.Add(existing);
            }
            else
            {
                var qr = new QrCode
                {
                    BusinessId = businessId,
                    ProductId = null,
                    QrType = QrType.Table,
                    Slug = tableSlug,
                    WebUrl = webUrl,
                    QrImageUrl = $"{_dishBaseUrl.TrimEnd('/')}/qr/{tableSlug}.png",
                    QrImageS3Key = $"qr-codes/{businessId}/{tableSlug}.png",
                    IsActive = true,
                };
                _db.QrCodes.Add(qr);
                results.Add(qr);
            }
        }

        await _db.SaveChangesAsync(ct);
        return results.Select(q => MapQr(q, $"Table {q.Slug.Split("-t").Last()}")).ToList();
    }

    public async Task<QrCodeDto> GenerateForProductAsync(Guid businessId, Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == productId && p.BusinessId == businessId, ct)
            ?? throw new NotFoundException("Product not found.");

        if (product.Status is not ProductStatus.Live and not ProductStatus.Review and not ProductStatus.Submitted)
            throw new ValidationException("Product must be submitted before generating a QR code.");

        var slug = await GenerateUniqueSlugAsync(product.Name, ct);
        var webUrl = BuildDishWebUrl(slug);
        var qrImageUrl = $"{_dishBaseUrl.TrimEnd('/')}/qr/{slug}.png";

        var qr = new QrCode
        {
            BusinessId = businessId,
            ProductId = productId,
            QrType = QrType.Product,
            Slug = slug,
            WebUrl = webUrl,
            QrImageUrl = qrImageUrl,
            QrImageS3Key = $"qr-codes/{businessId}/{slug}.png",
            IsActive = true,
        };

        _db.QrCodes.Add(qr);
        await _db.SaveChangesAsync(ct);

        return MapQr(qr, product.Name);
    }

    public async Task<IReadOnlyList<QrCodeDto>> ListAsync(Guid businessId, CancellationToken ct = default)
    {
        var codes = await _db.QrCodes
            .Include(q => q.Product)
            .Where(q => q.BusinessId == businessId)
            .OrderByDescending(q => q.CreatedAt)
            .ToListAsync(ct);

        var dirty = false;
        foreach (var qr in codes)
        {
            var expected = BuildDishWebUrl(qr.Slug);
            if (qr.WebUrl != expected)
            {
                qr.WebUrl = expected;
                qr.UpdatedAt = DateTime.UtcNow;
                dirty = true;
            }
        }

        if (dirty)
            await _db.SaveChangesAsync(ct);

        return codes.Select(q => MapQr(q, q.Product?.Name)).ToList();
    }

    public async Task<QrCodeDto> DeactivateAsync(Guid businessId, Guid qrCodeId, CancellationToken ct = default)
    {
        var qr = await _db.QrCodes
            .Include(q => q.Product)
            .FirstOrDefaultAsync(q => q.Id == qrCodeId && q.BusinessId == businessId, ct)
            ?? throw new NotFoundException("QR code not found.");

        qr.IsActive = false;
        qr.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapQr(qr, qr.Product?.Name);
    }

    private async Task<string> GenerateUniqueSlugAsync(string productName, CancellationToken ct)
    {
        var baseSlug = Slugify(productName);
        var suffix = GenerateSuffix();
        var slug = $"{baseSlug}-{suffix}";

        while (await _db.QrCodes.AnyAsync(q => q.Slug == slug, ct))
        {
            suffix = GenerateSuffix();
            slug = $"{baseSlug}-{suffix}";
        }

        return slug;
    }

    internal static string Slugify(string value)
    {
        var lower = value.Trim().ToLowerInvariant();
        var slug = Regex.Replace(lower, @"[^a-z0-9]+", "-").Trim('-');
        return string.IsNullOrEmpty(slug) ? "product" : slug[..Math.Min(slug.Length, 40)].TrimEnd('-');
    }

    private static string GenerateSuffix()
    {
        const string chars = "abcdefghijklmnopqrstuvwxyz0123456789";
        return string.Create(4, chars, (span, c) =>
        {
            for (var i = 0; i < span.Length; i++)
                span[i] = c[Random.Shared.Next(c.Length)];
        });
    }

    internal static QrCodeDto MapQr(QrCode qr, string? productName) => new(
        qr.Id,
        qr.BusinessId,
        qr.ProductId,
        productName,
        qr.QrType,
        qr.Slug,
        qr.WebUrl,
        qr.QrImageUrl,
        qr.IsActive,
        qr.CreatedAt);
}
