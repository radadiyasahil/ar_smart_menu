using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MediaUploadsController : ControllerBase
{
    private readonly IMediaUploadService _service;

    public MediaUploadsController(IMediaUploadService service) => _service = service;

    [HttpGet("booking/{bookingId:guid}")]
    public async Task<ActionResult<IReadOnlyList<MediaUploadDto>>> GetByBooking(
        Guid bookingId,
        CancellationToken ct) =>
        Ok(await _service.GetByBookingAsync(bookingId, ct));

    [HttpPost("initiate")]
    public async Task<ActionResult<MediaUploadDto>> Initiate(
        [FromBody] InitiateUploadRequest request,
        CancellationToken ct)
    {
        var result = await _service.InitiateUploadAsync(request, ct);
        return Ok(result);
    }

    [HttpPatch("{id:guid}/progress")]
    public async Task<ActionResult<MediaUploadDto>> UpdateProgress(
        Guid id,
        [FromBody] ProgressRequest request,
        CancellationToken ct)
    {
        var result = await _service.UpdateProgressAsync(id, request.ProgressPercent, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost("{id:guid}/complete")]
    public async Task<ActionResult<MediaUploadDto>> Complete(Guid id, CancellationToken ct)
    {
        var result = await _service.CompleteUploadAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost("{id:guid}/retry")]
    public async Task<ActionResult<MediaUploadDto>> Retry(Guid id, CancellationToken ct)
    {
        var result = await _service.RetryUploadAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }
}

public record ProgressRequest(int ProgressPercent);
