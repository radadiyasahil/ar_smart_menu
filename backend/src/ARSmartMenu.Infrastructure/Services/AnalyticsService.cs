using System.Text.Json;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class AnalyticsService : IAnalyticsService
{
    private readonly AppDbContext _db;

    public AnalyticsService(AppDbContext db) => _db = db;

    public async Task<AnalyticsOverviewDto> GetOverviewAsync(Guid businessId, string range, CancellationToken ct = default)
    {
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business == null || business.Status != BusinessStatus.Active)
        {
            return new AnalyticsOverviewDto(0, 0, 0, 0m, 0, 0, 0m);
        }

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

        // Fetch Orders and Sales data from TableOrders
        var ordersQuery = _db.TableOrders
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= from && o.Status != "CANCELLED");

        var totalOrders = await ordersQuery.CountAsync(ct);
        var totalRevenue = totalOrders == 0 ? 0 : await ordersQuery.SumAsync(o => o.TotalAmount, ct);
        var avgOrderValue = totalOrders == 0 ? 0m : Math.Round((decimal)totalRevenue / totalOrders, 2);

        return new AnalyticsOverviewDto(
            totalScans,
            totalViews,
            uniqueVisitors,
            conversionRate,
            totalOrders,
            totalRevenue,
            avgOrderValue);
    }

    public async Task<IReadOnlyList<AnalyticsChartPointDto>> GetChartAsync(
        Guid businessId,
        string range,
        CancellationToken ct = default)
    {
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business == null || business.Status != BusinessStatus.Active)
        {
            return Array.Empty<AnalyticsChartPointDto>();
        }

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

        var orderStats = await _db.TableOrders
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= from && o.Status != "CANCELLED")
            .GroupBy(o => o.CreatedAt.Date)
            .Select(g => new { Date = g.Key, Orders = g.Count(), Revenue = g.Sum(o => o.TotalAmount) })
            .ToListAsync(ct);

        var points = new List<AnalyticsChartPointDto>();

        if (days >= 365)
        {
            // For yearly view: aggregate by month (last 12 months)
            for (var m = 11; m >= 0; m--)
            {
                var monthStart = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1).AddMonths(-m);
                var monthEnd = monthStart.AddMonths(1);

                var scans = scanCounts.Where(x => x.Date >= monthStart && x.Date < monthEnd).Sum(x => x.Count);
                var views = viewCounts.Where(x => x.Date >= monthStart && x.Date < monthEnd).Sum(x => x.Count);
                var orders = orderStats.Where(x => x.Date >= monthStart && x.Date < monthEnd).Sum(x => x.Orders);
                var revenue = orderStats.Where(x => x.Date >= monthStart && x.Date < monthEnd).Sum(x => x.Revenue);

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
            // For today, week, month: generate daily points
            for (var i = 0; i < days; i++)
            {
                var date = DateTime.UtcNow.Date.AddDays(-(days - 1 - i));
                var scans = scanCounts.FirstOrDefault(x => x.Date == date)?.Count ?? 0;
                var views = viewCounts.FirstOrDefault(x => x.Date == date)?.Count ?? 0;
                var orders = orderStats.FirstOrDefault(x => x.Date == date)?.Orders ?? 0;
                var revenue = orderStats.FirstOrDefault(x => x.Date == date)?.Revenue ?? 0;

                points.Add(new AnalyticsChartPointDto(
                    date.ToString("yyyy-MM-dd"),
                    scans,
                    views,
                    orders,
                    revenue));
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
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business == null || business.Status != BusinessStatus.Active)
        {
            return Array.Empty<TopProductAnalyticsDto>();
        }

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

        var allProducts = await _db.Products
            .AsNoTracking()
            .Where(p => p.BusinessId == businessId)
            .ToDictionaryAsync(p => p.Id, p => p.Name, ct);

        // Fetch orders in range to parse ordered dish quantities and revenue
        var orders = await _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == businessId && o.CreatedAt >= from && o.Status != "CANCELLED")
            .Select(o => o.ItemsJson)
            .ToListAsync(ct);

        var dishSales = new Dictionary<string, (string Name, int Quantity, int Revenue, Guid? ProductId)>(StringComparer.OrdinalIgnoreCase);

        foreach (var json in orders)
        {
            if (string.IsNullOrWhiteSpace(json)) continue;
            try
            {
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in doc.RootElement.EnumerateArray())
                    {
                        var name = item.TryGetProperty("name", out var nProp) ? nProp.GetString() ?? "" : "";
                        if (string.IsNullOrWhiteSpace(name)) continue;

                        var qty = item.TryGetProperty("quantity", out var qProp) && qProp.TryGetInt32(out var q) ? q : 1;
                        var price = item.TryGetProperty("unitPrice", out var pProp) && pProp.TryGetInt32(out var p) ? p : 0;
                        Guid? prodId = null;
                        if (item.TryGetProperty("id", out var idProp) && Guid.TryParse(idProp.GetString(), out var gId))
                        {
                            prodId = gId;
                        }
                        else
                        {
                            var matched = allProducts.FirstOrDefault(kvp => kvp.Value.Equals(name, StringComparison.OrdinalIgnoreCase));
                            if (matched.Key != Guid.Empty) prodId = matched.Key;
                        }

                        var key = prodId?.ToString() ?? name.Trim().ToLowerInvariant();
                        if (dishSales.TryGetValue(key, out var existing))
                        {
                            dishSales[key] = (existing.Name, existing.Quantity + qty, existing.Revenue + (price * qty), existing.ProductId ?? prodId);
                        }
                        else
                        {
                            dishSales[key] = (name, qty, price * qty, prodId);
                        }
                    }
                }
            }
            catch
            {
                // skip malformed item
            }
        }

        var results = new List<TopProductAnalyticsDto>();

        foreach (var (_, data) in dishSales)
        {
            var pId = data.ProductId ?? Guid.Empty;
            var scans = pId != Guid.Empty ? (scanStats.FirstOrDefault(s => s.ProductId == pId)?.Scans ?? 0) : 0;
            var views = pId != Guid.Empty ? (viewStats.FirstOrDefault(v => v.ProductId == pId)?.Views ?? 0) : 0;
            var conversion = scans == 0 ? 0m : Math.Round((decimal)views / scans * 100m, 2);

            results.Add(new TopProductAnalyticsDto(
                pId,
                data.Name,
                scans,
                views,
                conversion,
                data.Quantity,
                data.Revenue));
        }

        // Add any products that have scans/views but were not ordered
        foreach (var s in scanStats)
        {
            if (!results.Any(r => r.ProductId == s.ProductId && r.ProductId != Guid.Empty))
            {
                var views = viewStats.FirstOrDefault(v => v.ProductId == s.ProductId)?.Views ?? 0;
                var conversion = s.Scans == 0 ? 0m : Math.Round((decimal)views / s.Scans * 100m, 2);
                results.Add(new TopProductAnalyticsDto(
                    s.ProductId,
                    allProducts.GetValueOrDefault(s.ProductId, "Unknown"),
                    s.Scans,
                    views,
                    conversion,
                    0,
                    0));
            }
        }

        return results
            .OrderByDescending(p => p.OrderCount)
            .ThenByDescending(p => p.TotalRevenue)
            .ThenByDescending(p => p.Scans)
            .Take(limit)
            .ToList();
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
