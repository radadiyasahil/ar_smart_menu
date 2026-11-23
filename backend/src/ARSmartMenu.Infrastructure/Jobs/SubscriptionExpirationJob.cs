using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Jobs;

/// <summary>
/// Background job that regularly transitions past-due active subscriptions to Expired status.
/// Runs hourly in Hangfire and at application startup.
/// </summary>
public class SubscriptionExpirationJob
{
    private readonly AppDbContext _db;
    private readonly ILogger<SubscriptionExpirationJob> _logger;

    public SubscriptionExpirationJob(AppDbContext db, ILogger<SubscriptionExpirationJob> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task ProcessExpiredSubscriptionsAsync(CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;

        var expiredCount = await _db.Subscriptions
            .Where(s => s.Status == SubscriptionStatus.Active && s.EndsAt <= now)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.Status, SubscriptionStatus.Expired)
                .SetProperty(x => x.UpdatedAt, now), ct);

        if (expiredCount > 0)
        {
            _logger.LogInformation(
                "[SubscriptionExpirationJob] Successfully marked {Count} expired subscriptions as Expired at {Timestamp}.",
                expiredCount,
                now);
        }
    }
}
