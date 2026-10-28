using System.Security.Claims;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly IJwtTokenService _jwt;

    public AuthController(IAuthService auth, IJwtTokenService jwt)
    {
        _auth = auth;
        _jwt = jwt;
    }

    /// <summary>Send a 6-digit OTP to the given mobile number.</summary>
    [HttpPost("send-otp")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<SendOtpResponse>>> SendOtp(
        [FromBody] SendOtpRequest request,
        CancellationToken ct)
    {
        var result = await _auth.SendOtpAsync(request, ct);
        return Ok(ApiResponse<SendOtpResponse>.Ok(result, result.Message));
    }

    /// <summary>Verify OTP and receive a JWT access token.</summary>
    [HttpPost("verify-otp")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<VerifyOtpResponse>>> VerifyOtp(
        [FromBody] VerifyOtpRequest request,
        CancellationToken ct)
    {
        var result = await _auth.VerifyOtpAsync(request, ct);
        return Ok(ApiResponse<VerifyOtpResponse>.Ok(result, "Login successful"));
    }

    /// <summary>Development-only: login with mobile only (no OTP). Disabled in production.</summary>
    [HttpPost("dev-login")]
    [AllowAnonymous]
    public async Task<ActionResult<ApiResponse<VerifyOtpResponse>>> DevLogin(
        [FromBody] SendOtpRequest request,
        CancellationToken ct)
    {
        if (!HttpContext.RequestServices.GetRequiredService<IHostEnvironment>().IsDevelopment())
            return NotFound(ApiResponse<VerifyOtpResponse>.Fail("Not available", "NOT_FOUND"));

        var result = await _auth.DevLoginAsync(request, ct);
        return Ok(ApiResponse<VerifyOtpResponse>.Ok(result, "Dev login successful"));
    }

    /// <summary>Issue a new JWT for the authenticated user.</summary>
    [HttpPost("refresh-token")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<RefreshTokenResponse>>> RefreshToken(CancellationToken ct)
    {
        var userId = GetUserId();
        var result = await _auth.RefreshTokenAsync(userId, ct);
        return Ok(ApiResponse<RefreshTokenResponse>.Ok(result));
    }

    /// <summary>Revoke the current JWT.</summary>
    [HttpPost("logout")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<object>>> Logout(CancellationToken ct)
    {
        var jti = User.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Jti);
        var expClaim = User.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Exp);

        if (string.IsNullOrEmpty(jti))
            throw new UnauthorizedException("Invalid token.");

        var expiresAt = DateTime.UtcNow.AddDays(7);
        if (long.TryParse(expClaim, out var expUnix))
            expiresAt = DateTimeOffset.FromUnixTimeSeconds(expUnix).UtcDateTime;

        await _auth.LogoutAsync(jti, expiresAt, ct);
        return Ok(ApiResponse<object>.Ok(new { message = "Logged out" }));
    }

    /// <summary>Return the authenticated user and their business (if any).</summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<AuthMeResponse>>> Me(CancellationToken ct)
    {
        var result = await _auth.GetMeAsync(GetUserId(), ct);
        return Ok(ApiResponse<AuthMeResponse>.Ok(result));
    }

    /// <summary>Update current authenticated user's profile.</summary>
    [HttpPut("me")]
    [Authorize]
    public async Task<ActionResult<ApiResponse<UserDto>>> UpdateMe(
        [FromBody] UpdateUserRequest request,
        CancellationToken ct)
    {
        var result = await _auth.UpdateMeAsync(GetUserId(), request, ct);
        return Ok(ApiResponse<UserDto>.Ok(result, "Profile updated successfully"));
    }

    private Guid GetUserId()
    {
        var sub = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

        if (!Guid.TryParse(sub, out var userId))
            throw new UnauthorizedException("Invalid token.");

        return userId;
    }
}
