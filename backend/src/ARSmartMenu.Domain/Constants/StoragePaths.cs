namespace ARSmartMenu.Domain.Constants;

/// <summary>
/// Cloud storage folder structure — maps to S3/Cloudinary paths.
/// CDN (Cloudflare) serves from /glb, /usdz, /thumbnails after publish.
/// </summary>
public static class StoragePaths
{
    public const string RawMedia = "raw-media";
    public const string ProcessedModels = "processed-models";
    public const string Thumbnails = "thumbnails";
    public const string Usdz = "usdz";
    public const string Glb = "glb";
    public const string Temporary = "temporary";
    public const string Exports = "exports";

    public static string BuildPath(string folder, string businessId, string fileName) =>
        $"{folder}/{businessId}/{fileName}";
}
