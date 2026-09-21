using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

/// <summary>
/// Placeholder ingestion for Polycam and Luma AI exports.
/// Downloads export URL → stores in /exports/ → enqueues processing pipeline.
/// </summary>
public class ExternalToolIngestionService : IExternalToolIngestionService
{
    private readonly AppDbContext _db;
    private readonly ProcessingQueueService _queue;

    public ExternalToolIngestionService(AppDbContext db, ProcessingQueueService queue)
    {
        _db = db;
        _queue = queue;
    }

    public async Task<ProcessingJobDto> IngestPolycamExportAsync(
        PolycamIngestRequest request,
        CancellationToken ct = default)
    {
        // MVP: log export URL and enqueue — real implementation downloads GLB from Polycam
        var booking = await _db.ShootBookings.FindAsync([request.BookingId], ct)
            ?? throw new InvalidOperationException("Booking not found");

        var upload = new Domain.Entities.MediaUpload
        {
            BookingId = request.BookingId,
            FileName = $"{request.ProductSlug}-polycam.glb",
            ContentType = "model/gltf-binary",
            FileSizeBytes = 0,
            StorageKey = $"exports/{booking.BusinessId}/{request.ProductSlug}-polycam.glb",
            StorageUrl = request.ExportUrl,
            Status = Domain.Enums.MediaUploadStatus.Completed,
            UploadProgressPercent = 100,
        };

        _db.MediaUploads.Add(upload);
        await _db.SaveChangesAsync(ct);

        return await _queue.EnqueueFromUploadAsync(upload.Id, ExternalToolSource.Polycam, ct);
    }

    public async Task<ProcessingJobDto> IngestLumaAiExportAsync(
        LumaAiIngestRequest request,
        CancellationToken ct = default)
    {
        var booking = await _db.ShootBookings.FindAsync([request.BookingId], ct)
            ?? throw new InvalidOperationException("Booking not found");

        var upload = new Domain.Entities.MediaUpload
        {
            BookingId = request.BookingId,
            FileName = $"{request.ProductSlug}-luma.glb",
            ContentType = "model/gltf-binary",
            FileSizeBytes = 0,
            StorageKey = $"exports/{booking.BusinessId}/{request.ProductSlug}-luma.glb",
            StorageUrl = request.ExportUrl,
            Status = Domain.Enums.MediaUploadStatus.Completed,
            UploadProgressPercent = 100,
        };

        _db.MediaUploads.Add(upload);
        await _db.SaveChangesAsync(ct);

        return await _queue.EnqueueFromUploadAsync(upload.Id, ExternalToolSource.LumaAi, ct);
    }
}
