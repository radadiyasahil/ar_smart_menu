using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class ProductPhoto : BaseEntity
{
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;

    public required string PhotoUrl { get; set; }
    public required string S3Key { get; set; }
    public PhotoAngleType AngleType { get; set; } = PhotoAngleType.Other;
    public int SortOrder { get; set; }
    public int? FileSizeBytes { get; set; }
    public string? MimeType { get; set; }
    public string UploadedBy { get; set; } = "owner";
}
