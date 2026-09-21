using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Jobs;
using ARSmartMenu.Infrastructure.Persistence;
using Hangfire;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Services;

public class BookingService : IBookingService
{
    private readonly AppDbContext _db;

    public BookingService(AppDbContext db) => _db = db;

    public async Task<IReadOnlyList<BookingDto>> GetAllAsync(BookingFilter? filter = null, CancellationToken ct = default)
    {
        var query = _db.ShootBookings
            .Include(b => b.Photographer)
            .AsQueryable();

        if (filter?.Status is not null)
            query = query.Where(b => b.Status == filter.Status);
        if (!string.IsNullOrWhiteSpace(filter?.City))
            query = query.Where(b => b.City == filter.City);

        var items = await query
            .OrderByDescending(b => b.ScheduledAt)
            .ToListAsync(ct);
        return items.Select(ToDto).ToList();
    }

    public async Task<BookingDto?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var entity = await _db.ShootBookings
            .Include(b => b.Photographer)
            .FirstOrDefaultAsync(b => b.Id == id, ct);
        return entity is null ? null : ToDto(entity);
    }

    public async Task<BookingDto> CreateAsync(CreateBookingRequest request, CancellationToken ct = default)
    {
        var entity = new ShootBooking
        {
            BusinessId = request.BusinessId,
            BusinessName = request.BusinessName,
            Category = request.Category,
            LocationAddress = request.LocationAddress,
            City = request.City,
            ScheduledAt = request.ScheduledAt,
            Notes = request.Notes,
            Status = BookingStatus.Scheduled,
        };
        _db.ShootBookings.Add(entity);
        await _db.SaveChangesAsync(ct);
        return ToDto(entity);
    }

    public async Task<BookingDto?> AssignPhotographerAsync(Guid bookingId, Guid photographerId, CancellationToken ct = default)
    {
        var booking = await _db.ShootBookings.Include(b => b.Photographer)
            .FirstOrDefaultAsync(b => b.Id == bookingId, ct);
        var photographer = await _db.Photographers.FindAsync([photographerId], ct);

        if (booking is null || photographer is null) return null;

        booking.PhotographerId = photographerId;
        booking.Status = BookingStatus.Assigned;
        booking.UpdatedAt = DateTime.UtcNow;
        photographer.Status = PhotographerStatus.Busy;

        await _db.SaveChangesAsync(ct);
        return ToDto(booking);
    }

    public async Task<BookingDto?> UpdateStatusAsync(Guid bookingId, BookingStatus status, CancellationToken ct = default)
    {
        var booking = await _db.ShootBookings.Include(b => b.Photographer)
            .FirstOrDefaultAsync(b => b.Id == bookingId, ct);
        if (booking is null) return null;

        booking.Status = status;
        booking.UpdatedAt = DateTime.UtcNow;

        // When media uploaded, enqueue processing pipeline
        if (status == BookingStatus.Uploaded)
        {
            booking.Status = BookingStatus.Processing;
            BackgroundJob.Enqueue<PipelineJobRunner>(j => j.StartProcessingForBookingAsync(bookingId));
        }

        await _db.SaveChangesAsync(ct);
        return ToDto(booking);
    }

    private static BookingDto ToDto(ShootBooking b) => new(
        b.Id, b.BusinessId, b.BusinessName, b.Category, b.LocationAddress, b.City,
        b.ScheduledAt, b.Status, b.PhotographerId, b.Photographer?.Name, b.Notes);
}
