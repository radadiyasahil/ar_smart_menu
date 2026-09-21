using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Constants;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Hosting;

namespace ARSmartMenu.Infrastructure.Services;

public class ProductService : IProductService
{
    private const int AutoSubmitPhotoCount = 4;

    private static readonly PhotoAngleType[] RequiredPhotoAngles =
    [
        PhotoAngleType.Front,
        PhotoAngleType.Top,
        PhotoAngleType.Left,
        PhotoAngleType.Right,
    ];

    private readonly AppDbContext _db;
    private readonly IStorageService _storage;
    private readonly IProductProcessingService _productProcessing;
    private readonly IPhotoModelGenerationService _photoModels;
    private readonly MediaUrlResolver _mediaUrls;
    private readonly IWebHostEnvironment _env;
    private readonly string? _localRoot;

    public ProductService(
        AppDbContext db,
        IStorageService storage,
        IProductProcessingService productProcessing,
        IPhotoModelGenerationService photoModels,
        MediaUrlResolver mediaUrls,
        IWebHostEnvironment env,
        IConfiguration config)
    {
        _db = db;
        _storage = storage;
        _productProcessing = productProcessing;
        _photoModels = photoModels;
        _mediaUrls = mediaUrls;
        _env = env;
        _localRoot = config["Storage:LocalRoot"];
    }

    public async Task<IReadOnlyList<ProductDto>> ListAsync(Guid businessId, CancellationToken ct = default)
    {
        var products = await _db.Products
            .AsNoTracking()
            .Include(p => p.Photos.OrderBy(ph => ph.SortOrder))
            .Include(p => p.Model3d)
            .Where(p => p.BusinessId == businessId)
            .OrderBy(p => p.DisplayOrder)
            .ThenByDescending(p => p.CreatedAt)
            .ToListAsync(ct);

        return products.Select(MapProduct).ToList();
    }

    public async Task<ProductDto> GetByIdAsync(Guid businessId, Guid productId, CancellationToken ct = default)
    {
        var product = await LoadProductAsync(businessId, productId, ct);
        return MapProduct(product);
    }

    public async Task<ProductDto> CreateAsync(Guid businessId, CreateProductRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationException("Product name is required.");

        await EnsureWithinPlanLimitAsync(businessId, ct);

        var product = new Product
        {
            BusinessId = businessId,
            Name = request.Name.Trim(),
            Description = request.Description?.Trim(),
            PricePaise = request.PricePaise,
            Category = request.Category,
            VegStatus = request.VegStatus,
            IsSpicy = request.IsSpicy,
            IsBestseller = request.IsBestseller,
            IsNew = request.IsNew,
            Status = ProductStatus.Draft,
        };

        _db.Products.Add(product);
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }

    public async Task<ProductDto> UpdateAsync(
        Guid businessId,
        Guid productId,
        UpdateProductRequest request,
        CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        if (!string.IsNullOrWhiteSpace(request.Name))
            product.Name = request.Name.Trim();
        if (request.Description is not null)
            product.Description = request.Description;
        if (request.PricePaise.HasValue)
            product.PricePaise = request.PricePaise;
        if (request.Category.HasValue)
            product.Category = request.Category;
        if (request.VegStatus.HasValue)
            product.VegStatus = request.VegStatus.Value;
        if (request.IsSpicy.HasValue)
            product.IsSpicy = request.IsSpicy.Value;
        if (request.IsBestseller.HasValue)
            product.IsBestseller = request.IsBestseller.Value;
        if (request.IsNew.HasValue)
            product.IsNew = request.IsNew.Value;
        if (request.DisplayOrder.HasValue)
            product.DisplayOrder = request.DisplayOrder.Value;

        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }

    public async Task DeleteAsync(Guid businessId, Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        _db.Products.Remove(product);
        await _db.SaveChangesAsync(ct);
    }

    public async Task<ProductDto> SetSoldOutAsync(Guid businessId, Guid productId, bool soldOut, CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.SoldOutToday = soldOut;
        product.SoldOutDate = soldOut ? DateOnly.FromDateTime(DateTime.UtcNow) : null;
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }

    public async Task<UploadPhotoResponse> UploadPhotoAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        PhotoAngleType angleType,
        CancellationToken ct = default)
    {
        if (file.Length == 0)
            throw new ValidationException("Photo file is required.");
        if (file.Length > 10 * 1024 * 1024)
            throw new ValidationException("Photo must be under 10 MB.");

        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        if (!RequiredPhotoAngles.Contains(angleType))
            throw new ValidationException("Use front, top, left, or right photo angles.");

        // Stuck state: submitted early without all 4 angles — let owner finish uploads.
        if (product.Status == ProductStatus.Submitted && !HasAllRequiredAngles(product.Photos))
        {
            product.Status = ProductStatus.Draft;
            product.UpdatedAt = DateTime.UtcNow;
        }

        var existing = product.Photos.FirstOrDefault(p => p.AngleType == angleType);
        if (product.Status == ProductStatus.Live && existing is null)
            throw new ValidationException("Cannot add new photos to a live product. Replace an existing angle instead.");

        if (existing is null && product.Photos.Count >= AutoSubmitPhotoCount)
        {
            var legacy = product.Photos.FirstOrDefault(p => !RequiredPhotoAngles.Contains(p.AngleType));
            if (legacy is not null)
            {
                _db.ProductPhotos.Remove(legacy);
                product.Photos.Remove(legacy);
            }
            else
            {
                throw new ValidationException("Maximum 4 photos already uploaded.");
            }
        }

        var ext = Path.GetExtension(file.FileName);
        if (string.IsNullOrEmpty(ext))
            ext = ".jpg";

        var storageKey = StoragePaths.BuildPath(
            StoragePaths.RawMedia,
            businessId.ToString(),
            $"{productId:N}-{Guid.NewGuid():N}{ext}");

        await _storage.GetSignedUploadUrlAsync(storageKey, file.ContentType, ct);
        await LocalMediaStorage.SaveUploadAsync(_env, storageKey, file, _localRoot, ct);

        var photoUrl = _mediaUrls.Resolve(storageKey, null);

        ProductPhoto photo;
        if (existing is not null)
        {
            existing.PhotoUrl = photoUrl;
            existing.S3Key = storageKey;
            existing.FileSizeBytes = (int)file.Length;
            existing.MimeType = file.ContentType;
            existing.UpdatedAt = DateTime.UtcNow;
            photo = existing;
        }
        else
        {
            photo = new ProductPhoto
            {
                ProductId = productId,
                PhotoUrl = photoUrl,
                S3Key = storageKey,
                AngleType = angleType,
                SortOrder = product.Photos.Count,
                FileSizeBytes = (int)file.Length,
                MimeType = file.ContentType,
            };
            _db.ProductPhotos.Add(photo);
            product.Photos.Add(photo);
        }

        product.UpdatedAt = DateTime.UtcNow;

        var autoSubmitted = false;
        var shouldEnqueueProcessing = false;
        var shouldRegenerateLiveModel = false;
        if (HasAllRequiredAngles(product.Photos))
        {
            if (product.Status == ProductStatus.Draft)
            {
                product.Status = ProductStatus.Submitted;
                autoSubmitted = true;
                shouldEnqueueProcessing = true;
            }
            else if (product.Status == ProductStatus.Submitted)
            {
                autoSubmitted = true;
                shouldEnqueueProcessing = true;
            }
            else if (product.Status == ProductStatus.Live)
            {
                shouldRegenerateLiveModel = true;
            }
        }

        await _db.SaveChangesAsync(ct);

        if (shouldEnqueueProcessing)
        {
            await _productProcessing.EnqueueFromProductPhotosAsync(productId, ct);
        }
        else if (shouldRegenerateLiveModel)
        {
            await _photoModels.TryRegeneratePublishedProductAsync(productId, ct);
        }

        var refreshed = await LoadProductAsync(businessId, productId, ct);
        return new UploadPhotoResponse(
            MapPhoto(photo),
            autoSubmitted,
            MapProduct(refreshed));
    }

    private static bool HasAllRequiredAngles(IEnumerable<ProductPhoto> photos)
    {
        var used = photos.Select(p => p.AngleType).ToHashSet();
        return RequiredPhotoAngles.All(used.Contains);
    }

    private async Task<Product> LoadProductAsync(Guid businessId, Guid productId, CancellationToken ct)
    {
        return await _db.Products
            .AsNoTracking()
            .Include(p => p.Photos.OrderBy(ph => ph.SortOrder))
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");
    }

    private async Task EnsureWithinPlanLimitAsync(Guid businessId, CancellationToken ct)
    {
        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        if (subscription is null) return;

        var count = await _db.Products.CountAsync(p => p.BusinessId == businessId, ct);
        if (count >= subscription.Plan.MaxProducts)
            throw new ValidationException($"Product limit ({subscription.Plan.MaxProducts}) reached for your plan.");
    }

    internal ProductDto MapProduct(Product product) => new(
        product.Id,
        product.BusinessId,
        product.Name,
        product.Description,
        product.PricePaise,
        product.Category,
        product.VegStatus,
        product.IsSpicy,
        product.IsBestseller,
        product.IsNew,
        product.Status,
        product.RejectionReason,
        product.SoldOutToday,
        product.SoldOutDate,
        product.DisplayOrder,
        product.Photos.OrderBy(p => p.SortOrder).Select(p => MapPhoto(p)).ToList(),
        product.Model3d is null ? null : MapModel(product.Model3d),
        product.CreatedAt);

    private ProductPhotoDto MapPhoto(ProductPhoto photo) => new(
        photo.Id,
        _mediaUrls.Resolve(photo.S3Key, photo.PhotoUrl),
        photo.AngleType,
        photo.SortOrder,
        photo.MimeType,
        photo.FileSizeBytes,
        photo.CreatedAt);

    internal static Model3dSummaryDto MapModel(Model3d model) => new(
        model.Id,
        model.GlbUrl,
        model.UsdzUrl,
        model.ProcessingStatus,
        model.ApprovedAt);
}
