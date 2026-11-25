using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class NotificationService : INotificationService
{
    private readonly AppDbContext _db;

    public NotificationService(AppDbContext db) => _db = db;

    public async Task<NotificationListResponse> GetNotificationsAsync(Guid businessId, CancellationToken ct = default)
    {
        var items = await _db.Notifications.AsNoTracking()
            .Where(n => n.BusinessId == businessId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(50)
            .Select(n => new NotificationDto(n.Id, n.Title, n.Body, n.Type, n.CreatedAt, n.ProductId, n.IsRead))
            .ToListAsync(ct);
        var unread = await _db.Notifications.CountAsync(n => n.BusinessId == businessId && !n.IsRead, ct);
        return new(items, unread);
    }

    public async Task MarkReadAsync(Guid businessId, Guid notificationId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        await _db.Notifications
            .Where(x => x.Id == notificationId && x.BusinessId == businessId && !x.IsRead)
            .ExecuteUpdateAsync(s => s
                .SetProperty(n => n.IsRead, true)
                .SetProperty(n => n.ReadAt, now)
                .SetProperty(n => n.UpdatedAt, now), ct);
    }

    public async Task MarkAllReadAsync(Guid businessId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        await _db.Notifications
            .Where(n => n.BusinessId == businessId && !n.IsRead)
            .ExecuteUpdateAsync(s => s
                .SetProperty(n => n.IsRead, true)
                .SetProperty(n => n.ReadAt, now)
                .SetProperty(n => n.UpdatedAt, now), ct);
    }

    public async Task DeleteNotificationAsync(Guid businessId, Guid notificationId, CancellationToken ct = default)
    {
        await _db.Notifications
            .Where(x => x.Id == notificationId && x.BusinessId == businessId)
            .ExecuteDeleteAsync(ct);
    }

    public async Task<NotificationDto> CreateNotificationAsync(
        Guid businessId, string title, string body, string type, Guid? productId = null, CancellationToken ct = default)
    {
        var n = new AppNotification { BusinessId = businessId, ProductId = productId, Title = title, Body = body, Type = type };
        _db.Notifications.Add(n);
        await _db.SaveChangesAsync(ct);
        return new(n.Id, n.Title, n.Body, n.Type, n.CreatedAt, n.ProductId, n.IsRead);
    }
}
