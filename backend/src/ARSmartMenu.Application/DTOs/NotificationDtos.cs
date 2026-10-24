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
