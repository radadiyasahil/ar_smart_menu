using ARSmartMenu.Domain.Enums;

namespace ARSmartMenu.Application.DTOs;

// ── Business ──────────────────────────────────────────────────────────────────

public record CreateBusinessRequest(
    string BusinessName,
    BusinessType BusinessType,
    string City,
    string FullAddress,
    string? FssaiNumber = null,
    string? GstNumber = null);

public record UpdateBusinessRequest(
    string? BusinessName = null,
    BusinessType? BusinessType = null,
    string? City = null,
    string? FullAddress = null,
    string? LogoUrl = null,
    string? FssaiNumber = null,
    string? GstNumber = null,
    string? UpiId = null);

public record BusinessDto(
    Guid Id,
    Guid OwnerId,
    string BusinessName,
    BusinessType BusinessType,
    string City,
    string FullAddress,
    string? LogoUrl,
    string? FssaiNumber,
    string? GstNumber,
    string? BankAccountNumber,
    string? BankIfsc,
    string? UpiId,
    bool BankPennyVerified,
    BusinessStatus Status,
    string? RejectionReason,
    DateTime? ApprovedAt,
    DateTime CreatedAt);

public record VerifyBankRequest(string BankAccountNumber, string BankIfsc);

public record VerifyBankResponse(bool Verified, string Message);

public record SubmitKycRequest(
    string? FullName,
    string? AadhaarLast4,
    string? PanNumber);

// ── Product ─────────────────────────────────────────────────────────────────

public record CreateProductRequest(
    string Name,
    string? Description = null,
    int? PricePaise = null,
    ProductCategory? Category = null,
    VegStatus VegStatus = VegStatus.NotApplicable,
    bool IsSpicy = false,
    bool IsBestseller = false,
    bool IsNew = false);

public record UpdateProductRequest(
    string? Name = null,
    string? Description = null,
    int? PricePaise = null,
    ProductCategory? Category = null,
    VegStatus? VegStatus = null,
    bool? IsSpicy = null,
    bool? IsBestseller = null,
    bool? IsNew = null,
    int? DisplayOrder = null);

public record ProductPhotoDto(
    Guid Id,
    string PhotoUrl,
    PhotoAngleType AngleType,
    int SortOrder,
    string? MimeType,
    int? FileSizeBytes,
    DateTime CreatedAt);

public record Model3dSummaryDto(
    Guid Id,
    string? GlbUrl,
    string? UsdzUrl,
    ModelProcessingStatus ProcessingStatus,
    DateTime? ApprovedAt);

public record ProductDto(
    Guid Id,
    Guid BusinessId,
    string Name,
    string? Description,
    int? PricePaise,
    ProductCategory? Category,
    VegStatus VegStatus,
    bool IsSpicy,
    bool IsBestseller,
    bool IsNew,
    ProductStatus Status,
    string? RejectionReason,
    bool SoldOutToday,
    DateOnly? SoldOutDate,
    int DisplayOrder,
    IReadOnlyList<ProductPhotoDto> Photos,
    Model3dSummaryDto? Model3d,
    DateTime CreatedAt);

public record UploadPhotoResponse(
    ProductPhotoDto Photo,
    bool AutoSubmitted,
    ProductDto? Product);

public record SetSoldOutRequest(bool SoldOut);

// ── Subscription ────────────────────────────────────────────────────────────

public record SubscriptionPlanDto(
    Guid Id,
    string Name,
    string Slug,
    int MonthlyPricePaise,
    int YearlyPricePaise,
    int MaxProducts,
    bool IncludesShoot,
    int ShootsPerYear,
    bool ApiIntegration,
    bool AnalyticsExport,
    bool WhatsappSupport,
    int DisplayOrder);

public record SubscriptionDto(
    Guid Id,
    Guid BusinessId,
    SubscriptionPlanDto Plan,
    BillingCycle BillingCycle,
    SubscriptionStatus Status,
    DateTime StartsAt,
    DateTime EndsAt,
    int ShootsUsed,
    DateTime? CancelledAt);

public record CreateOrderRequest(Guid PlanId, BillingCycle BillingCycle);

public record CreateOrderResponse(
    string OrderId,
    int AmountPaise,
    string Currency,
    string RazorpayKeyId);

public record VerifyPaymentRequest(
    string RazorpayOrderId,
    string RazorpayPaymentId,
    string RazorpaySignature);

public record VerifyPaymentResponse(SubscriptionDto Subscription, string Message);

// ── QR Code ─────────────────────────────────────────────────────────────────

public record QrCodeDto(
    Guid Id,
    Guid BusinessId,
    Guid? ProductId,
    string? ProductName,
    QrType QrType,
    string Slug,
    string WebUrl,
    string? QrImageUrl,
    bool IsActive,
    DateTime CreatedAt);

public record GenerateQrRequest(Guid ProductId);

// ── Analytics ─────────────────────────────────────────────────────────────────

public record AnalyticsOverviewDto(
    int TotalScans,
    int TotalViews,
    int UniqueVisitors,
    decimal ConversionRate);

public record AnalyticsChartPointDto(
    string Date,
    int Scans,
    int Views);

public record TopProductAnalyticsDto(
    Guid ProductId,
    string ProductName,
    int Scans,
    int Views,
    decimal ConversionRate);

public record AnalyticsDateRangeQuery(string Range = "7d");

// ── Admin ───────────────────────────────────────────────────────────────────

public record AdminDashboardDto(
    int TotalBusinesses,
    int ActiveBusinesses,
    int PendingApprovals,
    int PendingProductReviews,
    int TotalScans,
    int TotalArViews,
    int TotalProducts);

public record AdminProductReviewItemDto(
    Guid ProductId,
    string ProductName,
    Guid BusinessId,
    string BusinessName,
    ProductStatus ProductStatus,
    int PhotoCount,
    Guid? ProcessingJobId,
    ProcessingJobStatus? JobStatus,
    DateTime UpdatedAt);

public record AdminBusinessListItemDto(
    Guid Id,
    string BusinessName,
    BusinessType BusinessType,
    string City,
    BusinessStatus Status,
    string OwnerMobile,
    string? OwnerName,
    KycStatus OwnerKycStatus,
    int ProductCount,
    DateTime CreatedAt);

public record AdminBusinessFilter(
    BusinessStatus? Status = null,
    BusinessType? BusinessType = null,
    string? City = null,
    string? Search = null);

public record ApproveBusinessRequest(string? AdminNotes = null);

public record RejectBusinessRequest(string Reason, string? AdminNotes = null);
public record RejectProductRequest(string Reason);

// ── Public AR ─────────────────────────────────────────────────────────────────

public record PublicArProductDto(
    Guid Id,
    string Name,
    string? Description,
    int? PriceInPaise,
    VegStatus VegStatus,
    bool IsSpicy,
    bool IsBestseller,
    bool SoldOutToday,
    int? Calories,
    IReadOnlyList<string> PhotoUrls);

public record PublicArBusinessDto(
    string BusinessName,
    string City,
    string? OrderingUrl,
    string? LogoUrl);

public record PublicArModelDto(
    string? GlbUrl,
    string? UsdzUrl);

public record PublicArOtherProductDto(
    Guid Id,
    string Name,
    int? PriceInPaise,
    string Slug,
    PublicArModelDto Model);

public record PublicArResponse(
    string Slug,
    PublicArProductDto Product,
    PublicArBusinessDto Business,
    PublicArModelDto Model,
    IReadOnlyList<PublicArOtherProductDto> OtherProducts);

public record PublicMenuResponse(
    string Slug,
    string BusinessName,
    string? LogoUrl,
    string City,
    string? Address,
    string? WhatsAppNumber,
    string? OrderingUrl,
    IReadOnlyList<PublicMenuCategoryDto> Categories);

public record PublicMenuCategoryDto(
    string CategoryName,
    int CategoryId,
    IReadOnlyList<PublicMenuDishDto> Dishes);

public record PublicMenuDishDto(
    Guid Id,
    string Name,
    string? Description,
    int? PricePaise,
    int VegStatus,
    bool IsSpicy,
    bool IsBestseller,
    bool IsNew,
    bool SoldOutToday,
    string? ThumbnailUrl,
    IReadOnlyList<string> PhotoUrls,
    string? GlbUrl,
    string? UsdzUrl,
    bool Has3dModel,
    string DishSlug);

public record LogScanRequest(
    string? SessionId = null,
    string? Referrer = null,
    string? VisitorFingerprint = null,
    string? DeviceType = null,
    string? Platform = null);

public record LogViewEventRequest(
    string? SessionId = null,
    int ViewDurationSeconds = 0,
    bool ArLaunched = false,
    string? VisitorFingerprint = null,
    string? DeviceType = null,
    string? Platform = null,
    Guid? ScanEventId = null,
    bool Rotated = false,
    bool Resized = false,
    bool Shared = false,
    bool ClickedOrder = false);

public record LogEventResponse(Guid EventId, string Message);
