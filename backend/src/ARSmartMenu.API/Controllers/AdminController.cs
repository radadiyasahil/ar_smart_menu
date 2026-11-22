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
    private readonly ISubscriptionService _subscriptions;

    public AdminController(
        IAdminService admin,
        IProductProcessingService productProcessing,
        ARSmartMenu.Infrastructure.Jobs.PipelineJobRunner pipeline,
        ICurrentUserService currentUser,
        ISubscriptionService subscriptions)
    {
        _admin = admin;
        _productProcessing = productProcessing;
        _pipeline = pipeline;
        _currentUser = currentUser;
        _subscriptions = subscriptions;
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

    /// <summary>Get detailed business profile by ID for the admin full-page view.</summary>
    [HttpGet("businesses/{id:guid}")]
    public async Task<ActionResult<ApiResponse<AdminBusinessListItemDto>>> GetBusinessById(
        Guid id,
        CancellationToken ct)
    {
        var result = await _admin.GetBusinessByIdAsync(id, ct);
        if (result == null)
            return NotFound(ApiResponse<AdminBusinessListItemDto>.Fail("Business not found"));
        return Ok(ApiResponse<AdminBusinessListItemDto>.Ok(result));
    }

    /// <summary>Update business details and notes directly from the admin full-page view.</summary>
    [HttpPut("businesses/{id:guid}")]
    public async Task<ActionResult<ApiResponse<AdminBusinessListItemDto>>> UpdateBusiness(
        Guid id,
        [FromBody] AdminUpdateBusinessRequest request,
        CancellationToken ct)
    {
        var result = await _admin.UpdateBusinessAsync(_currentUser.GetUserId(), id, request, ct);
        return Ok(ApiResponse<AdminBusinessListItemDto>.Ok(result, "Business details updated successfully"));
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

    /// <summary>Approve a product and notify the owner.</summary>
    [HttpPost("products/{productId:guid}/approve")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> ApproveProduct(
        Guid productId,
        CancellationToken ct)
    {
        var result = await _admin.ApproveProductAsync(_currentUser.GetUserId(), productId, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product approved and notification sent"));
    }

    /// <summary>Reject a product with reason and notify the owner.</summary>
    [HttpPost("products/{productId:guid}/reject")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> RejectProduct(
        Guid productId,
        [FromBody] RejectProductRequest request,
        CancellationToken ct)
    {
        var result = await _admin.RejectProductAsync(_currentUser.GetUserId(), productId, request.Reason, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product rejected and notification sent"));
    }

    /// <summary>Publish a product directly to Live in AR and notify the owner.</summary>
    [HttpPost("products/{productId:guid}/make-live")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> MakeProductLive(
        Guid productId,
        CancellationToken ct)
    {
        var result = await _admin.MakeProductLiveAsync(_currentUser.GetUserId(), productId, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product is now Live and notification sent"));
    }

    /// <summary>Change business status (Active, Suspended, Deactivated, Rejected) with notes.</summary>
    [HttpPost("businesses/{id:guid}/set-status")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> SetBusinessStatus(
        Guid id,
        [FromBody] AdminSetBusinessStatusRequest request,
        CancellationToken ct)
    {
        var result = await _admin.SetBusinessStatusAsync(
            _currentUser.GetUserId(),
            id,
            request.Status,
            request.Reason,
            request.AdminNotes,
            ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, $"Business status updated to {request.Status}"));
    }

    /// <summary>Change product status (Live, Paused, Draft, Review, Rejected).</summary>
    [HttpPost("products/{productId:guid}/set-status")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> SetProductStatus(
        Guid productId,
        [FromBody] UpdateProductStatusRequest request,
        CancellationToken ct)
    {
        var result = await _admin.SetProductStatusAsync(_currentUser.GetUserId(), productId, request.Status, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, $"Product status updated to {request.Status}"));
    }

    [HttpPost("businesses/{id:guid}/grant-subscription")]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> GrantSubscription(
        Guid id,
        [FromBody] AdminGrantSubscriptionRequest request,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminGrantPlanAsync(id, request, ct);
        return Ok(ApiResponse<SubscriptionDto>.Ok(result, "Subscription plan granted successfully"));
    }

    /// <summary>Emergency reset of restaurant owner PIN by Super Admin.</summary>
    [HttpPost("businesses/{id:guid}/reset-pin")]
    public async Task<ActionResult<ApiResponse<object>>> ResetOwnerPin(
        Guid id,
        [FromBody] AdminResetPinRequest request,
        CancellationToken ct)
    {
        await _admin.ResetOwnerPinAsync(id, request.NewPin, ct);
        return Ok(ApiResponse<object>.Ok(null, "Owner PIN successfully reset"));
    }

    [HttpPost("businesses/{id:guid}/cancel-subscription")]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> CancelSubscription(
        Guid id,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminCancelPlanAsync(id, ct);
        return Ok(ApiResponse<SubscriptionDto>.Ok(result, "Subscription cancelled successfully"));
    }

    /// <summary>Get real-time pending approval notifications (businesses and dishes) for the admin.</summary>
    /// <summary>Get real-time pending approval notifications (businesses and dishes) for the admin.</summary>
    [HttpGet("notifications")]
    public async Task<ActionResult<ApiResponse<AdminNotificationsResponse>>> GetNotifications(CancellationToken ct)
    {
        var result = await _admin.GetNotificationsAsync(ct);
        return Ok(ApiResponse<AdminNotificationsResponse>.Ok(result));
    }

    // ── Dynamic Subscription Plan Management ──────────────────────────────────
    /// <summary>List all subscription plans with active subscriber counts for admin configuration.</summary>
    [HttpGet("plans")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SubscriptionPlanDto>>>> GetPlans(CancellationToken ct)
    {
        var result = await _subscriptions.AdminListAllPlansAsync(ct);
        return Ok(ApiResponse<IReadOnlyList<SubscriptionPlanDto>>.Ok(result));
    }

    /// <summary>Create a new subscription plan (e.g. Festival plan, custom duration, special discounts).</summary>
    [HttpPost("plans")]
    public async Task<ActionResult<ApiResponse<SubscriptionPlanDto>>> CreatePlan(
        [FromBody] CreateSubscriptionPlanRequest request,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminCreatePlanAsync(request, ct);
        return Ok(ApiResponse<SubscriptionPlanDto>.Ok(result, "Subscription plan created successfully"));
    }

    /// <summary>Update an existing plan's amount, discount, duration, features, or badge.</summary>
    [HttpPut("plans/{id:guid}")]
    public async Task<ActionResult<ApiResponse<SubscriptionPlanDto>>> UpdatePlan(
        Guid id,
        [FromBody] UpdateSubscriptionPlanRequest request,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminUpdatePlanAsync(id, request, ct);
        return Ok(ApiResponse<SubscriptionPlanDto>.Ok(result, "Subscription plan updated successfully"));
    }

    /// <summary>Safely remove/archive a plan without disrupting active business subscribers.</summary>
    [HttpDelete("plans/{id:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> DeletePlan(
        Guid id,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminDeletePlanAsync(id, ct);
        return Ok(ApiResponse<bool>.Ok(result, "Subscription plan removed/archived safely. Active business subscriptions will not be interrupted."));
    }

    /// <summary>Toggle active or disabled status for a subscription plan.</summary>
    [HttpPost("plans/{id:guid}/toggle-status")]
    public async Task<ActionResult<ApiResponse<SubscriptionPlanDto>>> TogglePlanStatus(
        Guid id,
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminTogglePlanStatusAsync(id, ct);
        return Ok(ApiResponse<SubscriptionPlanDto>.Ok(result, $"Plan status set to {(result.IsActive ? "Active" : "Inactive")}"));
    }

    /// <summary>Get current dynamic customer GST rate setting.</summary>
    [HttpGet("settings/gst-rate")]
    public async Task<ActionResult<ApiResponse<GstRateSettingDto>>> GetGstRateSetting(CancellationToken ct)
    {
        var result = await _subscriptions.GetGstRateSettingAsync(ct);
        return Ok(ApiResponse<GstRateSettingDto>.Ok(result));
    }

    /// <summary>Update customer GST rate % dynamically from admin panel.</summary>
    [HttpPut("settings/gst-rate")]
    public async Task<ActionResult<ApiResponse<GstRateSettingDto>>> UpdateGstRateSetting(
        [FromBody] UpdateGstRateRequest request,
        CancellationToken ct)
    {
        var result = await _subscriptions.UpdateGstRateSettingAsync(request.GstRatePercent, ct);
        return Ok(ApiResponse<GstRateSettingDto>.Ok(result, $"Customer GST rate successfully updated to {result.GstRatePercent:0.##}%"));
    }

    /// <summary>Get dynamic platform support & contact details (WhatsApp, Email, Phone, Help Message).</summary>
    [HttpGet("settings/support-contact")]
    public async Task<ActionResult<ApiResponse<SupportContactSettingDto>>> GetSupportContactSetting(CancellationToken ct)
    {
        var result = await _subscriptions.GetSupportContactSettingAsync(ct);
        return Ok(ApiResponse<SupportContactSettingDto>.Ok(result));
    }

    /// <summary>Update dynamic platform support & contact details from admin panel.</summary>
    [HttpPut("settings/support-contact")]
    public async Task<ActionResult<ApiResponse<SupportContactSettingDto>>> UpdateSupportContactSetting(
        [FromBody] UpdateSupportContactSettingRequest request,
        CancellationToken ct)
    {
        var result = await _subscriptions.UpdateSupportContactSettingAsync(request, ct);
        return Ok(ApiResponse<SupportContactSettingDto>.Ok(result, "Platform support contact details updated successfully"));
    }

    /// <summary>Get history of all past subscriptions and invoices for a specific business.</summary>
    [HttpGet("businesses/{id:guid}/subscriptions/history")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>>> GetBusinessSubscriptionHistory(
        Guid id,
        CancellationToken ct)
    {
        var result = await _subscriptions.GetSubscriptionHistoryAsync(id, ct);
        return Ok(ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>.Ok(result));
    }

    /// <summary>Get all past subscription transactions across the platform for admin audit & analytics.</summary>
    [HttpGet("subscriptions/all-history")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>>> GetAllSubscriptionHistory(
        CancellationToken ct)
    {
        var result = await _subscriptions.AdminGetAllSubscriptionHistoryAsync(ct);
        return Ok(ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>.Ok(result));
    }

    /// <summary>Get full GST Tax Invoice JSON for any past subscription transaction.</summary>
    [HttpGet("subscriptions/{id:guid}/invoice")]
    public async Task<ActionResult<ApiResponse<SubscriptionInvoiceDto>>> GetSubscriptionInvoice(
        Guid id,
        CancellationToken ct)
    {
        var result = await _subscriptions.GetInvoiceAsync(id, requestingBusinessId: null, isAdmin: true, ct);
        return Ok(ApiResponse<SubscriptionInvoiceDto>.Ok(result));
    }

    /// <summary>Download/View printable Government & Audit compliant A4 GST Tax Invoice HTML for any past subscription transaction.</summary>
    [HttpGet("subscriptions/{id:guid}/invoice/html")]
    public async Task<IActionResult> GetSubscriptionInvoiceHtml(
        Guid id,
        CancellationToken ct)
    {
        var html = await _subscriptions.GenerateInvoiceHtmlAsync(id, requestingBusinessId: null, isAdmin: true, ct);
        return Content(html, "text/html; charset=utf-8");
    }
}
