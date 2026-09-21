using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PhotographersController : ControllerBase
{
    private readonly IPhotographerService _service;

    public PhotographersController(IPhotographerService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<PhotographerDto>>> GetAll(CancellationToken ct) =>
        Ok(await _service.GetAllAsync(ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<PhotographerDto>> GetById(Guid id, CancellationToken ct)
    {
        var result = await _service.GetByIdAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("available")]
    public async Task<ActionResult<IReadOnlyList<PhotographerDto>>> GetAvailable(
        [FromQuery] string city,
        CancellationToken ct) =>
        Ok(await _service.GetAvailableInCityAsync(city, ct));

    [HttpPost]
    public async Task<ActionResult<PhotographerDto>> Create(
        [FromBody] CreatePhotographerRequest request,
        CancellationToken ct)
    {
        var result = await _service.CreateAsync(request, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<PhotographerDto>> Update(
        Guid id,
        [FromBody] UpdatePhotographerRequest request,
        CancellationToken ct)
    {
        var result = await _service.UpdateAsync(id, request, ct);
        return result is null ? NotFound() : Ok(result);
    }
}
