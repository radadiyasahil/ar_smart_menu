using ARSmartMenu.API.Authorization;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[AdminAuthorize]
public class ProcessingQueueController : ControllerBase
{
    private readonly IProcessingQueueService _service;

    public ProcessingQueueController(IProcessingQueueService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ProcessingJobDto>>> GetQueue(
        [FromQuery] ProcessingJobStatus? status,
        CancellationToken ct) =>
        Ok(await _service.GetQueueAsync(status, ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ProcessingJobDto>> GetById(Guid id, CancellationToken ct)
    {
        var result = await _service.GetByIdAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("{id:guid}/logs")]
    public async Task<ActionResult<IReadOnlyList<ProcessingLogDto>>> GetLogs(
        Guid id,
        CancellationToken ct) =>
        Ok(await _service.GetLogsAsync(id, ct));

    [HttpPost("{id:guid}/retry")]
    public async Task<ActionResult<ProcessingJobDto>> Retry(Guid id, CancellationToken ct)
    {
        var result = await _service.RetryAsync(id, ct);
        return result is null ? NotFound() : Ok(result);
    }
}
