using ARSmartMenu.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Persistence;

public partial class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // Core SaaS entities (from backend specification)
    public DbSet<User> Users => Set<User>();
    public DbSet<Business> Businesses => Set<Business>();
    public DbSet<SubscriptionPlan> SubscriptionPlans => Set<SubscriptionPlan>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ProductPhoto> ProductPhotos => Set<ProductPhoto>();
    public DbSet<Model3d> Models3d => Set<Model3d>();
    public DbSet<QrCode> QrCodes => Set<QrCode>();
    public DbSet<OtpRecord> OtpRecords => Set<OtpRecord>();
    public DbSet<RevokedToken> RevokedTokens => Set<RevokedToken>();
    public DbSet<ArScanEvent> ArScanEvents => Set<ArScanEvent>();
    public DbSet<ArViewEvent> ArViewEvents => Set<ArViewEvent>();
    public DbSet<AppNotification> Notifications => Set<AppNotification>();

    // Phase 4 pipeline entities
    public DbSet<Photographer> Photographers => Set<Photographer>();
    public DbSet<ShootBooking> ShootBookings => Set<ShootBooking>();
    public DbSet<MediaUpload> MediaUploads => Set<MediaUpload>();
    public DbSet<ProcessingJob> ProcessingJobs => Set<ProcessingJob>();
    public DbSet<ProcessingLog> ProcessingLogs => Set<ProcessingLog>();
    public DbSet<ModelAsset> ModelAssets => Set<ModelAsset>();
    public DbSet<ApprovalReview> ApprovalReviews => Set<ApprovalReview>();
    public DbSet<DeliveryIntegration> DeliveryIntegrations => Set<DeliveryIntegration>();
    public DbSet<EmbedLink> EmbedLinks => Set<EmbedLink>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        ConfigureSaaS(modelBuilder);
        ConfigurePipeline(modelBuilder);
    }

    partial void ConfigureSaaS(ModelBuilder modelBuilder);

    private static void ConfigurePipeline(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Photographer>(e =>
        {
            e.HasIndex(p => p.Phone).IsUnique();
            e.Property(p => p.Rating).HasPrecision(3, 2);
        });

        modelBuilder.Entity<ShootBooking>(e =>
        {
            e.HasIndex(b => b.Status);
            e.HasIndex(b => b.City);
            e.HasOne(b => b.Photographer)
                .WithMany(p => p.Bookings)
                .HasForeignKey(b => b.PhotographerId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<MediaUpload>(e =>
        {
            e.HasOne(m => m.Booking)
                .WithMany(b => b.MediaUploads)
                .HasForeignKey(m => m.BookingId);
        });

        modelBuilder.Entity<ProcessingJob>(e =>
        {
            e.HasIndex(j => j.Status);
            e.HasOne(j => j.Booking)
                .WithMany(b => b.ProcessingJobs)
                .HasForeignKey(j => j.BookingId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(j => j.Product)
                .WithMany()
                .HasForeignKey(j => j.ProductId)
                .OnDelete(DeleteBehavior.SetNull);
            e.HasOne(j => j.MediaUpload)
                .WithMany()
                .HasForeignKey(j => j.MediaUploadId)
                .OnDelete(DeleteBehavior.SetNull);
            e.HasOne(j => j.ModelAsset)
                .WithOne(m => m.ProcessingJob)
                .HasForeignKey<ModelAsset>(m => m.ProcessingJobId);
            e.HasOne(j => j.Review)
                .WithOne(r => r.ProcessingJob)
                .HasForeignKey<ApprovalReview>(r => r.ProcessingJobId);
        });

        modelBuilder.Entity<ModelAsset>(e =>
        {
            e.HasIndex(m => new { m.BusinessId, m.ProductSlug }).IsUnique();
        });

        modelBuilder.Entity<EmbedLink>(e =>
        {
            e.HasIndex(l => l.Slug).IsUnique();
            e.HasOne(l => l.ModelAsset)
                .WithMany()
                .HasForeignKey(l => l.ModelAssetId);
        });

        modelBuilder.Entity<DeliveryIntegration>(e =>
        {
            e.HasIndex(i => new { i.BusinessId, i.Platform }).IsUnique();
        });
    }
}
