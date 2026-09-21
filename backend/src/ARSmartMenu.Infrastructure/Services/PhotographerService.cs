using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class PhotographerService : IPhotographerService
{
    private readonly AppDbContext _db;

    public PhotographerService(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<PhotographerDto>> GetAllAsync(CancellationToken ct = default)
    {
        var items = await _db.Photographers
            .OrderByDescending(p => p.Rating)
            .ToListAsync(ct);
        return items.Select(ToDto).ToList();
    }

    public async Task<PhotographerDto?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var entity = await _db.Photographers.FindAsync([id], ct);
        return entity is null ? null : ToDto(entity);
    }

    public async Task<PhotographerDto> CreateAsync(CreatePhotographerRequest request, CancellationToken ct = default)
    {
        var entity = new Photographer
        {
            Name = request.Name,
            Phone = request.Phone,
            CityCoverage = request.CityCoverage,
        };
        _db.Photographers.Add(entity);
        await _db.SaveChangesAsync(ct);
        return ToDto(entity);
    }

    public async Task<PhotographerDto?> UpdateAsync(Guid id, UpdatePhotographerRequest request, CancellationToken ct = default)
    {
        var entity = await _db.Photographers.FindAsync([id], ct);
        if (entity is null) return null;

        if (request.Name is not null) entity.Name = request.Name;
        if (request.Phone is not null) entity.Phone = request.Phone;
        if (request.CityCoverage is not null) entity.CityCoverage = request.CityCoverage;
        if (request.Status.HasValue) entity.Status = request.Status.Value;
        if (request.IsActive.HasValue) entity.IsActive = request.IsActive.Value;
        entity.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);
        return ToDto(entity);
    }

    public async Task<IReadOnlyList<PhotographerDto>> GetAvailableInCityAsync(string city, CancellationToken ct = default)
    {
        var items = await _db.Photographers
            .Where(p => p.IsActive && p.Status == PhotographerStatus.Available &&
                        p.CityCoverage.Contains(city))
            .ToListAsync(ct);
        return items.Select(ToDto).ToList();
    }

    private static PhotographerDto ToDto(Photographer p) => new(
        p.Id, p.Name, p.Phone, p.CityCoverage, p.Status, p.Rating, p.CompletedShoots, p.IsActive);
}
