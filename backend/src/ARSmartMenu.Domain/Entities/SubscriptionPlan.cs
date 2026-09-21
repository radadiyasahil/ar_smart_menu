namespace ARSmartMenu.Domain.Entities;

/// <summary>Subscription tier — Starter, Growth, Pro.</summary>
public class SubscriptionPlan : BaseEntity
{
    public required string Name { get; set; }
    public required string Slug { get; set; }
    public int MonthlyPricePaise { get; set; }
    public int YearlyPricePaise { get; set; }
    public int MaxProducts { get; set; }
    public bool IncludesShoot { get; set; }
    public int ShootsPerYear { get; set; }
    public bool ApiIntegration { get; set; }
    public bool AnalyticsExport { get; set; }
    public bool WhatsappSupport { get; set; }
    public bool IsActive { get; set; } = true;
    public int DisplayOrder { get; set; }

    public ICollection<Subscription> Subscriptions { get; set; } = [];
}
