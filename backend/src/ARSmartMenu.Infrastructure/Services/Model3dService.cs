using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class Model3dService : IModel3dService
{
    private readonly AppDbContext _db;

    public Model3dService(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<Model3dSummaryDto>> ListForBusinessAsync(Guid businessId, CancellationToken ct = default)
    {
        var models = await _db.Models3d
            .AsNoTracking()
            .Include(m => m.Product)
            .Where(m => m.Product.BusinessId == businessId)
            .OrderByDescending(m => m.CreatedAt)
            .ToListAsync(ct);

        return models.Select(ProductService.MapModel).ToList();
    }

    public async Task<Model3dSummaryDto> GetByIdAsync(Guid businessId, Guid modelId, CancellationToken ct = default)
    {
        var model = await _db.Models3d
            .AsNoTracking()
            .Include(m => m.Product)
            .FirstOrDefaultAsync(m => m.Id == modelId && m.Product.BusinessId == businessId, ct)
            ?? throw new NotFoundException("3D model not found.");

        return ProductService.MapModel(model);
    }
}
