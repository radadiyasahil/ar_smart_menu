using System.Security.Cryptography;
using System.Text;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Services;

public class AuthService : IAuthService
{
    private const int OtpLength = 6;
    private const int OtpTtlMinutes = 5;
    private const int MaxOtpSendsPerWindow = 3;
    private const int OtpRateLimitWindowMinutes = 10;
    private const int MaxVerifyAttempts = 5;

    private readonly AppDbContext _db;
    private readonly IJwtTokenService _jwt;
    private readonly IOtpSender _otpSender;
    private readonly IConfiguration _config;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        AppDbContext db,
        IJwtTokenService jwt,
        IOtpSender otpSender,
        IConfiguration config,
        ILogger<AuthService> logger)
    {
        _db = db;
        _jwt = jwt;
        _otpSender = otpSender;
        _config = config;
        _logger = logger;
    }

    public async Task<SendOtpResponse> SendOtpAsync(SendOtpRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        var windowStart = DateTime.UtcNow.AddMinutes(-OtpRateLimitWindowMinutes);
        var recentCount = await _db.OtpRecords
            .CountAsync(o => o.MobileNumber == mobile && o.CreatedAt >= windowStart, ct);

        if (recentCount >= MaxOtpSendsPerWindow)
        {
            throw new ValidationException("Too many OTP requests. Please try again in a few minutes.");
        }

        var otp = GenerateOtp();
        var record = new OtpRecord
        {
            MobileNumber = mobile,
            OtpHash = HashOtp(mobile, otp),
            ExpiresAt = DateTime.UtcNow.AddMinutes(OtpTtlMinutes),
        };

        _db.OtpRecords.Add(record);
        await _db.SaveChangesAsync(ct);

        await _otpSender.SendAsync(mobile, otp, ct);
        _logger.LogInformation("OTP generated for {Mobile}, otpId={OtpId}", mobile, record.Id);

        return new SendOtpResponse("OTP sent", record.Id);
    }

    public async Task<VerifyOtpResponse> VerifyOtpAsync(VerifyOtpRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        if (string.IsNullOrWhiteSpace(request.Otp) || request.Otp.Length != OtpLength)
            throw new ValidationException("OTP must be a 6-digit code.");

        var record = await _db.OtpRecords
            .FirstOrDefaultAsync(o => o.Id == request.OtpId && o.MobileNumber == mobile, ct);

        if (record is null)
            throw new UnauthorizedException("Invalid OTP session.");

        if (record.IsUsed)
            throw new UnauthorizedException("OTP already used.");

        if (record.ExpiresAt < DateTime.UtcNow)
            throw new UnauthorizedException("OTP expired.");

        if (record.AttemptCount >= MaxVerifyAttempts)
            throw new UnauthorizedException("Too many failed attempts. Request a new OTP.");

        var devBypass = _config["Otp:DevBypassCode"];
        var otpValid = (!string.IsNullOrEmpty(devBypass) && request.Otp == devBypass)
            || record.OtpHash == HashOtp(mobile, request.Otp);

        if (!otpValid)
        {
            record.AttemptCount++;
            record.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
            throw new UnauthorizedException("Invalid OTP.");
        }

        record.IsUsed = true;
        record.UpdatedAt = DateTime.UtcNow;

        var user = await _db.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobile, ct);
        var isNewUser = user is null;

        if (isNewUser)
        {
            user = new User
            {
                MobileNumber = mobile,
                WhatsAppNumber = mobile,
            };
            _db.Users.Add(user);
        }

        await _db.SaveChangesAsync(ct);

        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == user!.Id, ct);

        var token = _jwt.GenerateToken(user!, business?.Id);

        return new VerifyOtpResponse(token, MapUser(user!), isNewUser);
    }

    /// <summary>Development-only login — no OTP, no rate limit.</summary>
    public async Task<VerifyOtpResponse> DevLoginAsync(SendOtpRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        var user = await _db.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobile, ct);
        var isNewUser = user is null;

        if (isNewUser)
        {
            user = new User
            {
                MobileNumber = mobile,
                WhatsAppNumber = mobile,
            };
            _db.Users.Add(user);
            await _db.SaveChangesAsync(ct);
        }

        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == user!.Id, ct);

        var token = _jwt.GenerateToken(user!, business?.Id);
        _logger.LogWarning("Dev login for {Mobile} (no OTP)", mobile);

        return new VerifyOtpResponse(token, MapUser(user!), isNewUser);
    }

    public async Task<RefreshTokenResponse> RefreshTokenAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == userId, ct);

        return new RefreshTokenResponse(_jwt.GenerateToken(user, business?.Id));
    }

    public async Task LogoutAsync(string tokenId, DateTime tokenExpiresAt, CancellationToken ct = default)
    {
        var exists = await _db.RevokedTokens.AnyAsync(r => r.TokenId == tokenId, ct);
        if (exists) return;

        _db.RevokedTokens.Add(new RevokedToken
        {
            TokenId = tokenId,
            ExpiresAt = tokenExpiresAt,
        });
        await _db.SaveChangesAsync(ct);
    }

    public async Task<AuthMeResponse> GetMeAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == userId, ct);

        return new AuthMeResponse(
            MapUser(user),
            business is null ? null : MapBusiness(business));
    }

    public async Task<UserDto> UpdateMeAsync(Guid userId, UpdateUserRequest request, CancellationToken ct = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        if (request.FullName != null)
            user.FullName = string.IsNullOrWhiteSpace(request.FullName) ? null : request.FullName.Trim();
        if (request.WhatsAppNumber != null)
            user.WhatsAppNumber = string.IsNullOrWhiteSpace(request.WhatsAppNumber) ? null : request.WhatsAppNumber.Trim();
        if (!string.IsNullOrWhiteSpace(request.LanguagePreference))
            user.LanguagePreference = request.LanguagePreference.Trim();

        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapUser(user);
    }

    public Task<bool> IsTokenRevokedAsync(string tokenId, CancellationToken ct = default) =>
        _db.RevokedTokens.AnyAsync(r => r.TokenId == tokenId, ct);

    private string HashOtp(string mobile, string otp)
    {
        var secret = _config["Jwt:Secret"] ?? "dev-secret";
        var payload = $"{mobile}:{otp}:{secret}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(payload));
        return Convert.ToHexString(hash);
    }

    private static string GenerateOtp()
    {
        var value = RandomNumberGenerator.GetInt32(0, 1_000_000);
        return value.ToString("D6");
    }

    internal static string NormalizeMobile(string mobile)
    {
        var digits = new string(mobile.Where(char.IsDigit).ToArray());
        if (digits.Length == 12 && digits.StartsWith("91"))
            digits = digits[2..];
        return digits;
    }

    internal static void ValidateMobile(string mobile)
    {
        if (mobile.Length != 10 || mobile[0] is < '6' or > '9')
            throw new ValidationException("Mobile must be a valid 10-digit Indian number.");
    }

    internal static UserDto MapUser(User user) => new(
        user.Id,
        user.MobileNumber,
        user.WhatsAppNumber,
        user.FullName,
        user.LanguagePreference,
        user.KycStatus,
        user.IsAdmin,
        user.CreatedAt);

    internal static BusinessSummaryDto MapBusiness(Business business) => new(
        business.Id,
        business.BusinessName,
        business.BusinessType,
        business.City,
        business.Status);
}
