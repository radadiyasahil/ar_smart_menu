using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class QrCode : BaseEntity
{
    public Guid? ProductId { get; set; }
    public Product? Product { get; set; }

    public Guid BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public QrType QrType { get; set; } = QrType.Product;
    public required string Slug { get; set; }
    public required string WebUrl { get; set; }
    public string? QrImageUrl { get; set; }
    public string? QrImageS3Key { get; set; }
    public string? QrPdfUrl { get; set; }
    public string? QrPdfS3Key { get; set; }
    public bool IsActive { get; set; } = true;
}
