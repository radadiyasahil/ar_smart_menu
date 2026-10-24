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

    public ProductsController(IProductService products, ICurrentUserService currentUser)
    {
        _products = products;
        _currentUser = currentUser;
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
        var result = await _products.CreateAsync(businessId, request, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product created"));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ApiResponse<ProductDto>>> Update(
        Guid id,
        [FromBody] UpdateProductRequest request,
        CancellationToken ct)
    {
        var businessId = RequireBusinessId();
        var result = await _products.UpdateAsync(businessId, id, request, ct);
        return Ok(ApiResponse<ProductDto>.Ok(result, "Product updated"));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<object>>> Delete(Guid id, CancellationToken ct)
    {
        var businessId = RequireBusinessId();
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
