using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/shoots")]
[Authorize]
public class ShootsController : ControllerBase
{
    private readonly IBookingService _bookings;

    public ShootsController(IBookingService bookings) => _bookings = bookings;

    [HttpGet]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<BookingDto>>>> GetAll(
        [FromQuery] BookingStatus? status,
        [FromQuery] string? city,
        CancellationToken ct)
    {
        var result = await _bookings.GetAllAsync(new BookingFilter(status, city), ct);
        return Ok(ApiResponse<IReadOnlyList<BookingDto>>.Ok(result));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<BookingDto>>> GetById(Guid id, CancellationToken ct)
    {
        var result = await _bookings.GetByIdAsync(id, ct);
        if (result is null)
            throw new NotFoundException("Shoot booking not found.");

        return Ok(ApiResponse<BookingDto>.Ok(result));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<BookingDto>>> Create(
        [FromBody] CreateBookingRequest request,
        CancellationToken ct)
    {
        var result = await _bookings.CreateAsync(request, ct);
        return Ok(ApiResponse<BookingDto>.Ok(result, "Shoot booked"));
    }

    [HttpPost("{id:guid}/assign/{photographerId:guid}")]
    public async Task<ActionResult<ApiResponse<BookingDto>>> Assign(
        Guid id,
        Guid photographerId,
        CancellationToken ct)
    {
        var result = await _bookings.AssignPhotographerAsync(id, photographerId, ct);
        if (result is null)
            throw new NotFoundException("Shoot booking not found.");

        return Ok(ApiResponse<BookingDto>.Ok(result, "Photographer assigned"));
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<ActionResult<ApiResponse<BookingDto>>> UpdateStatus(
        Guid id,
        [FromBody] UpdateShootStatusRequest request,
        CancellationToken ct)
    {
        var result = await _bookings.UpdateStatusAsync(id, request.Status, ct);
        if (result is null)
            throw new NotFoundException("Shoot booking not found.");

        return Ok(ApiResponse<BookingDto>.Ok(result, "Status updated"));
    }
}

public record UpdateShootStatusRequest(BookingStatus Status);
