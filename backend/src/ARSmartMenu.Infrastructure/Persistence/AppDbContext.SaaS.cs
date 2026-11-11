using ARSmartMenu.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ARSmartMenu.Infrastructure.Persistence;

public partial class AppDbContext
{
    partial void ConfigureSaaS(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(u => u.MobileNumber).IsUnique();
        });

        modelBuilder.Entity<Business>(e =>
        {
            e.HasIndex(b => b.OwnerId);
            e.HasIndex(b => b.Status);
            e.HasOne(b => b.Owner)
                .WithMany(u => u.Businesses)
                .HasForeignKey(b => b.OwnerId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(b => b.ApprovedBy)
                .WithMany()
                .HasForeignKey(b => b.ApprovedById)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<SubscriptionPlan>(e =>
        {
            e.HasIndex(p => p.Slug).IsUnique();
        });

        modelBuilder.Entity<Subscription>(e =>
        {
            e.HasIndex(s => s.BusinessId);
            e.HasIndex(s => s.Status);
            e.HasOne(s => s.Business)
                .WithMany(b => b.Subscriptions)
                .HasForeignKey(s => s.BusinessId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(s => s.Plan)
                .WithMany(p => p.Subscriptions)
                .HasForeignKey(s => s.PlanId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Product>(e =>
        {
            e.HasIndex(p => p.BusinessId);
            e.HasIndex(p => p.Status);
            e.HasIndex(p => new { p.SoldOutToday, p.SoldOutDate });
            e.HasOne(p => p.Business)
                .WithMany(b => b.Products)
                .HasForeignKey(p => p.BusinessId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ProductPhoto>(e =>
        {
            e.HasIndex(p => p.ProductId);
            e.HasOne(p => p.Product)
                .WithMany(pr => pr.Photos)
                .HasForeignKey(p => p.ProductId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Model3d>(e =>
        {
            e.HasIndex(m => m.ProductId).IsUnique();
            e.HasIndex(m => m.ProcessingStatus);
            e.HasOne(m => m.Product)
                .WithOne(p => p.Model3d)
                .HasForeignKey<Model3d>(m => m.ProductId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(m => m.ReviewedBy)
                .WithMany()
                .HasForeignKey(m => m.ReviewedById)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<QrCode>(e =>
        {
            e.HasIndex(q => q.Slug).IsUnique();
            e.HasIndex(q => q.BusinessId);
            e.HasOne(q => q.Business)
                .WithMany(b => b.QrCodes)
                .HasForeignKey(q => q.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(q => q.Product)
                .WithMany(p => p.QrCodes)
                .HasForeignKey(q => q.ProductId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<OtpRecord>(e =>
        {
            e.HasIndex(o => o.MobileNumber);
            e.HasIndex(o => o.ExpiresAt);
        });

        modelBuilder.Entity<RevokedToken>(e =>
        {
            e.HasIndex(r => r.TokenId).IsUnique();
            e.HasIndex(r => r.ExpiresAt);
        });

        modelBuilder.Entity<ArScanEvent>(e =>
        {
            e.HasIndex(s => s.BusinessId);
            e.HasIndex(s => s.ProductId);
            e.HasIndex(s => s.CreatedAt);
            e.HasOne(s => s.QrCode)
                .WithMany()
                .HasForeignKey(s => s.QrCodeId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(s => s.Business)
                .WithMany()
                .HasForeignKey(s => s.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(s => s.Product)
                .WithMany()
                .HasForeignKey(s => s.ProductId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<ArViewEvent>(e =>
        {
            e.HasIndex(v => v.BusinessId);
            e.HasIndex(v => v.ProductId);
            e.HasIndex(v => v.CreatedAt);
            e.HasOne(v => v.QrCode)
                .WithMany()
                .HasForeignKey(v => v.QrCodeId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(v => v.Business)
                .WithMany()
                .HasForeignKey(v => v.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasOne(v => v.Product)
                .WithMany()
                .HasForeignKey(v => v.ProductId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<AppNotification>(e =>
        {
            e.HasIndex(n => n.BusinessId);
            e.HasIndex(n => n.CreatedAt);
            e.HasIndex(n => n.IsRead);
            e.HasOne(n => n.Business)
                .WithMany()
                .HasForeignKey(n => n.BusinessId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(n => n.Product)
                .WithMany()
                .HasForeignKey(n => n.ProductId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }
}
