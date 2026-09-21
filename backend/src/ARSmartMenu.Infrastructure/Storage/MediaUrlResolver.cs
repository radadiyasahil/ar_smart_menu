using Microsoft.Extensions.Configuration;

namespace ARSmartMenu.Infrastructure.Storage;

public class MediaUrlResolver
{
    private readonly string _publicBaseUrl;

    public MediaUrlResolver(IConfiguration configuration)
    {
        _publicBaseUrl = configuration["Storage:PublicBaseUrl"]
            ?? configuration["Storage:MockBaseUrl"]
            ?? "http://localhost:5232/api/media";
    }

    public string Resolve(string? storageKey, string? fallbackUrl = null)
    {
        if (!string.IsNullOrWhiteSpace(storageKey))
            return LocalMediaStorage.BuildPublicUrl(_publicBaseUrl, storageKey);

        return fallbackUrl ?? string.Empty;
    }
}
