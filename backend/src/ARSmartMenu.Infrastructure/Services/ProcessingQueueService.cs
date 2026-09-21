using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Jobs;
using ARSmartMenu.Infrastructure.Persistence;
using Hangfire;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class ProcessingQueueService : IProcessingQueueService
{
    private readonly AppDbContext _db;

    public ProcessingQueueService(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<ProcessingJobDto>> GetQueueAsync(
        ProcessingJobStatus? status = null,
        CancellationToken ct = default)
    {
        var query = _db.ProcessingJobs
            .Include(j => j.Booking)
            .Include(j => j.Product)
            .AsQueryable();

        if (status.HasValue)
            query = query.Where(j => j.Status == status);

        var items = await query
            .OrderBy(j => j.CreatedAt)
            .ToListAsync(ct);
        return items.Select(ToDto).ToList();
    }

    public async Task<ProcessingJobDto?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var job = await _db.ProcessingJobs
            .Include(j => j.Booking)
            .Include(j => j.Product)
            .FirstOrDefaultAsync(j => j.Id == id, ct);
        return job is null ? null : ToDto(job);
    }

    public async Task<ProcessingJobDto> EnqueueFromUploadAsync(
        Guid mediaUploadId,
        ExternalToolSource source,
        CancellationToken ct = default)
    {
        var upload = await _db.MediaUploads.Include(u => u.Booking)
            .FirstOrDefaultAsync(u => u.Id == mediaUploadId, ct)
            ?? throw new InvalidOperationException("Upload not found");

        var job = new ProcessingJob
        {
            BookingId = upload.BookingId,
            MediaUploadId = mediaUploadId,
            Source = source,
            Status = ProcessingJobStatus.Queued,
            EstimatedCompletionAt = DateTime.UtcNow.AddHours(2),
        };

        _db.ProcessingJobs.Add(job);
        await _db.SaveChangesAsync(ct);

        await AddLogAsync(job.Id, "Job queued for processing", ct);

        BackgroundJob.Enqueue<PipelineJobRunner>(j => j.RunProcessingPipelineAsync(job.Id));

        return ToDto(job);
    }

    public async Task<ProcessingJobDto?> RetryAsync(Guid jobId, CancellationToken ct = default)
    {
        var job = await _db.ProcessingJobs.Include(j => j.Booking)
            .FirstOrDefaultAsync(j => j.Id == jobId, ct);
        if (job is null) return null;

        job.RetryCount++;
        job.Status = ProcessingJobStatus.Queued;
        job.FailureReason = null;
        job.UpdatedAt = DateTime.UtcNow;

        await AddLogAsync(job.Id, $"Retry #{job.RetryCount} scheduled", ct);
        await _db.SaveChangesAsync(ct);

        BackgroundJob.Enqueue<PipelineJobRunner>(j => j.RunProcessingPipelineAsync(job.Id));

        return ToDto(job);
    }

    public async Task<IReadOnlyList<ProcessingLogDto>> GetLogsAsync(Guid jobId, CancellationToken ct = default) =>
        await _db.ProcessingLogs
            .Where(l => l.ProcessingJobId == jobId)
            .OrderBy(l => l.CreatedAt)
            .Select(l => new ProcessingLogDto(l.Id, l.Message, l.Details, l.Level, l.CreatedAt))
            .ToListAsync(ct);

    internal async Task AddLogAsync(Guid jobId, string message, CancellationToken ct, string level = "Info", string? details = null)
    {
        _db.ProcessingLogs.Add(new ProcessingLog
        {
            ProcessingJobId = jobId,
            Message = message,
            Details = details,
            Level = level,
        });
        await _db.SaveChangesAsync(ct);
    }

    private static ProcessingJobDto ToDto(ProcessingJob j) => new(
        j.Id,
        j.BookingId,
        j.ProductId,
        j.Booking?.BusinessName ?? "",
        j.Product?.Name,
        j.Status,
        j.Source,
        j.Version,
        j.EstimatedCompletionAt,
        j.RetryCount,
        j.FailureReason,
        j.CreatedAt);
}
