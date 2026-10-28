namespace ARSmartMenu.Domain.Entities;

/// <summary>Represents a live dine-in table order ticket placed by customer via WebAR.</summary>
public class TableOrder : BaseEntity
{
    public Guid BusinessId { get; set; }
    public string TableNumber { get; set; } = string.Empty;
    public int Round { get; set; } = 1;
    public string Status { get; set; } = "PENDING"; // "PENDING", "ACCEPTED", "CANCELLED", "COMPLETED"
    public string Instructions { get; set; } = string.Empty;
    public string CustomerPhone { get; set; } = string.Empty;
    public string ItemsJson { get; set; } = "[]";
    public int TotalAmount { get; set; } = 0;
    public DateTime? AcceptedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public Business? Business { get; set; }
}
