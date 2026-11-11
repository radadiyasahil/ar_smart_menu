namespace ARSmartMenu.Domain.Entities;

/// <summary>Optimized 3D asset ready for CDN deployment and WebAR.</summary>
public class ModelAsset : BaseEntity
{
    public Guid ProcessingJobId { get; set; }
    public ProcessingJob ProcessingJob { get; set; } = null!;

    public Guid BusinessId { get; set; }
    public required string ProductSlug { get; set; }
    public required string ProductName { get; set; }

    public required string GlbStorageKey { get; set; }
    public string? GlbCdnUrl { get; set; }
    public string? UsdzStorageKey { get; set; }
    public string? UsdzCdnUrl { get; set; }
    public string? ThumbnailStorageKey { get; set; }
    public string? ThumbnailCdnUrl { get; set; }

    public long GlbSizeBytes { get; set; }
    public bool IsPublished { get; set; }
    public DateTime? PublishedAt { get; set; }
    public string? EmbedUrl { get; set; }
}
