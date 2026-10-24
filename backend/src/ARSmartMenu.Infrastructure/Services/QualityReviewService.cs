using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class QualityReviewService : IQualityReviewService
{
    private const string DevGlbUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.glb";
    private const string DevUsdzUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.usdz";

    private readonly AppDbContext _db;
    private readonly IStorageService _storage;
    private readonly IQrCodeService _qrCodes;
    private readonly MediaUrlResolver _mediaUrls;
    private readonly Microsoft.Extensions.Configuration.IConfiguration _config;
    private readonly INotificationService _notifications;

    public QualityReviewService(
        AppDbContext db,
        IStorageService storage,
        IQrCodeService qrCodes,
        MediaUrlResolver mediaUrls,
        Microsoft.Extensions.Configuration.IConfiguration config,
        INotificationService notifications)
    {
        _db = db;
        _storage = storage;
        _qrCodes = qrCodes;
        _mediaUrls = mediaUrls;
        _config = config;
        _notifications = notifications;
    }

    public async Task<ApprovalReviewDto?> GetReviewAsync(Guid jobId, CancellationToken ct = default)
    {
        var review = await _db.ApprovalReviews
            .FirstOrDefaultAsync(r => r.ProcessingJobId == jobId, ct);
        return review is null ? null : ToDto(review);
    }

    public async Task<ApprovalReviewDto> SubmitReviewAsync(
        Guid jobId,
        SubmitReviewRequest request,
        CancellationToken ct = default)
    {
        var job = await _db.ProcessingJobs
            .Include(j => j.Review)
            .Include(j => j.Product)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct)
            ?? throw new InvalidOperationException("Processing job not found");

        if (request.Decision == ReviewDecision.Rejected
            && string.IsNullOrWhiteSpace(request.RejectionReason))
        {
            throw new ValidationException("Rejection reason is required.");
        }

        var review = job.Review ?? new ApprovalReview { ProcessingJobId = jobId };
        review.Decision = request.Decision;
        review.RejectionReason = request.Decision == ReviewDecision.Rejected
            ? FormatOwnerRejectionMessage(request.RejectionReason!, request.ImprovementNotes)
            : request.RejectionReason;
        review.ModelQualityScore = request.ModelQualityScore;
        review.TextureQualityScore = request.TextureQualityScore;
        review.ScaleAccuracyScore = request.ScaleAccuracyScore;
        review.RenderingQualityScore = request.RenderingQualityScore;
        review.InternalNotes = request.InternalNotes;
        review.ReviewerId = request.ReviewerId;
        review.ReviewedAt = DateTime.UtcNow;

        if (job.Review is null)
            _db.ApprovalReviews.Add(review);

        job.Status = request.Decision switch
        {
            ReviewDecision.Approved => ProcessingJobStatus.Approved,
            ReviewDecision.Rejected => ProcessingJobStatus.Rejected,
            ReviewDecision.ReuploadRequested => ProcessingJobStatus.Failed,
            _ => ProcessingJobStatus.Review,
        };
        job.UpdatedAt = DateTime.UtcNow;

        if (job.ProductId.HasValue)
        {
            var product = await _db.Products.FirstOrDefaultAsync(p => p.Id == job.ProductId.Value, ct);
            if (product is not null)
            {
                product.Status = request.Decision switch
                {
                    ReviewDecision.Approved => ProductStatus.Review,
                    ReviewDecision.Rejected => ProductStatus.Rejected,
                    ReviewDecision.ReuploadRequested => ProductStatus.Submitted,
                    _ => product.Status,
                };
                product.RejectionReason = request.Decision switch
                {
                    ReviewDecision.Rejected => FormatOwnerRejectionMessage(
                        request.RejectionReason!, request.ImprovementNotes),
                    ReviewDecision.Approved => null,
                    _ => product.RejectionReason,
                };
                product.UpdatedAt = DateTime.UtcNow;
            }
        }

        await _db.SaveChangesAsync(ct);
        return ToDto(review);
    }

    /// <summary>
    /// Live publish: approved model → product Model3d → QR → WebAR live.
    /// </summary>
    public async Task<ModelAssetDto?> PublishApprovedAssetAsync(Guid jobId, CancellationToken ct = default)
    {
        var job = await _db.ProcessingJobs
            .Include(j => j.ModelAsset)
            .Include(j => j.Booking)
            .Include(j => j.Review)
            .Include(j => j.Product!)
                .ThenInclude(p => p.Model3d)
            .Include(j => j.Product!)
                .ThenInclude(p => p.Business)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct);

        if (job?.Review?.Decision != ReviewDecision.Approved || job.ModelAsset is null)
            return null;

        var asset = job.ModelAsset;
        var webArBase = _config["WebAr:BaseUrl"] ?? "http://localhost:5173/dish";

        asset.GlbCdnUrl = !string.IsNullOrWhiteSpace(asset.GlbStorageKey)
            ? _mediaUrls.Resolve(asset.GlbStorageKey)
            : DevGlbUrl;
        asset.UsdzCdnUrl = DevUsdzUrl;
        asset.ThumbnailCdnUrl = asset.ThumbnailStorageKey is not null
            ? _mediaUrls.Resolve(asset.ThumbnailStorageKey)
            : null;

        var embedBase = _config["Embed:BaseUrl"] ?? webArBase.TrimEnd('/');
        asset.EmbedUrl = $"{embedBase.TrimEnd('/')}/{asset.ProductSlug}";
        asset.IsPublished = true;
        asset.PublishedAt ??= DateTime.UtcNow;
        asset.UpdatedAt = DateTime.UtcNow;

        await UpsertEmbedLinkAsync(asset, ct);

        if (job.Product is not null)
        {
            var product = job.Product;
            product.Status = ProductStatus.Live;
            product.UpdatedAt = DateTime.UtcNow;

            if (product.Model3d is null)
            {
                product.Model3d = new Model3d { ProductId = product.Id };
                _db.Models3d.Add(product.Model3d);
            }

            product.Model3d.GlbUrl = asset.GlbCdnUrl;
            product.Model3d.UsdzUrl = asset.UsdzCdnUrl;
            product.Model3d.GlbS3Key = asset.GlbStorageKey;
            product.Model3d.UsdzS3Key = asset.UsdzStorageKey;
            product.Model3d.GlbSizeBytes = (int?)asset.GlbSizeBytes;
            product.Model3d.ProcessingStatus = ModelProcessingStatus.Approved;
            product.Model3d.ProcessingCompletedAt = DateTime.UtcNow;
            product.Model3d.ApprovedAt = DateTime.UtcNow;
            product.Model3d.UpdatedAt = DateTime.UtcNow;

            await EnsureProductQrAsync(product, ct);
        }

        job.Status = ProcessingJobStatus.Approved;
        job.CompletedAt = DateTime.UtcNow;
        job.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        return new ModelAssetDto(
            asset.Id, asset.ProductSlug, asset.ProductName,
            asset.GlbCdnUrl, asset.UsdzCdnUrl, asset.ThumbnailCdnUrl,
            asset.GlbSizeBytes, asset.IsPublished, asset.EmbedUrl);
    }

    private async Task UpsertEmbedLinkAsync(ModelAsset asset, CancellationToken ct)
    {
        var existing = await _db.EmbedLinks
            .FirstOrDefaultAsync(
                e => e.ModelAssetId == asset.Id || e.Slug == asset.ProductSlug,
                ct);

        if (existing is not null)
        {
            existing.BusinessId = asset.BusinessId;
            existing.ModelAssetId = asset.Id;
            existing.Slug = asset.ProductSlug;
            existing.PublicUrl = asset.EmbedUrl!;
            existing.OrderDeepLink ??= $"https://order.example.com/{asset.ProductSlug}?ref=ar";
            existing.IsActive = true;
            existing.UpdatedAt = DateTime.UtcNow;
            return;
        }

        _db.EmbedLinks.Add(new EmbedLink
        {
            BusinessId = asset.BusinessId,
            ModelAssetId = asset.Id,
            Slug = asset.ProductSlug,
            PublicUrl = asset.EmbedUrl!,
            OrderDeepLink = $"https://order.example.com/{asset.ProductSlug}?ref=ar",
            IsActive = true,
        });
    }

    private async Task EnsureProductQrAsync(Product product, CancellationToken ct)
    {
        var hasQr = await _db.QrCodes.AnyAsync(
            q => q.ProductId == product.Id && q.IsActive, ct);

        if (!hasQr)
        {
            await _qrCodes.GenerateForProductAsync(product.BusinessId, product.Id, ct);
            return;
        }

        var qr = await _db.QrCodes
            .FirstAsync(q => q.ProductId == product.Id && q.IsActive, ct);
        qr.WebUrl = _qrCodes.BuildDishWebUrl(qr.Slug);
        qr.UpdatedAt = DateTime.UtcNow;
    }

    private static ApprovalReviewDto ToDto(ApprovalReview r) => new(
        r.Id, r.ProcessingJobId, r.Decision, r.RejectionReason,
        r.ModelQualityScore, r.TextureQualityScore, r.ScaleAccuracyScore,
        r.RenderingQualityScore, r.ReviewedAt);

    internal static string FormatOwnerRejectionMessage(string reason, string? improvementNotes)
    {
        var trimmedReason = reason.Trim();
        var trimmedImprovement = improvementNotes?.Trim();
        if (string.IsNullOrEmpty(trimmedImprovement))
            return trimmedReason;
        return $"{trimmedReason}\n\nWhat to improve:\n{trimmedImprovement}";
    }
}
