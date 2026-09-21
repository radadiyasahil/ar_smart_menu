using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

/// <summary>Platform user — business owner or admin.</summary>
public class User : BaseEntity
{
    public required string MobileNumber { get; set; }
    public string? WhatsAppNumber { get; set; }
    public string? FullName { get; set; }
    public string? AadhaarLast4 { get; set; }
    public string? AadhaarDocUrl { get; set; }
    public string? PanNumber { get; set; }
    public string LanguagePreference { get; set; } = "hi";
    public KycStatus KycStatus { get; set; } = KycStatus.Pending;
    public bool IsAdmin { get; set; }

    public ICollection<Business> Businesses { get; set; } = [];
}
