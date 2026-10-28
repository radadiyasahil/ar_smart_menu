using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class BusinessService : IBusinessService
{
    private readonly AppDbContext _db;

    public BusinessService(AppDbContext db) => _db = db;

    public async Task<BusinessDto> CreateAsync(Guid userId, CreateBusinessRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.BusinessName))
            throw new ValidationException("Business name is required.");
        if (string.IsNullOrWhiteSpace(request.City))
            throw new ValidationException("City is required.");
        if (string.IsNullOrWhiteSpace(request.FullAddress))
            throw new ValidationException("Full address is required.");

        var hasBusiness = await _db.Businesses.AnyAsync(b => b.OwnerId == userId, ct);
        if (hasBusiness)
            throw new ConflictException("You already have a registered business.");

        var business = new Business
        {
            OwnerId = userId,
            BusinessName = request.BusinessName.Trim(),
            BusinessType = request.BusinessType,
            City = request.City.Trim(),
            FullAddress = request.FullAddress.Trim(),
            FssaiNumber = request.FssaiNumber?.Trim(),
            GstNumber = request.GstNumber?.Trim(),
            Status = BusinessStatus.PendingApproval,
        };

        _db.Businesses.Add(business);
        await _db.SaveChangesAsync(ct);

        return MapBusiness(business);
    }

    public async Task<BusinessDto> GetMeAsync(Guid userId, CancellationToken ct = default)
    {
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.OwnerId == userId, ct)
            ?? throw new NotFoundException("Business not found.");

        return MapBusiness(business);
    }

    public async Task<BusinessDto> UpdateMeAsync(Guid userId, UpdateBusinessRequest request, CancellationToken ct = default)
    {
        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.OwnerId == userId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (!string.IsNullOrWhiteSpace(request.BusinessName))
            business.BusinessName = request.BusinessName.Trim();
        if (request.BusinessType.HasValue)
            business.BusinessType = request.BusinessType.Value;
        if (!string.IsNullOrWhiteSpace(request.City))
            business.City = request.City.Trim();
        if (!string.IsNullOrWhiteSpace(request.FullAddress))
            business.FullAddress = request.FullAddress.Trim();
        if (request.LogoUrl is not null)
            business.LogoUrl = request.LogoUrl;
        if (request.FssaiNumber is not null)
            business.FssaiNumber = request.FssaiNumber;
        if (request.GstNumber is not null)
            business.GstNumber = request.GstNumber;
        if (request.UpiId is not null)
            business.UpiId = request.UpiId;

        business.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapBusiness(business);
    }

    public async Task<BusinessDto> UpdateStatusAsync(Guid userId, UpdateBusinessStatusRequest request, CancellationToken ct = default)
    {
        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.OwnerId == userId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (request.Status != BusinessStatus.Active && request.Status != BusinessStatus.Deactivated && request.Status != BusinessStatus.Suspended)
        {
            throw new ValidationException("Owner can only activate, deactivate, or pause their business.");
        }

        if (business.Status == BusinessStatus.PendingApproval)
        {
            throw new ValidationException("Cannot change status while business is pending admin approval.");
        }
        if (business.Status == BusinessStatus.Rejected && request.Status == BusinessStatus.Active)
        {
            throw new ValidationException("Cannot activate a rejected business. Please update registration and contact admin.");
        }

        business.Status = request.Status;
        if (request.Status is BusinessStatus.Deactivated or BusinessStatus.Suspended)
        {
            if (!string.IsNullOrWhiteSpace(request.Reason))
                business.RejectionReason = request.Reason.Trim();
        }
        else if (request.Status == BusinessStatus.Active)
        {
            business.RejectionReason = null;
        }

        business.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapBusiness(business);
    }

    public async Task<VerifyBankResponse> VerifyBankAsync(Guid userId, VerifyBankRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.BankAccountNumber) || request.BankAccountNumber.Length < 9)
            throw new ValidationException("Valid bank account number is required.");
        if (string.IsNullOrWhiteSpace(request.BankIfsc) || request.BankIfsc.Length != 11)
            throw new ValidationException("Valid 11-character IFSC is required.");

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.OwnerId == userId, ct)
            ?? throw new NotFoundException("Business not found.");

        business.BankAccountNumber = request.BankAccountNumber.Trim();
        business.BankIfsc = request.BankIfsc.Trim().ToUpperInvariant();
        business.BankPennyVerified = true;
        business.RazorpayContactId ??= $"contact_mock_{business.Id:N}"[..24];
        business.RazorpayFundAccountId ??= $"fa_mock_{business.Id:N}"[..24];
        business.UpdatedAt = DateTime.UtcNow;

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user is not null && user.KycStatus == KycStatus.Pending)
        {
            user.KycStatus = KycStatus.Submitted;
            user.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(ct);

        return new VerifyBankResponse(true, "Bank account verified via mock penny drop.");
    }

    public async Task<UserDto> SubmitKycAsync(Guid userId, SubmitKycRequest request, CancellationToken ct = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new NotFoundException("User not found.");

        if (!string.IsNullOrWhiteSpace(request.FullName))
            user.FullName = request.FullName.Trim();
        if (!string.IsNullOrWhiteSpace(request.AadhaarLast4))
            user.AadhaarLast4 = request.AadhaarLast4.Trim();
        if (!string.IsNullOrWhiteSpace(request.PanNumber))
            user.PanNumber = request.PanNumber.Trim().ToUpperInvariant();

        if (user.KycStatus == KycStatus.Pending)
            user.KycStatus = KycStatus.Submitted;

        user.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return AuthService.MapUser(user);
    }

    internal static BusinessDto MapBusiness(Business business) => new(
        business.Id,
        business.OwnerId,
        business.BusinessName,
        business.BusinessType,
        business.City,
        business.FullAddress,
        business.LogoUrl,
        business.FssaiNumber,
        business.GstNumber,
        business.BankAccountNumber,
        business.BankIfsc,
        business.UpiId,
        business.BankPennyVerified,
        business.Status,
        business.RejectionReason,
        business.ApprovedAt,
        business.CreatedAt);
}
