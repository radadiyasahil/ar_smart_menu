using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/subscriptions")]
public class SubscriptionsController : ControllerBase
{
    private readonly ISubscriptionService _subscriptions;
    private readonly ICurrentUserService _currentUser;

    public SubscriptionsController(ISubscriptionService subscriptions, ICurrentUserService currentUser)
    {
        _subscriptions = subscriptions;
        _currentUser = currentUser;
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
        var businessId = RequireBusinessId();
        var result = await _subscriptions.GetMeAsync(businessId, ct);
        if (result is null)
            return Ok(ApiResponse<SubscriptionDto>.Ok(null!, "No active subscription"));

        return Ok(ApiResponse<SubscriptionDto>.Ok(result));
    }

    [HttpPost("create-order")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<CreateOrderResponse>>> CreateOrder(
        [FromBody] CreateOrderRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _subscriptions.CreateOrderAsync(businessId, request, ct);
        return Ok(ApiResponse<CreateOrderResponse>.Ok(result));
    }

    [HttpPost("verify-payment")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<VerifyPaymentResponse>>> VerifyPayment(
        [FromBody] VerifyPaymentRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _subscriptions.VerifyPaymentAsync(businessId, request, ct);
        return Ok(ApiResponse<VerifyPaymentResponse>.Ok(result, result.Message));
    }

    private Guid RequireBusinessId()
    {
        return _currentUser.GetBusinessId()
            ?? throw new ValidationException("No business linked to this account.");
    }
}
