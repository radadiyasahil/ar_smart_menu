namespace ARSmartMenu.Domain.Entities;

/// <summary>Subscription tier — Starter, Growth, Pro, or dynamic custom/festival plans.</summary>
public class SubscriptionPlan : BaseEntity
{
    public required string Name { get; set; }
    public required string Slug { get; set; }
    public int MonthlyPricePaise { get; set; }
    public int YearlyPricePaise { get; set; }
    public int MaxProducts { get; set; } = 50;
    public bool IncludesShoot { get; set; }
    public int ShootsPerYear { get; set; }
    public bool ApiIntegration { get; set; }
    public bool AnalyticsExport { get; set; }
    public bool WhatsappSupport { get; set; }
    public bool IsActive { get; set; } = true;
    public int DisplayOrder { get; set; }

    // Dynamic fields for real-world festival discounts, custom durations & safeguards:
    public string? Description { get; set; }
    public int DurationDays { get; set; } = 30;
    public int BasePricePaise { get; set; } = 0;
    public int GstPaise { get; set; } = 0;
    public int TotalPricePaise { get; set; } = 0;
    public int? OriginalPricePaise { get; set; }
    public int DiscountPercent { get; set; } = 0;
    public string? Badge { get; set; }
    public string? FacilitiesJson { get; set; }
    public bool IsDeleted { get; set; } = false;

    public ICollection<Subscription> Subscriptions { get; set; } = [];
}
