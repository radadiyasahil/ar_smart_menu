namespace ARSmartMenu.Application.DTOs;

public record NotificationDto(
    Guid Id,
    string Title,
    string Body,
    string Type,
    DateTime CreatedAt,
    Guid? ProductId,
    bool Read);

public record NotificationListResponse(
    IReadOnlyList<NotificationDto> Notifications,
    int UnreadCount);

public record AdminNotificationDto(
    Guid Id,
    string Title,
    string Message,
    string Type, // "business_approval" | "product_review"
    Guid BusinessId,
    string BusinessName,
    Guid? ProductId,
    string? ProductName,
    string? PhotoUrl,
    DateTime CreatedAt,
    string ActionUrl);

public record AdminNotificationsResponse(
    IReadOnlyList<AdminNotificationDto> Notifications,
    int TotalPendingCount,
    int PendingBusinessesCount,
    int PendingProductsCount);
