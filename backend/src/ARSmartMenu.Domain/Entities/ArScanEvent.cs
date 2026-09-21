namespace ARSmartMenu.Domain.Entities;

/// <summary>QR code scan event for analytics.</summary>
public class ArScanEvent : BaseEntity
{
    public Guid QrCodeId { get; set; }
    public QrCode QrCode { get; set; } = null!;

    public Guid BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public Guid? ProductId { get; set; }
    public Product? Product { get; set; }

    public string? SessionId { get; set; }
    public string? UserAgent { get; set; }
    public string? IpAddress { get; set; }
    public string? Referrer { get; set; }
}
