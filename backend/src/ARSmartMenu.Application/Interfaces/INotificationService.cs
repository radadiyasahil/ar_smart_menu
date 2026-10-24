using ARSmartMenu.Application.DTOs;

namespace ARSmartMenu.Application.Interfaces;

public interface INotificationService
{
    Task<NotificationListResponse> GetNotificationsAsync(Guid businessId, CancellationToken ct = default);
    Task MarkReadAsync(Guid businessId, Guid notificationId, CancellationToken ct = default);
    Task MarkAllReadAsync(Guid businessId, CancellationToken ct = default);
    Task DeleteNotificationAsync(Guid businessId, Guid notificationId, CancellationToken ct = default);
    Task<NotificationDto> CreateNotificationAsync(
        Guid businessId,
        string title,
        string body,
        string type,
        Guid? productId = null,
        CancellationToken ct = default);
}
