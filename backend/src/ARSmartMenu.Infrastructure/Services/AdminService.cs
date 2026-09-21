using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class AdminService : IAdminService
{
    private readonly AppDbContext _db;

    public AdminService(AppDbContext db) => _db = db;

    public async Task<AdminDashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var totalBusinesses = await _db.Businesses.CountAsync(ct);
        var activeBusinesses = await _db.Businesses.CountAsync(b => b.Status == BusinessStatus.Active, ct);
        var pendingApprovals = await _db.Businesses.CountAsync(b => b.Status == BusinessStatus.PendingApproval, ct);
        var pendingProductReviews = await _db.Products.CountAsync(
            p => p.Status == ProductStatus.Review
                || p.Status == ProductStatus.Submitted
                || p.Status == ProductStatus.Processing,
            ct);
        var totalScans = await _db.ArScanEvents.CountAsync(ct);
        var totalViews = await _db.ArViewEvents.CountAsync(ct);
        var totalProducts = await _db.Products.CountAsync(ct);

        return new AdminDashboardDto(
            totalBusinesses,
            activeBusinesses,
            pendingApprovals,
            pendingProductReviews,
            totalScans,
            totalViews,
            totalProducts);
    }

    public async Task<PagedResult<AdminBusinessListItemDto>> ListBusinessesAsync(
        AdminBusinessFilter? filter,
        PaginationQuery pagination,
        CancellationToken ct = default)
    {
        var query = _db.Businesses
            .AsNoTracking()
            .Include(b => b.Owner)
            .AsQueryable();

        if (filter?.Status is not null)
            query = query.Where(b => b.Status == filter.Status);
        if (filter?.BusinessType is not null)
            query = query.Where(b => b.BusinessType == filter.BusinessType);
        if (!string.IsNullOrWhiteSpace(filter?.City))
            query = query.Where(b => b.City.Contains(filter.City));
        if (!string.IsNullOrWhiteSpace(filter?.Search))
        {
            var term = filter.Search.Trim();
            query = query.Where(b =>
                b.BusinessName.Contains(term)
                || b.Owner.MobileNumber.Contains(term)
                || (b.Owner.FullName != null && b.Owner.FullName.Contains(term)));
        }

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(b => b.CreatedAt)
            .Skip(pagination.Skip)
            .Take(Math.Clamp(pagination.Limit, 1, 100))
            .Select(b => new AdminBusinessListItemDto(
                b.Id,
                b.BusinessName,
                b.BusinessType,
                b.City,
                b.Status,
                b.Owner.MobileNumber,
                b.Owner.FullName,
                b.Owner.KycStatus,
                b.Products.Count,
                b.CreatedAt))
            .ToListAsync(ct);

        return new PagedResult<AdminBusinessListItemDto>
        {
            Items = items,
            Total = total,
            Page = pagination.Page,
            Limit = pagination.Limit,
        };
    }

    public async Task<BusinessDto> ApproveBusinessAsync(
        Guid adminUserId,
        Guid businessId,
        ApproveBusinessRequest request,
        CancellationToken ct = default)
    {
        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        business.Status = BusinessStatus.Active;
        business.ApprovedAt = DateTime.UtcNow;
        business.ApprovedById = adminUserId;
        business.RejectionReason = null;
        if (!string.IsNullOrWhiteSpace(request.AdminNotes))
            business.AdminNotes = request.AdminNotes.Trim();
        business.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);
        return BusinessService.MapBusiness(business);
    }

    public async Task<BusinessDto> RejectBusinessAsync(
        Guid adminUserId,
        Guid businessId,
        RejectBusinessRequest request,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationException("Rejection reason is required.");

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        business.Status = BusinessStatus.Rejected;
        business.RejectionReason = request.Reason.Trim();
        business.ApprovedById = adminUserId;
        business.ApprovedAt = null;
        if (!string.IsNullOrWhiteSpace(request.AdminNotes))
            business.AdminNotes = request.AdminNotes.Trim();
        business.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);
        return BusinessService.MapBusiness(business);
    }

    public async Task<IReadOnlyList<AdminProductReviewItemDto>> GetProductReviewQueueAsync(
        ProcessingJobStatus? jobStatus = null,
        CancellationToken ct = default)
    {
        var products = await _db.Products
            .AsNoTracking()
            .Include(p => p.Business)
            .Include(p => p.Photos)
            .Where(p => p.Status != ProductStatus.Draft && p.Status != ProductStatus.Paused)
            // Hide incomplete uploads — owner must finish 4 photos first.
            .Where(p => p.Photos.Count >= 4
                || p.Status == ProductStatus.Live
                || p.Status == ProductStatus.Rejected)
            .OrderByDescending(p => p.UpdatedAt)
            .ToListAsync(ct);

        if (products.Count == 0)
            return Array.Empty<AdminProductReviewItemDto>();

        var productIds = products.Select(p => p.Id).ToList();
        var jobs = await _db.ProcessingJobs
            .AsNoTracking()
            .Where(j => j.ProductId != null && productIds.Contains(j.ProductId.Value))
            .OrderByDescending(j => j.CreatedAt)
            .ToListAsync(ct);

        var latestJobByProduct = new Dictionary<Guid, ProcessingJob>();
        foreach (var job in jobs)
        {
            var pid = job.ProductId!.Value;
            latestJobByProduct.TryAdd(pid, job);
        }

        var items = products.Select(p =>
        {
            latestJobByProduct.TryGetValue(p.Id, out var job);
            return new AdminProductReviewItemDto(
                p.Id,
                p.Name,
                p.BusinessId,
                p.Business.BusinessName,
                p.Status,
                p.Photos.Count,
                job?.Id,
                job?.Status,
                p.UpdatedAt ?? p.CreatedAt);
        }).ToList();

        if (!jobStatus.HasValue)
            return items;

        return jobStatus.Value switch
        {
            ProcessingJobStatus.Review => items.Where(i =>
                i.JobStatus == ProcessingJobStatus.Review
                || i.JobStatus == ProcessingJobStatus.Optimizing
                || i.JobStatus == ProcessingJobStatus.Processing
                || i.ProductStatus == ProductStatus.Review
                || (i.ProcessingJobId is null && i.PhotoCount >= 4
                    && i.ProductStatus is ProductStatus.Submitted or ProductStatus.Processing))
                .ToList(),
            ProcessingJobStatus.Approved => items.Where(i =>
                i.JobStatus == ProcessingJobStatus.Approved).ToList(),
            _ => items.Where(i => i.JobStatus == jobStatus).ToList(),
        };
    }
}
