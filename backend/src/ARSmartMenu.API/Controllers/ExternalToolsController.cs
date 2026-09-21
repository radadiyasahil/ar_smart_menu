using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ExternalToolsController : ControllerBase
{
    private readonly IExternalToolIngestionService _service;

    public ExternalToolsController(IExternalToolIngestionService service) => _service = service;

    /// <summary>Ingest Polycam GLB export into processing pipeline.</summary>
    [HttpPost("polycam")]
    public async Task<IActionResult> IngestPolycam(
        [FromBody] PolycamIngestRequest request,
        CancellationToken ct)
    {
        var job = await _service.IngestPolycamExportAsync(request, ct);
        return Ok(job);
    }

    /// <summary>Ingest Luma AI export into processing pipeline.</summary>
    [HttpPost("luma")]
    public async Task<IActionResult> IngestLuma(
        [FromBody] LumaAiIngestRequest request,
        CancellationToken ct)
    {
        var job = await _service.IngestLumaAiExportAsync(request, ct);
        return Ok(job);
    }
}
