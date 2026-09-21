using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

/// <summary>3D AR model linked to a product (GLB + USDZ).</summary>
public class Model3d : BaseEntity
{
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;

    public string? GlbUrl { get; set; }
    public string? UsdzUrl { get; set; }
    public string? GlbS3Key { get; set; }
    public string? UsdzS3Key { get; set; }
    public int? GlbSizeBytes { get; set; }
    public int? UsdzSizeBytes { get; set; }
    public ModelProcessingStatus ProcessingStatus { get; set; } = ModelProcessingStatus.Queued;
    public string? ProcessingError { get; set; }
    public string? ProcessingJobId { get; set; }
    public Guid? ReviewedById { get; set; }
    public User? ReviewedBy { get; set; }
    public string? ReviewNotes { get; set; }
    public DateTime? ProcessingStartedAt { get; set; }
    public DateTime? ProcessingCompletedAt { get; set; }
    public DateTime? ApprovedAt { get; set; }
}
