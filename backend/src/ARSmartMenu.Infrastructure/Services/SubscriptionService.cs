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

    private static readonly Dictionary<string, (string Description, int DurationDays, int BasePaise, int GstPaise, int TotalPaise, int? OrigPaise, int DiscPct, string Badge, List<string> Facilities)> PlanMetadata = new()
    {
        ["trial-7-days"] = (
            "Experience full 3D AR smart menu, kitchen ticketing, and table billing free for 7 days.",
            7,
            0,
            0,
            0,
            null,
            0,
            "Free Starter Trial",
            new() {
                "7 Days Full Feature Access",
                "Interactive 3D AR Menu Visualizer",
                "Up to 25 Dishes with 3D AR Models",
                "Table QR Codes with Standee PDF",
                "Live Kitchen Order Tickets (KOT)",
                "Table Billing POS & Round Tracking",
                "Direct Diner Kitchen Dispatch",
                "No Credit Card Required"
            }
        ),
        ["plan-3-months"] = (
            "Complete smart menu package for growing cafes and dine-in restaurants.",
            90,
            249900,
            44982,
            294882,
            null,
            0,
            "Quarterly Starter",
            new() {
                "90 Days All-Features Included",
                "Interactive 3D AR Menu on diner phones",
                "Up to 75 Dishes & Unlimited Categories",
                "Table QR Codes + High-Res Standee PDF",
                "Live Kitchen Order Tickets (KOT)",
                "Table Billing POS & Round Tracking",
                "Multi-Round Diner Tracking & Waiter Call",
                "WhatsApp Bill Receipts & Reports",
                "Standard WhatsApp & Email Support"
            }
        ),
        ["plan-6-months"] = (
            "Most popular half-yearly plan with bulk import and priority 3D dish processing.",
            180,
            399900,
            71982,
            471882,
            499900,
            20,
            "🔥 Most Popular (Save 20%)",
            new() {
                "180 Days Full Platform Access",
                "Up to 250 Dishes with Hero 3D AR Badges",
                "Bulk Menu CSV / Text Import (50+ dishes)",
                "Priority 3D Model Conversion & Approval",
                "Branded Table QR Codes + Table Standee PDF",
                "Complete Kitchen KOT & Table Billing POS",
                "Multi-Round Diner Live Tracking",
                "Customer Scans & Sales Analytics",
                "Save 20% compared to quarterly renewals",
                "Priority WhatsApp Support"
            }
        ),
        ["plan-1-year"] = (
            "Full enterprise suite with unlimited dishes, custom branding, and dedicated VIP support.",
            365,
            599900,
            107982,
            707882,
            999900,
            40,
            "👑 Best Value • Exclusive 40% OFF",
            new() {
                "365 Days Unlimited Platform Access",
                "Unlimited Dishes & Unlimited Categories",
                "Unlimited 3D AR Models with Auto-Approval",
                "Unlimited Custom Table QR Standee PDFs",
                "Complete Kitchen Order Ticketing (KOT)",
                "Full Table Billing POS & WhatsApp Receipts",
                "Multi-Round Diner Live Order Tracking",
                "Real-time Scan Heatmaps & Conversion Stats",
                "Exclusive 40% Discount (Only ₹499/mo effective)",
                "Dedicated Account Manager & VIP 24/7 Support",
                "Free 3D Food Photography Guidance & Setup"
            }
        )
    };

    private async Task EnsurePlansSeededAsync(CancellationToken ct)
    {
        var existingSlugs = await _db.SubscriptionPlans.Select(p => p.Slug).ToListAsync(ct);
        bool modified = false;

        if (!existingSlugs.Contains("trial-7-days"))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "7-Day Free Trial",
                Slug = "trial-7-days",
                MonthlyPricePaise = 0,
                YearlyPricePaise = 0,
                MaxProducts = 25,
                IncludesShoot = false,
                DisplayOrder = 1,
                IsActive = true,
            });
            modified = true;
        }

        if (!existingSlugs.Contains("plan-3-months"))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Starter (3 Months)",
                Slug = "plan-3-months",
                MonthlyPricePaise = 249900,
                YearlyPricePaise = 249900,
                MaxProducts = 75,
                IncludesShoot = false,
                DisplayOrder = 2,
                IsActive = true,
            });
            modified = true;
        }

        if (!existingSlugs.Contains("plan-6-months"))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Growth (6 Months)",
                Slug = "plan-6-months",
                MonthlyPricePaise = 399900,
                YearlyPricePaise = 399900,
                MaxProducts = 250,
                IncludesShoot = true,
                ShootsPerYear = 1,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 3,
                IsActive = true,
            });
            modified = true;
        }

        if (!existingSlugs.Contains("plan-1-year"))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Annual VIP (1 Year)",
                Slug = "plan-1-year",
                MonthlyPricePaise = 599900,
                YearlyPricePaise = 599900,
                MaxProducts = 999999,
                IncludesShoot = true,
                ShootsPerYear = 4,
                ApiIntegration = true,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 4,
                IsActive = true,
            });
            modified = true;
        }

        var oldPlans = await _db.SubscriptionPlans
            .Where(p => (p.Slug == "starter" || p.Slug == "growth" || p.Slug == "pro") && p.IsActive)
            .ToListAsync(ct);
        if (oldPlans.Count > 0)
        {
            foreach (var op in oldPlans) op.IsActive = false;
            modified = true;
        }

        if (modified)
        {
            await _db.SaveChangesAsync(ct);
        }
    }

    public async Task<IReadOnlyList<SubscriptionPlanDto>> ListPlansAsync(CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var plans = await _db.SubscriptionPlans
            .AsNoTracking()
            .Where(p => p.IsActive)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync(ct);

        return plans.Select(MapPlan).ToList();
    }

    public async Task<SubscriptionDto?> GetMeAsync(Guid businessId, CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        var hasUsedTrial = await _db.Subscriptions
            .AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);

        if (subscription is null)
        {
            return new SubscriptionDto(
                Id: Guid.Empty,
                BusinessId: businessId,
                Plan: null,
                BillingCycle: BillingCycle.Monthly,
                Status: SubscriptionStatus.Expired,
                StartsAt: DateTime.MinValue,
                EndsAt: DateTime.MinValue,
                ShootsUsed: 0,
                CancelledAt: null,
                DaysRemaining: 0,
                IsActive: false,
                IsTrial: false,
                HasUsedTrial: hasUsedTrial
            );
        }

        return MapSubscription(subscription, hasUsedTrial);
    }

    public async Task<SubscriptionDto> ActivateTrialAsync(Guid businessId, CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var hasUsedTrial = await _db.Subscriptions
            .AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);
        if (hasUsedTrial)
            throw new ValidationException("7-Day Free Trial has already been used by this business. Please select an affordable paid plan to continue.");

        var trialPlan = await _db.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.Slug == "trial-7-days" && p.IsActive, ct)
            ?? throw new NotFoundException("Trial plan configuration not found.");

        var existing = await _db.Subscriptions
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .ToListAsync(ct);
        foreach (var sub in existing)
        {
            sub.Status = SubscriptionStatus.Cancelled;
            sub.CancelledAt = DateTime.UtcNow;
            sub.UpdatedAt = DateTime.UtcNow;
        }

        var startsAt = DateTime.UtcNow;
        var endsAt = startsAt.AddDays(7);
        var newSub = new Subscription
        {
            BusinessId = businessId,
            PlanId = trialPlan.Id,
            BillingCycle = BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = endsAt,
            RazorpaySubscriptionId = "TRIAL_7_DAYS_ACTIVATED",
        };
        _db.Subscriptions.Add(newSub);

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business != null && (business.Status == BusinessStatus.PendingApproval || business.Status == BusinessStatus.Deactivated))
        {
            business.Status = BusinessStatus.Active;
            business.ApprovedAt ??= DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(ct);
        await _db.Entry(newSub).Reference(s => s.Plan).LoadAsync(ct);
        return MapSubscription(newSub, hasUsedTrial: true);
    }

    public async Task<SubscriptionDto> ActivatePlanAsync(
        Guid businessId,
        ActivatePlanRequest request,
        CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var plan = await _db.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.Id == request.PlanId && p.IsActive, ct)
            ?? throw new NotFoundException("Selected subscription plan not found.");

        int durationDays = 30;
        if (PlanMetadata.TryGetValue(plan.Slug, out var meta))
            durationDays = meta.DurationDays;
        else if (plan.Slug == "trial-7-days") durationDays = 7;
        else if (plan.Slug == "plan-3-months") durationDays = 90;
        else if (plan.Slug == "plan-6-months") durationDays = 180;
        else if (plan.Slug == "plan-1-year") durationDays = 365;

        var existing = await _db.Subscriptions
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .ToListAsync(ct);
        foreach (var oldSub in existing)
        {
            oldSub.Status = SubscriptionStatus.Cancelled;
            oldSub.CancelledAt = DateTime.UtcNow;
            oldSub.UpdatedAt = DateTime.UtcNow;
        }

        var startsAt = DateTime.UtcNow;
        var endsAt = startsAt.AddDays(durationDays);
        var newSub = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = durationDays >= 365 ? BillingCycle.Yearly : BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = endsAt,
            RazorpaySubscriptionId = request.TransactionRef ?? $"SIM_{request.PaymentMethod ?? "UPI"}_{Guid.NewGuid():N}"[..18],
        };
        _db.Subscriptions.Add(newSub);

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business != null && (business.Status == BusinessStatus.PendingApproval || business.Status == BusinessStatus.Deactivated))
        {
            business.Status = BusinessStatus.Active;
            business.ApprovedAt ??= DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(ct);
        await _db.Entry(newSub).Reference(s => s.Plan).LoadAsync(ct);

        var hasUsedTrial = await _db.Subscriptions.AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);
        return MapSubscription(newSub, hasUsedTrial: hasUsedTrial);
    }

    public async Task<SubscriptionDto> AdminGrantPlanAsync(
        Guid businessId,
        AdminGrantSubscriptionRequest request,
        CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var normalizedSlug = (request.PlanSlug ?? "").ToLower().Trim();
        if (normalizedSlug.Contains("1-year") || normalizedSlug.Contains("annual") || normalizedSlug.Contains("vip"))
            normalizedSlug = "plan-1-year";
        else if (normalizedSlug.Contains("6-month") || normalizedSlug.Contains("growth"))
            normalizedSlug = "plan-6-months";
        else if (normalizedSlug.Contains("3-month") || normalizedSlug.Contains("starter"))
            normalizedSlug = "plan-3-months";
        else if (normalizedSlug.Contains("trial") || normalizedSlug.Contains("7-day"))
            normalizedSlug = "trial-7-days";

        var plan = await _db.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.Slug.ToLower() == normalizedSlug && p.IsActive, ct)
            ?? await _db.SubscriptionPlans.FirstOrDefaultAsync(p => p.IsActive, ct)
            ?? throw new NotFoundException("Plan not found.");

        int durationDays = request.CustomDays ?? 30;
        if (request.CustomDays == null && PlanMetadata.TryGetValue(plan.Slug, out var meta))
            durationDays = meta.DurationDays;

        var existing = await _db.Subscriptions
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .ToListAsync(ct);
        foreach (var oldSub in existing)
        {
            oldSub.Status = SubscriptionStatus.Cancelled;
            oldSub.CancelledAt = DateTime.UtcNow;
            oldSub.UpdatedAt = DateTime.UtcNow;
        }

        var startsAt = DateTime.UtcNow;
        var endsAt = startsAt.AddDays(durationDays);
        var sub = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = durationDays >= 365 ? BillingCycle.Yearly : BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = endsAt,
            RazorpaySubscriptionId = $"ADMIN_GRANT_{request.Notes ?? "Manual"}"[..Math.Min(24, 12 + (request.Notes?.Length ?? 6))],
        };
        _db.Subscriptions.Add(sub);

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        if (business != null)
        {
            business.Status = BusinessStatus.Active;
        }

        await _db.SaveChangesAsync(ct);
        await _db.Entry(sub).Reference(s => s.Plan).LoadAsync(ct);

        var hasUsedTrial = await _db.Subscriptions.AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);
        return MapSubscription(sub, hasUsedTrial: hasUsedTrial);
    }

    public async Task<SubscriptionDto> AdminCancelPlanAsync(Guid businessId, CancellationToken ct = default)
    {
        var existing = await _db.Subscriptions
            .Include(s => s.Plan)
            .Where(s => s.BusinessId == businessId && s.Status == SubscriptionStatus.Active)
            .ToListAsync(ct);

        foreach (var sub in existing)
        {
            sub.Status = SubscriptionStatus.Expired;
            sub.EndsAt = DateTime.UtcNow;
            sub.CancelledAt = DateTime.UtcNow;
            sub.UpdatedAt = DateTime.UtcNow;
        }
        await _db.SaveChangesAsync(ct);

        var hasUsedTrial = await _db.Subscriptions.AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);
        var last = existing.OrderByDescending(s => s.EndsAt).FirstOrDefault();
        if (last != null)
        {
            return MapSubscription(last, hasUsedTrial);
        }

        return new SubscriptionDto(
            Id: Guid.Empty,
            BusinessId: businessId,
            Plan: null,
            BillingCycle: BillingCycle.Monthly,
            Status: SubscriptionStatus.Expired,
            StartsAt: DateTime.MinValue,
            EndsAt: DateTime.MinValue,
            ShootsUsed: 0,
            CancelledAt: DateTime.UtcNow,
            DaysRemaining: 0,
            IsActive: false,
            IsTrial: false,
            HasUsedTrial: hasUsedTrial
        );
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

        var hasUsedTrial = await _db.Subscriptions.AnyAsync(s => s.BusinessId == businessId && s.Plan.Slug == "trial-7-days", ct);
        return new VerifyPaymentResponse(
            MapSubscription(subscription, hasUsedTrial),
            "Payment verified (mock Razorpay).");
    }

    internal static SubscriptionPlanDto MapPlan(SubscriptionPlan plan)
    {
        PlanMetadata.TryGetValue(plan.Slug, out var meta);
        return new SubscriptionPlanDto(
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
            plan.DisplayOrder,
            Description: meta.Description ?? "Access our complete 3D AR Smart Menu & POS platform.",
            DurationDays: meta.DurationDays != 0 ? meta.DurationDays : 30,
            BasePricePaise: meta.BasePaise != 0 ? meta.BasePaise : plan.MonthlyPricePaise,
            GstPaise: meta.GstPaise != 0 ? meta.GstPaise : (int)(plan.MonthlyPricePaise * 0.18),
            TotalPricePaise: meta.TotalPaise != 0 ? meta.TotalPaise : (int)(plan.MonthlyPricePaise * 1.18),
            OriginalPricePaise: meta.OrigPaise,
            DiscountPercent: meta.DiscPct,
            Badge: meta.Badge,
            Facilities: meta.Facilities ?? new List<string> {
                "3D AR Menu Visualizer",
                "Table QR Codes & PDF",
                "Kitchen Order Tickets (KOT)",
                "Table Billing POS"
            });
    }

    internal static SubscriptionDto MapSubscription(Subscription subscription, bool hasUsedTrial)
    {
        var now = DateTime.UtcNow;
        var isActive = subscription.Status == SubscriptionStatus.Active && subscription.EndsAt > now;
        var daysRemaining = isActive ? Math.Max(0, (int)Math.Ceiling((subscription.EndsAt - now).TotalDays)) : 0;
        var status = isActive ? subscription.Status : SubscriptionStatus.Expired;
        var isTrial = subscription.Plan?.Slug == "trial-7-days";

        return new SubscriptionDto(
            subscription.Id,
            subscription.BusinessId,
            subscription.Plan != null ? MapPlan(subscription.Plan) : null,
            subscription.BillingCycle,
            status,
            subscription.StartsAt,
            subscription.EndsAt,
            subscription.ShootsUsed,
            subscription.CancelledAt,
            DaysRemaining: daysRemaining,
            IsActive: isActive,
            IsTrial: isTrial,
            HasUsedTrial: hasUsedTrial);
    }
}
