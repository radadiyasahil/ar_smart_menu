using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Domain.Entities;

public class DeliveryIntegration : BaseEntity
{
    public Guid BusinessId { get; set; }
    public IntegrationPlatform Platform { get; set; }
    public bool IsEnabled { get; set; }
    public string? ApiKeyHash { get; set; }
    public string? WebhookUrl { get; set; }
    public string? DeepLinkTemplate { get; set; }
    public string? EmbedBaseUrl { get; set; }
    public DateTime? LastSyncAt { get; set; }
}
