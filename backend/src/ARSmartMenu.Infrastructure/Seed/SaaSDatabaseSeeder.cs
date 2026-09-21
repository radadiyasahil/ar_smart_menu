using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Seed;

/// <summary>Seeds subscription plans and demo SaaS data for WebAR testing.</summary>
public static class SaaSDatabaseSeeder
{
    public const string DemoQrSlug = "demo-butter-chicken-x7k2";
    public const string DemoOwnerMobile = "9876543210";
    public const string AdminMobile = "9000000001";

    public static async Task SeedAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("SaaSDatabaseSeeder");

        await SeedPlansAsync(db, logger);
        await SeedDemoDataAsync(db, config, logger);
    }

    private static async Task SeedPlansAsync(AppDbContext db, ILogger logger)
    {
        if (await db.SubscriptionPlans.AnyAsync()) return;

        logger.LogInformation("Seeding subscription plans...");

        db.SubscriptionPlans.AddRange(
            new SubscriptionPlan
            {
                Name = "Starter",
                Slug = "starter",
                MonthlyPricePaise = 39900,
                YearlyPricePaise = 406920,
                MaxProducts = 20,
                IncludesShoot = false,
                ShootsPerYear = 0,
                DisplayOrder = 1,
            },
            new SubscriptionPlan
            {
                Name = "Growth",
                Slug = "growth",
                MonthlyPricePaise = 99900,
                YearlyPricePaise = 959040,
                MaxProducts = 100,
                IncludesShoot = true,
                ShootsPerYear = 1,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 2,
            },
            new SubscriptionPlan
            {
                Name = "Pro",
                Slug = "pro",
                MonthlyPricePaise = 249900,
                YearlyPricePaise = 2249100,
                MaxProducts = 999999,
                IncludesShoot = true,
                ShootsPerYear = 4,
                ApiIntegration = true,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 3,
            });

        await db.SaveChangesAsync();
        logger.LogInformation("Subscription plans seeded.");
    }

    private static async Task SeedDemoDataAsync(AppDbContext db, IConfiguration config, ILogger logger)
    {
        var existing = await db.QrCodes
            .Include(q => q.Product!)
                .ThenInclude(p => p.Model3d)
            .FirstOrDefaultAsync(q => q.Slug == DemoQrSlug);
        if (existing?.Product?.Model3d is { } model)
        {
            model.GlbUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.glb";
            model.UsdzUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.usdz";
            await db.SaveChangesAsync();
            return;
        }

        if (await db.QrCodes.AnyAsync(q => q.Slug == DemoQrSlug)) return;

        logger.LogInformation("Seeding demo business, product, model, and QR for WebAR...");

        var cdnBase = config["Storage:MockBaseUrl"] ?? "https://cdn.ar-smartmenu.com";
        var webArBase = config["WebAr:BaseUrl"] ?? "https://ar.ar-smartmenu.com";

        var adminUser = await db.Users.FirstOrDefaultAsync(u => u.MobileNumber == AdminMobile);
        if (adminUser is null)
        {
            adminUser = new User
            {
                MobileNumber = AdminMobile,
                WhatsAppNumber = AdminMobile,
                FullName = "Platform Admin",
                IsAdmin = true,
                KycStatus = KycStatus.Verified,
            };
            db.Users.Add(adminUser);
        }
        else
        {
            adminUser.IsAdmin = true;
        }

        var owner = await db.Users.FirstOrDefaultAsync(u => u.MobileNumber == DemoOwnerMobile);
        if (owner is null)
        {
            owner = new User
            {
                MobileNumber = DemoOwnerMobile,
                WhatsAppNumber = DemoOwnerMobile,
                FullName = "Demo Restaurant Owner",
                KycStatus = KycStatus.Verified,
            };
            db.Users.Add(owner);
        }

        await db.SaveChangesAsync();

        var business = new Business
        {
            OwnerId = owner.Id,
            BusinessName = "Spice Garden Demo",
            BusinessType = BusinessType.Restaurant,
            City = "Mumbai",
            FullAddress = "12 Marine Drive, Mumbai, Maharashtra 400002",
            Status = BusinessStatus.Active,
            BankPennyVerified = true,
            ApprovedAt = DateTime.UtcNow,
            ApprovedById = adminUser.Id,
        };
        db.Businesses.Add(business);
        await db.SaveChangesAsync();

        var growthPlan = await db.SubscriptionPlans.FirstAsync(p => p.Slug == "growth");
        db.Subscriptions.Add(new Subscription
        {
            BusinessId = business.Id,
            PlanId = growthPlan.Id,
            BillingCycle = BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = DateTime.UtcNow.AddMonths(-1),
            EndsAt = DateTime.UtcNow.AddMonths(1),
        });

        var product = new Product
        {
            BusinessId = business.Id,
            Name = "Butter Chicken",
            Description = "Creamy tomato-based curry with tender chicken — demo WebAR dish.",
            PricePaise = 34900,
            Category = ProductCategory.MainCourse,
            VegStatus = VegStatus.NonVeg,
            IsBestseller = true,
            Status = ProductStatus.Live,
            DisplayOrder = 1,
        };
        db.Products.Add(product);
        await db.SaveChangesAsync();

        db.ProductPhotos.AddRange(
            new ProductPhoto
            {
                ProductId = product.Id,
                PhotoUrl = $"{cdnBase}/demo/butter-chicken-front.jpg",
                S3Key = $"raw-media/{business.Id}/demo-front.jpg",
                AngleType = PhotoAngleType.Front,
                SortOrder = 0,
            },
            new ProductPhoto
            {
                ProductId = product.Id,
                PhotoUrl = $"{cdnBase}/demo/butter-chicken-top.jpg",
                S3Key = $"raw-media/{business.Id}/demo-top.jpg",
                AngleType = PhotoAngleType.Top,
                SortOrder = 1,
            },
            new ProductPhoto
            {
                ProductId = product.Id,
                PhotoUrl = $"{cdnBase}/demo/butter-chicken-left.jpg",
                S3Key = $"raw-media/{business.Id}/demo-left.jpg",
                AngleType = PhotoAngleType.Left,
                SortOrder = 2,
            },
            new ProductPhoto
            {
                ProductId = product.Id,
                PhotoUrl = $"{cdnBase}/demo/butter-chicken-right.jpg",
                S3Key = $"raw-media/{business.Id}/demo-right.jpg",
                AngleType = PhotoAngleType.Right,
                SortOrder = 3,
            });

        db.Models3d.Add(new Model3d
        {
            ProductId = product.Id,
            GlbUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.glb",
            UsdzUrl = "https://modelviewer.dev/shared-assets/models/Hamburger.usdz",
            GlbS3Key = $"glb/{business.Id}/{DemoQrSlug}.glb",
            UsdzS3Key = $"usdz/{business.Id}/{DemoQrSlug}.usdz",
            ProcessingStatus = ModelProcessingStatus.Approved,
            ApprovedAt = DateTime.UtcNow,
            ProcessingCompletedAt = DateTime.UtcNow,
        });

        db.QrCodes.Add(new QrCode
        {
            BusinessId = business.Id,
            ProductId = product.Id,
            QrType = QrType.Product,
            Slug = DemoQrSlug,
            WebUrl = $"{webArBase.TrimEnd('/')}/{DemoQrSlug}",
            QrImageUrl = $"{webArBase.TrimEnd('/')}/qr/{DemoQrSlug}.png",
            QrImageS3Key = $"qr-codes/{business.Id}/{DemoQrSlug}.png",
            IsActive = true,
        });

        await db.SaveChangesAsync();
        logger.LogInformation(
            "Demo WebAR data seeded. Slug={Slug}, OwnerMobile={Mobile}, AdminMobile={Admin}",
            DemoQrSlug,
            DemoOwnerMobile,
            AdminMobile);
    }
}
