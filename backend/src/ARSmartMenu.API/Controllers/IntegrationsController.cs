using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class IntegrationsController : ControllerBase
{
    private readonly IIntegrationService _service;

    public IntegrationsController(IIntegrationService service) => _service = service;

    [HttpGet("business/{businessId:guid}")]
    public async Task<ActionResult<IReadOnlyList<IntegrationDto>>> GetByBusiness(
        Guid businessId,
        CancellationToken ct) =>
        Ok(await _service.GetByBusinessAsync(businessId, ct));

    [HttpPost("embed")]
    public async Task<ActionResult<EmbedLinkDto>> GenerateEmbedLink(
        [FromBody] GenerateEmbedRequest request,
        CancellationToken ct)
    {
        var result = await _service.GenerateEmbedLinkAsync(request.ModelAssetId, request.Slug, ct);
        return Ok(result);
    }

    [HttpGet("deeplink")]
    public async Task<ActionResult<string>> GetDeepLink(
        [FromQuery] Guid businessId,
        [FromQuery] IntegrationPlatform platform,
        [FromQuery] string productSlug,
        CancellationToken ct)
    {
        var link = await _service.GetOrderDeepLinkAsync(businessId, platform, productSlug, ct);
        return Ok(new { deepLink = link });
    }
}

public record GenerateEmbedRequest(Guid ModelAssetId, string Slug);
