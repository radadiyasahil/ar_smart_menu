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
    private readonly AppLookupCacheService _lookupCache;

    public AdminService(
        AppDbContext db,
        INotificationService notifications,
        IProductService products,
        AppLookupCacheService lookupCache)
    {
        _db = db;
        _notifications = notifications;
        _products = products;
        _lookupCache = lookupCache;
    }

    private sealed class AdminDashboardStatsSpRow
    {
        public int TotalBusinesses { get; set; }
        public int ActiveBusinesses { get; set; }
        public int PendingApprovals { get; set; }
        public int PendingProductReviews { get; set; }
        public int TotalScans { get; set; }
        public int TotalArViews { get; set; }
        public int TotalProducts { get; set; }
        public int TotalLiveDishes { get; set; }
        public int TotalArDishes { get; set; }
        public int TotalOrdersPlaced { get; set; }
        public int TotalOrdersCompleted { get; set; }
        public double? AverageRating { get; set; }
        public int TotalReviews { get; set; }
    }

    private sealed class AdminBusinessSummaryRow
    {
        public Guid Id { get; set; }
        public Guid OwnerId { get; set; }
        public string BusinessName { get; set; } = string.Empty;
        public int BusinessType { get; set; }
        public string City { get; set; } = string.Empty;
        public string FullAddress { get; set; } = string.Empty;
        public int Status { get; set; }
        public string? FssaiNumber { get; set; }
        public string? GstNumber { get; set; }
        public string? UpiId { get; set; }
        public string? BankAccountNumber { get; set; }
        public string? BankIfsc { get; set; }
        public bool BankPennyVerified { get; set; }
        public string? RejectionReason { get; set; }
        public string? AdminNotes { get; set; }
        public int? CustomDishLimit { get; set; }
        public bool ArViewEnabled { get; set; }
        public int ArPerViewChargePaise { get; set; }
        public int ArViewCredits { get; set; }
        public int ArViewsUsed { get; set; }
        public DateTime CreatedAt { get; set; }
        public string OwnerMobile { get; set; } = string.Empty;
        public string? OwnerName { get; set; }
        public int OwnerKycStatus { get; set; }
        public string? OwnerWhatsApp { get; set; }
        public string? OwnerAadhaarLast4 { get; set; }
        public string? OwnerPanNumber { get; set; }
        public string? SubscriptionPlanName { get; set; }
        public string? SubscriptionPlanSlug { get; set; }
        public DateTime? SubscriptionStartsAt { get; set; }
        public DateTime? SubscriptionEndsAt { get; set; }
        public int? SubStatusInt { get; set; }
        public int? PlanMaxProducts { get; set; }
        public string SubscriptionStatus { get; set; } = "None";
        public int SubscriptionDaysRemaining { get; set; }
        public bool HasUsedTrial { get; set; }
        public int EffectiveDishLimit { get; set; }
        public int ProductCount { get; set; }
        public int LiveProductCount { get; set; }
        public int ArProductCount { get; set; }
        public int TotalOrdersCount { get; set; }
        public int CompletedOrdersCount { get; set; }
        public int TotalScans { get; set; }
        public int TotalViews { get; set; }
        public double? AverageRating { get; set; }
        public int TotalReviews { get; set; }
    }

    private Task<List<AdminDashboardStatsSpRow>> ExecDashboardSpAsync(CancellationToken ct) =>
        _db.Database.SqlQueryRaw<AdminDashboardStatsSpRow>("EXEC [dbo].[usp_GetAdminDashboardStats]").ToListAsync(ct);

    public async Task<AdminDashboardDto> GetDashboardAsync(CancellationToken ct = default)
    {
        var s = (await ExecDashboardSpAsync(ct)).FirstOrDefault();
        if (s == null)
            return new AdminDashboardDto(0, 0, 0, 0, 0, 0, 0);

        return new AdminDashboardDto(
            s.TotalBusinesses,
            s.ActiveBusinesses,
            s.PendingApprovals,
            s.PendingProductReviews,
            s.TotalScans,
            s.TotalArViews,
            s.TotalProducts);
    }

    public async Task<AdminOperationsSummaryDto> GetOperationsSummaryAsync(CancellationToken ct = default)
    {
        var s = (await ExecDashboardSpAsync(ct)).FirstOrDefault();
        if (s == null)
            return new AdminOperationsSummaryDto(0, 0, 0, 0, 0, 0, 0L, 0, 0, null, 0);

        return new AdminOperationsSummaryDto(
            s.TotalBusinesses,
            s.TotalProducts,
            s.TotalLiveDishes,
            s.TotalArDishes,
            s.TotalOrdersPlaced,
            s.TotalOrdersCompleted,
            0L, // Zeroed out to protect private restaurant revenue
            s.TotalScans,
            s.TotalArViews,
            s.AverageRating,
            s.TotalReviews);
    }

    private static AdminBusinessListItemDto MapSummaryRow(AdminBusinessSummaryRow r) => new(
        r.Id,
        r.BusinessName,
        (BusinessType)r.BusinessType,
        r.City,
        (BusinessStatus)r.Status,
        r.OwnerMobile,
        r.OwnerName,
        (KycStatus)r.OwnerKycStatus,
        r.ProductCount,
        r.CreatedAt,
        r.FullAddress,
        r.FssaiNumber,
        r.GstNumber,
        r.UpiId,
        r.BankAccountNumber,
        r.BankIfsc,
        r.BankPennyVerified,
        r.OwnerWhatsApp,
        r.OwnerAadhaarLast4,
        r.OwnerPanNumber,
        r.RejectionReason,
        r.AdminNotes,
        r.SubscriptionPlanName,
        r.SubscriptionStatus,
        r.SubscriptionStartsAt,
        r.SubscriptionEndsAt,
        r.SubscriptionDaysRemaining,
        r.HasUsedTrial,
        r.CustomDishLimit,
        r.EffectiveDishLimit,
        r.ArViewEnabled,
        r.ArPerViewChargePaise,
        r.ArViewCredits,
        r.ArViewsUsed,
        r.LiveProductCount,
        r.ArProductCount,
        r.TotalOrdersCount,
        r.CompletedOrdersCount,
        0L,
        r.TotalScans,
        r.TotalViews,
        r.AverageRating,
        r.TotalReviews);

    public async Task<PagedResult<AdminBusinessListItemDto>> ListBusinessesAsync(
        AdminBusinessFilter? filter,
        PaginationQuery pagination,
        CancellationToken ct = default)
    {
        var query = _db.Database.SqlQueryRaw<AdminBusinessSummaryRow>(
            "SELECT * FROM [dbo].[vw_AdminBusinessSummary]");

        if (filter?.Status is not null)
        {
            var statusInt = (int)filter.Status.Value;
            query = query.Where(b => b.Status == statusInt);
        }
        if (filter?.BusinessType is not null)
        {
            var typeInt = (int)filter.BusinessType.Value;
            query = query.Where(b => b.BusinessType == typeInt);
        }
        if (!string.IsNullOrWhiteSpace(filter?.City))
        {
            var city = filter.City.Trim();
            query = query.Where(b => b.City.Contains(city));
        }
        if (!string.IsNullOrWhiteSpace(filter?.Search))
        {
            var term = filter.Search.Trim();
            query = query.Where(b =>
                b.BusinessName.Contains(term)
                || b.OwnerMobile.Contains(term)
                || (b.OwnerName != null && b.OwnerName.Contains(term)));
        }

        var total = await query.CountAsync(ct);

        var rows = await query
            .OrderByDescending(b => b.CreatedAt)
            .Skip(pagination.Skip)
            .Take(Math.Clamp(pagination.Limit, 1, 100))
            .ToListAsync(ct);

        return new PagedResult<AdminBusinessListItemDto>
        {
            Items = rows.Select(MapSummaryRow).ToList(),
            Total = total,
            Page = pagination.Page,
            Limit = pagination.Limit
        };
    }

    public async Task<AdminBusinessListItemDto?> GetBusinessByIdAsync(Guid businessId, CancellationToken ct = default)
    {
        var row = await _db.Database
            .SqlQueryRaw<AdminBusinessSummaryRow>("SELECT * FROM [dbo].[vw_AdminBusinessSummary]")
            .FirstOrDefaultAsync(b => b.Id == businessId, ct);

        return row == null ? null : MapSummaryRow(row);
    }

    public async Task<AdminBusinessListItemDto> UpdateBusinessAsync(
        Guid adminUserId,
        Guid businessId,
        AdminUpdateBusinessRequest request,
        CancellationToken ct = default)
    {
        var b = await _db.Businesses
            .Include(b => b.Owner)
            .FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (!string.IsNullOrWhiteSpace(request.BusinessName))
            b.BusinessName = request.BusinessName.Trim();

        if (request.BusinessType.HasValue)
            b.BusinessType = request.BusinessType.Value;

        if (!string.IsNullOrWhiteSpace(request.City))
            b.City = request.City.Trim();

        if (request.FullAddress != null)
            b.FullAddress = request.FullAddress.Trim();

        if (request.FssaiNumber != null)
            b.FssaiNumber = string.IsNullOrWhiteSpace(request.FssaiNumber) ? null : request.FssaiNumber.Trim();

        if (request.GstNumber != null)
            b.GstNumber = string.IsNullOrWhiteSpace(request.GstNumber) ? null : request.GstNumber.Trim();

        if (request.UpiId != null)
            b.UpiId = string.IsNullOrWhiteSpace(request.UpiId) ? null : request.UpiId.Trim();

        if (request.BankAccountNumber != null)
            b.BankAccountNumber = string.IsNullOrWhiteSpace(request.BankAccountNumber) ? null : request.BankAccountNumber.Trim();

        if (request.BankIfsc != null)
            b.BankIfsc = string.IsNullOrWhiteSpace(request.BankIfsc) ? null : request.BankIfsc.Trim();

        if (request.AdminNotes != null)
            b.AdminNotes = request.AdminNotes.Trim();

        if (b.Owner != null)
        {
            if (!string.IsNullOrWhiteSpace(request.OwnerFullName))
                b.Owner.FullName = request.OwnerFullName.Trim();

            if (request.OwnerWhatsApp != null)
                b.Owner.WhatsAppNumber = string.IsNullOrWhiteSpace(request.OwnerWhatsApp) ? null : request.OwnerWhatsApp.Trim();

            if (request.OwnerKycStatus.HasValue)
                b.Owner.KycStatus = (KycStatus)request.OwnerKycStatus.Value;
        }

        b.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        _lookupCache.InvalidateBusiness(businessId);

        return await GetBusinessByIdAsync(businessId, ct)
            ?? throw new NotFoundException("Business not found.");
    }

    public async Task<AdminBusinessListItemDto> UpdateBusinessSettingsAsync(
        Guid businessId,
        UpdateBusinessSettingsRequest request,
        CancellationToken ct = default)
    {
        var business = await _db.Businesses
            .FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (request.CustomDishLimit.HasValue)
            business.CustomDishLimit = request.CustomDishLimit.Value > 0 ? request.CustomDishLimit.Value : null;

        if (request.ArViewEnabled.HasValue)
            business.ArViewEnabled = request.ArViewEnabled.Value;

        if (request.ArPerViewChargePaise.HasValue)
            business.ArPerViewChargePaise = Math.Max(0, request.ArPerViewChargePaise.Value);

        if (request.ArViewCredits.HasValue)
            business.ArViewCredits = Math.Max(0, request.ArViewCredits.Value);

        business.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        _lookupCache.InvalidateBusiness(businessId);

        return await GetBusinessByIdAsync(businessId, ct)
            ?? throw new NotFoundException("Business not found.");
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

        // Auto-activate 7-day free trial on approval if no active subscription exists
        var hasActiveSub = await _db.Subscriptions
            .AnyAsync(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);
        if (!hasActiveSub)
        {
            var trialPlan = await _db.SubscriptionPlans
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Slug == "trial-7-days" && p.IsActive, ct);
            if (trialPlan != null)
            {
                var hasUsedTrial = await _db.Subscriptions
                    .AnyAsync(s => s.BusinessId == businessId && s.PlanId == trialPlan.Id, ct);
                if (!hasUsedTrial)
                {
                    var startsAt = DateTime.UtcNow;
                    _db.Subscriptions.Add(new Subscription
                    {
                        BusinessId = businessId,
                        PlanId = trialPlan.Id,
                        BillingCycle = BillingCycle.Monthly,
                        Status = SubscriptionStatus.Active,
                        StartsAt = startsAt,
                        EndsAt = startsAt.AddDays(7),
                        PaymentMethod = "Free Trial",
                        TransactionRef = "TRIAL_7_DAYS_APPROVAL",
                        PaymentStatus = "Completed",
                        InvoiceDate = startsAt,
                        InvoiceNumber = $"INV-{startsAt:yyyyMM}-{Guid.NewGuid().ToString()[..6].ToUpper()}",
                        CustomerBusinessName = business.BusinessName,
                        CustomerGstNumber = business.GstNumber,
                        CustomerAddress = business.FullAddress,
                        CustomerCity = business.City,
                        CustomerState = business.City,
                        SacCode = "998313"
                    });
                }
            }
        }

        await _db.SaveChangesAsync(ct);
        _lookupCache.InvalidateBusiness(businessId);

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
        _lookupCache.InvalidateBusiness(businessId);

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
            .Where(p => p.Status != ProductStatus.Draft)
            .Where(p => p.Photos.Count >= 4
                || p.Status == ProductStatus.Submitted
                || p.Status == ProductStatus.Review
                || p.Status == ProductStatus.Processing
                || (p.Status == ProductStatus.Live && p.Model3d != null)
                || (p.Status == ProductStatus.Paused && p.Model3d != null))
            .OrderByDescending(p => p.UpdatedAt)
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.BusinessId,
                BusinessName = p.Business.BusinessName,
                p.Status,
                p.UpdatedAt,
                p.CreatedAt,
                p.Description,
                p.PricePaise,
                p.Category,
                p.VegStatus,
                p.IsSpicy,
                p.IsBestseller,
                p.IsNew,
                p.RejectionReason,
                GlbUrl = p.Model3d != null ? p.Model3d.GlbUrl : null,
                HasModel = p.Model3d != null,
                Photos = p.Photos
                    .OrderBy(ph => ph.SortOrder)
                    .Select(ph => new ProductPhotoDto(
                        ph.Id,
                        ph.PhotoUrl,
                        ph.AngleType,
                        ph.SortOrder,
                        ph.MimeType,
                        ph.FileSizeBytes,
                        ph.CreatedAt))
                    .ToList()
            })
            .ToListAsync(ct);

        if (products.Count == 0)
            return Array.Empty<AdminProductReviewItemDto>();

        var productIds = products.Select(p => p.Id).ToList();
        var latestJobs = await _db.ProcessingJobs
            .AsNoTracking()
            .Where(j => j.ProductId != null && productIds.Contains(j.ProductId.Value))
            .GroupBy(j => j.ProductId!.Value)
            .Select(g => g.OrderByDescending(j => j.CreatedAt)
                .Select(j => new { ProductId = j.ProductId!.Value, j.Id, j.Status })
                .First())
            .ToDictionaryAsync(x => x.ProductId, ct);

        var items = products.Select(p =>
        {
            latestJobs.TryGetValue(p.Id, out var job);
            var isHero = p.Photos.Count >= 4 || p.HasModel || p.Status is ProductStatus.Submitted or ProductStatus.Review or ProductStatus.Processing;
            return new AdminProductReviewItemDto(
                p.Id,
                p.Name,
                p.BusinessId,
                p.BusinessName,
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
                p.Photos,
                p.GlbUrl,
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
        _lookupCache.InvalidateBusiness(product.BusinessId);

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
        _lookupCache.InvalidateBusiness(product.BusinessId);

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
        _lookupCache.InvalidateBusiness(product.BusinessId);

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
        _lookupCache.InvalidateBusiness(businessId);

        return BusinessService.MapBusiness(business);
    }

    public async Task<ProductDto> SetProductStatusAsync(
        Guid adminUserId,
        Guid productId,
        ProductStatus status,
        CancellationToken ct = default)
    {
        var product = await _db.Products
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = status;
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        _lookupCache.InvalidateBusiness(product.BusinessId);

        return await _products.GetByIdAsync(product.BusinessId, product.Id, ct);
    }

    public async Task<AdminNotificationsResponse> GetNotificationsAsync(CancellationToken ct = default)
    {
        var notifications = new List<AdminNotificationDto>();

        var pendingBusinesses = await _db.Businesses
            .AsNoTracking()
            .Where(b => b.Status == BusinessStatus.PendingApproval)
            .OrderByDescending(b => b.CreatedAt)
            .Take(30)
            .Select(b => new { b.Id, b.BusinessName, b.City, b.LogoUrl, b.CreatedAt })
            .ToListAsync(ct);

        foreach (var b in pendingBusinesses)
        {
            notifications.Add(new AdminNotificationDto(
                b.Id,
                $"New Business: {b.BusinessName}",
                $"'{b.BusinessName}' ({b.City}) submitted for approval. Click to verify and activate.",
                "business_approval",
                b.Id,
                b.BusinessName,
                null,
                null,
                b.LogoUrl,
                b.CreatedAt,
                $"/businesses?status=pending&businessId={b.Id}"
            ));
        }

        var reviewProducts = await _db.Products
            .AsNoTracking()
            .Where(p => p.Status != ProductStatus.Draft && p.Status != ProductStatus.Live && p.Status != ProductStatus.Rejected)
            .Where(p => p.Photos.Count >= 4
                || p.Status == ProductStatus.Submitted
                || p.Status == ProductStatus.Review
                || p.Status == ProductStatus.Processing)
            .OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt)
            .Take(30)
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.BusinessId,
                BusinessName = p.Business != null ? p.Business.BusinessName : "Restaurant",
                FrontPhoto = p.Photos
                    .Where(x => x.AngleType == PhotoAngleType.Front)
                    .Select(x => x.PhotoUrl)
                    .FirstOrDefault()
                    ?? p.Photos.Select(x => x.PhotoUrl).FirstOrDefault(),
                Timestamp = p.UpdatedAt ?? p.CreatedAt
            })
            .ToListAsync(ct);

        foreach (var p in reviewProducts)
        {
            notifications.Add(new AdminNotificationDto(
                p.Id,
                $"New Dish for Review: {p.Name}",
                $"'{p.Name}' from {p.BusinessName} is waiting for 3D AR review and approval.",
                "product_review",
                p.BusinessId,
                p.BusinessName,
                p.Id,
                p.Name,
                p.FrontPhoto,
                p.Timestamp,
                $"/products?filter=pending&productId={p.Id}"
            ));
        }

        var sorted = notifications.OrderByDescending(n => n.CreatedAt).ToList();

        return new AdminNotificationsResponse(
            sorted,
            pendingBusinesses.Count + reviewProducts.Count,
            pendingBusinesses.Count,
            reviewProducts.Count
        );
    }

    public async Task ResetOwnerPinAsync(Guid businessId, string newPin, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(newPin) || newPin.Trim().Length < 4)
            throw new ValidationException("New PIN or password must be at least 4 digits/characters.");

        var ownerId = await _db.Businesses
            .AsNoTracking()
            .Where(b => b.Id == businessId)
            .Select(b => (Guid?)b.OwnerId)
            .FirstOrDefaultAsync(ct)
            ?? throw new NotFoundException("Business not found.");

        var owner = await _db.Users.FirstOrDefaultAsync(u => u.Id == ownerId, ct)
            ?? throw new NotFoundException("Owner account not found for this business.");

        owner.PasswordHash = PasswordHelper.HashPassword(newPin.Trim());
        owner.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    public async Task<byte[]> ExportOperationsCsvAsync(CancellationToken ct = default)
    {
        var businesses = await _db.Database
            .SqlQueryRaw<AdminBusinessSummaryRow>("SELECT * FROM [dbo].[vw_AdminBusinessSummary]")
            .OrderByDescending(b => b.CreatedAt)
            .ToListAsync(ct);

        var sb = new System.Text.StringBuilder();

        // UTF-8 BOM so Excel opens it with proper formatting
        sb.Append('\uFEFF');
        sb.AppendLine("Restaurant Name,City,Business Type,Status,Subscription Plan,Subscription Status,Days Remaining,Total Dishes Listed,Live Dishes,3D AR Dishes,Dish Limit,Capacity Used %,Total Orders Placed,Completed Orders,Fulfillment %,Total Scans,Total AR Views,Owner Name,Owner Mobile,Registered Date");

        static string Escape(string? val) => $"\"{(val ?? "").Replace("\"", "\"\"")}\"";

        foreach (var b in businesses)
        {
            var effectiveLimit = b.EffectiveDishLimit;
            var capacityPct = effectiveLimit > 0 ? Math.Round((double)b.ProductCount / effectiveLimit * 100.0, 1) : 0;
            var fulfillmentPct = b.TotalOrdersCount > 0 ? Math.Round((double)b.CompletedOrdersCount / b.TotalOrdersCount * 100.0, 1) : 0;

            sb.AppendLine(string.Join(",",
                Escape(b.BusinessName),
                Escape(b.City),
                Escape(((BusinessType)b.BusinessType).ToString()),
                Escape(((BusinessStatus)b.Status).ToString()),
                Escape(b.SubscriptionPlanName ?? "None"),
                Escape(b.SubscriptionStatus),
                b.SubscriptionDaysRemaining,
                b.ProductCount,
                b.LiveProductCount,
                b.ArProductCount,
                effectiveLimit,
                $"{capacityPct}%",
                b.TotalOrdersCount,
                b.CompletedOrdersCount,
                $"{fulfillmentPct}%",
                b.TotalScans,
                b.TotalViews,
                Escape(b.OwnerName ?? "Owner"),
                Escape(b.OwnerMobile),
                b.CreatedAt.ToString("yyyy-MM-dd")
            ));
        }

        return System.Text.Encoding.UTF8.GetBytes(sb.ToString());
    }
}
