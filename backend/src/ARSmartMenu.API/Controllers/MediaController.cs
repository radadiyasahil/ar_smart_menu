using ARSmartMenu.Infrastructure.Storage;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.StaticFiles;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/media")]
public class MediaController : ControllerBase
{
    private readonly IWebHostEnvironment _env;
    private readonly IConfiguration _config;
    private readonly FileExtensionContentTypeProvider _contentTypes = new();

    public MediaController(IWebHostEnvironment env, IConfiguration config)
    {
        _env = env;
        _config = config;
        // Required for Android Scene Viewer + iOS Quick Look AR
        _contentTypes.Mappings[".glb"] = "model/gltf-binary";
        _contentTypes.Mappings[".gltf"] = "model/gltf+json";
        _contentTypes.Mappings[".usdz"] = "model/vnd.usdz+zip";
    }

    [HttpGet("{**storageKey}")]
    [AllowAnonymous]
    public IActionResult GetFile(string storageKey)
    {
        if (string.IsNullOrWhiteSpace(storageKey))
            return NotFound();

        var localRoot = _config["Storage:LocalRoot"];
        var filePath = LocalMediaStorage.TryResolveFilePath(_env, storageKey, localRoot);
        if (filePath is null)
            return NotFound();

        if (!_contentTypes.TryGetContentType(filePath, out var contentType))
            contentType = "application/octet-stream";

        Response.Headers.Append("Access-Control-Allow-Origin", "*");
        Response.Headers.Append("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges");
        return PhysicalFile(filePath, contentType, enableRangeProcessing: true);
    }
}
