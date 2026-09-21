using ARSmartMenu.Application.CaptureGuides;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CaptureGuidesController : ControllerBase
{
    [HttpGet("{category}")]
    public IActionResult GetGuides(BusinessCategory category) =>
        Ok(CaptureGuideCatalog.GetGuidesForCategory(category));
}
