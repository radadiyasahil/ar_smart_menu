using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Http;

namespace ARSmartMenu.Application.Interfaces;

public interface ICurrentUserService
{
    Guid GetUserId();
    Guid? GetBusinessId();
    bool IsAdmin();
}

public interface IBusinessService
{
    Task<BusinessDto> CreateAsync(Guid userId, CreateBusinessRequest request, CancellationToken ct = default);
    Task<BusinessDto> GetMeAsync(Guid userId, CancellationToken ct = default);
    Task<BusinessDto> UpdateMeAsync(Guid userId, UpdateBusinessRequest request, CancellationToken ct = default);
    Task<BusinessDto> UpdateStatusAsync(Guid userId, UpdateBusinessStatusRequest request, CancellationToken ct = default);
    Task<VerifyBankResponse> VerifyBankAsync(Guid userId, VerifyBankRequest request, CancellationToken ct = default);
    Task<UserDto> SubmitKycAsync(Guid userId, SubmitKycRequest request, CancellationToken ct = default);
}

public interface IProductService
{
    Task<IReadOnlyList<ProductDto>> ListAsync(Guid businessId, CancellationToken ct = default);
    Task<ProductDto> GetByIdAsync(Guid businessId, Guid productId, CancellationToken ct = default);
    Task<ProductDto> CreateAsync(Guid businessId, CreateProductRequest request, CancellationToken ct = default);
    Task<BulkCreateProductsResponse> BulkCreateAsync(Guid businessId, BulkCreateProductsRequest request, CancellationToken ct = default);
    Task<ProductDto> UpdateAsync(Guid businessId, Guid productId, UpdateProductRequest request, CancellationToken ct = default);
    Task<ProductDto> UpdateStatusAsync(Guid businessId, Guid productId, ProductStatus status, CancellationToken ct = default);
    Task<IReadOnlyList<ProductDto>> BulkUpdateStatusAsync(Guid businessId, IReadOnlyList<Guid> productIds, ProductStatus status, CancellationToken ct = default);
    Task DeleteAsync(Guid businessId, Guid productId, CancellationToken ct = default);
    Task<ProductDto> SetSoldOutAsync(Guid businessId, Guid productId, bool soldOut, CancellationToken ct = default);
    Task<UploadPhotoResponse> UploadPhotoAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        PhotoAngleType angleType,
        CancellationToken ct = default);
    Task<ProductDto> UploadModelAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        CancellationToken ct = default);
    Task<ProductDto> UploadVideoAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        CancellationToken ct = default);
}

public interface ISubscriptionService
{
    Task<IReadOnlyList<SubscriptionPlanDto>> ListPlansAsync(CancellationToken ct = default);
    Task<SubscriptionDto?> GetMeAsync(Guid businessId, CancellationToken ct = default);
    Task<SubscriptionDto> ActivateTrialAsync(Guid businessId, CancellationToken ct = default);
    Task<SubscriptionDto> ActivatePlanAsync(Guid businessId, ActivatePlanRequest request, CancellationToken ct = default);
    Task<SubscriptionDto> AdminGrantPlanAsync(Guid businessId, AdminGrantSubscriptionRequest request, CancellationToken ct = default);
    Task<SubscriptionDto> AdminCancelPlanAsync(Guid businessId, CancellationToken ct = default);
    Task<CreateOrderResponse> CreateOrderAsync(Guid businessId, CreateOrderRequest request, CancellationToken ct = default);
    Task<VerifyPaymentResponse> VerifyPaymentAsync(Guid businessId, VerifyPaymentRequest request, CancellationToken ct = default);
}

public interface IQrCodeService
{
    string BuildDishWebUrl(string slug);
    string BuildMenuWebUrl(string slug, int? tableNumber = null);
    string BuildQrWebUrl(ARSmartMenu.Domain.Enums.QrType qrType, string slug, int? tableNumber = null);
    Task<QrCodeDto> GenerateForProductAsync(Guid businessId, Guid productId, CancellationToken ct = default);
    Task<QrCodeDto> GetOrCreateMasterQrAsync(Guid businessId, CancellationToken ct = default);
    Task<IReadOnlyList<QrCodeDto>> GenerateTableQrsAsync(Guid businessId, int tableCount, CancellationToken ct = default);
    Task<IReadOnlyList<QrCodeDto>> ListAsync(Guid businessId, CancellationToken ct = default);
    Task<QrCodeDto> DeactivateAsync(Guid businessId, Guid qrCodeId, CancellationToken ct = default);
}

public interface IAnalyticsService
{
    Task<AnalyticsOverviewDto> GetOverviewAsync(Guid businessId, string range, CancellationToken ct = default);
    Task<IReadOnlyList<AnalyticsChartPointDto>> GetChartAsync(Guid businessId, string range, CancellationToken ct = default);
    Task<IReadOnlyList<TopProductAnalyticsDto>> GetTopProductsAsync(Guid businessId, string range, int limit, CancellationToken ct = default);
}

public interface IAdminService
{
    Task<AdminDashboardDto> GetDashboardAsync(CancellationToken ct = default);
    Task<PagedResult<AdminBusinessListItemDto>> ListBusinessesAsync(
        AdminBusinessFilter? filter,
        PaginationQuery pagination,
        CancellationToken ct = default);
    Task<BusinessDto> ApproveBusinessAsync(Guid adminUserId, Guid businessId, ApproveBusinessRequest request, CancellationToken ct = default);
    Task<BusinessDto> RejectBusinessAsync(Guid adminUserId, Guid businessId, RejectBusinessRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<AdminProductReviewItemDto>> GetProductReviewQueueAsync(
        ProcessingJobStatus? jobStatus = null,
        CancellationToken ct = default);
    Task<ProductDto> ApproveProductAsync(Guid adminUserId, Guid productId, CancellationToken ct = default);
    Task<ProductDto> RejectProductAsync(Guid adminUserId, Guid productId, string reason, CancellationToken ct = default);
    Task<ProductDto> MakeProductLiveAsync(Guid adminUserId, Guid productId, CancellationToken ct = default);
    Task<BusinessDto> SetBusinessStatusAsync(Guid adminUserId, Guid businessId, BusinessStatus status, string? reason = null, string? adminNotes = null, CancellationToken ct = default);
    Task<ProductDto> SetProductStatusAsync(Guid adminUserId, Guid productId, ProductStatus status, CancellationToken ct = default);
}

public interface IPublicArService
{
    Task<PublicArResponse> GetBySlugAsync(string slug, CancellationToken ct = default);
    Task<PublicMenuResponse> GetMenuBySlugAsync(string slug, CancellationToken ct = default);
    Task<LogEventResponse> LogScanAsync(string slug, LogScanRequest request, string? userAgent, string? ipAddress, CancellationToken ct = default);
    Task<LogEventResponse> LogViewEventAsync(string slug, LogViewEventRequest request, string? userAgent, CancellationToken ct = default);
}

public interface IModel3dService
{
    Task<IReadOnlyList<Model3dSummaryDto>> ListForBusinessAsync(Guid businessId, CancellationToken ct = default);
    Task<Model3dSummaryDto> GetByIdAsync(Guid businessId, Guid modelId, CancellationToken ct = default);
}

public interface IProductProcessingService
{
    Task EnqueueFromProductPhotosAsync(Guid productId, CancellationToken ct = default);
}
