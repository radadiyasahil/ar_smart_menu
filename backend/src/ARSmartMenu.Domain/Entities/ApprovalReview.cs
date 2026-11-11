using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class ApprovalReview : BaseEntity
{
    public Guid ProcessingJobId { get; set; }
    public ProcessingJob ProcessingJob { get; set; } = null!;

    public ReviewDecision Decision { get; set; } = ReviewDecision.Pending;
    public string? ReviewerId { get; set; }
    public string? RejectionReason { get; set; }

    public int ModelQualityScore { get; set; }
    public int TextureQualityScore { get; set; }
    public int ScaleAccuracyScore { get; set; }
    public int RenderingQualityScore { get; set; }
    public string? InternalNotes { get; set; }
    public DateTime? ReviewedAt { get; set; }
}
