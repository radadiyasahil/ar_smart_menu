namespace ARSmartMenu.Domain.Entities;

/// <summary>
/// SEO-friendly embed link: https://ar.[domain].com/dish/{slug}
/// </summary>
public class EmbedLink : BaseEntity
{
    public Guid BusinessId { get; set; }
    public Guid ModelAssetId { get; set; }
    public ModelAsset ModelAsset { get; set; } = null!;

    public required string Slug { get; set; }
    public required string PublicUrl { get; set; }
    public string? OrderDeepLink { get; set; }
    public bool IsActive { get; set; } = true;
    public long ViewCount { get; set; }
}
