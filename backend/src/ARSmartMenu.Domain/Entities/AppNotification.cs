namespace ARSmartMenu.Domain.Entities;

public class AppNotification : BaseEntity
{
    public Guid BusinessId { get; set; }
    public Guid? ProductId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string Type { get; set; } = "info"; // "productLive", "productRejected", "productReview", "businessApproved", "businessRejected", "info"
    public bool IsRead { get; set; } = false;
    public DateTime? ReadAt { get; set; }

    public Business? Business { get; set; }
    public Product? Product { get; set; }
}
