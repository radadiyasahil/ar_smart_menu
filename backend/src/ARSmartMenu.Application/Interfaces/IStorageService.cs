namespace ARSmartMenu.Application.Interfaces;

/// <summary>
/// Cloud storage abstraction — swap Local/Mock for AWS S3 or Cloudinary in production.
/// Supports signed upload URLs and temporary access URLs.
/// </summary>
public interface IStorageService
{
    Task<SignedUploadResult> GetSignedUploadUrlAsync(
        string storageKey,
        string contentType,
        CancellationToken ct = default);

    Task<string> GetTemporaryAccessUrlAsync(
        string storageKey,
        TimeSpan expiry,
        CancellationToken ct = default);

    Task<bool> DeleteAsync(string storageKey, CancellationToken ct = default);

    Task<StorageObjectInfo?> GetObjectInfoAsync(string storageKey, CancellationToken ct = default);
}

public record SignedUploadResult(
    string UploadUrl,
    string StorageKey,
    DateTime ExpiresAt);

public record StorageObjectInfo(
    string StorageKey,
    long SizeBytes,
    string ContentType,
    DateTime LastModified);
