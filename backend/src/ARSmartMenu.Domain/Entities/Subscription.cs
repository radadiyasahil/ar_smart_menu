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
    public int BasePricePaise { get; set; } = 0;
    public int GstPaise { get; set; } = 0;
    public int TotalPricePaise { get; set; } = 0;
    public string? PaymentMethod { get; set; } = "UPI";
    public string? TransactionRef { get; set; }
    public string PaymentStatus { get; set; } = "Completed";
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public string? CustomerBusinessName { get; set; }
    public string? CustomerGstNumber { get; set; }
    public string? CustomerAddress { get; set; }
    public string? CustomerCity { get; set; }
    public string? CustomerState { get; set; }
    public string? SacCode { get; set; } = "998313";
    public decimal GstRatePercent { get; set; } = 18.0m;

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public int BaseAmountPaise { get => BasePricePaise; set => BasePricePaise = value; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public int TotalAmountPaise { get => TotalPricePaise; set => TotalPricePaise = value; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? PaymentRef { get => TransactionRef; set => TransactionRef = value; }
}
