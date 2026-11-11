using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notifications;
    private readonly ICurrentUserService _currentUser;

    public NotificationsController(INotificationService notifications, ICurrentUserService currentUser)
    {
        _notifications = notifications;
        _currentUser = currentUser;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<NotificationListResponse>>> List(CancellationToken ct)
    {
        var bid = _currentUser.GetBusinessId();
        if (bid is null) return Ok(ApiResponse<NotificationListResponse>.Ok(new(Array.Empty<NotificationDto>(), 0)));
        return Ok(ApiResponse<NotificationListResponse>.Ok(await _notifications.GetNotificationsAsync(bid.Value, ct)));
    }

    [HttpPost("{id:guid}/read")]
    public async Task<ActionResult<ApiResponse<object>>> MarkRead(Guid id, CancellationToken ct)
    {
        var bid = _currentUser.GetBusinessId();
        if (bid is not null) await _notifications.MarkReadAsync(bid.Value, id, ct);
        return Ok(ApiResponse<object>.Ok(new { id, read = true }, "Marked read"));
    }

    [HttpPost("read-all")]
    public async Task<ActionResult<ApiResponse<object>>> MarkAllRead(CancellationToken ct)
    {
        var bid = _currentUser.GetBusinessId();
        if (bid is not null) await _notifications.MarkAllReadAsync(bid.Value, ct);
        return Ok(ApiResponse<object>.Ok(new { allRead = true }, "All marked read"));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(Guid id, CancellationToken ct)
    {
        var bid = _currentUser.GetBusinessId();
        if (bid is not null) await _notifications.DeleteNotificationAsync(bid.Value, id, ct);
        return Ok(ApiResponse<object>.Ok(new { id, deleted = true }, "Deleted"));
    }
}
