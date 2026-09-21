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

    public ICollection<Product> Products { get; set; } = [];
    public ICollection<Subscription> Subscriptions { get; set; } = [];
    public ICollection<QrCode> QrCodes { get; set; } = [];
}
