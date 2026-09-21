using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Seed;

/// <summary>Seeds demo data for MVP development and admin panel testing.</summary>
public static class DatabaseSeeder
{
    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("DatabaseSeeder");

        await db.Database.MigrateAsync();

        if (await db.Photographers.AnyAsync()) return;

        logger.LogInformation("Seeding demo pipeline data...");

        var photographers = new[]
        {
            new Photographer { Name = "Rajesh Kumar", Phone = "+919876543210", CityCoverage = "Mumbai,Pune", Rating = 4.7m, CompletedShoots = 45 },
            new Photographer { Name = "Priya Sharma", Phone = "+919876543211", CityCoverage = "Delhi,Noida", Rating = 4.5m, CompletedShoots = 32 },
        };
        db.Photographers.AddRange(photographers);

        var booking = new ShootBooking
        {
            BusinessId = Guid.Parse("11111111-1111-1111-1111-111111111111"),
            BusinessName = "Spice Garden Restaurant",
            Category = BusinessCategory.Restaurant,
            LocationAddress = "123 MG Road",
            City = "Mumbai",
            ScheduledAt = DateTime.UtcNow.AddDays(1),
            Status = BookingStatus.Assigned,
            PhotographerId = photographers[0].Id,
        };
        db.ShootBookings.Add(booking);

        db.DeliveryIntegrations.AddRange(
            new DeliveryIntegration
            {
                BusinessId = booking.BusinessId,
                Platform = IntegrationPlatform.Swiggy,
                IsEnabled = true,
                DeepLinkTemplate = "swiggy://dish/{slug}",
                EmbedBaseUrl = "https://ar.ar-smartmenu.com/dish",
            },
            new DeliveryIntegration
            {
                BusinessId = booking.BusinessId,
                Platform = IntegrationPlatform.Zomato,
                IsEnabled = true,
                DeepLinkTemplate = "zomato://order/{slug}",
            });

        await db.SaveChangesAsync();
        logger.LogInformation("Demo data seeded successfully");
    }
}
