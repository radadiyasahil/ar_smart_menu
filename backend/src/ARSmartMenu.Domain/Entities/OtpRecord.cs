namespace ARSmartMenu.Domain.Entities;

/// <summary>One-time password sent to a mobile number for login.</summary>
public class OtpRecord : BaseEntity
{
    public required string MobileNumber { get; set; }
    public required string OtpHash { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsUsed { get; set; }
    public int AttemptCount { get; set; }
}
