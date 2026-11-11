using System.Text;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/analytics")]
[Authorize]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsService _analytics;
    private readonly ICurrentUserService _currentUser;
    private readonly AppDbContext _db;

    public AnalyticsController(
        IAnalyticsService analytics,
        ICurrentUserService currentUser,
        AppDbContext db)
    {
        _analytics = analytics;
        _currentUser = currentUser;
        _db = db;
    }

    private async Task<Guid?> GetActiveUserBusinessIdAsync(CancellationToken ct)
    {
        var userId = _currentUser.GetUserId();
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == userId, ct);

        if (business == null || business.Status != BusinessStatus.Active)
            return null;

        return business.Id;
    }

    [HttpGet("overview")]
    public async Task<ActionResult<ApiResponse<AnalyticsOverviewDto>>> Overview(
        [FromQuery] string range = "7d",
        CancellationToken ct = default)
    {
        var businessId = await GetActiveUserBusinessIdAsync(ct);
        if (!businessId.HasValue)
        {
            return Ok(ApiResponse<AnalyticsOverviewDto>.Ok(new AnalyticsOverviewDto(0, 0, 0, 0m, 0, 0, 0m)));
        }
        var result = await _analytics.GetOverviewAsync(businessId.Value, range, ct);
        return Ok(ApiResponse<AnalyticsOverviewDto>.Ok(result));
    }

    [HttpGet("chart")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AnalyticsChartPointDto>>>> Chart(
        [FromQuery] string range = "7d",
        CancellationToken ct = default)
    {
        var businessId = await GetActiveUserBusinessIdAsync(ct);
        if (!businessId.HasValue)
        {
            return Ok(ApiResponse<IReadOnlyList<AnalyticsChartPointDto>>.Ok(Array.Empty<AnalyticsChartPointDto>()));
        }
        var result = await _analytics.GetChartAsync(businessId.Value, range, ct);
        return Ok(ApiResponse<IReadOnlyList<AnalyticsChartPointDto>>.Ok(result));
    }

    [HttpGet("top-products")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<TopProductAnalyticsDto>>>> TopProducts(
        [FromQuery] string range = "7d",
        [FromQuery] int limit = 10,
        CancellationToken ct = default)
    {
        var businessId = await GetActiveUserBusinessIdAsync(ct);
        if (!businessId.HasValue)
        {
            return Ok(ApiResponse<IReadOnlyList<TopProductAnalyticsDto>>.Ok(Array.Empty<TopProductAnalyticsDto>()));
        }
        var result = await _analytics.GetTopProductsAsync(businessId.Value, range, limit, ct);
        return Ok(ApiResponse<IReadOnlyList<TopProductAnalyticsDto>>.Ok(result));
    }

    [HttpGet("export")]
    public async Task<IActionResult> ExportFinancialReport(
        [FromQuery] string range = "365d",
        CancellationToken ct = default)
    {
        var userId = _currentUser.GetUserId();
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == userId, ct);

        if (business == null || business.Status != BusinessStatus.Active)
        {
            return BadRequest(ApiResponse<object>.Fail("Active business required to export report."));
        }

        var overview = await _analytics.GetOverviewAsync(business.Id, range, ct);
        var chart = await _analytics.GetChartAsync(business.Id, range, ct);
        var topProducts = await _analytics.GetTopProductsAsync(business.Id, range, 50, ct);

        var orders = await _db.TableOrders
            .AsNoTracking()
            .Where(o => o.BusinessId == business.Id && o.Status != "CANCELLED")
            .OrderByDescending(o => o.CreatedAt)
            .Take(500)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        // UTF-8 BOM for Microsoft Excel compatibility
        sb.Append('\uFEFF');

        // Header Section
        sb.AppendLine("AR SMART MENU - FINANCIAL AUDIT & REVENUE REPORT");
        sb.AppendLine($"Business Name,\"{business.BusinessName.Replace("\"", "\"\"")}\"");
        sb.AppendLine($"City / Address,\"{business.City}, {business.FullAddress.Replace("\"", "\"\"")}\"");
        sb.AppendLine($"GST Number,\"{business.GstNumber ?? "N/A"}\"");
        sb.AppendLine($"FSSAI License,\"{business.FssaiNumber ?? "N/A"}\"");
        sb.AppendLine($"Reporting Period,\"{range}\"");
        sb.AppendLine($"Generated On (UTC),\"{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss}\"");
        sb.AppendLine();

        // Financial KPI Summary
        sb.AppendLine("KEY FINANCIAL AUDIT METRICS");
        sb.AppendLine("Metric,Value,Unit / Notes");
        sb.AppendLine($"Total Gross Revenue,{overview.TotalRevenue},INR (₹)");
        sb.AppendLine($"Total Orders Completed,{overview.TotalOrders},Orders");
        sb.AppendLine($"Average Order Value (AOV),{overview.AverageOrderValue:F2},INR (₹)");
        sb.AppendLine($"Estimated GST (5%),{Math.Round(overview.TotalRevenue * 0.05m, 2)},INR (₹)");
        sb.AppendLine($"Net Revenue (Excl. GST),{Math.Round(overview.TotalRevenue * 0.95m, 2)},INR (₹)");
        sb.AppendLine($"Total Dine-in AR Scans,{overview.TotalScans},Scans");
        sb.AppendLine($"Unique Diners / Visitors,{overview.UniqueVisitors},Visitors");
        sb.AppendLine($"Conversion Rate,{overview.ConversionRate:F2},%");
        sb.AppendLine();

        // Periodic Breakdown
        sb.AppendLine("PERIODIC SALES & ORDER LEDGER");
        sb.AppendLine("Date / Period,Orders,Dine-in Scans,Menu Views,Gross Revenue (INR),Est. GST 5% (INR),Net Revenue (INR)");
        foreach (var p in chart)
        {
            var gst = Math.Round(p.Revenue * 0.05m, 2);
            var net = Math.Round(p.Revenue * 0.95m, 2);
            sb.AppendLine($"{p.Date},{p.Orders},{p.Scans},{p.Views},{p.Revenue},{gst},{net}");
        }
        sb.AppendLine();

        // Menu / Dish Sales Performance
        sb.AppendLine("MENU ITEMS & DISH SALES PERFORMANCE");
        sb.AppendLine("Product ID,Dish Name,Quantity Sold,Scans,Views,Conversion Rate (%),Total Revenue (INR),Share of Revenue (%)");
        foreach (var prod in topProducts)
        {
            var share = overview.TotalRevenue > 0
                ? Math.Round((decimal)prod.TotalRevenue / overview.TotalRevenue * 100m, 2)
                : 0m;
            sb.AppendLine($"\"{prod.ProductId}\",\"{prod.ProductName.Replace("\"", "\"\"")}\",{prod.OrderCount},{prod.Scans},{prod.Views},{prod.ConversionRate:F2},{prod.TotalRevenue},{share}");
        }
        sb.AppendLine();

        // Audit Trail: Table Orders
        sb.AppendLine("AUDIT TRAIL - COMPLETED TABLE ORDERS & BILLS");
        sb.AppendLine("Order ID,Table Number,Date (UTC),Customer Phone,Total Amount (INR),Status");
        foreach (var o in orders)
        {
            sb.AppendLine($"\"{o.Id}\",\"Table {o.TableNumber}\",\"{o.CreatedAt:yyyy-MM-dd HH:mm}\",\"{o.CustomerPhone ?? "N/A"}\",{o.TotalAmount},\"{o.Status}\"");
        }

        var bytes = Encoding.UTF8.GetBytes(sb.ToString());
        var fileName = $"Financial_Audit_Report_{business.BusinessName.Replace(" ", "_")}_{DateTime.UtcNow:yyyyMMdd}.csv";

        return File(bytes, "text/csv; charset=utf-8", fileName);
    }
}
