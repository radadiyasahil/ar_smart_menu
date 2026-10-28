using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/businesses")]
[Authorize]
public class BusinessesController : ControllerBase
{
    private readonly IBusinessService _business;
    private readonly ICurrentUserService _currentUser;

    public BusinessesController(IBusinessService business, ICurrentUserService currentUser)
    {
        _business = business;
        _currentUser = currentUser;
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> Create(
        [FromBody] CreateBusinessRequest request,
        CancellationToken ct)
    {
        var result = await _business.CreateAsync(_currentUser.GetUserId(), request, ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, "Business created"));
    }

    [HttpGet("me")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> GetMe(CancellationToken ct)
    {
        var result = await _business.GetMeAsync(_currentUser.GetUserId(), ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result));
    }

    [HttpPut("me")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> UpdateMe(
        [FromBody] UpdateBusinessRequest request,
        CancellationToken ct)
    {
        var result = await _business.UpdateMeAsync(_currentUser.GetUserId(), request, ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, "Business updated"));
    }

    [HttpPost("me/verify-bank")]
    public async Task<ActionResult<ApiResponse<VerifyBankResponse>>> VerifyBank(
        [FromBody] VerifyBankRequest request,
        CancellationToken ct)
    {
        var result = await _business.VerifyBankAsync(_currentUser.GetUserId(), request, ct);
        return Ok(ApiResponse<VerifyBankResponse>.Ok(result, result.Message));
    }

    [HttpPost("me/kyc")]
    public async Task<ActionResult<ApiResponse<UserDto>>> SubmitKyc(
        [FromBody] SubmitKycRequest request,
        CancellationToken ct)
    {
        var result = await _business.SubmitKycAsync(_currentUser.GetUserId(), request, ct);
        return Ok(ApiResponse<UserDto>.Ok(result, "KYC submitted"));
    }

    [HttpPatch("me/status")]
    public async Task<ActionResult<ApiResponse<BusinessDto>>> UpdateStatus(
        [FromBody] UpdateBusinessStatusRequest request,
        CancellationToken ct)
    {
        var result = await _business.UpdateStatusAsync(_currentUser.GetUserId(), request, ct);
        return Ok(ApiResponse<BusinessDto>.Ok(result, $"Business status updated to {request.Status}"));
    }
}
