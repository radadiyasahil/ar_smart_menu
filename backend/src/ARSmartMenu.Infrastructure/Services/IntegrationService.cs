using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class IntegrationService : IIntegrationService
{
    private readonly AppDbContext _db;
    private readonly Microsoft.Extensions.Configuration.IConfiguration _config;

    public IntegrationService(AppDbContext db, Microsoft.Extensions.Configuration.IConfiguration config)
    {
        _db = db;
        _config = config;
    }

    public async Task<IReadOnlyList<IntegrationDto>> GetByBusinessAsync(Guid businessId, CancellationToken ct = default) =>
        await _db.DeliveryIntegrations
            .Where(i => i.BusinessId == businessId)
            .Select(i => new IntegrationDto(
                i.Id, i.BusinessId, i.Platform, i.IsEnabled,
                i.DeepLinkTemplate, i.EmbedBaseUrl))
            .ToListAsync(ct);

    public async Task<EmbedLinkDto> GenerateEmbedLinkAsync(Guid modelAssetId, string slug, CancellationToken ct = default)
    {
        var asset = await _db.ModelAssets.FindAsync([modelAssetId], ct)
            ?? throw new InvalidOperationException("Model asset not found");

        var embedBase = _config["Embed:BaseUrl"] ?? "https://ar.ar-smartmenu.com/dish";
        var publicUrl = $"{embedBase}/{slug}";

        var link = new EmbedLink
        {
            BusinessId = asset.BusinessId,
            ModelAssetId = modelAssetId,
            Slug = slug,
            PublicUrl = publicUrl,
            OrderDeepLink = GetOrderDeepLink(asset.BusinessId, IntegrationPlatform.Custom, slug),
            IsActive = true,
        };

        _db.EmbedLinks.Add(link);
        await _db.SaveChangesAsync(ct);

        return new EmbedLinkDto(link.Id, link.Slug, link.PublicUrl, link.OrderDeepLink, link.IsActive);
    }

    public Task<string> GetOrderDeepLinkAsync(
        Guid businessId,
        IntegrationPlatform platform,
        string productSlug,
        CancellationToken ct = default)
    {
        var link = GetOrderDeepLink(businessId, platform, productSlug);
        return Task.FromResult(link);
    }

    /// <summary>
    /// Deep link placeholders for Swiggy, Zomato, Domino's, Burger King.
    /// Replace with real partner APIs in production.
    /// </summary>
    private string GetOrderDeepLink(Guid businessId, IntegrationPlatform platform, string productSlug)
    {
        var tracking = $"?utm_source=ar&business={businessId}&product={productSlug}";

        return platform switch
        {
            IntegrationPlatform.Swiggy => $"swiggy://dish/{productSlug}{tracking}",
            IntegrationPlatform.Zomato => $"zomato://order/{productSlug}{tracking}",
            IntegrationPlatform.Dominos => $"dominos://product/{productSlug}{tracking}",
            IntegrationPlatform.BurgerKing => $"burgerking://item/{productSlug}{tracking}",
            _ => $"https://order.example.com/{productSlug}{tracking}",
        };
    }
}
