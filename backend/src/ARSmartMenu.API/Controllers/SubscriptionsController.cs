using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/subscriptions")]
public class SubscriptionsController : ControllerBase
{
    private readonly ISubscriptionService _subscriptions;
    private readonly ICurrentUserService _currentUser;
    private readonly AppDbContext _db;

    public SubscriptionsController(
        ISubscriptionService subscriptions,
        ICurrentUserService currentUser,
        AppDbContext db)
    {
        _subscriptions = subscriptions;
        _currentUser = currentUser;
        _db = db;
    }

    [HttpGet("plans")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SubscriptionPlanDto>>>> ListPlans(CancellationToken ct)
    {
        var result = await _subscriptions.ListPlansAsync(ct);
        return Ok(ApiResponse<IReadOnlyList<SubscriptionPlanDto>>.Ok(result));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> GetMe(CancellationToken ct)
    {
        var userId = _currentUser.GetUserId();
        var businessId = _currentUser.GetBusinessId();

        if (!businessId.HasValue)
        {
            var b = await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(x => x.OwnerId == userId, ct);
            businessId = b?.Id;
        }

        if (!businessId.HasValue)
        {
            var ownerSub = await _subscriptions.GetMeByOwnerAsync(userId, ct);
            if (ownerSub != null) return Ok(ApiResponse<SubscriptionDto>.Ok(ownerSub));

            return Ok(ApiResponse<SubscriptionDto>.Ok(new SubscriptionDto(
                Id: Guid.Empty,
                BusinessId: Guid.Empty,
                Plan: null,
                BillingCycle: ARSmartMenu.Domain.Enums.BillingCycle.Monthly,
                Status: ARSmartMenu.Domain.Enums.SubscriptionStatus.Expired,
                StartsAt: DateTime.MinValue,
                EndsAt: DateTime.MinValue,
                ShootsUsed: 0,
                CancelledAt: null,
                DaysRemaining: 0,
                IsActive: false,
                IsTrial: false,
                HasUsedTrial: false
            ), "No business linked to this account yet"));
        }

        var result = await _subscriptions.GetMeAsync(businessId.Value, userId, ct);
        if (result is null)
            return Ok(ApiResponse<SubscriptionDto>.Ok(null!, "No active subscription"));

        return Ok(ApiResponse<SubscriptionDto>.Ok(result));
    }

    [HttpPost("activate-trial")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> ActivateTrial(CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.ActivateTrialAsync(businessId, ct);
        return Ok(ApiResponse<SubscriptionDto>.Ok(result, "7-Day Free Trial activated successfully!"));
    }

    [HttpPost("activate-plan")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<SubscriptionDto>>> ActivatePlan(
        [FromBody] ActivatePlanRequest request,
        CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.ActivatePlanAsync(businessId, request, ct);
        return Ok(ApiResponse<SubscriptionDto>.Ok(result, "Plan activated successfully!"));
    }

    [HttpPost("create-order")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<CreateOrderResponse>>> CreateOrder(
        [FromBody] CreateOrderRequest request,
        CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.CreateOrderAsync(businessId, request, ct);
        return Ok(ApiResponse<CreateOrderResponse>.Ok(result));
    }

    [HttpPost("verify-payment")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<VerifyPaymentResponse>>> VerifyPayment(
        [FromBody] VerifyPaymentRequest request,
        CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.VerifyPaymentAsync(businessId, request, ct);
        return Ok(ApiResponse<VerifyPaymentResponse>.Ok(result, result.Message));
    }

    /// <summary>
    /// Get history of all past and active subscriptions with invoice numbers for this owner/business.
    /// </summary>
    [HttpGet("history")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>>> GetHistory(CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.GetSubscriptionHistoryAsync(businessId, ct);
        return Ok(ApiResponse<IReadOnlyList<SubscriptionHistoryItemDto>>.Ok(result));
    }

    /// <summary>
    /// Get full GST Tax Invoice JSON for any past subscription transaction.
    /// </summary>
    [HttpGet("{id:guid}/invoice")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<SubscriptionInvoiceDto>>> GetInvoice(Guid id, CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var result = await _subscriptions.GetInvoiceAsync(id, requestingBusinessId: businessId, isAdmin: false, ct);
        return Ok(ApiResponse<SubscriptionInvoiceDto>.Ok(result));
    }

    /// <summary>
    /// Get current dynamic customer GST rate for subscriptions.
    /// </summary>
    [HttpGet("gst-rate")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<GstRateSettingDto>>> GetGstRate(CancellationToken ct)
    {
        var result = await _subscriptions.GetGstRateSettingAsync(ct);
        return Ok(ApiResponse<GstRateSettingDto>.Ok(result));
    }

    /// <summary>
    /// Get dynamic platform support contact details (WhatsApp, Email, Phone, Help Message) for app settings.
    /// </summary>
    [HttpGet("support-contact")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<SupportContactSettingDto>>> GetSupportContact(CancellationToken ct)
    {
        var result = await _subscriptions.GetSupportContactSettingAsync(ct);
        return Ok(ApiResponse<SupportContactSettingDto>.Ok(result));
    }

    /// <summary>
    /// Download/View printable Government & Audit compliant A4 GST Tax Invoice HTML for any past subscription transaction.
    /// </summary>
    [HttpGet("{id:guid}/invoice/html")]
    [Authorize]
    public async Task<IActionResult> GetInvoiceHtml(Guid id, CancellationToken ct)
    {
        var businessId = await ResolveBusinessIdAsync();
        var html = await _subscriptions.GenerateInvoiceHtmlAsync(id, requestingBusinessId: businessId, isAdmin: false, ct);
        return Content(html, "text/html; charset=utf-8");
    }

    private async Task<Guid> ResolveBusinessIdAsync()
    {
        var businessId = _currentUser.GetBusinessId();
        if (businessId.HasValue) return businessId.Value;

        var userId = _currentUser.GetUserId();
        var b = await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(x => x.OwnerId == userId);
        if (b != null) return b.Id;

        throw new ValidationException("No business linked to this account.");
    }
}
