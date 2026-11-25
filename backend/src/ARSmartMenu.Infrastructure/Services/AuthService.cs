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
    private readonly AppLookupCacheService _lookupCache;

    public AuthService(
        AppDbContext db,
        IJwtTokenService jwt,
        IOtpSender otpSender,
        IConfiguration config,
        ILogger<AuthService> logger,
        AppLookupCacheService lookupCache)
    {
        _db = db;
        _jwt = jwt;
        _otpSender = otpSender;
        _config = config;
        _logger = logger;
        _lookupCache = lookupCache;
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

        await ValidateAndConsumeOtpAsync(mobile, request.OtpId, request.Otp, detailedErrors: false, ct);

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

        return await IssueAuthResponseAsync(user!, isNewUser, ct);
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

        _logger.LogWarning("Dev login for {Mobile} (no OTP)", mobile);
        return await IssueAuthResponseAsync(user!, isNewUser, ct);
    }

    /// <summary>Mobile number + password / PIN login (no OTP needed).</summary>
    public async Task<VerifyOtpResponse> PasswordLoginAsync(PasswordLoginRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        if (string.IsNullOrWhiteSpace(request.Password))
            throw new ValidationException("Password is required.");

        var user = await _db.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobile, ct);
        if (user is null)
            throw new UnauthorizedException("No account found with this mobile number. Please register first.");

        // If user doesn't have a password set yet (e.g. earlier dev/OTP user), set it on first password login
        if (string.IsNullOrEmpty(user.PasswordHash))
        {
            user.PasswordHash = PasswordHelper.HashPassword(request.Password.Trim());
            await _db.SaveChangesAsync(ct);
        }
        else if (!PasswordHelper.VerifyPassword(request.Password.Trim(), user.PasswordHash))
        {
            throw new UnauthorizedException("Incorrect password or PIN. Please try again.");
        }

        _logger.LogInformation("Password login successful for {Mobile}", mobile);
        return await IssueAuthResponseAsync(user, forceIsNewUser: null, ct);
    }

    /// <summary>Mobile number + password / PIN registration (no OTP needed).</summary>
    public async Task<VerifyOtpResponse> PasswordRegisterAsync(PasswordRegisterRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        if (string.IsNullOrWhiteSpace(request.Password) || request.Password.Trim().Length < 4)
            throw new ValidationException("Password or PIN must be at least 4 characters/digits.");

        var user = await _db.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobile, ct);

        if (user is null)
        {
            user = new User
            {
                MobileNumber = mobile,
                WhatsAppNumber = mobile,
                FullName = request.FullName?.Trim(),
                PasswordHash = PasswordHelper.HashPassword(request.Password.Trim()),
            };
            _db.Users.Add(user);
        }
        else
        {
            // Update credentials for existing user registering/setting password
            user.PasswordHash = PasswordHelper.HashPassword(request.Password.Trim());
            if (!string.IsNullOrWhiteSpace(request.FullName))
                user.FullName = request.FullName.Trim();
        }
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("Password registration successful for {Mobile}", mobile);
        return await IssueAuthResponseAsync(user, forceIsNewUser: null, ct);
    }

    /// <summary>Reset owner PIN using verified OTP session.</summary>
    public async Task<VerifyOtpResponse> ResetPinAsync(ResetPinRequest request, CancellationToken ct = default)
    {
        var mobile = NormalizeMobile(request.Mobile);
        ValidateMobile(mobile);

        if (string.IsNullOrWhiteSpace(request.NewPin) || request.NewPin.Trim().Length < 4)
            throw new ValidationException("New PIN or password must be at least 4 digits/characters.");

        await ValidateAndConsumeOtpAsync(mobile, request.OtpId, request.Otp, detailedErrors: true, ct);

        var user = await _db.Users.FirstOrDefaultAsync(u => u.MobileNumber == mobile, ct);
        if (user is null)
            throw new NotFoundException("No account registered with this mobile number.");

        user.PasswordHash = PasswordHelper.HashPassword(request.NewPin.Trim());
        user.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        _logger.LogInformation("PIN reset successful for {Mobile}", mobile);
        return await IssueAuthResponseAsync(user, forceIsNewUser: null, ct);
    }

    public async Task<RefreshTokenResponse> RefreshTokenAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        var businessId = await GetOwnedBusinessIdAsync(userId, ct);
        return new RefreshTokenResponse(_jwt.GenerateToken(user, businessId));
    }

    public async Task LogoutAsync(string tokenId, DateTime tokenExpiresAt, CancellationToken ct = default)
    {
        var exists = await _db.RevokedTokens.AsNoTracking().AnyAsync(r => r.TokenId == tokenId, ct);
        if (!exists)
        {
            _db.RevokedTokens.Add(new RevokedToken
            {
                TokenId = tokenId,
                ExpiresAt = tokenExpiresAt,
            });
            await _db.SaveChangesAsync(ct);
        }
        _lookupCache.MarkTokenRevoked(tokenId, tokenExpiresAt);
    }

    public async Task<AuthMeResponse> GetMeAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        var businessSummary = await _db.Businesses
            .AsNoTracking()
            .Where(b => b.OwnerId == userId)
            .Select(b => new BusinessSummaryDto(b.Id, b.BusinessName, b.BusinessType, b.City, b.Status))
            .FirstOrDefaultAsync(ct);

        return new AuthMeResponse(MapUser(user), businessSummary);
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
        _lookupCache.IsTokenRevokedAsync(tokenId, ct);

    private async Task ValidateAndConsumeOtpAsync(
        string mobile,
        Guid otpId,
        string otp,
        bool detailedErrors,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(otp) || otp.Length != OtpLength)
            throw new ValidationException("OTP must be a 6-digit code.");

        var record = await _db.OtpRecords
            .FirstOrDefaultAsync(o => o.Id == otpId && o.MobileNumber == mobile, ct)
            ?? throw new UnauthorizedException("Invalid OTP session.");

        if (record.IsUsed)
            throw new UnauthorizedException(detailedErrors ? "OTP has already been used. Please request a new code." : "OTP already used.");

        if (record.ExpiresAt < DateTime.UtcNow)
            throw new UnauthorizedException(detailedErrors ? "OTP has expired. Please request a fresh code." : "OTP expired.");

        if (record.AttemptCount >= MaxVerifyAttempts)
            throw new UnauthorizedException(detailedErrors ? "Too many failed attempts. Please request a fresh OTP." : "Too many failed attempts. Request a new OTP.");

        // Strict verification: only the exact OTP generated for this session and mobile is accepted
        var otpValid = record.OtpHash == HashOtp(mobile, otp);

        if (!otpValid)
        {
            record.AttemptCount++;
            record.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
            throw new UnauthorizedException(detailedErrors ? "Invalid OTP entered. Please check WhatsApp/SMS and try again." : "Invalid OTP.");
        }

        record.IsUsed = true;
        record.UpdatedAt = DateTime.UtcNow;
    }

    private Task<Guid?> GetOwnedBusinessIdAsync(Guid ownerId, CancellationToken ct) =>
        _db.Businesses
            .AsNoTracking()
            .Where(b => b.OwnerId == ownerId)
            .Select(b => (Guid?)b.Id)
            .FirstOrDefaultAsync(ct);

    private async Task<VerifyOtpResponse> IssueAuthResponseAsync(
        User user,
        bool? forceIsNewUser,
        CancellationToken ct)
    {
        var businessId = await GetOwnedBusinessIdAsync(user.Id, ct);
        var token = _jwt.GenerateToken(user, businessId);
        return new VerifyOtpResponse(token, MapUser(user), forceIsNewUser ?? businessId is null);
    }

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
