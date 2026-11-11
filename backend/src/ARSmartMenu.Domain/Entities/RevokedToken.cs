namespace ARSmartMenu.Domain.Entities;

/// <summary>JWT identifiers revoked on logout.</summary>
public class RevokedToken : BaseEntity
{
    public required string TokenId { get; set; }
    public DateTime ExpiresAt { get; set; }
}
