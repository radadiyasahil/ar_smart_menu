namespace ARSmartMenu.Domain.Enums;

/// <summary>3D processing pipeline job status.</summary>
public enum ProcessingJobStatus
{
    Queued = 0,
    Processing = 1,
    Optimizing = 2,
    Review = 3,
    Approved = 4,
    Rejected = 5,
    Failed = 6
}
