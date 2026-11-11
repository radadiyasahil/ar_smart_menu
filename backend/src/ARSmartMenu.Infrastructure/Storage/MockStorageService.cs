using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Constants;

namespace ARSmartMenu.Infrastructure.Storage;

/// <summary>
/// Mock storage service for MVP — simulates S3/Cloudinary signed URLs.
/// Replace with AwsS3StorageService or CloudinaryStorageService in production.
/// </summary>
public class MockStorageService : IStorageService
{
    private readonly string _baseUrl;

    public MockStorageService(Microsoft.Extensions.Configuration.IConfiguration configuration)
    {
        _baseUrl = configuration["Storage:MockBaseUrl"] ?? "https://cdn.ar-smartmenu.com";
    }

    public Task<SignedUploadResult> GetSignedUploadUrlAsync(
        string storageKey,
        string contentType,
        CancellationToken ct = default)
    {
        var expires = DateTime.UtcNow.AddHours(1);
        var uploadUrl = $"{_baseUrl}/upload?key={Uri.EscapeDataString(storageKey)}&expires={expires:O}";

        return Task.FromResult(new SignedUploadResult(uploadUrl, storageKey, expires));
    }

    public Task<string> GetTemporaryAccessUrlAsync(
        string storageKey,
        TimeSpan expiry,
        CancellationToken ct = default)
    {
        var url = $"{_baseUrl}/{storageKey}?token=mock-{Guid.NewGuid():N}&ttl={(int)expiry.TotalSeconds}";
        return Task.FromResult(url);
    }

    public Task<bool> DeleteAsync(string storageKey, CancellationToken ct = default) =>
        Task.FromResult(true);

    public Task<StorageObjectInfo?> GetObjectInfoAsync(string storageKey, CancellationToken ct = default) =>
        Task.FromResult<StorageObjectInfo?>(new StorageObjectInfo(
            storageKey, 1024 * 1024, "application/octet-stream", DateTime.UtcNow));
}

/// <summary>Helper to build consistent storage keys per cloud folder structure.</summary>
public static class StorageKeyBuilder
{
    public static string RawMedia(Guid businessId, string fileName) =>
        StoragePaths.BuildPath(StoragePaths.RawMedia, businessId.ToString(), fileName);

    public static string Glb(Guid businessId, string slug) =>
        StoragePaths.BuildPath(StoragePaths.Glb, businessId.ToString(), $"{slug}.glb");

    public static string Usdz(Guid businessId, string slug) =>
        StoragePaths.BuildPath(StoragePaths.Usdz, businessId.ToString(), $"{slug}.usdz");

    public static string Thumbnail(Guid businessId, string slug) =>
        StoragePaths.BuildPath(StoragePaths.Thumbnails, businessId.ToString(), $"{slug}.jpg");
}
