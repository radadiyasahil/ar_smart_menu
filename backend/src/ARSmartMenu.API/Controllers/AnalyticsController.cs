using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/analytics")]
[Authorize]
public class AnalyticsController : ControllerBase
{
    private readonly IAnalyticsService _analytics;
    private readonly ICurrentUserService _currentUser;

    public AnalyticsController(IAnalyticsService analytics, ICurrentUserService currentUser)
    {
        _analytics = analytics;
        _currentUser = currentUser;
    }

    [HttpGet("overview")]
    public async Task<ActionResult<ApiResponse<AnalyticsOverviewDto>>> Overview(
        [FromQuery] string range = "7d",
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _analytics.GetOverviewAsync(businessId, range, ct);
        return Ok(ApiResponse<AnalyticsOverviewDto>.Ok(result));
    }

    [HttpGet("chart")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AnalyticsChartPointDto>>>> Chart(
        [FromQuery] string range = "7d",
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _analytics.GetChartAsync(businessId, range, ct);
        return Ok(ApiResponse<IReadOnlyList<AnalyticsChartPointDto>>.Ok(result));
    }

    [HttpGet("top-products")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<TopProductAnalyticsDto>>>> TopProducts(
        [FromQuery] string range = "7d",
        [FromQuery] int limit = 10,
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _analytics.GetTopProductsAsync(businessId, range, limit, ct);
        return Ok(ApiResponse<IReadOnlyList<TopProductAnalyticsDto>>.Ok(result));
    }

    private Guid RequireBusinessId()
    {
        return _currentUser.GetBusinessId()
            ?? throw new ValidationException("No business linked to this account.");
    }
}
