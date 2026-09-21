namespace ARSmartMenu.Domain.Enums;

/// <summary>End-to-end shoot booking lifecycle.</summary>
public enum BookingStatus
{
    Scheduled = 0,
    Assigned = 1,
    EnRoute = 2,
    InProgress = 3,
    Uploaded = 4,
    Processing = 5,
    Completed = 6,
    Cancelled = 7
}
