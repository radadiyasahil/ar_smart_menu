using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Application.Interfaces;

public interface IPhotographerService
{
    Task<IReadOnlyList<PhotographerDto>> GetAllAsync(CancellationToken ct = default);
    Task<PhotographerDto?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<PhotographerDto> CreateAsync(CreatePhotographerRequest request, CancellationToken ct = default);
    Task<PhotographerDto?> UpdateAsync(Guid id, UpdatePhotographerRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<PhotographerDto>> GetAvailableInCityAsync(string city, CancellationToken ct = default);
}

public interface IBookingService
{
    Task<IReadOnlyList<BookingDto>> GetAllAsync(BookingFilter? filter = null, CancellationToken ct = default);
    Task<BookingDto?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<BookingDto> CreateAsync(CreateBookingRequest request, CancellationToken ct = default);
    Task<BookingDto?> AssignPhotographerAsync(Guid bookingId, Guid photographerId, CancellationToken ct = default);
    Task<BookingDto?> UpdateStatusAsync(Guid bookingId, BookingStatus status, CancellationToken ct = default);
}

public interface IMediaUploadService
{
    Task<MediaUploadDto> InitiateUploadAsync(InitiateUploadRequest request, CancellationToken ct = default);
    Task<MediaUploadDto?> UpdateProgressAsync(Guid uploadId, int progressPercent, CancellationToken ct = default);
    Task<MediaUploadDto?> CompleteUploadAsync(Guid uploadId, CancellationToken ct = default);
    Task<MediaUploadDto?> RetryUploadAsync(Guid uploadId, CancellationToken ct = default);
    Task<IReadOnlyList<MediaUploadDto>> GetByBookingAsync(Guid bookingId, CancellationToken ct = default);
}

public interface IProcessingQueueService
{
    Task<IReadOnlyList<ProcessingJobDto>> GetQueueAsync(ProcessingJobStatus? status = null, CancellationToken ct = default);
    Task<ProcessingJobDto?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<ProcessingJobDto> EnqueueFromUploadAsync(Guid mediaUploadId, ExternalToolSource source, CancellationToken ct = default);
    Task<ProcessingJobDto?> RetryAsync(Guid jobId, CancellationToken ct = default);
    Task<IReadOnlyList<ProcessingLogDto>> GetLogsAsync(Guid jobId, CancellationToken ct = default);
}

public interface IQualityReviewService
{
    Task<ApprovalReviewDto?> GetReviewAsync(Guid jobId, CancellationToken ct = default);
    Task<ApprovalReviewDto> SubmitReviewAsync(Guid jobId, SubmitReviewRequest request, CancellationToken ct = default);
    Task<ModelAssetDto?> PublishApprovedAssetAsync(Guid jobId, CancellationToken ct = default);
}

public interface IIntegrationService
{
    Task<IReadOnlyList<IntegrationDto>> GetByBusinessAsync(Guid businessId, CancellationToken ct = default);
    Task<EmbedLinkDto> GenerateEmbedLinkAsync(Guid modelAssetId, string slug, CancellationToken ct = default);
    Task<string> GetOrderDeepLinkAsync(Guid businessId, IntegrationPlatform platform, string productSlug, CancellationToken ct = default);
}

public interface IExternalToolIngestionService
{
    Task<ProcessingJobDto> IngestPolycamExportAsync(PolycamIngestRequest request, CancellationToken ct = default);
    Task<ProcessingJobDto> IngestLumaAiExportAsync(LumaAiIngestRequest request, CancellationToken ct = default);
}

public interface IPhotoModelGenerationService
{
    Task<PhotoModelGenerationResult?> TryGenerateFromProductAsync(
        Guid productId,
        Guid businessId,
        string productSlug,
        CancellationToken ct = default);

    Task<bool> TryRegeneratePublishedProductAsync(Guid productId, CancellationToken ct = default);
}

public record PhotoModelGenerationResult(
    string GlbStorageKey,
    string GlbPublicUrl,
    long GlbSizeBytes,
    string ThumbnailStorageKey,
    string ThumbnailPublicUrl);

public record BookingFilter(BookingStatus? Status = null, string? City = null);

public record PolycamIngestRequest(Guid BookingId, string ExportUrl, string ProductSlug);
public record LumaAiIngestRequest(Guid BookingId, string ExportUrl, string ProductSlug);
