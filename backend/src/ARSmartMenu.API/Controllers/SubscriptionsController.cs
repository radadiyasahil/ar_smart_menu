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
