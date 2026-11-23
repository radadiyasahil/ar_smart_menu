using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

/// <summary>Restaurant / retail business registered on the platform.</summary>
public class Business : BaseEntity
{
    public Guid OwnerId { get; set; }
    public User Owner { get; set; } = null!;

    public required string BusinessName { get; set; }
    public BusinessType BusinessType { get; set; }
    public required string City { get; set; }
    public required string FullAddress { get; set; }
    public string? LogoUrl { get; set; }
    public string? FssaiNumber { get; set; }
    public string? GstNumber { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankIfsc { get; set; }
    public string? UpiId { get; set; }
    public bool BankPennyVerified { get; set; }
    public string? RazorpayContactId { get; set; }
    public string? RazorpayFundAccountId { get; set; }
    public BusinessStatus Status { get; set; } = BusinessStatus.PendingApproval;
    public string? RejectionReason { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public Guid? ApprovedById { get; set; }
    public User? ApprovedBy { get; set; }
    public string? AdminNotes { get; set; }
    public string? WifiName { get; set; }
    public string? WifiPassword { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public int GeofenceRadiusMeters { get; set; } = 200;
    public bool RequireGeofence { get; set; } = false;

    // Dynamic Dish Limit & AR View Pricing (Admin Configurable)
    public int? CustomDishLimit { get; set; }
    public bool ArViewEnabled { get; set; } = true;
    public int ArPerViewChargePaise { get; set; } = 50;
    public int ArViewCredits { get; set; } = 500;
    public int ArViewsUsed { get; set; } = 0;

    /// <summary>Standard GST / Tax rate in percent (e.g. 5.0 for 5% restaurant GST in India).</summary>
    public double GstRate { get; set; } = 5.0;

    public ICollection<Product> Products { get; set; } = [];
    public ICollection<Subscription> Subscriptions { get; set; } = [];
    public ICollection<QrCode> QrCodes { get; set; } = [];
}
