using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class Subscription : BaseEntity
{
    public Guid BusinessId { get; set; }
    public Business Business { get; set; } = null!;

    public Guid PlanId { get; set; }
    public SubscriptionPlan Plan { get; set; } = null!;

    public BillingCycle BillingCycle { get; set; } = BillingCycle.Monthly;
    public SubscriptionStatus Status { get; set; } = SubscriptionStatus.Active;
    public DateTime StartsAt { get; set; }
    public DateTime EndsAt { get; set; }
    public DateTime? CancelledAt { get; set; }
    public string? CancellationReason { get; set; }
    public string? RazorpaySubscriptionId { get; set; }
    public int ShootsUsed { get; set; }

    // GST Tax Invoice & Audit Fields (Government Tax Return / Audit Compliant)
    public string? InvoiceNumber { get; set; }
    public int BaseAmountPaise { get; set; }
    public int GstPaise { get; set; }
    public int TotalAmountPaise { get; set; }
    public string? PaymentMethod { get; set; }
    public string? PaymentRef { get; set; }
    public string? CustomerGstNumber { get; set; }
    public string? CustomerBusinessName { get; set; }
    public string? CustomerAddress { get; set; }
    public string? CustomerState { get; set; }
    public string? SacCode { get; set; } = "998313";
}
