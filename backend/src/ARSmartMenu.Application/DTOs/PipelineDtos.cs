using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Application.DTOs;

public record PhotographerDto(
    Guid Id,
    string Name,
    string Phone,
    string CityCoverage,
    PhotographerStatus Status,
    decimal Rating,
    int CompletedShoots,
    bool IsActive);

public record CreatePhotographerRequest(
    string Name,
    string Phone,
    string CityCoverage);

public record UpdatePhotographerRequest(
    string? Name,
    string? Phone,
    string? CityCoverage,
    PhotographerStatus? Status,
    bool? IsActive);

public record BookingDto(
    Guid Id,
    Guid BusinessId,
    string BusinessName,
    BusinessCategory Category,
    string LocationAddress,
    string City,
    DateTime ScheduledAt,
    BookingStatus Status,
    Guid? PhotographerId,
    string? PhotographerName,
    string? Notes);

public record CreateBookingRequest(
    Guid BusinessId,
    string BusinessName,
    BusinessCategory Category,
    string LocationAddress,
    string City,
    DateTime ScheduledAt,
    string? Notes);

public record MediaUploadDto(
    Guid Id,
    Guid BookingId,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    CaptureGuideType? CaptureGuide,
    string StorageKey,
    MediaUploadStatus Status,
    int UploadProgressPercent,
    int RetryCount,
    string? UploadUrl);

public record InitiateUploadRequest(
    Guid BookingId,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    CaptureGuideType? CaptureGuide);

public record ProcessingJobDto(
    Guid Id,
    Guid BookingId,
    Guid? ProductId,
    string BusinessName,
    string? ProductName,
    ProcessingJobStatus Status,
    ExternalToolSource Source,
    int Version,
    DateTime? EstimatedCompletionAt,
    int RetryCount,
    string? FailureReason,
    DateTime CreatedAt);

public record ProcessingLogDto(
    Guid Id,
    string Message,
    string? Details,
    string Level,
    DateTime CreatedAt);

public record ApprovalReviewDto(
    Guid Id,
    Guid ProcessingJobId,
    ReviewDecision Decision,
    string? RejectionReason,
    int ModelQualityScore,
    int TextureQualityScore,
    int ScaleAccuracyScore,
    int RenderingQualityScore,
    DateTime? ReviewedAt);

public record SubmitReviewRequest(
    ReviewDecision Decision,
    string? RejectionReason,
    string? ImprovementNotes,
    int ModelQualityScore,
    int TextureQualityScore,
    int ScaleAccuracyScore,
    int RenderingQualityScore,
    string? InternalNotes,
    string? ReviewerId);

public record ModelAssetDto(
    Guid Id,
    string ProductSlug,
    string ProductName,
    string? GlbCdnUrl,
    string? UsdzCdnUrl,
    string? ThumbnailCdnUrl,
    long GlbSizeBytes,
    bool IsPublished,
    string? EmbedUrl);

public record IntegrationDto(
    Guid Id,
    Guid BusinessId,
    IntegrationPlatform Platform,
    bool IsEnabled,
    string? DeepLinkTemplate,
    string? EmbedBaseUrl);

public record EmbedLinkDto(
    Guid Id,
    string Slug,
    string PublicUrl,
    string? OrderDeepLink,
    bool IsActive);
