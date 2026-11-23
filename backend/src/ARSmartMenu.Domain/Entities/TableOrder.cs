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
    public bool BillRequested { get; set; } = false;
    public DateTime? BillRequestedAt { get; set; }

    /// <summary>3-digit PIN for multi-diner table collaboration (e.g. "482").</summary>
    public string? PartyPin { get; set; }

    /// <summary>Customer feedback rating (1 to 5 stars).</summary>
    public int? Rating { get; set; }

    /// <summary>Optional review / comment left by customer after bill settlement.</summary>
    public string? FeedbackComment { get; set; }

    /// <summary>JSON serialized tags selected by customer (e.g. ["Delicious Food", "Fast Service"]).</summary>
    public string? FeedbackTagsJson { get; set; }

    /// <summary>Timestamp when customer submitted their feedback.</summary>
    public DateTime? FeedbackSubmittedAt { get; set; }

    public Business? Business { get; set; }
}
