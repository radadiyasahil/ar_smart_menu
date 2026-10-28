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
            .Include(p => p.Photos)
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
        await EnsureBusinessActiveAsync(businessId, ct);

        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationException("Product name is required.");
        if (request.PricePaise.HasValue && request.PricePaise.Value <= 0)
            throw new ValidationException("Price must be greater than zero.");

        await EnsureWithinPlanLimitAsync(businessId, ct);

        var status = request.Status ?? (request.Enable3dAr ? ProductStatus.Draft : ProductStatus.Live);

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
            Status = status,
        };

        _db.Products.Add(product);
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }


    public async Task<BulkCreateProductsResponse> BulkCreateAsync(
        Guid businessId,
        BulkCreateProductsRequest request,
        CancellationToken ct = default)
    {
        await EnsureBusinessActiveAsync(businessId, ct);

        if (request.Products == null || request.Products.Count == 0)
            throw new ValidationException("No products provided in bulk request.");

        var validItems = request.Products
            .Where(p => !string.IsNullOrWhiteSpace(p.Name))
            .ToList();

        if (validItems.Count == 0)
            throw new ValidationException("At least one product with a valid name is required.");

        await EnsureWithinPlanLimitAsync(businessId, validItems.Count, ct);

        var currentMaxOrder = await _db.Products
            .Where(p => p.BusinessId == businessId)
            .Select(p => (int?)p.DisplayOrder)
            .MaxAsync(ct) ?? 0;

        var createdProducts = new List<Product>();
        var order = currentMaxOrder;

        foreach (var item in validItems)
        {
            order++;
            var product = new Product
            {
                BusinessId = businessId,
                Name = item.Name.Trim(),
                Description = string.IsNullOrWhiteSpace(item.Description) ? null : item.Description.Trim(),
                PricePaise = item.PricePaise,
                Category = item.Category ?? ProductCategory.MainCourse,
                VegStatus = item.VegStatus,
                IsSpicy = item.IsSpicy,
                IsBestseller = item.IsBestseller,
                IsNew = item.IsNew,
                Status = ProductStatus.Live,
                DisplayOrder = order,
            };
            createdProducts.Add(product);
        }

        await _db.Products.AddRangeAsync(createdProducts, ct);
        await _db.SaveChangesAsync(ct);

        var dtos = createdProducts.Select(MapProduct).ToList();
        return new BulkCreateProductsResponse(createdProducts.Count, dtos);
    }



    public async Task<ProductDto> UpdateAsync(
        Guid businessId,
        Guid productId,
        UpdateProductRequest request,
        CancellationToken ct = default)
    {
        await EnsureBusinessActiveAsync(businessId, ct);

        if (request.PricePaise.HasValue && request.PricePaise.Value <= 0)
            throw new ValidationException("Price must be greater than zero.");

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
        if (request.Status.HasValue)
            product.Status = request.Status.Value;

        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }

    public async Task<ProductDto> UpdateStatusAsync(Guid businessId, Guid productId, ProductStatus status, CancellationToken ct = default)
    {
        await EnsureBusinessActiveAsync(businessId, ct);

        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        product.Status = status;
        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return MapProduct(product);
    }

    public async Task<IReadOnlyList<ProductDto>> BulkUpdateStatusAsync(Guid businessId, IReadOnlyList<Guid> productIds, ProductStatus status, CancellationToken ct = default)
    {
        await EnsureBusinessActiveAsync(businessId, ct);

        var products = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .Where(p => p.BusinessId == businessId && productIds.Contains(p.Id))
            .ToListAsync(ct);

        foreach (var product in products)
        {
            product.Status = status;
            product.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(ct);
        return products.Select(MapProduct).ToList();
    }

    public async Task DeleteAsync(Guid businessId, Guid productId, CancellationToken ct = default)
    {
        await EnsureBusinessActiveAsync(businessId, ct);

        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        // 1. Unlink any notifications referencing this product (prevents FK_Notifications_Products_ProductId conflict)
        await _db.Notifications
            .Where(n => n.ProductId == productId)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ProductId, (Guid?)null), ct);

        // 2. Unlink any processing jobs referencing this product
        await _db.ProcessingJobs
            .Where(j => j.ProductId == productId)
            .ExecuteUpdateAsync(s => s.SetProperty(j => j.ProductId, (Guid?)null), ct);

        // 3. Unlink scan and view analytics events
        await _db.ArScanEvents
            .Where(e => e.ProductId == productId)
            .ExecuteUpdateAsync(s => s.SetProperty(e => e.ProductId, (Guid?)null), ct);

        await _db.ArViewEvents
            .Where(e => e.ProductId == productId)
            .ExecuteUpdateAsync(s => s.SetProperty(e => e.ProductId, (Guid?)null), ct);

        // 4. Handle associated QR codes: remove standalone product QRs with no scans, or unlink if scanned
        var qrCodes = await _db.QrCodes
            .Where(q => q.ProductId == productId)
            .ToListAsync(ct);

        foreach (var qr in qrCodes)
        {
            var hasScans = await _db.ArScanEvents.AnyAsync(e => e.QrCodeId == qr.Id, ct)
                        || await _db.ArViewEvents.AnyAsync(e => e.QrCodeId == qr.Id, ct);
            if (!hasScans)
            {
                _db.QrCodes.Remove(qr);
            }
            else
            {
                qr.ProductId = null;
                qr.IsActive = false;
            }
        }

        // 5. Clean up physical storage files for photos
        foreach (var photo in product.Photos)
        {
            if (!string.IsNullOrEmpty(photo.S3Key))
            {
                try { await _storage.DeleteAsync(photo.S3Key, ct); } catch { /* ignore storage cleanup error */ }
            }
        }

        // 6. Clean up physical storage files for 3D model
        if (product.Model3d != null)
        {
            if (!string.IsNullOrEmpty(product.Model3d.GlbS3Key))
            {
                try { await _storage.DeleteAsync(product.Model3d.GlbS3Key, ct); } catch { /* ignore storage cleanup error */ }
            }
            if (!string.IsNullOrEmpty(product.Model3d.UsdzS3Key))
            {
                try { await _storage.DeleteAsync(product.Model3d.UsdzS3Key, ct); } catch { /* ignore storage cleanup error */ }
            }
        }

        // 7. Remove the product
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
        await EnsureBusinessActiveAsync(businessId, ct);

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
        if (product.Status == ProductStatus.Live && existing is null && product.Photos.Count >= AutoSubmitPhotoCount)
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

    public async Task<ProductDto> UploadModelAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext != ".glb")
            throw new ValidationException("Only .glb 3D files are supported.");

        var storageKey = StoragePaths.BuildPath(
            StoragePaths.Glb,
            businessId.ToString(),
            $"{productId:N}-{Guid.NewGuid():N}.glb");

        await _storage.GetSignedUploadUrlAsync(storageKey, "model/gltf-binary", ct);
        await LocalMediaStorage.SaveUploadAsync(_env, storageKey, file, _localRoot, ct);

        var glbUrl = _mediaUrls.Resolve(storageKey, null);

        if (product.Model3d is null)
        {
            product.Model3d = new Model3d
            {
                ProductId = productId,
                GlbUrl = glbUrl,
                GlbS3Key = storageKey,
                GlbSizeBytes = (int)file.Length,
                ProcessingStatus = ModelProcessingStatus.Approved,
                ApprovedAt = DateTime.UtcNow,
            };
            _db.Models3d.Add(product.Model3d);
        }
        else
        {
            product.Model3d.GlbUrl = glbUrl;
            product.Model3d.GlbS3Key = storageKey;
            product.Model3d.GlbSizeBytes = (int)file.Length;
            product.Model3d.ProcessingStatus = ModelProcessingStatus.Approved;
            product.Model3d.ApprovedAt = DateTime.UtcNow;
            product.Model3d.UpdatedAt = DateTime.UtcNow;
        }

        product.Status = ProductStatus.Live;
        product.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        var refreshed = await LoadProductAsync(businessId, productId, ct);
        return MapProduct(refreshed);
    }

    public async Task<ProductDto> UploadVideoAsync(
        Guid businessId,
        Guid productId,
        IFormFile file,
        CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");

        if (file.Length > 35 * 1024 * 1024)
            throw new ValidationException("Video file must be under 35 MB to conserve storage.");

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (ext != ".mp4" && ext != ".mov" && ext != ".webm")
            throw new ValidationException("Only .mp4, .mov, or .webm videos are supported.");

        var storageKey = StoragePaths.BuildPath(
            "videos",
            businessId.ToString(),
            $"{productId:N}-{Guid.NewGuid():N}{ext}");

        await _storage.GetSignedUploadUrlAsync(storageKey, file.ContentType, ct);
        await LocalMediaStorage.SaveUploadAsync(_env, storageKey, file, _localRoot, ct);

        if (product.Status == ProductStatus.Draft)
        {
            product.Status = ProductStatus.Processing;
        }
        product.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        var refreshed = await LoadProductAsync(businessId, productId, ct);
        return MapProduct(refreshed);
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
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .FirstOrDefaultAsync(p => p.BusinessId == businessId && p.Id == productId, ct)
            ?? throw new NotFoundException("Product not found.");
    }

    private async Task EnsureBusinessActiveAsync(Guid businessId, CancellationToken ct)
    {
        var business = await _db.Businesses
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == businessId, ct)
            ?? throw new NotFoundException("Business not found.");

        if (business.Status == BusinessStatus.Deactivated)
            throw new ValidationException("Your restaurant operations are currently paused / deactivated. Please reactivate your business to perform this action.");

        if (business.Status == BusinessStatus.Suspended)
            throw new ValidationException("Your business account is suspended. Please contact support.");
    }

    private Task EnsureWithinPlanLimitAsync(Guid businessId, CancellationToken ct) =>
        EnsureWithinPlanLimitAsync(businessId, 1, ct);

    private async Task EnsureWithinPlanLimitAsync(Guid businessId, int additionalCount, CancellationToken ct = default)
    {
        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        if (subscription is null) return;

        var count = await _db.Products.CountAsync(p => p.BusinessId == businessId, ct);
        if (count + additionalCount > subscription.Plan.MaxProducts)
        {
            var msg = additionalCount > 1
                ? $"Adding {additionalCount} items would exceed your plan product limit ({count}/{subscription.Plan.MaxProducts}). Upgrade your plan to list more items."
                : $"Product limit ({subscription.Plan.MaxProducts}) reached for your plan.";
            throw new ValidationException(msg);
        }
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
