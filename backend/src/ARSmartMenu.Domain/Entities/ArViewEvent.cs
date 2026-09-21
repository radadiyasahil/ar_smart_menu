namespace ARSmartMenu.Domain.Entities;

/// <summary>AR model view event for analytics.</summary>
public class ArViewEvent : BaseEntity
{
    public Guid QrCodeId { get; set; }
    public QrCode QrCode { get; set; } = null!;

    public Guid BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public Guid? ProductId { get; set; }
    public Product? Product { get; set; }

    public string? SessionId { get; set; }
    public string? UserAgent { get; set; }
    public int ViewDurationSeconds { get; set; }
    public bool ArLaunched { get; set; }
}
