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
        var n = await _db.Notifications.FirstOrDefaultAsync(x => x.Id == notificationId && x.BusinessId == businessId, ct);
        if (n is { IsRead: false })
        {
            n.IsRead = true;
            n.ReadAt = n.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task MarkAllReadAsync(Guid businessId, CancellationToken ct = default)
    {
        var unread = await _db.Notifications.Where(n => n.BusinessId == businessId && !n.IsRead).ToListAsync(ct);
        if (unread.Count > 0)
        {
            var now = DateTime.UtcNow;
            foreach (var n in unread) { n.IsRead = true; n.ReadAt = n.UpdatedAt = now; }
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task DeleteNotificationAsync(Guid businessId, Guid notificationId, CancellationToken ct = default)
    {
        var n = await _db.Notifications.FirstOrDefaultAsync(x => x.Id == notificationId && x.BusinessId == businessId, ct);
        if (n is not null) { _db.Notifications.Remove(n); await _db.SaveChangesAsync(ct); }
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
