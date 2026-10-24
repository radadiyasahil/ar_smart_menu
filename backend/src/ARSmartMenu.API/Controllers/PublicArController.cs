using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/public/ar")]
public class PublicArController : ControllerBase
{
    private readonly IPublicArService _publicAr;

    public PublicArController(IPublicArService publicAr) => _publicAr = publicAr;

    [HttpGet("menu/{slug}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<PublicMenuResponse>>> GetMenuBySlug(string slug, CancellationToken ct)
    {
        var result = await _publicAr.GetMenuBySlugAsync(slug, ct);
        return Ok(ApiResponse<PublicMenuResponse>.Ok(result));
    }

    [HttpGet("{slug}")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<PublicArResponse>>> GetBySlug(string slug, CancellationToken ct)
    {
        var result = await _publicAr.GetBySlugAsync(slug, ct);
        return Ok(ApiResponse<PublicArResponse>.Ok(result));
    }

    [HttpPost("{slug}/scan")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<LogEventResponse>>> LogScan(
        string slug,
        [FromBody] LogScanRequest? request,
        CancellationToken ct)
    {
        var result = await _publicAr.LogScanAsync(
            slug,
            request ?? new LogScanRequest(),
            Request.Headers.UserAgent.ToString(),
            HttpContext.Connection.RemoteIpAddress?.ToString(),
            ct);
        return Ok(ApiResponse<LogEventResponse>.Ok(result, result.Message));
    }

    [HttpPost("{slug}/view")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<LogEventResponse>>> LogView(
        string slug,
        [FromBody] LogViewEventRequest? request,
        CancellationToken ct)
    {
        var result = await _publicAr.LogViewEventAsync(
            slug,
            request ?? new LogViewEventRequest(),
            Request.Headers.UserAgent.ToString(),
            ct);
        return Ok(ApiResponse<LogEventResponse>.Ok(result, result.Message));
    }
}
