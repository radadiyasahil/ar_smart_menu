using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Services;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Jobs;

/// <summary>
/// Hangfire background jobs for the media → 3D → optimization → review pipeline.
/// Owner photos are converted to a textured GLB for WebAR.
/// </summary>
public class PipelineJobRunner
{
    private readonly AppDbContext _db;
    private readonly IPhotoModelGenerationService _photoModels;
    private readonly ILogger<PipelineJobRunner> _logger;

    public PipelineJobRunner(
        AppDbContext db,
        IPhotoModelGenerationService photoModels,
        ILogger<PipelineJobRunner> logger)
    {
        _db = db;
        _photoModels = photoModels;
        _logger = logger;
    }

    public async Task StartProcessingForBookingAsync(Guid bookingId)
    {
        var uploads = await _db.MediaUploads
            .Where(u => u.BookingId == bookingId && u.Status == MediaUploadStatus.Completed)
            .ToListAsync();

        foreach (var upload in uploads)
        {
            await EnqueueProcessingJobAsync(upload.Id, ExternalToolSource.ManualUpload);
        }
    }

    public async Task EnqueueProcessingJobAsync(Guid mediaUploadId, ExternalToolSource source)
    {
        var upload = await _db.MediaUploads.Include(u => u.Booking)
            .FirstOrDefaultAsync(u => u.Id == mediaUploadId);
        if (upload is null) return;

        var existing = await _db.ProcessingJobs
            .AnyAsync(j => j.MediaUploadId == mediaUploadId && j.Status != ProcessingJobStatus.Failed);
        if (existing) return;

        var job = new ProcessingJob
        {
            BookingId = upload.BookingId,
            MediaUploadId = mediaUploadId,
            Source = source,
            Status = ProcessingJobStatus.Queued,
            EstimatedCompletionAt = DateTime.UtcNow.AddHours(2),
        };

        _db.ProcessingJobs.Add(job);
        await _db.SaveChangesAsync();

        await RunProcessingPipelineAsync(job.Id);
    }

    /// <summary>
    /// Simulates: raw media → external tool → Blender optimization → review queue.
    /// Idempotent — safe for Hangfire retries and admin "retry pipeline".
    /// </summary>
    public async Task RunProcessingPipelineAsync(Guid jobId)
    {
        var job = await _db.ProcessingJobs
            .Include(j => j.Booking)
            .Include(j => j.MediaUpload)
            .Include(j => j.Product)
            .FirstOrDefaultAsync(j => j.Id == jobId);

        if (job is null) return;

        if (job.Status is ProcessingJobStatus.Review or ProcessingJobStatus.Approved)
            return;

        try
        {
            if (job.Status is ProcessingJobStatus.Queued or ProcessingJobStatus.Failed)
            {
                job.Status = ProcessingJobStatus.Processing;
                job.StartedAt = DateTime.UtcNow;
                job.FailureReason = null;
                AppendLog(job, "Processing started");
            }

            if (job.Status == ProcessingJobStatus.Processing)
            {
                await Task.Delay(300);
                job.Status = ProcessingJobStatus.Optimizing;
                AppendLog(job, "Converting 4 photos into textured 3D GLB for WebAR");
            }

            await EnsureModelAssetAndReviewAsync(job);

            job.Status = ProcessingJobStatus.Review;
            job.UpdatedAt = DateTime.UtcNow;
            AppendLog(job, "Awaiting admin quality review");

            await SetLinkedProductStatusAsync(job, ProductStatus.Review);

            await _db.SaveChangesAsync();

            _logger.LogInformation("Processing job {JobId} ready for review", jobId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Pipeline failed for job {JobId}", jobId);
            job.Status = ProcessingJobStatus.Failed;
            job.FailureReason = ex.Message;
            job.UpdatedAt = DateTime.UtcNow;
            await SetLinkedProductStatusAsync(job, ProductStatus.Submitted);
            AppendLog(job, $"Pipeline failed: {ex.Message}", "Error");
            await _db.SaveChangesAsync();
        }
    }

    /// <summary>Admin helper — finish jobs stuck at Optimizing after a partial pipeline run.</summary>
    public async Task AdvanceStuckJobToReviewAsync(Guid jobId)
    {
        var job = await _db.ProcessingJobs
            .Include(j => j.Booking)
            .Include(j => j.Product)
            .FirstOrDefaultAsync(j => j.Id == jobId)
            ?? throw new InvalidOperationException("Processing job not found.");

        if (job.Status is ProcessingJobStatus.Approved)
            return;

        await EnsureModelAssetAndReviewAsync(job);

        job.Status = ProcessingJobStatus.Review;
        job.FailureReason = null;
        job.UpdatedAt = DateTime.UtcNow;
        AppendLog(job, "Advanced to review queue by admin");

        await SetLinkedProductStatusAsync(job, ProductStatus.Review);
        await _db.SaveChangesAsync();
    }

    public async Task GenerateThumbnailAsync(Guid modelAssetId)
    {
        var asset = await _db.ModelAssets.FindAsync(modelAssetId);
        if (asset is null) return;

        asset.ThumbnailStorageKey = StorageKeyBuilder.Thumbnail(asset.BusinessId, asset.ProductSlug);
        asset.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        _logger.LogInformation("Thumbnail generated for asset {AssetId}", modelAssetId);
    }

    public async Task CleanupTemporaryFilesAsync()
    {
        _logger.LogInformation("Cleanup job: removing expired temporary uploads");
        await Task.CompletedTask;
    }

    private async Task EnsureModelAssetAndReviewAsync(ProcessingJob job)
    {
        var asset = await _db.ModelAssets
            .FirstOrDefaultAsync(m => m.ProcessingJobId == job.Id);

        if (asset is null)
        {
            var productName = job.Product?.Name ?? job.Booking.BusinessName + " Item";
            var slug = await ResolveProductSlugAsync(job);

            asset = new ModelAsset
            {
                ProcessingJobId = job.Id,
                BusinessId = job.Booking.BusinessId,
                ProductSlug = slug,
                ProductName = productName,
                GlbStorageKey = StorageKeyBuilder.Glb(job.Booking.BusinessId, slug),
                UsdzStorageKey = StorageKeyBuilder.Usdz(job.Booking.BusinessId, slug),
                ThumbnailStorageKey = StorageKeyBuilder.Thumbnail(job.Booking.BusinessId, slug),
            };

            _db.ModelAssets.Add(asset);
            await _db.SaveChangesAsync();
        }

        if (job.ProductId.HasValue)
        {
            var generated = await _photoModels.TryGenerateFromProductAsync(
                job.ProductId.Value,
                job.Booking.BusinessId,
                asset.ProductSlug);

            if (generated is not null)
            {
                asset.GlbStorageKey = generated.GlbStorageKey;
                asset.GlbCdnUrl = generated.GlbPublicUrl;
                asset.GlbSizeBytes = generated.GlbSizeBytes;
                asset.ThumbnailStorageKey = generated.ThumbnailStorageKey;
                asset.ThumbnailCdnUrl = generated.ThumbnailPublicUrl;
                asset.UpdatedAt = DateTime.UtcNow;

                AppendLog(job,
                    $"Photo-to-3D complete — GLB {generated.GlbSizeBytes / 1024}KB with front/top/left/right textures");
            }
            else
            {
                AppendLog(job,
                    "Photo-to-3D skipped — ensure all 4 photos are uploaded and saved on disk",
                    "Warning");
            }
        }

        var hasReview = await _db.ApprovalReviews.AnyAsync(r => r.ProcessingJobId == job.Id);
        if (!hasReview)
        {
            _db.ApprovalReviews.Add(new ApprovalReview
            {
                ProcessingJobId = job.Id,
                Decision = ReviewDecision.Pending,
            });
        }
    }

    private async Task<string> ResolveProductSlugAsync(ProcessingJob job)
    {
        if (!job.ProductId.HasValue)
            return $"product-{job.Id:N}"[..12];

        var product = job.Product ?? await _db.Products
            .Include(p => p.QrCodes.Where(q => q.IsActive))
            .FirstOrDefaultAsync(p => p.Id == job.ProductId.Value);

        var qrSlug = product?.QrCodes.FirstOrDefault()?.Slug;
        if (!string.IsNullOrWhiteSpace(qrSlug))
            return qrSlug;

        var slugBase = QrCodeService.Slugify(product?.Name ?? "product");
        return $"{slugBase}-{job.Id.ToString("N")[..4]}";
    }

    private async Task SetLinkedProductStatusAsync(ProcessingJob job, ProductStatus status)
    {
        if (!job.ProductId.HasValue) return;

        var product = await _db.Products
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.Id == job.ProductId.Value);

        if (product is null) return;

        product.Status = status;
        product.UpdatedAt = DateTime.UtcNow;

        if (product.Model3d is not null)
        {
            product.Model3d.ProcessingStatus = status switch
            {
                ProductStatus.Processing => ModelProcessingStatus.Processing,
                ProductStatus.Review => ModelProcessingStatus.Done,
                ProductStatus.Submitted => ModelProcessingStatus.Failed,
                _ => product.Model3d.ProcessingStatus,
            };
            product.Model3d.UpdatedAt = DateTime.UtcNow;
        }
    }

    private void AppendLog(ProcessingJob job, string message, string level = "Info")
    {
        _db.ProcessingLogs.Add(new ProcessingLog
        {
            ProcessingJobId = job.Id,
            Message = message,
            Level = level,
        });
    }
}
