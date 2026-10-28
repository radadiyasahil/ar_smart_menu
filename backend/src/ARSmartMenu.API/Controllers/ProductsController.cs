using Microsoft.EntityFrameworkCore;
using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ARSmartMenu.API.Controllers;

[ApiController]
[Route("api/products")]
[Authorize]
public class ProductsController : ControllerBase
{
    private readonly IProductService _products;
    private readonly ICurrentUserService _currentUser;
    private readonly ARSmartMenu.Infrastructure.Persistence.AppDbContext _db;

    public ProductsController(
        IProductService products,
        ICurrentUserService currentUser,
        ARSmartMenu.Infrastructure.Persistence.AppDbContext db)
    {
        _products = products;
        _currentUser = currentUser;
        _db = db;
    }

    private async Task RequireActiveSubscriptionAsync(Guid businessId, CancellationToken ct)
    {
        var hasActive = await _db.Subscriptions
            .AnyAsync(s => s.BusinessId == businessId && s.Status == ARSmartMenu.Domain.Enums.SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);
        if (!hasActive)
        {
            throw new ValidationException("An active subscription plan or 7-day free trial is required to manage menu products. Please activate a plan in Subscription settings.");
        }
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<ProductDto>>>> List(CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.ListAsync(businessId, ct);
        return Ok(ApiResponse<IReadOnlyList<ProductDto>>.Ok(result));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> GetById(Guid id, CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.GetByIdAsync(businessId, id, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result));
    }

    [HttpPost]
    public async Task<ActionResult<ApiResponse<ProductDto>>> Create(
        [FromBody] CreateProductRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        await RequireActiveSubscriptionAsync(businessId, ct);
        var result = await _products.CreateAsync(businessId, request, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product created"));
    }

    [HttpPost("bulk")]
    public async Task<ActionResult<ApiResponse<BulkCreateProductsResponse>>> BulkCreate(
        [FromBody] BulkCreateProductsRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        await RequireActiveSubscriptionAsync(businessId, ct);
        var result = await _products.BulkCreateAsync(businessId, request, ct);
        return Ok(ApiResponse<BulkCreateProductsResponse>.Ok(result, $"{result.CreatedCount} products imported successfully"));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> Update(
        Guid id,
        [FromBody] UpdateProductRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        await RequireActiveSubscriptionAsync(businessId, ct);
        var result = await _products.UpdateAsync(businessId, id, request, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product updated"));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(Guid id, CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        await RequireActiveSubscriptionAsync(businessId, ct);
        await _products.DeleteAsync(businessId, id, ct);
        return Ok(ApiResponse<object>.Ok(new { message = "Product deleted" }));
    }

    [HttpPatch("{id:guid}/sold-out")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> SetSoldOut(
        Guid id,
        [FromBody] SetSoldOutRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.SetSoldOutAsync(businessId, id, request.SoldOut, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result));
    }


    [HttpPatch("{id:guid}/status")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> UpdateStatus(
        Guid id,
        [FromBody] UpdateProductStatusRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.UpdateStatusAsync(businessId, id, request.Status, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, $"Product status updated to {request.Status}"));
    }

    [HttpPatch("bulk-status")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<ProductDto>>>> BulkUpdateStatus(
        [FromBody] BulkUpdateProductStatusRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.BulkUpdateStatusAsync(businessId, request.ProductIds, request.Status, ct);
        return Ok(ApiResponse<IReadOnlyList<ProductDto>>.Ok(result, $"{result.Count} products updated to {request.Status}"));
    }





    [HttpPost("{id:guid}/photos")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<ActionResult<ApiResponse<UploadPhotoResponse>>> UploadPhoto(
        Guid id,
        IFormFile file,
        [FromForm] PhotoAngleType angleType = PhotoAngleType.Other,
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _products.UploadPhotoAsync(businessId, id, file, angleType, ct);
        var message = result.AutoSubmitted ? "Photo uploaded; product auto-submitted" : "Photo uploaded";
        return Ok(ApiResponse<UploadPhotoResponse>.Ok(result, message));
    }

    [HttpPost("{id:guid}/model")]
    [RequestSizeLimit(35 * 1024 * 1024)]
    public async Task<ActionResult<ApiResponse<ProductDto>>> UploadModel(
        Guid id,
        IFormFile file,
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _products.UploadModelAsync(businessId, id, file, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "3D Model (.glb) uploaded successfully! Product is now Live in AR."));
    }

    [HttpPost("{id:guid}/video")]
    [RequestSizeLimit(35 * 1024 * 1024)]
    public async Task<ActionResult<ApiResponse<ProductDto>>> UploadVideo(
        Guid id,
        IFormFile file,
        CancellationToken ct = default)
    {
        var businessId = RequireBusinessId();
        var result = await _products.UploadVideoAsync(businessId, id, file, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Walkaround video uploaded successfully."));
    }

    private Guid RequireBusinessId()
    {
        return _currentUser.GetBusinessId()
            ?? throw new ValidationException("No business linked to this account. Create a business first.");
    }
}
