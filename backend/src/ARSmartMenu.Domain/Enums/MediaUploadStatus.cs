namespace ARSmartMenu.Domain.Enums;

public enum MediaUploadStatus
{
    Pending = 0,
    Uploading = 1,
    Completed = 2,
    Failed = 3,
    RetryScheduled = 4
}
