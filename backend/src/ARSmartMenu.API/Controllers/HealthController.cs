using ARSmartMenu.Application.Common;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly AppDbContext _db;

    public HealthController(AppDbContext db) => _db = db;

    /// <summary>Verify API is running and SQL Server database is reachable.</summary>
    [HttpGet]
    public async Task<ActionResult<ApiResponse<object>>> Get(CancellationToken ct)
    {
        var canConnect = await _db.Database.CanConnectAsync(ct);
        if (!canConnect)
        {
            return StatusCode(503, ApiResponse<object>.Fail(
                "Cannot connect to SQL Server database.", "DB_UNAVAILABLE"));
        }

        var tableCounts = new
        {
            users = await _db.Users.CountAsync(ct),
            businesses = await _db.Businesses.CountAsync(ct),
            products = await _db.Products.CountAsync(ct),
            subscriptionPlans = await _db.SubscriptionPlans.CountAsync(ct),
        };

        return Ok(ApiResponse<object>.Ok(new
        {
            status = "healthy",
            database = "connected",
            provider = _db.Database.ProviderName,
            counts = tableCounts,
            timestamp = DateTime.UtcNow,
        }, "AR Smart Menu API is running"));
    }
}
