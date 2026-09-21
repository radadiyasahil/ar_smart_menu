using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class ShootBooking : BaseEntity
{
    public Guid BusinessId { get; set; }
    public required string BusinessName { get; set; }
    public BusinessCategory Category { get; set; }
    public required string LocationAddress { get; set; }
    public required string City { get; set; }
    public DateTime ScheduledAt { get; set; }
    public BookingStatus Status { get; set; } = BookingStatus.Scheduled;

    public Guid? PhotographerId { get; set; }
    public Photographer? Photographer { get; set; }

    public string? Notes { get; set; }
    public string? PhotographerNotes { get; set; }

    public ICollection<MediaUpload> MediaUploads { get; set; } = [];
    public ICollection<ProcessingJob> ProcessingJobs { get; set; } = [];
}
