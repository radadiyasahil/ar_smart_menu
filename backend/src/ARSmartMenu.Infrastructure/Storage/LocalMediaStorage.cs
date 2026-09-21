using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;

namespace ARSmartMenu.Infrastructure.Storage;

/// <summary>Dev/local disk storage for owner product photos.</summary>
public static class LocalMediaStorage
{
    public static string GetUploadRoot(IWebHostEnvironment env, string? configuredRoot = null)
    {
        if (!string.IsNullOrWhiteSpace(configuredRoot) && Path.IsPathRooted(configuredRoot))
            return configuredRoot;

        var relative = string.IsNullOrWhiteSpace(configuredRoot) ? "uploads" : configuredRoot;
        return Path.Combine(env.ContentRootPath, relative);
    }

    public static async Task SaveUploadAsync(
        IWebHostEnvironment env,
        string storageKey,
        IFormFile file,
        string? configuredRoot = null,
        CancellationToken ct = default)
    {
        var fullPath = GetFilePath(env, storageKey, configuredRoot);
        var directory = Path.GetDirectoryName(fullPath)
            ?? throw new InvalidOperationException("Invalid storage path.");

        Directory.CreateDirectory(directory);

        await using var stream = File.Create(fullPath);
        await file.CopyToAsync(stream, ct);
    }

    public static string? TryResolveFilePath(
        IWebHostEnvironment env,
        string storageKey,
        string? configuredRoot = null)
    {
        var fullPath = GetFilePath(env, storageKey, configuredRoot);
        return File.Exists(fullPath) ? fullPath : null;
    }

    public static string BuildPublicUrl(string publicBaseUrl, string storageKey) =>
        $"{publicBaseUrl.TrimEnd('/')}/{storageKey.Replace('\\', '/')}";

    private static string GetFilePath(
        IWebHostEnvironment env,
        string storageKey,
        string? configuredRoot)
    {
        var normalizedKey = storageKey.Replace('\\', '/').TrimStart('/');
        var root = GetUploadRoot(env, configuredRoot);
        var fullPath = Path.GetFullPath(Path.Combine(root, normalizedKey.Replace('/', Path.DirectorySeparatorChar)));
        var rootFull = Path.GetFullPath(root);

        if (!fullPath.StartsWith(rootFull, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid media path.");

        return fullPath;
    }
}
