using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace ARSmartMenu.Infrastructure.Services;

public class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _config;

    public JwtTokenService(IConfiguration config) => _config = config;

    public string GenerateToken(User user, Guid? businessId = null)
    {
        var secret = _config["Jwt:Secret"]
            ?? throw new InvalidOperationException("Jwt:Secret is not configured.");
        var issuer = _config["Jwt:Issuer"] ?? "ARSmartMenu";
        var audience = _config["Jwt:Audience"] ?? "ARSmartMenuClients";
        var expiresDays = int.TryParse(_config["Jwt:ExpiresInDays"], out var days) ? days : 7;

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var tokenId = Guid.NewGuid().ToString();

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, tokenId),
            new("mobile", user.MobileNumber),
        };

        if (user.IsAdmin)
            claims.Add(new Claim("is_admin", "true"));

        if (businessId.HasValue)
            claims.Add(new Claim("business_id", businessId.Value.ToString()));

        var token = new JwtSecurityToken(
            issuer,
            audience,
            claims,
            expires: DateTime.UtcNow.AddDays(expiresDays),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public (Guid UserId, string TokenId, DateTime ExpiresAt)? ValidateToken(
        string token,
        bool validateLifetime = true)
    {
        var secret = _config["Jwt:Secret"]
            ?? throw new InvalidOperationException("Jwt:Secret is not configured.");
        var issuer = _config["Jwt:Issuer"] ?? "ARSmartMenu";
        var audience = _config["Jwt:Audience"] ?? "ARSmartMenuClients";

        var handler = new JwtSecurityTokenHandler();
        var parameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = issuer,
            ValidateAudience = true,
            ValidAudience = audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
            ValidateLifetime = validateLifetime,
            ClockSkew = TimeSpan.FromMinutes(1),
        };

        try
        {
            var principal = handler.ValidateToken(token, parameters, out var validated);
            if (validated is not JwtSecurityToken jwt)
                return null;

            var sub = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
                ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
            var jti = principal.FindFirstValue(JwtRegisteredClaimNames.Jti);

            if (!Guid.TryParse(sub, out var userId) || string.IsNullOrEmpty(jti))
                return null;

            return (userId, jti, jwt.ValidTo);
        }
        catch
        {
            return null;
        }
    }
}
