using System.Numerics;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SharpGLTF.Geometry;
using SharpGLTF.Geometry.VertexTypes;
using SharpGLTF.Materials;
using SharpGLTF.Scenes;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace ARSmartMenu.Infrastructure.Services;

/// <summary>
/// Dev MVP: builds a textured GLB from the owner's 4 angle photos (front/top/left/right).
/// </summary>
public class PhotoModelGenerationService : IPhotoModelGenerationService
{
    private const int MaxTextureSize = 1024;

    private static readonly PhotoAngleType[] RequiredAngles =
    [
        PhotoAngleType.Front,
        PhotoAngleType.Top,
        PhotoAngleType.Left,
        PhotoAngleType.Right,
    ];

    private readonly AppDbContext _db;
    private readonly IWebHostEnvironment _env;
    private readonly MediaUrlResolver _mediaUrls;
    private readonly ILogger<PhotoModelGenerationService> _logger;
    private readonly string? _localRoot;

    public PhotoModelGenerationService(
        AppDbContext db,
        IWebHostEnvironment env,
        MediaUrlResolver mediaUrls,
        IConfiguration config,
        ILogger<PhotoModelGenerationService> logger)
    {
        _db = db;
        _env = env;
        _mediaUrls = mediaUrls;
        _logger = logger;
        _localRoot = config["Storage:LocalRoot"];
    }

    public async Task<PhotoModelGenerationResult?> TryGenerateFromProductAsync(
        Guid productId,
        Guid businessId,
        string productSlug,
        CancellationToken ct = default)
    {
        var photos = await _db.ProductPhotos
            .AsNoTracking()
            .Where(p => p.ProductId == productId)
            .ToListAsync(ct);

        var pathsByAngle = new Dictionary<PhotoAngleType, string>();
        foreach (var angle in RequiredAngles)
        {
            var photo = photos.FirstOrDefault(p => p.AngleType == angle);
            if (photo is null || string.IsNullOrWhiteSpace(photo.S3Key))
            {
                _logger.LogWarning(
                    "Photo-to-3D skipped for product {ProductId}: missing {Angle} photo",
                    productId, angle);
                return null;
            }

            var path = LocalMediaStorage.TryResolveFilePath(_env, photo.S3Key, _localRoot);
            if (path is null)
            {
                _logger.LogWarning(
                    "Photo-to-3D skipped for product {ProductId}: file missing for {Angle} ({Key})",
                    productId, angle, photo.S3Key);
                return null;
            }

            pathsByAngle[angle] = path;
        }

        try
        {
            var textures = new Dictionary<PhotoAngleType, Image<Rgba32>>();
            foreach (var (angle, path) in pathsByAngle)
            {
                var image = await Image.LoadAsync<Rgba32>(path, ct);
                image.Mutate(x => x.Resize(new ResizeOptions
                {
                    Mode = ResizeMode.Max,
                    Size = new Size(MaxTextureSize, MaxTextureSize),
                }));
                textures[angle] = image;
            }

            var glbBytes = BuildTexturedDishGlb(textures);
            foreach (var image in textures.Values)
                image.Dispose();

            var glbKey = StorageKeyBuilder.Glb(businessId, productSlug);
            var thumbKey = StorageKeyBuilder.Thumbnail(businessId, productSlug);

            await WriteBytesAsync(glbKey, glbBytes, ct);
            await WriteThumbnailAsync(thumbKey, pathsByAngle[PhotoAngleType.Front], ct);

            _logger.LogInformation(
                "Generated photo-based GLB for product {ProductId} ({Bytes} bytes)",
                productId, glbBytes.Length);

            return new PhotoModelGenerationResult(
                glbKey,
                _mediaUrls.Resolve(glbKey),
                glbBytes.Length,
                thumbKey,
                _mediaUrls.Resolve(thumbKey));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Photo-to-3D generation failed for product {ProductId}", productId);
            return null;
        }
    }

    public async Task<bool> TryRegeneratePublishedProductAsync(Guid productId, CancellationToken ct = default)
    {
        var product = await _db.Products
            .Include(p => p.Photos)
            .Include(p => p.Model3d)
            .Include(p => p.QrCodes.Where(q => q.IsActive))
            .FirstOrDefaultAsync(p => p.Id == productId, ct);

        if (product is null || product.Status != ProductStatus.Live)
            return false;

        var slug = product.QrCodes.FirstOrDefault()?.Slug
            ?? $"{QrCodeService.Slugify(product.Name)}-live";

        var generated = await TryGenerateFromProductAsync(
            product.Id,
            product.BusinessId,
            slug,
            ct);

        if (generated is null)
            return false;

        if (product.Model3d is not null)
        {
            product.Model3d.GlbUrl = generated.GlbPublicUrl;
            product.Model3d.GlbS3Key = generated.GlbStorageKey;
            product.Model3d.GlbSizeBytes = (int)generated.GlbSizeBytes;
            product.Model3d.UpdatedAt = DateTime.UtcNow;
        }

        var asset = await _db.ModelAssets
            .Include(m => m.ProcessingJob)
            .Where(m => m.ProcessingJob.ProductId == productId)
            .OrderByDescending(m => m.CreatedAt)
            .FirstOrDefaultAsync(ct);

        if (asset is not null)
        {
            asset.GlbStorageKey = generated.GlbStorageKey;
            asset.GlbCdnUrl = generated.GlbPublicUrl;
            asset.GlbSizeBytes = generated.GlbSizeBytes;
            asset.ThumbnailStorageKey = generated.ThumbnailStorageKey;
            asset.ThumbnailCdnUrl = generated.ThumbnailPublicUrl;
            asset.UpdatedAt = DateTime.UtcNow;
        }

        product.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        return true;
    }

    private async Task WriteBytesAsync(string storageKey, byte[] bytes, CancellationToken ct)
    {
        var fullPath = LocalMediaStorage.TryResolveFilePath(_env, storageKey, _localRoot)
            ?? GetWritePath(storageKey);

        var directory = Path.GetDirectoryName(fullPath)
            ?? throw new InvalidOperationException("Invalid storage path.");
        Directory.CreateDirectory(directory);
        await File.WriteAllBytesAsync(fullPath, bytes, ct);
    }

    private async Task WriteThumbnailAsync(string storageKey, string sourcePhotoPath, CancellationToken ct)
    {
        using var image = await Image.LoadAsync<Rgba32>(sourcePhotoPath, ct);
        image.Mutate(x => x.Resize(new ResizeOptions
        {
            Mode = ResizeMode.Crop,
            Size = new Size(512, 512),
        }));

        var fullPath = GetWritePath(storageKey);
        var directory = Path.GetDirectoryName(fullPath)
            ?? throw new InvalidOperationException("Invalid storage path.");
        Directory.CreateDirectory(directory);
        await image.SaveAsJpegAsync(fullPath, ct);
    }

    private string GetWritePath(string storageKey)
    {
        var root = LocalMediaStorage.GetUploadRoot(_env, _localRoot);
        var normalizedKey = storageKey.Replace('\\', '/').TrimStart('/');
        return Path.Combine(root, normalizedKey.Replace('/', Path.DirectorySeparatorChar));
    }

    private static byte[] BuildTexturedDishGlb(IReadOnlyDictionary<PhotoAngleType, Image<Rgba32>> textures)
    {
        var frontMat = CreateMaterial(textures[PhotoAngleType.Front], "front.jpg");
        var topMat = CreateMaterial(textures[PhotoAngleType.Top], "top.jpg");
        var leftMat = CreateMaterial(textures[PhotoAngleType.Left], "left.jpg");
        var rightMat = CreateMaterial(textures[PhotoAngleType.Right], "right.jpg");

        var mesh = new MeshBuilder<VertexPosition, VertexTexture1>("dish");

        const float halfWidth = 0.12f;
        const float halfHeight = 0.04f;
        const float halfDepth = 0.12f;

        // Front (+Z)
        AddQuad(mesh, frontMat,
            new Vector3(-halfWidth, -halfHeight, halfDepth),
            new Vector3(halfWidth, -halfHeight, halfDepth),
            new Vector3(halfWidth, halfHeight, halfDepth),
            new Vector3(-halfWidth, halfHeight, halfDepth));

        // Back (-Z) — reuse front texture for a closed box
        AddQuad(mesh, frontMat,
            new Vector3(halfWidth, -halfHeight, -halfDepth),
            new Vector3(-halfWidth, -halfHeight, -halfDepth),
            new Vector3(-halfWidth, halfHeight, -halfDepth),
            new Vector3(halfWidth, halfHeight, -halfDepth));

        // Top (+Y)
        AddQuad(mesh, topMat,
            new Vector3(-halfWidth, halfHeight, halfDepth),
            new Vector3(halfWidth, halfHeight, halfDepth),
            new Vector3(halfWidth, halfHeight, -halfDepth),
            new Vector3(-halfWidth, halfHeight, -halfDepth));

        // Bottom (-Y) — subtle dark base
        var baseMat = new MaterialBuilder()
            .WithDoubleSide(true)
            .WithMetallicRoughnessShader()
            .WithBaseColor(new Vector4(0.15f, 0.12f, 0.1f, 1f));
        AddQuad(mesh, baseMat,
            new Vector3(-halfWidth, -halfHeight, -halfDepth),
            new Vector3(halfWidth, -halfHeight, -halfDepth),
            new Vector3(halfWidth, -halfHeight, halfDepth),
            new Vector3(-halfWidth, -halfHeight, halfDepth));

        // Left (-X)
        AddQuad(mesh, leftMat,
            new Vector3(-halfWidth, -halfHeight, -halfDepth),
            new Vector3(-halfWidth, -halfHeight, halfDepth),
            new Vector3(-halfWidth, halfHeight, halfDepth),
            new Vector3(-halfWidth, halfHeight, -halfDepth));

        // Right (+X)
        AddQuad(mesh, rightMat,
            new Vector3(halfWidth, -halfHeight, halfDepth),
            new Vector3(halfWidth, -halfHeight, -halfDepth),
            new Vector3(halfWidth, halfHeight, -halfDepth),
            new Vector3(halfWidth, halfHeight, halfDepth));

        var scene = new SceneBuilder();
        scene.AddRigidMesh(mesh, Matrix4x4.Identity);

        var model = scene.ToGltf2();
        var glb = model.WriteGLB();
        return glb.Array is { } array ? array : glb.ToArray();
    }

    private static MaterialBuilder CreateMaterial(Image<Rgba32> texture, string name)
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"armenu-{Guid.NewGuid():N}.jpg");
        texture.SaveAsJpeg(tempPath);
        return new MaterialBuilder(name)
            .WithDoubleSide(true)
            .WithMetallicRoughnessShader()
            .WithChannelImage(KnownChannel.BaseColor, tempPath);
    }

    private static void AddQuad(
        MeshBuilder<VertexPosition, VertexTexture1> mesh,
        MaterialBuilder material,
        Vector3 v0,
        Vector3 v1,
        Vector3 v2,
        Vector3 v3)
    {
        var prim = mesh.UsePrimitive(material);
        prim.AddTriangle(
            (new VertexPosition(v0), new VertexTexture1(new Vector2(0, 1))),
            (new VertexPosition(v1), new VertexTexture1(new Vector2(1, 1))),
            (new VertexPosition(v2), new VertexTexture1(new Vector2(1, 0))));
        prim.AddTriangle(
            (new VertexPosition(v0), new VertexTexture1(new Vector2(0, 1))),
            (new VertexPosition(v2), new VertexTexture1(new Vector2(1, 0))),
            (new VertexPosition(v3), new VertexTexture1(new Vector2(0, 0))));
    }
}
