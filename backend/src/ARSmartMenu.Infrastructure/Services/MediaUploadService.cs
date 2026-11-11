using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Jobs;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Storage;
using Hangfire;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class MediaUploadService : IMediaUploadService
{
    private readonly AppDbContext _db;
    private readonly IStorageService _storage;

    public MediaUploadService(AppDbContext db, IStorageService storage)
    {
        _db = db;
        _storage = storage;
    }

    public async Task<MediaUploadDto> InitiateUploadAsync(InitiateUploadRequest request, CancellationToken ct = default)
    {
        var booking = await _db.ShootBookings.FindAsync([request.BookingId], ct)
            ?? throw new InvalidOperationException("Booking not found");

        var storageKey = StorageKeyBuilder.RawMedia(booking.BusinessId, request.FileName);
        var signed = await _storage.GetSignedUploadUrlAsync(storageKey, request.ContentType, ct);

        var upload = new MediaUpload
        {
            BookingId = request.BookingId,
            FileName = request.FileName,
            ContentType = request.ContentType,
            FileSizeBytes = request.FileSizeBytes,
            CaptureGuide = request.CaptureGuide,
            StorageKey = storageKey,
            Status = MediaUploadStatus.Uploading,
        };

        _db.MediaUploads.Add(upload);
        await _db.SaveChangesAsync(ct);

        return ToDto(upload, signed.UploadUrl);
    }

    public async Task<MediaUploadDto?> UpdateProgressAsync(Guid uploadId, int progressPercent, CancellationToken ct = default)
    {
        var upload = await _db.MediaUploads.FindAsync([uploadId], ct);
        if (upload is null) return null;

        upload.UploadProgressPercent = Math.Clamp(progressPercent, 0, 100);
        upload.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return ToDto(upload);
    }

    public async Task<MediaUploadDto?> CompleteUploadAsync(Guid uploadId, CancellationToken ct = default)
    {
        var upload = await _db.MediaUploads
            .Include(u => u.Booking)
            .FirstOrDefaultAsync(u => u.Id == uploadId, ct);
        if (upload is null) return null;

        upload.Status = MediaUploadStatus.Completed;
        upload.UploadProgressPercent = 100;
        upload.UpdatedAt = DateTime.UtcNow;

        // Create processing queue entry automatically
        BackgroundJob.Enqueue<PipelineJobRunner>(j =>
            j.EnqueueProcessingJobAsync(upload.Id, ExternalToolSource.ManualUpload));

        await _db.SaveChangesAsync(ct);
        return ToDto(upload);
    }

    public async Task<MediaUploadDto?> RetryUploadAsync(Guid uploadId, CancellationToken ct = default)
    {
        var upload = await _db.MediaUploads.FindAsync([uploadId], ct);
        if (upload is null) return null;

        upload.RetryCount++;
        upload.Status = MediaUploadStatus.RetryScheduled;
        upload.ErrorMessage = null;
        upload.UpdatedAt = DateTime.UtcNow;

        var signed = await _storage.GetSignedUploadUrlAsync(upload.StorageKey, upload.ContentType, ct);
        await _db.SaveChangesAsync(ct);

        return ToDto(upload, signed.UploadUrl);
    }

    public async Task<IReadOnlyList<MediaUploadDto>> GetByBookingAsync(Guid bookingId, CancellationToken ct = default)
    {
        var items = await _db.MediaUploads
            .Where(u => u.BookingId == bookingId)
            .OrderByDescending(u => u.CreatedAt)
            .ToListAsync(ct);
        return items.Select(u => ToDto(u)).ToList();
    }

    private static MediaUploadDto ToDto(MediaUpload u, string? uploadUrl = null) => new(
        u.Id, u.BookingId, u.FileName, u.ContentType, u.FileSizeBytes,
        u.CaptureGuide, u.StorageKey, u.Status, u.UploadProgressPercent, u.RetryCount, uploadUrl);
}
