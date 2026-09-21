using ARSmartMenu.Application.Common;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Domain.Entities;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace ARSmartMenu.Infrastructure.Services;

public class SubscriptionService : ISubscriptionService
{
    private readonly AppDbContext _db;
    private readonly string _razorpayKeyId;

    public SubscriptionService(AppDbContext db, IConfiguration config)
    {
        _db = db;
        _razorpayKeyId = config["Razorpay:KeyId"] ?? "rzp_test_mock";
    }

    public async Task<IReadOnlyList<SubscriptionPlanDto>> ListPlansAsync(CancellationToken ct = default)
    {
        var plans = await _db.SubscriptionPlans
            .AsNoTracking()
            .Where(p => p.IsActive)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync(ct);

        return plans.Select(MapPlan).ToList();
    }

    public async Task<SubscriptionDto?> GetMeAsync(Guid businessId, CancellationToken ct = default)
    {
        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        return subscription is null ? null : MapSubscription(subscription);
    }

    public async Task<CreateOrderResponse> CreateOrderAsync(
        Guid businessId,
        CreateOrderRequest request,
        CancellationToken ct = default)
    {
        var plan = await _db.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == request.PlanId && p.IsActive, ct)
            ?? throw new NotFoundException("Subscription plan not found.");

        var amount = request.BillingCycle == BillingCycle.Yearly
            ? plan.YearlyPricePaise
            : plan.MonthlyPricePaise;

        var orderId = $"order_mock_{Guid.NewGuid():N}"[..20];

        return new CreateOrderResponse(orderId, amount, "INR", _razorpayKeyId);
    }

    public async Task<VerifyPaymentResponse> VerifyPaymentAsync(
        Guid businessId,
        VerifyPaymentRequest request,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.RazorpayOrderId)
            || string.IsNullOrWhiteSpace(request.RazorpayPaymentId))
            throw new ValidationException("Payment details are required.");

        var plan = await _db.SubscriptionPlans
            .AsNoTracking()
            .OrderBy(p => p.DisplayOrder)
            .FirstOrDefaultAsync(ct)
            ?? throw new NotFoundException("No subscription plans configured.");

        var existing = await _db.Subscriptions
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .ToListAsync(ct);

        foreach (var sub in existing)
        {
            sub.Status = SubscriptionStatus.Cancelled;
            sub.CancelledAt = DateTime.UtcNow;
            sub.UpdatedAt = DateTime.UtcNow;
        }

        var startsAt = DateTime.UtcNow;
        var subscription = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = startsAt.AddMonths(1),
            RazorpaySubscriptionId = request.RazorpayPaymentId,
        };

        _db.Subscriptions.Add(subscription);
        await _db.SaveChangesAsync(ct);

        await _db.Entry(subscription).Reference(s => s.Plan).LoadAsync(ct);

        return new VerifyPaymentResponse(
            MapSubscription(subscription),
            "Payment verified (mock Razorpay).");
    }

    internal static SubscriptionPlanDto MapPlan(SubscriptionPlan plan) => new(
        plan.Id,
        plan.Name,
        plan.Slug,
        plan.MonthlyPricePaise,
        plan.YearlyPricePaise,
        plan.MaxProducts,
        plan.IncludesShoot,
        plan.ShootsPerYear,
        plan.ApiIntegration,
        plan.AnalyticsExport,
        plan.WhatsappSupport,
        plan.DisplayOrder);

    internal static SubscriptionDto MapSubscription(Subscription subscription) => new(
        subscription.Id,
        subscription.BusinessId,
        MapPlan(subscription.Plan),
        subscription.BillingCycle,
        subscription.Status,
        subscription.StartsAt,
        subscription.EndsAt,
        subscription.ShootsUsed,
        subscription.CancelledAt);
}
