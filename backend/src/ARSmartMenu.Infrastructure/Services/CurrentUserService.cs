using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Http;

namespace ARSmartMenu.Infrastructure.Services;

public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _http;

    public CurrentUserService(IHttpContextAccessor http) => _http = http;

    public Guid GetUserId()
    {
        var user = _http.HttpContext?.User
            ?? throw new UnauthorizedException("Not authenticated.");

        var sub = user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue(JwtRegisteredClaimNames.Sub);

        if (!Guid.TryParse(sub, out var userId))
            throw new UnauthorizedException("Invalid token.");

        return userId;
    }

    public Guid? GetBusinessId()
    {
        var claim = _http.HttpContext?.User?.FindFirstValue("business_id");
        return Guid.TryParse(claim, out var businessId) ? businessId : null;
    }

    public bool IsAdmin()
    {
        var claim = _http.HttpContext?.User?.FindFirstValue("is_admin");
        return string.Equals(claim, "true", StringComparison.OrdinalIgnoreCase);
    }
}
