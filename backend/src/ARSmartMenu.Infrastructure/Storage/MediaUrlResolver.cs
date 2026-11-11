using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace ARSmartMenu.Infrastructure.Storage;

public class MediaUrlResolver
{
    private readonly string _configuredBaseUrl;
    private readonly IHttpContextAccessor? _httpContextAccessor;

    public MediaUrlResolver(IConfiguration configuration, IHttpContextAccessor? httpContextAccessor = null)
    {
        _configuredBaseUrl = configuration["Storage:PublicBaseUrl"]
            ?? configuration["Storage:MockBaseUrl"]
            ?? "http://localhost:5232/api/media";
        _httpContextAccessor = httpContextAccessor;
    }

    public string Resolve(string? storageKey, string? fallbackUrl = null)
    {
        if (string.IsNullOrWhiteSpace(storageKey))
            return fallbackUrl ?? string.Empty;

        var baseUrl = _configuredBaseUrl;
        var httpContext = _httpContextAccessor?.HttpContext;
        if (httpContext != null && httpContext.Request.Host.HasValue)
        {
            baseUrl = $"{httpContext.Request.Scheme}://{httpContext.Request.Host}/api/media";
        }

        return LocalMediaStorage.BuildPublicUrl(baseUrl, storageKey);
    }
}
