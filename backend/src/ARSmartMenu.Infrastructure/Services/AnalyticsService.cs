using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class AnalyticsService : IAnalyticsService
{
    private readonly AppDbContext _db;

    public AnalyticsService(AppDbContext db) => _db = db;

    public async Task<AnalyticsOverviewDto> GetOverviewAsync(Guid businessId, string range, CancellationToken ct = default)
    {
        var (from, _) = ResolveRange(range);

        var scans = _db.ArScanEvents.Where(e => e.BusinessId == businessId && e.CreatedAt >= from);
        var views = _db.ArViewEvents.Where(e => e.BusinessId == businessId && e.CreatedAt >= from);

        var totalScans = await scans.CountAsync(ct);
        var totalViews = await views.CountAsync(ct);
        var uniqueVisitors = await scans
            .Select(e => e.SessionId ?? e.IpAddress ?? e.Id.ToString())
            .Distinct()
            .CountAsync(ct);

        var conversionRate = totalScans == 0
            ? 0m
            : Math.Round((decimal)totalViews / totalScans * 100m, 2);

        return new AnalyticsOverviewDto(totalScans, totalViews, uniqueVisitors, conversionRate);
    }

    public async Task<IReadOnlyList<AnalyticsChartPointDto>> GetChartAsync(
        Guid businessId,
        string range,
        CancellationToken ct = default)
    {
        var (from, days) = ResolveRange(range);

        var scanCounts = await _db.ArScanEvents
            .Where(e => e.BusinessId == businessId && e.CreatedAt >= from)
            .GroupBy(e => e.CreatedAt.Date)
            .Select(g => new { Date = g.Key, Count = g.Count() })
            .ToListAsync(ct);

        var viewCounts = await _db.ArViewEvents
            .Where(e => e.BusinessId == businessId && e.CreatedAt >= from)
            .GroupBy(e => e.CreatedAt.Date)
            .Select(g => new { Date = g.Key, Count = g.Count() })
            .ToListAsync(ct);

        var points = new List<AnalyticsChartPointDto>();
        for (var i = 0; i < days; i++)
        {
            var date = DateTime.UtcNow.Date.AddDays(-(days - 1 - i));
            var scans = scanCounts.FirstOrDefault(x => x.Date == date)?.Count ?? 0;
            var views = viewCounts.FirstOrDefault(x => x.Date == date)?.Count ?? 0;
            points.Add(new AnalyticsChartPointDto(date.ToString("yyyy-MM-dd"), scans, views));
        }

        return points;
    }

    public async Task<IReadOnlyList<TopProductAnalyticsDto>> GetTopProductsAsync(
        Guid businessId,
        string range,
        int limit,
        CancellationToken ct = default)
    {
        var (from, _) = ResolveRange(range);
        limit = Math.Clamp(limit, 1, 50);

        var scanStats = await _db.ArScanEvents
            .Where(e => e.BusinessId == businessId && e.CreatedAt >= from && e.ProductId != null)
            .GroupBy(e => e.ProductId)
            .Select(g => new { ProductId = g.Key!.Value, Scans = g.Count() })
            .ToListAsync(ct);

        var viewStats = await _db.ArViewEvents
            .Where(e => e.BusinessId == businessId && e.CreatedAt >= from && e.ProductId != null)
            .GroupBy(e => e.ProductId)
            .Select(g => new { ProductId = g.Key!.Value, Views = g.Count() })
            .ToListAsync(ct);

        var productIds = scanStats.Select(s => s.ProductId)
            .Union(viewStats.Select(v => v.ProductId))
            .ToList();

        if (productIds.Count == 0)
            return [];

        var products = await _db.Products
            .AsNoTracking()
            .Where(p => productIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, p => p.Name, ct);

        return productIds
            .Select(id =>
            {
                var scans = scanStats.FirstOrDefault(s => s.ProductId == id)?.Scans ?? 0;
                var views = viewStats.FirstOrDefault(v => v.ProductId == id)?.Views ?? 0;
                var conversion = scans == 0 ? 0m : Math.Round((decimal)views / scans * 100m, 2);
                return new TopProductAnalyticsDto(id, products.GetValueOrDefault(id, "Unknown"), scans, views, conversion);
            })
            .OrderByDescending(p => p.Scans)
            .ThenByDescending(p => p.Views)
            .Take(limit)
            .ToList();
    }

    private static (DateTime From, int Days) ResolveRange(string range)
    {
        var normalized = range.Trim().ToLowerInvariant();
        return normalized switch
        {
            "today" or "1d" => (DateTime.UtcNow.Date, 1),
            "30d" or "30days" or "month" => (DateTime.UtcNow.Date.AddDays(-29), 30),
            "custom" => (DateTime.UtcNow.Date.AddDays(-6), 7),
            _ => (DateTime.UtcNow.Date.AddDays(-6), 7),
        };
    }
}
