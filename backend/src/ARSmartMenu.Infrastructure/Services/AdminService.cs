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

        var businessIds = businesses.Select(b => b.Id).ToList();

        // 1. Grouped product counts (total, live on menu, and with 3D AR model)
        var productStats = await _db.Products
            .AsNoTracking()
            .Where(p => businessIds.Contains(p.BusinessId))
            .GroupBy(p => p.BusinessId)
            .Select(g => new
            {
                BusinessId = g.Key,
                Total = g.Count(),
                Live = g.Count(p => p.Status == ProductStatus.Live),
                WithAr = g.Count(p => p.Model3d != null)
            })
            .ToDictionaryAsync(x => x.BusinessId, ct);

        // 2. Grouped table order stats (counting distinct dining orders where Round <= 1; sales kept 0 for super-admin privacy)
        var orderStats = await _db.TableOrders
            .AsNoTracking()
            .Where(o => businessIds.Contains(o.BusinessId) && o.Round <= 1)
            .GroupBy(o => o.BusinessId)
            .Select(g => new
            {
                BusinessId = g.Key,
                TotalOrders = g.Count(),
                CompletedOrders = g.Count(o => o.Status == "COMPLETED" || o.Status == "PAID" || o.Status == "SETTLED"),
                CompletedSalesPaise = 0L
            })
            .ToDictionaryAsync(x => x.BusinessId, ct);

        // 3. Grouped AR scans and 3D views
        var scanStats = await _db.ArScanEvents
            .AsNoTracking()
            .Where(e => businessIds.Contains(e.BusinessId))
            .GroupBy(e => e.BusinessId)
            .Select(g => new { BusinessId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.BusinessId, x => x.Count, ct);

        var viewStats = await _db.ArViewEvents
            .AsNoTracking()
            .Where(e => businessIds.Contains(e.BusinessId))
            .GroupBy(e => e.BusinessId)
            .Select(g => new { BusinessId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.BusinessId, x => x.Count, ct);

        // 4. Grouped customer reviews and ratings
        var feedbackStats = await _db.TableOrders
            .AsNoTracking()
            .Where(o => businessIds.Contains(o.BusinessId) && o.Rating.HasValue && o.Rating.Value > 0)
            .GroupBy(o => o.BusinessId)
            .Select(g => new
            {
                BusinessId = g.Key,
                Count = g.Count(),
                AvgRating = Math.Round(g.Average(o => (double)o.Rating!.Value), 1)
            })
            .ToDictionaryAsync(x => x.BusinessId, ct);

        var now = DateTime.UtcNow;
        var items = businesses.Select(b =>
        {
            var activeSub = b.Subscriptions
                .Where(s => s.Status == SubscriptionStatus.Active && s.EndsAt > now)
                .OrderByDescending(s => s.EndsAt)
                .FirstOrDefault();

            var latestSub = activeSub ?? b.Subscriptions
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

            var pStat = productStats.GetValueOrDefault(b.Id);
            var oStat = orderStats.GetValueOrDefault(b.Id);
            var scans = scanStats.GetValueOrDefault(b.Id, 0);
            var views = viewStats.GetValueOrDefault(b.Id, 0);
            var fStat = feedbackStats.GetValueOrDefault(b.Id);

            return new AdminBusinessListItemDto(
                b.Id,
                b.BusinessName,
                b.BusinessType,
                b.City,
                b.Status,
                b.Owner.MobileNumber,
                b.Owner.FullName,
                b.Owner.KycStatus,
                pStat?.Total ?? 0,
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
                hasUsedTrial,
                b.CustomDishLimit,
                b.CustomDishLimit.HasValue && b.CustomDishLimit.Value > 0 ? b.CustomDishLimit.Value : (latestSub?.Plan?.MaxProducts ?? 50),
                b.ArViewEnabled,
                b.ArPerViewChargePaise,
                b.ArViewCredits,
                b.ArViewsUsed,
                pStat?.Live ?? 0,
                pStat?.WithAr ?? 0,
                oStat?.TotalOrders ?? 0,
                oStat?.CompletedOrders ?? 0,
                oStat?.CompletedSalesPaise ?? 0,
                scans,
                views,
                fStat != null ? fStat.AvgRating : (double?)null,
                fStat?.Count ?? 0);
        }).ToList();

        return new PagedResult<AdminBusinessListItemDto>
        {
            Items = items,
            Total = total,
            Page = pagination.Page,
            Limit = pagination.Limit
        };
    }

    public async Task<AdminBusinessListItemDto?> GetBusinessByIdAsync(Guid businessId, CancellationToken ct = default)
    {
        var b = await _db.Businesses
            .AsNoTracking()
            .Include(b => b.Owner)
            .Include(b => b.Products)
            .Include(b => b.Subscriptions)
                .ThenInclude(s => s.Plan)
            .FirstOrDefaultAsync(b => b.Id == businessId, ct);

        if (b == null) return null;
        return await MapAdminBusinessDetailedAsync(b, ct);
    }

    public async Task<AdminBusinessListItemDto> UpdateBusinessAsync(
        Guid adminUserId,
        Guid businessId,
        AdminUpdateBusinessRequest request,
        CancellationToken ct = default)
    {
        var b = await _db.Businesses
            .Include(b => b.Owner)
            .Include(b => b.Products)
            .Include(b => b.Subscriptions)
                .ThenInclude(s => s.Plan)
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

        return await MapAdminBusinessDetailedAsync(b, ct);
    }

    public async Task<AdminBusinessListItemDto> UpdateBusinessSettingsAsync(
        Guid businessId,
        UpdateBusinessSettingsRequest request,
        CancellationToken ct = default)
    {
        var business = await _db.Businesses
            .Include(b => b.Owner)
            .Include(b => b.Subscriptions)
                .ThenInclude(s => s.Plan)
            .FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (request.CustomDishLimit.HasValue)
        {
            business.CustomDishLimit = request.CustomDishLimit.Value > 0 ? request.CustomDishLimit.Value : null;
        }

        if (request.ArViewEnabled.HasValue)
        {
            business.ArViewEnabled = request.ArViewEnabled.Value;
        }

        if (request.ArPerViewChargePaise.HasValue)
        {
            business.ArPerViewChargePaise = Math.Max(0, request.ArPerViewChargePaise.Value);
        }

        if (request.ArViewCredits.HasValue)
        {
            business.ArViewCredits = Math.Max(0, request.ArViewCredits.Value);
        }

        business.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return await MapAdminBusinessDetailedAsync(business, ct);
    }

    private async Task<AdminBusinessListItemDto> MapAdminBusinessDetailedAsync(Business b, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
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
        var effectiveDishLimit = b.CustomDishLimit.HasValue && b.CustomDishLimit.Value > 0
            ? b.CustomDishLimit.Value
            : (latestSub?.Plan?.MaxProducts ?? 50);

        var productCount = await _db.Products.CountAsync(p => p.BusinessId == b.Id, ct);
        var liveProductCount = await _db.Products.CountAsync(p => p.BusinessId == b.Id && p.Status == ProductStatus.Live, ct);
        var arProductCount = await _db.Products.CountAsync(p => p.BusinessId == b.Id && p.Model3d != null, ct);

        var totalOrdersCount = await _db.TableOrders.CountAsync(o => o.BusinessId == b.Id && o.Round <= 1, ct);
        var completedOrdersQuery = _db.TableOrders.Where(o => o.BusinessId == b.Id && o.Round <= 1 && (o.Status == "COMPLETED" || o.Status == "PAID" || o.Status == "SETTLED"));
        var completedOrdersCount = await completedOrdersQuery.CountAsync(ct);
        var completedSalesPaise = 0L;

        var scans = await _db.ArScanEvents.CountAsync(e => e.BusinessId == b.Id, ct);
        var views = await _db.ArViewEvents.CountAsync(e => e.BusinessId == b.Id, ct);

        var feedbackQuery = _db.TableOrders.Where(o => o.BusinessId == b.Id && o.Rating.HasValue && o.Rating.Value > 0);
        var feedbackCount = await feedbackQuery.CountAsync(ct);
        var avgRating = feedbackCount > 0 ? Math.Round(await feedbackQuery.AverageAsync(o => (double)o.Rating!.Value, ct), 1) : (double?)null;

        return new AdminBusinessListItemDto(
            b.Id,
            b.BusinessName,
            b.BusinessType,
            b.City,
            b.Status,
            b.Owner?.MobileNumber ?? "",
            b.Owner?.FullName,
            b.Owner?.KycStatus ?? KycStatus.Pending,
            productCount,
            b.CreatedAt,
            b.FullAddress,
            b.FssaiNumber,
            b.GstNumber,
            b.UpiId,
            b.BankAccountNumber,
            b.BankIfsc,
            b.BankPennyVerified,
            b.Owner?.WhatsAppNumber,
            b.Owner?.AadhaarLast4,
            b.Owner?.PanNumber,
            b.RejectionReason,
            b.AdminNotes,
            latestSub?.Plan?.Name,
            subStatus,
            latestSub?.StartsAt,
            latestSub?.EndsAt,
            daysRem,
            hasUsedTrial,
            b.CustomDishLimit,
            effectiveDishLimit,
            b.ArViewEnabled,
            b.ArPerViewChargePaise,
            b.ArViewCredits,
            b.ArViewsUsed,
            liveProductCount,
            arProductCount,
            totalOrdersCount,
            completedOrdersCount,
            completedSalesPaise,
            scans,
            views,
            avgRating,
            feedbackCount);
    }

    private static AdminBusinessListItemDto MapAdminBusiness(Business b)
    {
        var now = DateTime.UtcNow;
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
            b.Owner?.MobileNumber ?? "",
            b.Owner?.FullName,
            b.Owner?.KycStatus ?? KycStatus.Pending,
            b.Products?.Count ?? 0,
            b.CreatedAt,
            b.FullAddress,
            b.FssaiNumber,
            b.GstNumber,
            b.UpiId,
            b.BankAccountNumber,
            b.BankIfsc,
            b.BankPennyVerified,
            b.Owner?.WhatsAppNumber,
            b.Owner?.AadhaarLast4,
            b.Owner?.PanNumber,
            b.RejectionReason,
            b.AdminNotes,
            latestSub?.Plan?.Name,
            subStatus,
            latestSub?.StartsAt,
            latestSub?.EndsAt,
            daysRem,
            hasUsedTrial,
            b.CustomDishLimit,
            b.CustomDishLimit.HasValue && b.CustomDishLimit.Value > 0 ? b.CustomDishLimit.Value : (latestSub?.Plan?.MaxProducts ?? 50),
            b.ArViewEnabled,
            b.ArPerViewChargePaise,
            b.ArViewCredits,
            b.ArViewsUsed);
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
                    });
                }
            }
        }

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

    public async Task<AdminNotificationsResponse> GetNotificationsAsync(CancellationToken ct = default)
    {
        var notifications = new List<AdminNotificationDto>();

        // 1. Pending Businesses
        var pendingBusinesses = await _db.Businesses
            .AsNoTracking()
            .Where(b => b.Status == BusinessStatus.PendingApproval)
            .OrderByDescending(b => b.CreatedAt)
            .Take(30)
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

        // 2. Pending Hero Products / Dishes for Review
        var reviewProducts = await _db.Products
            .AsNoTracking()
            .Include(p => p.Business)
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .Where(p => p.Status != ProductStatus.Draft && p.Status != ProductStatus.Live && p.Status != ProductStatus.Rejected)
            .Where(p => p.Photos.Count >= 4
                || p.Status == ProductStatus.Submitted
                || p.Status == ProductStatus.Review
                || p.Status == ProductStatus.Processing)
            .OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt)
            .Take(30)
            .ToListAsync(ct);

        foreach (var p in reviewProducts)
        {
            var bName = p.Business?.BusinessName ?? "Restaurant";
            var photo = p.Photos.FirstOrDefault(x => x.AngleType == PhotoAngleType.Front)?.PhotoUrl
                ?? p.Photos.FirstOrDefault()?.PhotoUrl;

            notifications.Add(new AdminNotificationDto(
                p.Id,
                $"New Dish for Review: {p.Name}",
                $"'{p.Name}' from {bName} is waiting for 3D AR review and approval.",
                "product_review",
                p.BusinessId,
                bName,
                p.Id,
                p.Name,
                photo,
                p.UpdatedAt ?? p.CreatedAt,
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

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        var owner = await _db.Users.FirstOrDefaultAsync(u => u.Id == business.OwnerId, ct)
            ?? throw new NotFoundException("Owner account not found for this business.");

        owner.PasswordHash = PasswordHelper.HashPassword(newPin.Trim());
        owner.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    public async Task<AdminOperationsSummaryDto> GetOperationsSummaryAsync(CancellationToken ct = default)
    {
        var totalRestaurants = await _db.Businesses.CountAsync(ct);
        var totalDishesListed = await _db.Products.CountAsync(ct);
        var totalLiveDishes = await _db.Products.CountAsync(p => p.Status == ProductStatus.Live, ct);
        var totalArDishes = await _db.Products.CountAsync(p => p.Model3d != null, ct);

        var totalOrdersPlaced = await _db.TableOrders.CountAsync(o => o.Round <= 1, ct);
        var completedOrdersQuery = _db.TableOrders.Where(o => o.Round <= 1 && (o.Status == "COMPLETED" || o.Status == "PAID" || o.Status == "SETTLED"));
        var totalOrdersCompleted = await completedOrdersQuery.CountAsync(ct);
        var totalCompletedSalesPaise = 0L; // Zeroed out to protect private restaurant revenue

        var totalScans = await _db.ArScanEvents.CountAsync(ct);
        var totalViews = await _db.ArViewEvents.CountAsync(ct);

        var feedbackQuery = _db.TableOrders.Where(o => o.Rating.HasValue && o.Rating.Value > 0);
        var totalReviews = await feedbackQuery.CountAsync(ct);
        var averageRating = totalReviews > 0 ? Math.Round(await feedbackQuery.AverageAsync(o => (double)o.Rating!.Value, ct), 1) : (double?)null;

        return new AdminOperationsSummaryDto(
            totalRestaurants,
            totalDishesListed,
            totalLiveDishes,
            totalArDishes,
            totalOrdersPlaced,
            totalOrdersCompleted,
            totalCompletedSalesPaise,
            totalScans,
            totalViews,
            averageRating,
            totalReviews);
    }

    public async Task<byte[]> ExportOperationsCsvAsync(CancellationToken ct = default)
    {
        var businesses = await _db.Businesses
            .AsNoTracking()
            .Include(b => b.Owner)
            .Include(b => b.Subscriptions)
                .ThenInclude(s => s.Plan)
            .OrderByDescending(b => b.CreatedAt)
            .ToListAsync(ct);

        var businessIds = businesses.Select(b => b.Id).ToList();

        var productStats = await _db.Products
            .AsNoTracking()
            .Where(p => businessIds.Contains(p.BusinessId))
            .GroupBy(p => p.BusinessId)
            .Select(g => new
            {
                BusinessId = g.Key,
                Total = g.Count(),
                Live = g.Count(p => p.Status == ProductStatus.Live),
                WithAr = g.Count(p => p.Model3d != null)
            })
            .ToDictionaryAsync(x => x.BusinessId, ct);

        var orderStats = await _db.TableOrders
            .AsNoTracking()
            .Where(o => businessIds.Contains(o.BusinessId) && o.Round <= 1)
            .GroupBy(o => o.BusinessId)
            .Select(g => new
            {
                BusinessId = g.Key,
                TotalOrders = g.Count(),
                CompletedOrders = g.Count(o => o.Status == "COMPLETED" || o.Status == "PAID" || o.Status == "SETTLED")
            })
            .ToDictionaryAsync(x => x.BusinessId, ct);

        var scanStats = await _db.ArScanEvents
            .AsNoTracking()
            .Where(e => businessIds.Contains(e.BusinessId))
            .GroupBy(e => e.BusinessId)
            .Select(g => new { BusinessId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.BusinessId, x => x.Count, ct);

        var viewStats = await _db.ArViewEvents
            .AsNoTracking()
            .Where(e => businessIds.Contains(e.BusinessId))
            .GroupBy(e => e.BusinessId)
            .Select(g => new { BusinessId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.BusinessId, x => x.Count, ct);

        var now = DateTime.UtcNow;
        var sb = new System.Text.StringBuilder();

        // UTF-8 BOM so Excel opens it with proper formatting
        sb.Append('\uFEFF');
        sb.AppendLine("Restaurant Name,City,Business Type,Status,Subscription Plan,Subscription Status,Days Remaining,Total Dishes Listed,Live Dishes,3D AR Dishes,Dish Limit,Capacity Used %,Total Orders Placed,Completed Orders,Fulfillment %,Total Scans,Total AR Views,Owner Name,Owner Mobile,Registered Date");

        foreach (var b in businesses)
        {
            var activeSub = b.Subscriptions
                .Where(s => s.Status == SubscriptionStatus.Active && s.EndsAt > now)
                .OrderByDescending(s => s.EndsAt)
                .FirstOrDefault();
            var latestSub = activeSub ?? b.Subscriptions.OrderByDescending(s => s.EndsAt).FirstOrDefault();
            var isSubActive = latestSub != null && latestSub.Status == SubscriptionStatus.Active && latestSub.EndsAt > now;
            var daysRem = isSubActive ? Math.Max(0, (int)Math.Ceiling((latestSub!.EndsAt - now).TotalDays)) : 0;
            var subStatus = latestSub == null
                ? "None"
                : (isSubActive
                    ? (latestSub.Plan?.Slug == "trial-7-days" ? "Trial" : "Active")
                    : "Expired");

            var pStat = productStats.GetValueOrDefault(b.Id);
            var oStat = orderStats.GetValueOrDefault(b.Id);
            var scans = scanStats.GetValueOrDefault(b.Id, 0);
            var views = viewStats.GetValueOrDefault(b.Id, 0);

            var totalDishes = pStat?.Total ?? 0;
            var liveDishes = pStat?.Live ?? 0;
            var arDishes = pStat?.WithAr ?? 0;

            var effectiveLimit = b.CustomDishLimit.HasValue && b.CustomDishLimit.Value > 0
                ? b.CustomDishLimit.Value
                : (latestSub?.Plan?.MaxProducts ?? 50);

            var capacityPct = effectiveLimit > 0 ? Math.Round((double)totalDishes / effectiveLimit * 100.0, 1) : 0;

            var totalOrders = oStat?.TotalOrders ?? 0;
            var completedOrders = oStat?.CompletedOrders ?? 0;
            var fulfillmentPct = totalOrders > 0 ? Math.Round((double)completedOrders / totalOrders * 100.0, 1) : 0;

            string Escape(string? val) => $"\"{ (val ?? "").Replace("\"", "\"\"") }\"";

            sb.AppendLine(string.Join(",",
                Escape(b.BusinessName),
                Escape(b.City),
                Escape(b.BusinessType.ToString()),
                Escape(b.Status.ToString()),
                Escape(latestSub?.Plan?.Name ?? "None"),
                Escape(subStatus),
                daysRem,
                totalDishes,
                liveDishes,
                arDishes,
                effectiveLimit,
                $"{capacityPct}%",
                totalOrders,
                completedOrders,
                $"{fulfillmentPct}%",
                scans,
                views,
                Escape(b.Owner.FullName ?? "Owner"),
                Escape(b.Owner.MobileNumber),
                b.CreatedAt.ToString("yyyy-MM-dd")
            ));
        }

        return System.Text.Encoding.UTF8.GetBytes(sb.ToString());
    }
}
