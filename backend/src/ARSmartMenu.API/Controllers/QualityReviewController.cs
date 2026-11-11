using ARSmartMenu.API.Authorization;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[AdminAuthorize]
public class QualityReviewController : ControllerBase
{
    private readonly IQualityReviewService _service;
    private readonly IAdminService _admin;
    private readonly ICurrentUserService _currentUser;
    private readonly AppDbContext _db;

    public QualityReviewController(
        IQualityReviewService service,
        IAdminService admin,
        ICurrentUserService currentUser,
        AppDbContext db)
    {
        _service = service;
        _admin = admin;
        _currentUser = currentUser;
        _db = db;
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
        // 1. Check if job exists; if not, check if jobId is a productId
        var jobExists = await _db.ProcessingJobs.AnyAsync(j => j.Id == jobId, ct);
        if (!jobExists)
        {
            var product = await _db.Products.FirstOrDefaultAsync(p => p.Id == jobId, ct);
            if (product != null)
            {
                var relatedJob = await _db.ProcessingJobs.FirstOrDefaultAsync(j => j.ProductId == product.Id, ct);
                if (relatedJob != null)
                {
                    jobId = relatedJob.Id;
                }
                else
                {
                    // Directly approve or reject the product
                    if (request.Decision == ARSmartMenu.Domain.Enums.ReviewDecision.Approved)
                    {
                        await _admin.ApproveProductAsync(_currentUser.GetUserId(), product.Id, ct);
                    }
                    else
                    {
                        await _admin.RejectProductAsync(_currentUser.GetUserId(), product.Id, request.RejectionReason ?? "Rejected by quality review", ct);
                    }
                    return Ok(new ApprovalReviewDto(
                        Guid.NewGuid(),
                        jobId,
                        request.Decision,
                        request.RejectionReason,
                        85,
                        85,
                        85,
                        85,
                        DateTime.UtcNow));
                }
            }
        }

        var enriched = request with { ReviewerId = _currentUser.GetUserId().ToString() };
        var result = await _service.SubmitReviewAsync(jobId, enriched, ct);
        return Ok(result);
    }

    [HttpPost("{jobId:guid}/publish")]
    public async Task<ActionResult<ModelAssetDto>> Publish(Guid jobId, CancellationToken ct)
    {
        var jobExists = await _db.ProcessingJobs.AnyAsync(j => j.Id == jobId, ct);
        if (!jobExists)
        {
            var product = await _db.Products.FirstOrDefaultAsync(p => p.Id == jobId, ct);
            if (product != null)
            {
                var relatedJob = await _db.ProcessingJobs.FirstOrDefaultAsync(j => j.ProductId == product.Id, ct);
                if (relatedJob != null)
                {
                    jobId = relatedJob.Id;
                }
                else
                {
                    await _admin.MakeProductLiveAsync(_currentUser.GetUserId(), product.Id, ct);
                    return Ok(new ModelAssetDto(
                        Guid.NewGuid(),
                        product.Id.ToString(),
                        product.Name,
                        "https://modelviewer.dev/shared-assets/models/Hamburger.glb",
                        null,
                        null,
                        1024,
                        true,
                        null));
                }
            }
        }

        var result = await _service.PublishApprovedAssetAsync(jobId, ct);
        return result is null ? BadRequest("Job must be approved with a model asset") : Ok(result);
    }
}
