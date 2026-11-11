using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class ProcessingJob : BaseEntity
{
    public Guid BookingId { get; set; }
    public ShootBooking Booking { get; set; } = null!;

    /// <summary>Owner app photo-upload pipeline (optional).</summary>
    public Guid? ProductId { get; set; }
    public Product? Product { get; set; }

    public Guid? MediaUploadId { get; set; }
    public MediaUpload? MediaUpload { get; set; }

    public ProcessingJobStatus Status { get; set; } = ProcessingJobStatus.Queued;
    public ExternalToolSource Source { get; set; } = ExternalToolSource.ManualUpload;

    public int Version { get; set; } = 1;
    public DateTime? EstimatedCompletionAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public int RetryCount { get; set; }
    public string? FailureReason { get; set; }

    public ICollection<ProcessingLog> Logs { get; set; } = [];
    public ModelAsset? ModelAsset { get; set; }
    public ApprovalReview? Review { get; set; }
}
