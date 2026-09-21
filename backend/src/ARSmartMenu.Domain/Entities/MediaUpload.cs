using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class MediaUpload : BaseEntity
{
    public Guid BookingId { get; set; }
    public ShootBooking Booking { get; set; } = null!;

    public required string FileName { get; set; }
    public required string ContentType { get; set; }
    public long FileSizeBytes { get; set; }
    public CaptureGuideType? CaptureGuide { get; set; }

    /// <summary>Cloud storage key e.g. raw-media/{businessId}/{file}</summary>
    public required string StorageKey { get; set; }
    public string? StorageUrl { get; set; }

    public MediaUploadStatus Status { get; set; } = MediaUploadStatus.Pending;
    public int UploadProgressPercent { get; set; }
    public int RetryCount { get; set; }
    public string? ErrorMessage { get; set; }
    public string? Checksum { get; set; }
}
