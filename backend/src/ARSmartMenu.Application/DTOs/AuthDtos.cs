using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Application.DTOs;

public record SendOtpRequest(string Mobile);

public record SendOtpResponse(string Message, Guid OtpId);

public record VerifyOtpRequest(string Mobile, string Otp, Guid OtpId);

public record VerifyOtpResponse(string Token, UserDto User, bool IsNewUser);

public record RefreshTokenResponse(string Token);

public record AuthMeResponse(UserDto User, BusinessSummaryDto? Business);

public record UpdateUserRequest(
    string? FullName = null,
    string? WhatsAppNumber = null,
    string? LanguagePreference = null);

public record UserDto(
    Guid Id,
    string MobileNumber,
    string? WhatsAppNumber,
    string? FullName,
    string LanguagePreference,
    KycStatus KycStatus,
    bool IsAdmin,
    DateTime CreatedAt);

public record BusinessSummaryDto(
    Guid Id,
    string BusinessName,
    BusinessType BusinessType,
    string City,
    BusinessStatus Status);
