using ARSmartMenu.API.Authorization;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[AdminAuthorize]
public class QualityReviewController : ControllerBase
{
    private readonly IQualityReviewService _service;
    private readonly ICurrentUserService _currentUser;

    public QualityReviewController(IQualityReviewService service, ICurrentUserService currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    [HttpGet("{jobId:guid}")]
    public async Task<ActionResult<ApprovalReviewDto>> GetReview(Guid jobId, CancellationToken ct)
    {
        var result = await _service.GetReviewAsync(jobId, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost("{jobId:guid}")]
    public async Task<ActionResult<ApprovalReviewDto>> SubmitReview(
        Guid jobId,
        [FromBody] SubmitReviewRequest request,
        CancellationToken ct)
    {
        var enriched = request with { ReviewerId = _currentUser.GetUserId().ToString() };
        var result = await _service.SubmitReviewAsync(jobId, enriched, ct);
        return Ok(result);
    }

    [HttpPost("{jobId:guid}/publish")]
    public async Task<ActionResult<ModelAssetDto>> Publish(Guid jobId, CancellationToken ct)
    {
        var result = await _service.PublishApprovedAssetAsync(jobId, ct);
        return result is null ? BadRequest("Job must be approved with a model asset") : Ok(result);
    }
}
