using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Jobs;
using ARSmartMenu.Infrastructure.Persistence;
using Hangfire;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

/// <summary>
/// Queues 3D processing when an owner submits a product via photo upload.
/// </summary>
public class ProductProcessingService : IProductProcessingService
{
    private readonly AppDbContext _db;

    public ProductProcessingService(AppDbContext db) => _db = db;

    public async Task EnqueueFromProductPhotosAsync(Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Business)
            .Include(p => p.Model3d)
            .Include(p => p.Photos)
            .FirstOrDefaultAsync(p => p.Id == productId, ct)
            ?? throw new InvalidOperationException("Product not found.");

        if (product.Photos.Count < 4)
            throw new InvalidOperationException("Product needs 4 photos before processing.");

        var required = new[] { PhotoAngleType.Front, PhotoAngleType.Top, PhotoAngleType.Left, PhotoAngleType.Right };
        var angles = product.Photos.Select(p => p.AngleType).ToHashSet();
        if (!required.All(angles.Contains))
            throw new InvalidOperationException("Product needs front, top, left, and right photos.");

        var hasActiveJob = await _db.ProcessingJobs.AnyAsync(
            j => j.ProductId == productId
                 && j.Status != ProcessingJobStatus.Failed
                 && j.Status != ProcessingJobStatus.Rejected,
            ct);

        if (hasActiveJob) return;

        var booking = new ShootBooking
        {
            BusinessId = product.BusinessId,
            BusinessName = product.Business.BusinessName,
            Category = MapCategory(product.Business.BusinessType),
            LocationAddress = string.IsNullOrWhiteSpace(product.Business.FullAddress)
                ? product.Business.City
                : product.Business.FullAddress,
            City = product.Business.City,
            ScheduledAt = DateTime.UtcNow,
            Status = BookingStatus.Completed,
            Notes = $"Owner photo pipeline for product {product.Id}",
        };

        _db.ShootBookings.Add(booking);
        await _db.SaveChangesAsync(ct);

        product.Status = ProductStatus.Processing;
        product.UpdatedAt = DateTime.UtcNow;

        if (product.Model3d is null)
        {
            _db.Models3d.Add(new Model3d
            {
                ProductId = product.Id,
                ProcessingStatus = ModelProcessingStatus.Processing,
                ProcessingStartedAt = DateTime.UtcNow,
            });
        }
        else
        {
            product.Model3d.ProcessingStatus = ModelProcessingStatus.Processing;
            product.Model3d.ProcessingStartedAt = DateTime.UtcNow;
            product.Model3d.UpdatedAt = DateTime.UtcNow;
        }

        var job = new ProcessingJob
        {
            BookingId = booking.Id,
            ProductId = product.Id,
            Source = ExternalToolSource.ManualUpload,
            Status = ProcessingJobStatus.Queued,
            EstimatedCompletionAt = DateTime.UtcNow.AddMinutes(3),
        };

        _db.ProcessingJobs.Add(job);
        await _db.SaveChangesAsync(ct);

        BackgroundJob.Enqueue<PipelineJobRunner>(runner => runner.RunProcessingPipelineAsync(job.Id));
    }

    private static BusinessCategory MapCategory(BusinessType type) => type switch
    {
        BusinessType.Cafe => BusinessCategory.Cafe,
        BusinessType.Bakery => BusinessCategory.Bakery,
        BusinessType.Clothing => BusinessCategory.Clothing,
        BusinessType.Furniture => BusinessCategory.Furniture,
        _ => BusinessCategory.Restaurant,
    };
}
