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
    private readonly INotificationService _notifications;
    private readonly IProductService _products;

    public AdminService(AppDbContext db, INotificationService notifications, IProductService products)
    {
        _db = db;
        _notifications = notifications;
        _products = products;
    }

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

        var businesses = await query
            .Include(b => b.Subscriptions)
                .ThenInclude(s => s.Plan)
            .OrderByDescending(b => b.CreatedAt)
            .Skip(pagination.Skip)
            .Take(Math.Clamp(pagination.Limit, 1, 100))
            .ToListAsync(ct);

        var now = DateTime.UtcNow;
        var items = businesses.Select(b =>
        {
            var latestSub = b.Subscriptions
                .OrderByDescending(s => s.EndsAt)
                .FirstOrDefault();

            var isSubActive = latestSub != null && latestSub.Status == SubscriptionStatus.Active && latestSub.EndsAt > now;
            var daysRem = isSubActive ? Math.Max(0, (int)Math.Ceiling((latestSub!.EndsAt - now).TotalDays)) : 0;
            var subStatus = latestSub == null
                ? "None"
                : (isSubActive
                    ? (latestSub.Plan?.Slug == "trial-7-days" ? "Trial" : "Active")
                    : "Expired");

            var hasUsedTrial = b.Subscriptions.Any(s => s.Plan?.Slug == "trial-7-days");

            return new AdminBusinessListItemDto(
                b.Id,
                b.BusinessName,
                b.BusinessType,
                b.City,
                b.Status,
                b.Owner.MobileNumber,
                b.Owner.FullName,
                b.Owner.KycStatus,
                b.Products.Count,
                b.CreatedAt,
                b.FullAddress,
                b.FssaiNumber,
                b.GstNumber,
                b.UpiId,
                b.BankAccountNumber,
                b.BankIfsc,
                b.BankPennyVerified,
                b.Owner.WhatsAppNumber,
                b.Owner.AadhaarLast4,
                b.Owner.PanNumber,
                b.RejectionReason,
                b.AdminNotes,
                latestSub?.Plan?.Name,
                subStatus,
                latestSub?.StartsAt,
                latestSub?.EndsAt,
                daysRem,
                hasUsedTrial);
        }).ToList();

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

        await _notifications.CreateNotificationAsync(
            business.Id,
            "Business approved",
            $"{business.BusinessName} has been approved by admin. You can now add products and generate AR menus.",
            "businessApproved",
            null,
            ct);

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

        await _notifications.CreateNotificationAsync(
            business.Id,
            "Business needs changes",
            $"Admin rejected registration: {request.Reason.Trim()}",
            "businessRejected",
            null,
            ct);

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
            .Include(p => p.Model3d)
            .Where(p => p.Status != ProductStatus.Draft)
            // Only Hero / 3D AR items are sent for admin approval.
            // Normal items (auto-approved / live with standard 2D photos) bypass the approval queue.
            .Where(p => p.Photos.Count >= 4
                || p.Status == ProductStatus.Submitted
                || p.Status == ProductStatus.Review
                || p.Status == ProductStatus.Processing
                || (p.Status == ProductStatus.Live && p.Model3d != null)
                || (p.Status == ProductStatus.Paused && p.Model3d != null))
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
            var isHero = p.Photos.Count >= 4 || p.Model3d != null || p.Status == ProductStatus.Submitted || p.Status == ProductStatus.Review || p.Status == ProductStatus.Processing;
            return new AdminProductReviewItemDto(
                p.Id,
                p.Name,
                p.BusinessId,
                p.Business.BusinessName,
                p.Status,
                p.Photos.Count,
                job?.Id,
                job?.Status,
                p.UpdatedAt ?? p.CreatedAt,
                p.Description,
                p.PricePaise,
                p.Category,
                p.VegStatus,
                p.IsSpicy,
                p.IsBestseller,
                p.IsNew,
                p.Photos.OrderBy(ph => ph.SortOrder).Select(ph => new ProductPhotoDto(
                    ph.Id,
                    ph.PhotoUrl,
                    ph.AngleType,
                    ph.SortOrder,
                    ph.MimeType,
                    ph.FileSizeBytes,
                    ph.CreatedAt)).ToList(),
                p.Model3d?.GlbUrl,
                p.RejectionReason,
                p.CreatedAt,
                isHero);
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

    public async Task<ProductDto> ApproveProductAsync(Guid adminUserId, Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = product.Model3d?.GlbUrl != null ? ProductStatus.Live : ProductStatus.Review;
        product.RejectionReason = null;
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        await _notifications.CreateNotificationAsync(
            product.BusinessId,
            $"{product.Name} approved",
            $"Admin approved {product.Name}. It is ready for your 3D menu.",
            product.Status == ProductStatus.Live ? "productLive" : "productReview",
            product.Id,
            ct);

        return await _products.GetByIdAsync(product.BusinessId, product.Id, ct);
    }

    public async Task<ProductDto> RejectProductAsync(Guid adminUserId, Guid productId, string reason, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new ValidationException("Rejection reason is required.");

        var product = await _db.Products
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = ProductStatus.Rejected;
        product.RejectionReason = reason.Trim();
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        await _notifications.CreateNotificationAsync(
            product.BusinessId,
            $"{product.Name} rejected",
            $"Admin requested changes for {product.Name}: {reason.Trim()}",
            "productRejected",
            product.Id,
            ct);

        return await _products.GetByIdAsync(product.BusinessId, product.Id, ct);
    }

    public async Task<ProductDto> MakeProductLiveAsync(Guid adminUserId, Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = ProductStatus.Live;
        product.RejectionReason = null;
        product.UpdatedAt = DateTime.UtcNow;

        if (product.Model3d is null)
        {
            product.Model3d = new Model3d
            {
                ProductId = product.Id,
                GlbUrl = "https://modelviewer.dev/shared-assets/models/Astronaut.glb",
                ProcessingStatus = ModelProcessingStatus.Done,
                ApprovedAt = DateTime.UtcNow,
            };
            _db.Models3d.Add(product.Model3d);
        }

        await _db.SaveChangesAsync(ct);

        await _notifications.CreateNotificationAsync(
            product.BusinessId,
            $"{product.Name} is now LIVE in AR!",
            "Your dish 3D model is published and active. Customers can scan the QR code to view it in 3D AR.",
            "productLive",
            product.Id,
            ct);

        return await _products.GetByIdAsync(product.BusinessId, product.Id, ct);
    }

    public async Task<BusinessDto> SetBusinessStatusAsync(
        Guid adminUserId,
        Guid businessId,
        BusinessStatus status,
        string? reason = null,
        string? adminNotes = null,
        CancellationToken ct = default)
    {
        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        business.Status = status;
        business.ApprovedById = adminUserId;
        if (status == BusinessStatus.Active)
        {
            business.ApprovedAt = DateTime.UtcNow;
            business.RejectionReason = null;
        }
        else if (status is BusinessStatus.Rejected or BusinessStatus.Suspended or BusinessStatus.Deactivated)
        {
            if (!string.IsNullOrWhiteSpace(reason))
                business.RejectionReason = reason.Trim();
        }

        if (!string.IsNullOrWhiteSpace(adminNotes))
            business.AdminNotes = adminNotes.Trim();

        business.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return BusinessService.MapBusiness(business);
    }

    public async Task<ProductDto> SetProductStatusAsync(
        Guid adminUserId,
        Guid productId,
        ProductStatus status,
        CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = status;
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return await _products.GetByIdAsync(product.BusinessId, product.Id, ct);
    }
}
