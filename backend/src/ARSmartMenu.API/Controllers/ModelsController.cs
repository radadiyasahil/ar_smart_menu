using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/models")]
[Authorize]
public class ModelsController : ControllerBase
{
    private readonly IModel3dService _models;
    private readonly ICurrentUserService _currentUser;

    public ModelsController(IModel3dService models, ICurrentUserService currentUser)
    {
        _models = models;
        _currentUser = currentUser;
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Model3dSummaryDto>>>> List(CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _models.ListForBusinessAsync(businessId, ct);
        return Ok(ApiResponse<IReadOnlyList<Model3dSummaryDto>>.Ok(result));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<Model3dSummaryDto>>> GetById(Guid id, CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _models.GetByIdAsync(businessId, id, ct);
        return Ok(ApiResponse<Model3dSummaryDto>.Ok(result));
    }

    private Guid RequireBusinessId()
    {
        return _currentUser.GetBusinessId()
            ?? throw new ValidationException("No business linked to this account.");
    }
}
