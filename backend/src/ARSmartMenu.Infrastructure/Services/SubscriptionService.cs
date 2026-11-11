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
        ["plan-1-month"] = (
            "Standard monthly access to interactive 3D AR menu, kitchen ticketing & table billing.",
            30,
            59900,
            10782,
            70682,
            null,
            0,
            "Monthly Standard (₹599/mo)",
            new() {
                "30 Days Full Platform Access",
                "Interactive 3D AR Menu on diner phones",
                "Up to 50 Dishes & Unlimited Categories",
                "Table QR Codes + Standee PDF",
                "Live Kitchen Order Tickets (KOT)",
                "Table Billing POS & Round Tracking",
                "Standard WhatsApp & Email Support"
            }
        ),
        ["plan-3-months"] = (
            "Complete smart menu package for growing cafes and dine-in restaurants.",
            90,
            149900,
            26982,
            176882,
            179700,
            17,
            "Quarterly Starter (Save 17%)",
            new() {
                "90 Days All-Features Included",
                "Interactive 3D AR Menu on diner phones",
                "Up to 75 Dishes & Unlimited Categories",
                "Table QR Codes + High-Res Standee PDF",
                "Live Kitchen Order Tickets (KOT)",
                "Table Billing POS & Round Tracking",
                "Multi-Round Diner Tracking & Waiter Call",
                "Save 17% compared to monthly rate (₹499/mo base)",
                "WhatsApp Bill Receipts & Reports",
                "Standard WhatsApp & Email Support"
            }
        ),
        ["plan-6-months"] = (
            "Most popular half-yearly plan with bulk import and priority 3D dish processing.",
            180,
            249900,
            44982,
            294882,
            359400,
            30,
            "🔥 Most Popular (Save 30%)",
            new() {
                "180 Days Full Platform Access",
                "Up to 250 Dishes with Hero 3D AR Badges",
                "Bulk Menu CSV / Text Import (50+ dishes)",
                "Priority 3D Model Conversion & Approval",
                "Branded Table QR Codes + Table Standee PDF",
                "Complete Kitchen KOT & Table Billing POS",
                "Multi-Round Diner Live Tracking",
                "Customer Scans & Sales Analytics",
                "Save 30% compared to monthly rate (Only ₹416/mo base)",
                "Priority WhatsApp Support"
            }
        ),
        ["plan-1-year"] = (
            "Full enterprise suite with unlimited dishes, custom branding, and dedicated VIP support.",
            365,
            399900,
            71982,
            471882,
            718800,
            44,
            "👑 Best Value • Exclusive 44% OFF",
            new() {
                "365 Days Unlimited Platform Access",
                "Unlimited Dishes & Unlimited Categories",
                "Unlimited 3D AR Models with Auto-Approval",
                "Unlimited Custom Table QR Standee PDFs",
                "Complete Kitchen Order Ticketing (KOT)",
                "Full Table Billing POS & WhatsApp Receipts",
                "Multi-Round Diner Live Order Tracking",
                "Real-time Scan Heatmaps & Conversion Stats",
                "Exclusive 44% Discount (Only ₹333/mo base)",
                "Dedicated Account Manager & VIP 24/7 Support",
                "Free 3D Food Photography Guidance & Setup"
            }
        )
    };

    private async Task EnsurePlansSeededAsync(CancellationToken ct)
    {
        var plans = await _db.SubscriptionPlans.ToListAsync(ct);
        var existingBySlug = plans.ToDictionary(p => p.Slug, p => p);
        bool modified = false;

        // Seed default plans if not already present
        if (!existingBySlug.TryGetValue("trial-7-days", out var trialPlan))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "7-Day Free Trial",
                Slug = "trial-7-days",
                MonthlyPricePaise = 0,
                YearlyPricePaise = 0,
                BasePricePaise = 0,
                GstPaise = 0,
                TotalPricePaise = 0,
                DiscountPercent = 0,
                DurationDays = 7,
                MaxProducts = 25,
                IncludesShoot = false,
                DisplayOrder = 1,
                IsActive = true,
                Description = "Experience full 3D AR smart menu, kitchen ticketing, and table billing free for 7 days.",
                Badge = "Free Starter Trial",
                FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(PlanMetadata["trial-7-days"].Facilities)
            });
            modified = true;
        }

        if (!existingBySlug.TryGetValue("plan-1-month", out var monthPlan))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Monthly Starter (1 Month)",
                Slug = "plan-1-month",
                MonthlyPricePaise = 59900,
                YearlyPricePaise = 59900,
                BasePricePaise = 59900,
                GstPaise = 10782,
                TotalPricePaise = 70682,
                DiscountPercent = 0,
                DurationDays = 30,
                MaxProducts = 50,
                IncludesShoot = false,
                DisplayOrder = 2,
                IsActive = true,
                Description = "Standard monthly access to interactive 3D AR menu, kitchen ticketing & table billing.",
                Badge = "Monthly Standard (₹599/mo)",
                FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(PlanMetadata["plan-1-month"].Facilities)
            });
            modified = true;
        }

        if (!existingBySlug.TryGetValue("plan-3-months", out var p3Plan))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Starter (3 Months)",
                Slug = "plan-3-months",
                MonthlyPricePaise = 149900,
                YearlyPricePaise = 149900,
                BasePricePaise = 149900,
                GstPaise = 26982,
                TotalPricePaise = 176882,
                OriginalPricePaise = 179700,
                DiscountPercent = 17,
                DurationDays = 90,
                MaxProducts = 75,
                IncludesShoot = false,
                DisplayOrder = 3,
                IsActive = true,
                Description = "Complete smart menu package for growing cafes and dine-in restaurants.",
                Badge = "Quarterly Starter (Save 17%)",
                FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(PlanMetadata["plan-3-months"].Facilities)
            });
            modified = true;
        }

        if (!existingBySlug.TryGetValue("plan-6-months", out var p6Plan))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Growth (6 Months)",
                Slug = "plan-6-months",
                MonthlyPricePaise = 249900,
                YearlyPricePaise = 249900,
                BasePricePaise = 249900,
                GstPaise = 44982,
                TotalPricePaise = 294882,
                OriginalPricePaise = 359400,
                DiscountPercent = 30,
                DurationDays = 180,
                MaxProducts = 250,
                IncludesShoot = true,
                ShootsPerYear = 1,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 4,
                IsActive = true,
                Description = "Most popular half-yearly plan with bulk import and priority 3D dish processing.",
                Badge = "🔥 Most Popular (Save 30%)",
                FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(PlanMetadata["plan-6-months"].Facilities)
            });
            modified = true;
        }

        if (!existingBySlug.TryGetValue("plan-1-year", out var p1yPlan))
        {
            _db.SubscriptionPlans.Add(new SubscriptionPlan
            {
                Name = "Annual VIP (1 Year)",
                Slug = "plan-1-year",
                MonthlyPricePaise = 399900,
                YearlyPricePaise = 399900,
                BasePricePaise = 399900,
                GstPaise = 71982,
                TotalPricePaise = 471882,
                OriginalPricePaise = 718800,
                DiscountPercent = 44,
                DurationDays = 365,
                MaxProducts = 999999,
                IncludesShoot = true,
                ShootsPerYear = 4,
                ApiIntegration = true,
                AnalyticsExport = true,
                WhatsappSupport = true,
                DisplayOrder = 5,
                IsActive = true,
                Description = "Full enterprise suite with unlimited dishes, custom branding, and dedicated VIP support.",
                Badge = "👑 Best Value • Exclusive 44% OFF",
                FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(PlanMetadata["plan-1-year"].Facilities)
            });
            modified = true;
        }

        // Sync metadata fields to DB columns for any existing plans missing them
        foreach (var p in plans)
        {
            if (PlanMetadata.TryGetValue(p.Slug, out var meta))
            {
                bool planMod = false;
                if (string.IsNullOrEmpty(p.Description)) { p.Description = meta.Description; planMod = true; }
                if (p.DurationDays == 0) { p.DurationDays = meta.DurationDays; planMod = true; }
                if (p.BasePricePaise == 0 && meta.BasePaise > 0) { p.BasePricePaise = meta.BasePaise; planMod = true; }
                if (p.GstPaise == 0 && meta.GstPaise > 0) { p.GstPaise = meta.GstPaise; planMod = true; }
                if (p.TotalPricePaise == 0 && meta.TotalPaise > 0) { p.TotalPricePaise = meta.TotalPaise; planMod = true; }
                if (p.OriginalPricePaise == null && meta.OrigPaise != null) { p.OriginalPricePaise = meta.OrigPaise; planMod = true; }
                if (p.DiscountPercent == 0 && meta.DiscPct > 0) { p.DiscountPercent = meta.DiscPct; planMod = true; }
                if (string.IsNullOrEmpty(p.Badge) && !string.IsNullOrEmpty(meta.Badge)) { p.Badge = meta.Badge; planMod = true; }
                if (string.IsNullOrEmpty(p.FacilitiesJson) && meta.Facilities != null) { p.FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(meta.Facilities); planMod = true; }
                if (planMod) modified = true;
            }
        }

        // Deactivate old legacy plans if any
        var oldPlans = plans
            .Where(p => (p.Slug == "starter" || p.Slug == "growth" || p.Slug == "pro") && p.IsActive)
            .ToList();
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
            .Where(p => p.IsActive && !p.IsDeleted)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync(ct);

        return plans.Select(MapPlan).ToList();
    }

    public async Task<SubscriptionDto?> GetMeAsync(Guid businessId, Guid? userId = null, CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var business = await _db.Businesses.AsNoTracking().FirstOrDefaultAsync(b => b.Id == businessId, ct);
        var ownerId = userId ?? business?.OwnerId;

        // 1. Prioritize active, unexpired subscription for this business OR for any business owned by the same user account
        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Include(s => s.Business)
            .Where(s => (s.BusinessId == businessId || (ownerId.HasValue && s.Business.OwnerId == ownerId.Value))
                        && s.Status == SubscriptionStatus.Active
                        && s.EndsAt > DateTime.UtcNow)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        // 2. If no active, find the most recent one (trial or expired)
        if (subscription is null)
        {
            subscription = await _db.Subscriptions
                .AsNoTracking()
                .Include(s => s.Plan)
                .Include(s => s.Business)
                .Where(s => s.BusinessId == businessId || (ownerId.HasValue && s.Business.OwnerId == ownerId.Value))
                .OrderByDescending(s => s.EndsAt)
                .FirstOrDefaultAsync(ct);
        }

        var hasUsedTrial = await _db.Subscriptions
            .AnyAsync(s => (s.BusinessId == businessId || (ownerId.HasValue && s.Business.OwnerId == ownerId.Value))
                           && s.Plan.Slug == "trial-7-days", ct);

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

    public async Task<SubscriptionDto?> GetMeByOwnerAsync(Guid ownerId, CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var subscription = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Include(s => s.Business)
            .Where(s => s.Business.OwnerId == ownerId && s.Status == SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow)
            .OrderByDescending(s => s.EndsAt)
            .FirstOrDefaultAsync(ct);

        if (subscription is null)
        {
            subscription = await _db.Subscriptions
                .AsNoTracking()
                .Include(s => s.Plan)
                .Include(s => s.Business)
                .Where(s => s.Business.OwnerId == ownerId)
                .OrderByDescending(s => s.EndsAt)
                .FirstOrDefaultAsync(ct);
        }

        var hasUsedTrial = await _db.Subscriptions
            .AnyAsync(s => s.Business.OwnerId == ownerId && s.Plan.Slug == "trial-7-days", ct);

        if (subscription is null) return null;
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

        var ownerId = business?.OwnerId;
        if (ownerId.HasValue)
        {
            var otherBusinesses = await _db.Businesses
                .Where(b => b.OwnerId == ownerId.Value && (b.Status == BusinessStatus.PendingApproval || b.Status == BusinessStatus.Deactivated))
                .ToListAsync(ct);
            foreach (var ob in otherBusinesses)
            {
                ob.Status = BusinessStatus.Active;
                ob.ApprovedAt ??= DateTime.UtcNow;
            }
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
        else if (plan.Slug == "plan-1-month") durationDays = 30;
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
        else if (normalizedSlug.Contains("1-month") || normalizedSlug.Contains("monthly"))
            normalizedSlug = "plan-1-month";
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


    public async Task<IReadOnlyList<SubscriptionPlanDto>> AdminListAllPlansAsync(CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);

        var activeSubCounts = await _db.Subscriptions
            .Where(s => s.Status == SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow)
            .GroupBy(s => s.PlanId)
            .Select(g => new { PlanId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.PlanId, x => x.Count, ct);

        var plans = await _db.SubscriptionPlans
            .AsNoTracking()
            .Where(p => !p.IsDeleted)
            .OrderBy(p => p.DisplayOrder)
            .ToListAsync(ct);

        return plans.Select(p => MapPlan(p, activeSubCounts.GetValueOrDefault(p.Id, 0))).ToList();
    }

    public async Task<SubscriptionPlanDto> AdminCreatePlanAsync(CreateSubscriptionPlanRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationException("Plan name is required.");
        if (string.IsNullOrWhiteSpace(request.Slug))
            throw new ValidationException("Plan slug is required.");

        var slug = request.Slug.Trim().ToLowerInvariant();
        if (!System.Text.RegularExpressions.Regex.IsMatch(slug, @"^[a-z0-9-]+$"))
            throw new ValidationException("Plan slug can only contain lowercase alphanumeric characters and hyphens.");

        var exists = await _db.SubscriptionPlans.AnyAsync(p => p.Slug == slug && !p.IsDeleted, ct);
        if (exists)
            throw new ValidationException($"A subscription plan with slug '{slug}' already exists.");

        if (request.DurationDays <= 0)
            throw new ValidationException("Duration must be at least 1 day.");

        if (request.BasePricePaise < 0)
            throw new ValidationException("Base price cannot be negative.");

        if (request.DiscountPercent < 0 || request.DiscountPercent > 100)
            throw new ValidationException("Discount percentage must be between 0 and 100.");

        if (request.OriginalPricePaise.HasValue && request.OriginalPricePaise.Value < request.BasePricePaise)
            throw new ValidationException("Original price must be greater than or equal to the discounted base price.");

        var gstPaise = (int)Math.Round(request.BasePricePaise * 0.18);
        var totalPaise = request.BasePricePaise + gstPaise;

        var plan = new SubscriptionPlan
        {
            Name = request.Name.Trim(),
            Slug = slug,
            BasePricePaise = request.BasePricePaise,
            GstPaise = gstPaise,
            TotalPricePaise = totalPaise,
            MonthlyPricePaise = request.BasePricePaise,
            YearlyPricePaise = request.DurationDays >= 365 ? request.BasePricePaise : request.BasePricePaise * 12,
            OriginalPricePaise = request.OriginalPricePaise,
            DiscountPercent = request.DiscountPercent,
            DurationDays = request.DurationDays,
            MaxProducts = request.MaxProducts > 0 ? request.MaxProducts : 50,
            Description = request.Description?.Trim(),
            Badge = request.Badge?.Trim(),
            FacilitiesJson = request.Facilities != null && request.Facilities.Count > 0
                ? System.Text.Json.JsonSerializer.Serialize(request.Facilities)
                : null,
            IncludesShoot = request.IncludesShoot,
            ShootsPerYear = request.ShootsPerYear,
            ApiIntegration = request.ApiIntegration,
            AnalyticsExport = request.AnalyticsExport,
            WhatsappSupport = request.WhatsappSupport,
            DisplayOrder = request.DisplayOrder,
            IsActive = request.IsActive,
            IsDeleted = false
        };

        _db.SubscriptionPlans.Add(plan);
        await _db.SaveChangesAsync(ct);

        return MapPlan(plan, 0);
    }

    public async Task<SubscriptionPlanDto> AdminUpdatePlanAsync(Guid id, UpdateSubscriptionPlanRequest request, CancellationToken ct = default)
    {
        var plan = await _db.SubscriptionPlans.FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted, ct)
            ?? throw new NotFoundException("Subscription plan not found.");

        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationException("Plan name is required.");

        if (request.DurationDays <= 0)
            throw new ValidationException("Duration must be at least 1 day.");

        if (request.BasePricePaise < 0)
            throw new ValidationException("Base price cannot be negative.");

        if (request.DiscountPercent < 0 || request.DiscountPercent > 100)
            throw new ValidationException("Discount percentage must be between 0 and 100.");

        if (request.OriginalPricePaise.HasValue && request.OriginalPricePaise.Value < request.BasePricePaise)
            throw new ValidationException("Original price must be greater than or equal to the discounted base price.");

        if (!string.IsNullOrWhiteSpace(request.Slug))
        {
            var slug = request.Slug.Trim().ToLowerInvariant();
            if (slug != plan.Slug)
            {
                var exists = await _db.SubscriptionPlans.AnyAsync(p => p.Slug == slug && p.Id != id && !p.IsDeleted, ct);
                if (exists)
                    throw new ValidationException($"A subscription plan with slug '{slug}' already exists.");
                plan.Slug = slug;
            }
        }

        var gstPaise = (int)Math.Round(request.BasePricePaise * 0.18);
        var totalPaise = request.BasePricePaise + gstPaise;

        plan.Name = request.Name.Trim();
        plan.BasePricePaise = request.BasePricePaise;
        plan.GstPaise = gstPaise;
        plan.TotalPricePaise = totalPaise;
        plan.MonthlyPricePaise = request.BasePricePaise;
        plan.YearlyPricePaise = request.DurationDays >= 365 ? request.BasePricePaise : request.BasePricePaise * 12;
        plan.OriginalPricePaise = request.OriginalPricePaise;
        plan.DiscountPercent = request.DiscountPercent;
        plan.DurationDays = request.DurationDays;
        plan.MaxProducts = request.MaxProducts > 0 ? request.MaxProducts : 50;
        plan.Description = request.Description?.Trim();
        plan.Badge = request.Badge?.Trim();
        if (request.Facilities != null)
        {
            plan.FacilitiesJson = System.Text.Json.JsonSerializer.Serialize(request.Facilities);
        }
        plan.IncludesShoot = request.IncludesShoot;
        plan.ShootsPerYear = request.ShootsPerYear;
        plan.ApiIntegration = request.ApiIntegration;
        plan.AnalyticsExport = request.AnalyticsExport;
        plan.WhatsappSupport = request.WhatsappSupport;
        plan.DisplayOrder = request.DisplayOrder;
        plan.IsActive = request.IsActive;
        plan.UpdatedAt = DateTime.UtcNow;

        // Note: Existing business active subscriptions are left untouched to guarantee
        // that businesses currently on this plan remain running seamlessly with their purchased terms.
        await _db.SaveChangesAsync(ct);

        var subscriberCount = await _db.Subscriptions
            .CountAsync(s => s.PlanId == id && s.Status == SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);

        return MapPlan(plan, subscriberCount);
    }

    public async Task<bool> AdminDeletePlanAsync(Guid id, CancellationToken ct = default)
    {
        var plan = await _db.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundException("Subscription plan not found.");

        var hasSubscriptions = await _db.Subscriptions.AnyAsync(s => s.PlanId == id, ct);

        if (hasSubscriptions)
        {
            // REAL-LIFE PRODUCTION RULE:
            // Never hard-delete a plan that has active or past business subscriptions.
            // Soft-delete / archive it instead:
            // 1. New businesses will never see it or buy it.
            // 2. Existing active businesses will continue running without interruption until their plan expires!
            plan.IsDeleted = true;
            plan.IsActive = false;
            plan.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
            return true;
        }
        else
        {
            // Zero businesses have ever used this plan — can safely remove it completely
            _db.SubscriptionPlans.Remove(plan);
            await _db.SaveChangesAsync(ct);
            return true;
        }
    }

    public async Task<SubscriptionPlanDto> AdminTogglePlanStatusAsync(Guid id, CancellationToken ct = default)
    {
        var plan = await _db.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.Id == id && !p.IsDeleted, ct)
            ?? throw new NotFoundException("Subscription plan not found.");

        plan.IsActive = !plan.IsActive;
        plan.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        var subscriberCount = await _db.Subscriptions
            .CountAsync(s => s.PlanId == id && s.Status == SubscriptionStatus.Active && s.EndsAt > DateTime.UtcNow, ct);

        return MapPlan(plan, subscriberCount);
    }


    internal static SubscriptionPlanDto MapPlan(SubscriptionPlan plan, int subscriberCount = 0)
    {
        IReadOnlyList<string>? facilities = null;
        if (!string.IsNullOrEmpty(plan.FacilitiesJson))
        {
            try
            {
                facilities = System.Text.Json.JsonSerializer.Deserialize<List<string>>(plan.FacilitiesJson);
            }
            catch { }
        }

        if (facilities == null || facilities.Count == 0)
        {
            if (PlanMetadata.TryGetValue(plan.Slug, out var meta) && meta.Facilities != null)
            {
                facilities = meta.Facilities;
            }
            else
            {
                facilities = new List<string>
                {
                    $"{plan.DurationDays} Days Platform Access",
                    $"Up to {plan.MaxProducts} Dishes",
                    "3D AR Menu Visualizer",
                    "Table QR Codes & PDF",
                    "Live Kitchen Order Tickets (KOT)",
                    "Table Billing POS"
                };
            }
        }

        var basePrice = plan.BasePricePaise != 0 ? plan.BasePricePaise : plan.MonthlyPricePaise;
        var gstPrice = plan.GstPaise != 0 ? plan.GstPaise : (int)Math.Round(basePrice * 0.18);
        var totalPrice = plan.TotalPricePaise != 0 ? plan.TotalPricePaise : (basePrice + gstPrice);
        var duration = plan.DurationDays > 0 ? plan.DurationDays : (plan.Slug == "plan-1-year" ? 365 : plan.Slug == "trial-7-days" ? 7 : 30);

        string? desc = plan.Description;
        string? badge = plan.Badge;
        int? origPrice = plan.OriginalPricePaise;
        int discPct = plan.DiscountPercent;

        if (string.IsNullOrEmpty(desc) && PlanMetadata.TryGetValue(plan.Slug, out var fallbackMeta))
        {
            desc = fallbackMeta.Description;
            badge ??= fallbackMeta.Badge;
            origPrice ??= fallbackMeta.OrigPaise;
            if (discPct == 0) discPct = fallbackMeta.DiscPct;
        }

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
            Description: desc ?? "Access our complete 3D AR Smart Menu & POS platform.",
            DurationDays: duration,
            BasePricePaise: basePrice,
            GstPaise: gstPrice,
            TotalPricePaise: totalPrice,
            OriginalPricePaise: origPrice,
            DiscountPercent: discPct,
            Badge: badge,
            Facilities: facilities,
            IsActive: plan.IsActive && !plan.IsDeleted,
            SubscriberCount: subscriberCount);
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
