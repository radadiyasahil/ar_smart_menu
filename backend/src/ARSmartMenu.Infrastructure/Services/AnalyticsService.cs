using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class AnalyticsService : IAnalyticsService
{
    private readonly AppDbContext _db;

    public AnalyticsService(AppDbContext db) => _db = db;

    private sealed class OverviewSpRow
    {
        public int TotalScans { get; set; }
        public int TotalViews { get; set; }
        public int UniqueVisitors { get; set; }
        public int TotalOrders { get; set; }
        public int TotalRevenue { get; set; }
    }

    private sealed class ChartSpRow
    {
        public DateTime BucketDate { get; set; }
        public int Scans { get; set; }
        public int Views { get; set; }
        public int Orders { get; set; }
        public int Revenue { get; set; }
    }

    private sealed class TopProductSpRow
    {
        public Guid ProductId { get; set; }
        public string ProductName { get; set; } = string.Empty;
        public int Scans { get; set; }
        public int Views { get; set; }
        public int OrderCount { get; set; }
        public int TotalRevenue { get; set; }
    }

    public async Task<AnalyticsDashboardDto> GetDashboardAsync(
        Guid businessId,
        string range,
        int topLimit = 10,
        CancellationToken ct = default)
    {
        var overview = await GetOverviewAsync(businessId, range, ct);
        var chart = await GetChartAsync(businessId, range, ct);
        var topProducts = await GetTopProductsAsync(businessId, range, topLimit, ct);
        return new AnalyticsDashboardDto(overview, chart, topProducts);
    }

    public async Task<AnalyticsOverviewDto> GetOverviewAsync(Guid businessId, string range, CancellationToken ct = default)
    {
        var (from, _) = ResolveRange(range);

        var row = await _db.Database
            .SqlQueryRaw<OverviewSpRow>(
                "EXEC [dbo].[usp_GetBusinessAnalyticsOverview] @BusinessId = {0}, @FromDate = {1}",
                businessId,
                from)
            .ToListAsync(ct);

        var stats = row.FirstOrDefault();
        if (stats == null)
            return new AnalyticsOverviewDto(0, 0, 0, 0m, 0, 0, 0m);

        var conversionRate = stats.TotalScans == 0
            ? 0m
            : Math.Round((decimal)stats.TotalViews / stats.TotalScans * 100m, 2);
        var avgOrderValue = stats.TotalOrders == 0
            ? 0m
            : Math.Round((decimal)stats.TotalRevenue / stats.TotalOrders, 2);

        return new AnalyticsOverviewDto(
            stats.TotalScans,
            stats.TotalViews,
            stats.UniqueVisitors,
            conversionRate,
            stats.TotalOrders,
            stats.TotalRevenue,
            avgOrderValue);
    }

    public async Task<IReadOnlyList<AnalyticsChartPointDto>> GetChartAsync(
        Guid businessId,
        string range,
        CancellationToken ct = default)
    {
        var (from, days) = ResolveRange(range);

        var rows = await _db.Database
            .SqlQueryRaw<ChartSpRow>(
                "EXEC [dbo].[usp_GetBusinessAnalyticsChart] @BusinessId = {0}, @FromDate = {1}",
                businessId,
                from)
            .ToListAsync(ct);

        var byDate = rows.ToDictionary(r => r.BucketDate.Date);
        var points = new List<AnalyticsChartPointDto>();

        if (days >= 365)
        {
            for (var m = 11; m >= 0; m--)
            {
                var monthStart = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1).AddMonths(-m);
                var monthEnd = monthStart.AddMonths(1);

                var scans = rows.Where(x => x.BucketDate >= monthStart && x.BucketDate < monthEnd).Sum(x => x.Scans);
                var views = rows.Where(x => x.BucketDate >= monthStart && x.BucketDate < monthEnd).Sum(x => x.Views);
                var orders = rows.Where(x => x.BucketDate >= monthStart && x.BucketDate < monthEnd).Sum(x => x.Orders);
                var revenue = rows.Where(x => x.BucketDate >= monthStart && x.BucketDate < monthEnd).Sum(x => x.Revenue);

                points.Add(new AnalyticsChartPointDto(
                    monthStart.ToString("yyyy-MM-01"),
                    scans,
                    views,
                    orders,
                    revenue));
            }
        }
        else
        {
            for (var i = 0; i < days; i++)
            {
                var date = DateTime.UtcNow.Date.AddDays(-(days - 1 - i));
                byDate.TryGetValue(date, out var bucket);
                points.Add(new AnalyticsChartPointDto(
                    date.ToString("yyyy-MM-dd"),
                    bucket?.Scans ?? 0,
                    bucket?.Views ?? 0,
                    bucket?.Orders ?? 0,
                    bucket?.Revenue ?? 0));
            }
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

        var rows = await _db.Database
            .SqlQueryRaw<TopProductSpRow>(
                "EXEC [dbo].[usp_GetTopProductsAnalytics] @BusinessId = {0}, @FromDate = {1}, @Limit = {2}",
                businessId,
                from,
                limit)
            .ToListAsync(ct);

        return rows.Select(r => new TopProductAnalyticsDto(
            r.ProductId,
            r.ProductName,
            r.Scans,
            r.Views,
            r.Scans == 0 ? 0m : Math.Round((decimal)r.Views / r.Scans * 100m, 2),
            r.OrderCount,
            r.TotalRevenue)).ToList();
    }

    private static (DateTime From, int Days) ResolveRange(string range)
    {
        var normalized = range.Trim().ToLowerInvariant();
        return normalized switch
        {
            "today" or "1d" or "day" => (DateTime.UtcNow.Date, 1),
            "week" or "7d" or "7days" => (DateTime.UtcNow.Date.AddDays(-6), 7),
            "30d" or "30days" or "month" => (DateTime.UtcNow.Date.AddDays(-29), 30),
            "year" or "yearly" or "365d" or "1y" => (DateTime.UtcNow.Date.AddDays(-364), 365),
            _ => (DateTime.UtcNow.Date.AddDays(-6), 7),
        };
    }
}
