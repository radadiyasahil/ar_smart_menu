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
