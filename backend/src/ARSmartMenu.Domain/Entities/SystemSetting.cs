namespace ARSmartMenu.Domain.Entities;

/// <summary>
/// Dynamic global system settings configurable from the Super Admin panel
/// (e.g., Billing.GstRatePercent, Platform contact details, Razorpay keys, etc.)
/// </summary>
public class SystemSetting : BaseEntity
{
    public string Key { get; set; } = null!;
    public string Value { get; set; } = null!;
    public string? Description { get; set; }
    public string? Group { get; set; } = "General";
}
