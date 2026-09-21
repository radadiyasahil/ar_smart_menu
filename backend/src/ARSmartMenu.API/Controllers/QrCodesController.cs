using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/qrcodes")]
[Authorize]
public class QrCodesController : ControllerBase
{
    private readonly IQrCodeService _qrCodes;
    private readonly ICurrentUserService _currentUser;

    public QrCodesController(IQrCodeService qrCodes, ICurrentUserService currentUser)
    {
        _qrCodes = qrCodes;
        _currentUser = currentUser;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<QrCodeDto>>>> List(CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _qrCodes.ListAsync(businessId, ct);
        return Ok(ApiResponse<IReadOnlyList<QrCodeDto>>.Ok(result));
    }

    [HttpPost("generate")]
    public async Task<ActionResult<ApiResponse<QrCodeDto>>> Generate(
        [FromBody] GenerateQrRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _qrCodes.GenerateForProductAsync(businessId, request.ProductId, ct);
        return Ok(ApiResponse<QrCodeDto>.Ok(result, "QR code generated"));
    }

    [HttpPost("{id:guid}/deactivate")]
    public async Task<ActionResult<ApiResponse<QrCodeDto>>> Deactivate(Guid id, CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _qrCodes.DeactivateAsync(businessId, id, ct);
        return Ok(ApiResponse<QrCodeDto>.Ok(result, "QR code deactivated"));
    }

    private Guid RequireBusinessId()
    {
        return _currentUser.GetBusinessId()
            ?? throw new ValidationException("No business linked to this account.");
    }
}
