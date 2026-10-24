using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure.Jobs;
using ARSmartMenu.Infrastructure.Persistence;
using ARSmartMenu.Infrastructure.Services;
using ARSmartMenu.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ARSmartMenu.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Server=SAHIL\\mssqllocaldb;Database=ARSmartMenu;Trusted_Connection=True;TrustServerCertificate=True";

        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(connectionString));

        services.AddHttpContextAccessor();

        // Auth
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IOtpSender, MockOtpSender>();

        // SaaS
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        services.AddScoped<IBusinessService, BusinessService>();
        services.AddScoped<IProductService, ProductService>();
        services.AddScoped<IProductProcessingService, ProductProcessingService>();
        services.AddScoped<ISubscriptionService, SubscriptionService>();
        services.AddScoped<IQrCodeService, QrCodeService>();
        services.AddScoped<IAnalyticsService, AnalyticsService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddScoped<IPublicArService, PublicArService>();
        services.AddScoped<IModel3dService, Model3dService>();
        services.AddScoped<INotificationService, NotificationService>();

        // Storage — swap MockStorageService for AwsS3StorageService in production
        services.AddScoped<IStorageService, MockStorageService>();
        services.AddSingleton<MediaUrlResolver>();

        // Application services
        services.AddScoped<IPhotographerService, PhotographerService>();
        services.AddScoped<IBookingService, BookingService>();
        services.AddScoped<IMediaUploadService, MediaUploadService>();
        services.AddScoped<ProcessingQueueService>();
        services.AddScoped<IProcessingQueueService>(sp => sp.GetRequiredService<ProcessingQueueService>());
        services.AddScoped<IQualityReviewService, QualityReviewService>();
        services.AddScoped<IIntegrationService, IntegrationService>();
        services.AddScoped<IExternalToolIngestionService, ExternalToolIngestionService>();
        services.AddScoped<IPhotoModelGenerationService, PhotoModelGenerationService>();

        // Hangfire jobs
        services.AddScoped<PipelineJobRunner>();

        return services;
    }
}
