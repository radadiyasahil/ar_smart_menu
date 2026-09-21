using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BookingsController : ControllerBase
{
    private readonly IBookingService _service;

    public BookingsController(IBookingService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<BookingDto>>> GetAll(
        [FromQuery] BookingStatus? status,
        [FromQuery] string? city,
        CancellationToken ct) =>
        Ok(await _service.GetAllAsync(new BookingFilter(status, city), ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<BookingDto>> GetById(Guid id, CancellationToken ct)
    {
        var result = await _service.GetByIdAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost]
    public async Task<ActionResult<BookingDto>> Create(
        [FromBody] CreateBookingRequest request,
        CancellationToken ct)
    {
        var result = await _service.CreateAsync(request, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPost("{id:guid}/assign/{photographerId:guid}")]
    public async Task<ActionResult<BookingDto>> Assign(
        Guid id,
        Guid photographerId,
        CancellationToken ct)
    {
        var result = await _service.AssignPhotographerAsync(id, photographerId, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<ActionResult<BookingDto>> UpdateStatus(
        Guid id,
        [FromBody] UpdateStatusRequest request,
        CancellationToken ct)
    {
        var result = await _service.UpdateStatusAsync(id, request.Status, ct);
        return result is null ? NotFound() : Ok(result);
    }
}

public record UpdateStatusRequest(BookingStatus Status);
