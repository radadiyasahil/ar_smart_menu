using ARSmartMenu.API.Authorization;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/admin")]
[AdminAuthorize]
public class AdminController : ControllerBase
{
    private readonly IAdminService _admin;
    private readonly IProductProcessingService _productProcessing;
    private readonly ARSmartMenu.Infrastructure.Jobs.PipelineJobRunner _pipeline;
    private readonly ICurrentUserService _currentUser;

    public AdminController(
        IAdminService admin,
        IProductProcessingService productProcessing,
        ARSmartMenu.Infrastructure.Jobs.PipelineJobRunner pipeline,
        ICurrentUserService currentUser)
    {
        _admin = admin;
        _productProcessing = productProcessing;
        _pipeline = pipeline;
        _currentUser = currentUser;
    }

    [HttpGet("dashboard")]
    public async Task<ActionResult<ApiResponse<AdminDashboardDto>>> Dashboard(CancellationToken ct)
    {
        var result = await _admin.GetDashboardAsync(ct);
        return Ok(ApiResponse<AdminDashboardDto>.Ok(result));
    }

    [HttpGet("businesses")]
    public async Task<ActionResult<ApiResponse<PagedResult<AdminBusinessListItemDto>>>> ListBusinesses(
        [FromQuery] AdminBusinessFilter filter,
        [FromQuery] PaginationQuery pagination,
        CancellationToken ct)
    {
        var result = await _admin.ListBusinessesAsync(filter, pagination, ct);
        return Ok(ApiResponse<PagedResult<AdminBusinessListItemDto>>.Ok(result));
    }

    [HttpPost("businesses/{id:guid}/approve")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> Approve(
        Guid id,
        [FromBody] ApproveBusinessRequest? request,
        CancellationToken ct)
    {
        var result = await _admin.ApproveBusinessAsync(
            _currentUser.GetUserId(),
            id,
            request ?? new ApproveBusinessRequest(),
            ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, "Business approved"));
    }

    [HttpPost("businesses/{id:guid}/reject")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> Reject(
        Guid id,
        [FromBody] RejectBusinessRequest request,
        CancellationToken ct)
    {
        var result = await _admin.RejectBusinessAsync(_currentUser.GetUserId(), id, request, ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, "Business rejected"));
    }

    [HttpGet("products/review-queue")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AdminProductReviewItemDto>>>> ProductReviewQueue(
        [FromQuery] ProcessingJobStatus? jobStatus,
        CancellationToken ct)
    {
        var result = await _admin.GetProductReviewQueueAsync(jobStatus, ct);
        return Ok(ApiResponse<IReadOnlyList<AdminProductReviewItemDto>>.Ok(result));
    }

    /// <summary>Start or restart 3D pipeline for an owner product with 4 photos.</summary>
    [HttpPost("products/{productId:guid}/enqueue-processing")]
    public async Task<ActionResult<ApiResponse<object>>> EnqueueProductProcessing(
        Guid productId,
        CancellationToken ct)
    {
        await _productProcessing.EnqueueFromProductPhotosAsync(productId, ct);
        return Ok(ApiResponse<object>.Ok(new { productId }, "Processing queued"));
    }

    /// <summary>Move a stuck Optimizing/Processing job into Review so admin can approve.</summary>
    [HttpPost("processing-jobs/{jobId:guid}/advance-to-review")]
    public async Task<ActionResult<ApiResponse<object>>> AdvanceJobToReview(Guid jobId, CancellationToken ct)
    {
        await _pipeline.AdvanceStuckJobToReviewAsync(jobId);
        return Ok(ApiResponse<object>.Ok(new { jobId }, "Job moved to review"));
    }
}
