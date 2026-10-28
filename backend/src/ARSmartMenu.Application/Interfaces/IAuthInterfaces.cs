using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Domain.Entities;

namespace ARSmartMenu.Application.Interfaces;

public interface IAuthService
{
    Task<SendOtpResponse> SendOtpAsync(SendOtpRequest request, CancellationToken ct = default);
    Task<VerifyOtpResponse> VerifyOtpAsync(VerifyOtpRequest request, CancellationToken ct = default);
    Task<VerifyOtpResponse> DevLoginAsync(SendOtpRequest request, CancellationToken ct = default);
    Task<RefreshTokenResponse> RefreshTokenAsync(Guid userId, CancellationToken ct = default);
    Task LogoutAsync(string tokenId, DateTime tokenExpiresAt, CancellationToken ct = default);
    Task<AuthMeResponse> GetMeAsync(Guid userId, CancellationToken ct = default);
    Task<UserDto> UpdateMeAsync(Guid userId, UpdateUserRequest request, CancellationToken ct = default);
    Task<bool> IsTokenRevokedAsync(string tokenId, CancellationToken ct = default);
}

public interface IJwtTokenService
{
    string GenerateToken(User user, Guid? businessId = null);
    (Guid UserId, string TokenId, DateTime ExpiresAt)? ValidateToken(string token, bool validateLifetime = true);
}

public interface IOtpSender
{
    Task SendAsync(string mobileNumber, string otp, CancellationToken ct = default);
}
