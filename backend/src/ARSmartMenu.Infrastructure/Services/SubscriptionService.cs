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
    private static decimal? _cachedGstRate;

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

    public async Task<decimal> GetGstRatePercentRawAsync(CancellationToken ct = default)
    {
        if (_cachedGstRate.HasValue)
            return _cachedGstRate.Value;

        var setting = await _db.SystemSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Key == "Billing.GstRatePercent", ct);

        if (setting != null && decimal.TryParse(setting.Value, out var parsedRate) && parsedRate >= 0)
        {
            _cachedGstRate = parsedRate;
            return parsedRate;
        }

        _cachedGstRate = 18.0m;
        return 18.0m;
    }

    public async Task<GstRateSettingDto> GetGstRateSettingAsync(CancellationToken ct = default)
    {
        var setting = await _db.SystemSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Key == "Billing.GstRatePercent", ct);

        var rate = (setting != null && decimal.TryParse(setting.Value, out var parsedRate) && parsedRate >= 0)
            ? parsedRate
            : 18.0m;

        _cachedGstRate = rate;
        var halfRate = Math.Round(rate / 2m, 2);

        return new GstRateSettingDto(
            GstRatePercent: rate,
            CgstRatePercent: halfRate,
            SgstRatePercent: halfRate,
            IgstRatePercent: rate,
            LastUpdated: setting?.UpdatedAt ?? setting?.CreatedAt,
            Description: setting?.Description ?? "GST percentage applied to subscription plans and customer invoices"
        );
    }

    public async Task<GstRateSettingDto> UpdateGstRateSettingAsync(decimal newRatePercent, CancellationToken ct = default)
    {
        if (newRatePercent < 0 || newRatePercent > 100)
            throw new ValidationException("GST rate must be between 0% and 100%.");

        var setting = await _db.SystemSettings
            .FirstOrDefaultAsync(s => s.Key == "Billing.GstRatePercent", ct);

        if (setting == null)
        {
            setting = new SystemSetting
            {
                Key = "Billing.GstRatePercent",
                Value = newRatePercent.ToString("0.##"),
                Description = "GST percentage applied to subscription plans and customer invoices",
                Group = "Billing"
            };
            _db.SystemSettings.Add(setting);
        }
        else
        {
            setting.Value = newRatePercent.ToString("0.##");
            setting.UpdatedAt = DateTime.UtcNow;
        }

        // Dynamically recalculate GstPaise and TotalPricePaise on all active subscription plans
        var plans = await _db.SubscriptionPlans.Where(p => !p.IsDeleted).ToListAsync(ct);
        foreach (var p in plans)
        {
            var basePaise = p.BasePricePaise > 0 ? p.BasePricePaise : p.MonthlyPricePaise;
            p.GstPaise = (int)Math.Round(basePaise * (double)(newRatePercent / 100m));
            p.TotalPricePaise = basePaise + p.GstPaise;
        }

        await _db.SaveChangesAsync(ct);
        _cachedGstRate = newRatePercent;

        var halfRate = Math.Round(newRatePercent / 2m, 2);
        return new GstRateSettingDto(
            GstRatePercent: newRatePercent,
            CgstRatePercent: halfRate,
            SgstRatePercent: halfRate,
            IgstRatePercent: newRatePercent,
            LastUpdated: setting.UpdatedAt ?? DateTime.UtcNow,
            Description: setting.Description
        );
    }

    public async Task<SupportContactSettingDto> GetSupportContactSettingAsync(CancellationToken ct = default)
    {
        var settings = await _db.SystemSettings
            .AsNoTracking()
            .Where(s => s.Key.StartsWith("Platform.Support"))
            .ToListAsync(ct);

        var whatsapp = settings.FirstOrDefault(s => s.Key == "Platform.SupportWhatsApp")?.Value ?? "+91 98765 43210";
        var email = settings.FirstOrDefault(s => s.Key == "Platform.SupportEmail")?.Value ?? "support@arsmartmenu.com";
        var phone = settings.FirstOrDefault(s => s.Key == "Platform.SupportPhone")?.Value ?? "+91 98765 43210";
        var helpMsg = settings.FirstOrDefault(s => s.Key == "Platform.SupportHelpMessage")?.Value ?? "For assistance, queries, or account updates, reach out via:";

        var latestUpdate = settings
            .Select(s => s.UpdatedAt ?? s.CreatedAt)
            .DefaultIfEmpty(DateTime.UtcNow)
            .Max();

        return new SupportContactSettingDto(
            WhatsAppNumber: whatsapp,
            Email: email,
            PhoneNumber: phone,
            HelpMessage: helpMsg,
            LastUpdated: latestUpdate
        );
    }

    public async Task<SupportContactSettingDto> UpdateSupportContactSettingAsync(UpdateSupportContactSettingRequest request, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.WhatsAppNumber))
            throw new ValidationException("WhatsApp support number is required.");
        if (string.IsNullOrWhiteSpace(request.Email))
            throw new ValidationException("Support email address is required.");

        var keysToUpdate = new Dictionary<string, (string Value, string Description)>
        {
            ["Platform.SupportWhatsApp"] = (request.WhatsAppNumber.Trim(), "Platform official WhatsApp support number"),
            ["Platform.SupportEmail"] = (request.Email.Trim(), "Platform official support email address"),
            ["Platform.SupportPhone"] = (string.IsNullOrWhiteSpace(request.PhoneNumber) ? request.WhatsAppNumber.Trim() : request.PhoneNumber.Trim(), "Platform official customer care phone number"),
            ["Platform.SupportHelpMessage"] = (string.IsNullOrWhiteSpace(request.HelpMessage) ? "For assistance, queries, or account updates, reach out via:" : request.HelpMessage.Trim(), "Instructional header message shown in app support dialog")
        };

        var existingSettings = await _db.SystemSettings
            .Where(s => s.Key.StartsWith("Platform.Support"))
            .ToListAsync(ct);

        var now = DateTime.UtcNow;
        foreach (var (key, (val, desc)) in keysToUpdate)
        {
            var s = existingSettings.FirstOrDefault(x => x.Key == key);
            if (s == null)
            {
                _db.SystemSettings.Add(new SystemSetting
                {
                    Key = key,
                    Value = val,
                    Description = desc,
                    Group = "Support",
                    CreatedAt = now,
                    UpdatedAt = now
                });
            }
            else
            {
                s.Value = val;
                s.Description = desc;
                s.UpdatedAt = now;
            }
        }

        await _db.SaveChangesAsync(ct);

        return new SupportContactSettingDto(
            WhatsAppNumber: keysToUpdate["Platform.SupportWhatsApp"].Value,
            Email: keysToUpdate["Platform.SupportEmail"].Value,
            PhoneNumber: keysToUpdate["Platform.SupportPhone"].Value,
            HelpMessage: keysToUpdate["Platform.SupportHelpMessage"].Value,
            LastUpdated: now
        );
    }

    public async Task<IReadOnlyList<SubscriptionPlanDto>> ListPlansAsync(CancellationToken ct = default)
    {
        await EnsurePlansSeededAsync(ct);
        await GetGstRatePercentRawAsync(ct);

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

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
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
            InvoiceNumber = GenerateInvoiceNumber(startsAt),
            BaseAmountPaise = 0,
            GstPaise = 0,
            TotalAmountPaise = 0,
            PaymentMethod = "Free Trial",
            PaymentRef = "TRIAL_7_DAYS_ACTIVATED",
            CustomerGstNumber = business?.GstNumber,
            CustomerBusinessName = business?.BusinessName,
            CustomerAddress = business != null ? $"{business.FullAddress}, {business.City}" : null,
            CustomerState = business?.City,
            SacCode = "998313",
        };
        _db.Subscriptions.Add(newSub);

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

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        var startsAt = DateTime.UtcNow;
        var endsAt = startsAt.AddDays(durationDays);
        var dynamicGstRate = await GetGstRatePercentRawAsync(ct);
        var basePaise = plan.BasePricePaise > 0 ? plan.BasePricePaise : plan.MonthlyPricePaise;
        var gstPaise = plan.GstPaise > 0 ? plan.GstPaise : (int)Math.Round(basePaise * (double)(dynamicGstRate / 100m));
        var totalPaise = plan.TotalPricePaise > 0 ? plan.TotalPricePaise : (basePaise + gstPaise);
        var payMethod = request.PaymentMethod ?? "UPI";
        var payRef = request.TransactionRef ?? $"SIM_{payMethod}_{Guid.NewGuid():N}"[..18];

        var newSub = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = durationDays >= 365 ? BillingCycle.Yearly : BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = endsAt,
            RazorpaySubscriptionId = payRef,
            InvoiceNumber = GenerateInvoiceNumber(startsAt),
            BaseAmountPaise = basePaise,
            GstPaise = gstPaise,
            TotalAmountPaise = totalPaise,
            PaymentMethod = payMethod,
            PaymentRef = payRef,
            CustomerGstNumber = business?.GstNumber,
            CustomerBusinessName = business?.BusinessName,
            CustomerAddress = business != null ? $"{business.FullAddress}, {business.City}" : null,
            CustomerState = business?.City,
            SacCode = "998313",
            GstRatePercent = dynamicGstRate,
        };
        _db.Subscriptions.Add(newSub);

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

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        var startsAt = DateTime.UtcNow;
        var endsAt = startsAt.AddDays(durationDays);
        var dynamicGstRate = await GetGstRatePercentRawAsync(ct);
        var basePaise = plan.BasePricePaise > 0 ? plan.BasePricePaise : plan.MonthlyPricePaise;
        var gstPaise = plan.GstPaise > 0 ? plan.GstPaise : (int)Math.Round(basePaise * (double)(dynamicGstRate / 100m));
        var totalPaise = plan.TotalPricePaise > 0 ? plan.TotalPricePaise : (basePaise + gstPaise);
        var payRef = $"ADMIN_GRANT_{request.Notes ?? "Manual"}"[..Math.Min(24, 12 + (request.Notes?.Length ?? 6))];

        var sub = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = durationDays >= 365 ? BillingCycle.Yearly : BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = endsAt,
            RazorpaySubscriptionId = payRef,
            InvoiceNumber = GenerateInvoiceNumber(startsAt),
            BaseAmountPaise = basePaise,
            GstPaise = gstPaise,
            TotalAmountPaise = totalPaise,
            PaymentMethod = "Admin Grant",
            PaymentRef = payRef,
            CustomerGstNumber = business?.GstNumber,
            CustomerBusinessName = business?.BusinessName,
            CustomerAddress = business != null ? $"{business.FullAddress}, {business.City}" : null,
            CustomerState = business?.City,
            SacCode = "998313",
            GstRatePercent = dynamicGstRate,
        };
        _db.Subscriptions.Add(sub);

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

        var business = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId, ct);
        var startsAt = DateTime.UtcNow;
        var dynamicGstRate = await GetGstRatePercentRawAsync(ct);
        var basePaise = plan.BasePricePaise > 0 ? plan.BasePricePaise : plan.MonthlyPricePaise;
        var gstPaise = plan.GstPaise > 0 ? plan.GstPaise : (int)Math.Round(basePaise * (double)(dynamicGstRate / 100m));
        var totalPaise = plan.TotalPricePaise > 0 ? plan.TotalPricePaise : (basePaise + gstPaise);

        var subscription = new Subscription
        {
            BusinessId = businessId,
            PlanId = plan.Id,
            BillingCycle = BillingCycle.Monthly,
            Status = SubscriptionStatus.Active,
            StartsAt = startsAt,
            EndsAt = startsAt.AddMonths(1),
            RazorpaySubscriptionId = request.RazorpayPaymentId,
            InvoiceNumber = GenerateInvoiceNumber(startsAt),
            BaseAmountPaise = basePaise,
            GstPaise = gstPaise,
            TotalAmountPaise = totalPaise,
            PaymentMethod = "Razorpay",
            PaymentRef = request.RazorpayPaymentId,
            CustomerGstNumber = business?.GstNumber,
            CustomerBusinessName = business?.BusinessName,
            CustomerAddress = business != null ? $"{business.FullAddress}, {business.City}" : null,
            CustomerState = business?.City,
            SacCode = "998313",
            GstRatePercent = dynamicGstRate,
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

        var dynamicGstRate = await GetGstRatePercentRawAsync(ct);
        var gstPaise = (int)Math.Round(request.BasePricePaise * (double)(dynamicGstRate / 100m));
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

        var dynamicGstRate = await GetGstRatePercentRawAsync(ct);
        var gstPaise = (int)Math.Round(request.BasePricePaise * (double)(dynamicGstRate / 100m));
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

        var dynamicRate = _cachedGstRate ?? 18.0m;
        var basePrice = plan.BasePricePaise != 0 ? plan.BasePricePaise : plan.MonthlyPricePaise;
        var gstPrice = plan.GstPaise != 0 ? plan.GstPaise : (int)Math.Round(basePrice * (double)(dynamicRate / 100m));
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
            SubscriberCount: subscriberCount,
            GstRatePercent: dynamicRate);
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

    public async Task<IReadOnlyList<SubscriptionHistoryItemDto>> GetSubscriptionHistoryAsync(Guid businessId, CancellationToken ct = default)
    {
        await GetGstRatePercentRawAsync(ct);
        var subs = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Include(s => s.Business)
            .Where(s => s.BusinessId == businessId)
            .OrderByDescending(s => s.StartsAt)
            .ThenByDescending(s => s.CreatedAt)
            .ToListAsync(ct);

        return subs.Select(MapHistoryItem).ToList();
    }

    public async Task<IReadOnlyList<SubscriptionHistoryItemDto>> AdminGetAllSubscriptionHistoryAsync(CancellationToken ct = default)
    {
        await GetGstRatePercentRawAsync(ct);
        var subs = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Include(s => s.Business)
            .OrderByDescending(s => s.StartsAt)
            .ThenByDescending(s => s.CreatedAt)
            .ToListAsync(ct);

        return subs.Select(MapHistoryItem).ToList();
    }

    public async Task<SubscriptionInvoiceDto> GetInvoiceAsync(
        Guid subscriptionId,
        Guid? requestingBusinessId = null,
        bool isAdmin = false,
        CancellationToken ct = default)
    {
        var sub = await _db.Subscriptions
            .AsNoTracking()
            .Include(s => s.Plan)
            .Include(s => s.Business)
                .ThenInclude(b => b.Owner)
            .FirstOrDefaultAsync(s => s.Id == subscriptionId, ct)
            ?? throw new NotFoundException("Subscription record not found.");

        if (!isAdmin && requestingBusinessId.HasValue && sub.BusinessId != requestingBusinessId.Value)
        {
            throw new UnauthorizedAccessException("You are not authorized to view this subscription invoice.");
        }

        var business = sub.Business;
        var owner = business?.Owner;
        var plan = sub.Plan;
        var isTrial = plan?.Slug == "trial-7-days" || (sub.BaseAmountPaise == 0 && sub.TotalAmountPaise == 0 && (plan == null || plan.BasePricePaise == 0));
        var dynamicRate = await GetGstRatePercentRawAsync(ct);
        var effectiveGstRate = (double)(sub.GstRatePercent > 0 ? sub.GstRatePercent : dynamicRate);

        var invoiceNum = !string.IsNullOrWhiteSpace(sub.InvoiceNumber)
            ? sub.InvoiceNumber
            : $"INV-{sub.CreatedAt:yyyyMM}-{sub.Id.ToString()[..6].ToUpper()}";

        var basePaise = sub.BaseAmountPaise > 0 
            ? sub.BaseAmountPaise 
            : (isTrial ? 0 : (plan?.BasePricePaise ?? plan?.MonthlyPricePaise ?? 0));
        var gstPaise = sub.GstPaise > 0 
            ? sub.GstPaise 
            : (isTrial ? 0 : (plan?.GstPaise ?? (int)Math.Round(basePaise * (effectiveGstRate / 100.0))));
        var totalPaise = sub.TotalAmountPaise > 0 
            ? sub.TotalAmountPaise 
            : (isTrial ? 0 : (plan?.TotalPricePaise ?? (basePaise + gstPaise)));

        var baseRupees = basePaise / 100.0;
        var gstRupees = gstPaise / 100.0;
        var totalRupees = totalPaise / 100.0;

        const string supplierStateCode = "24";
        const string supplierState = "Gujarat";

        var custGst = (sub.CustomerGstNumber ?? business?.GstNumber ?? string.Empty).Trim().ToUpper();
        var custStateCode = custGst.Length >= 2 && char.IsDigit(custGst[0]) && char.IsDigit(custGst[1])
            ? custGst[..2]
            : "24";

        var custState = GetStateNameFromCode(custStateCode, business?.City ?? "Gujarat");
        var isInterState = custStateCode != supplierStateCode;

        double cgstRupees = 0;
        double sgstRupees = 0;
        double igstRupees = 0;
        double cgstRate = 0;
        double sgstRate = 0;
        double igstRate = 0;

        if (!isTrial && totalRupees > 0)
        {
            if (isInterState)
            {
                igstRate = effectiveGstRate;
                igstRupees = gstRupees;
            }
            else
            {
                cgstRate = effectiveGstRate / 2.0;
                sgstRate = effectiveGstRate / 2.0;
                cgstRupees = Math.Round(gstRupees / 2.0, 2);
                sgstRupees = gstRupees - cgstRupees;
            }
        }

        var durationDays = (sub.EndsAt - sub.StartsAt).Days;
        if (durationDays <= 0) durationDays = plan?.DurationDays ?? 30;

        var amountInWords = isTrial || totalRupees <= 0 
            ? "Zero Rupees Only (Complimentary Free Trial)" 
            : ConvertAmountToWords(totalRupees);

        return new SubscriptionInvoiceDto(
            Id: sub.Id,
            BusinessId: sub.BusinessId,
            InvoiceNumber: invoiceNum,
            InvoiceDate: sub.CreatedAt != DateTime.MinValue ? sub.CreatedAt : sub.StartsAt,
            PlanName: plan?.Name ?? (isTrial ? "7-Day Free Trial" : "Custom Plan"),
            PlanSlug: plan?.Slug ?? "custom",
            BillingCycle: sub.BillingCycle.ToString(),
            Status: sub.Status.ToString(),
            StartsAt: sub.StartsAt,
            EndsAt: sub.EndsAt,
            DurationDays: durationDays,
            BaseAmountPaise: basePaise,
            GstPaise: gstPaise,
            TotalAmountPaise: totalPaise,
            BaseAmountRupees: baseRupees,
            GstRupees: gstRupees,
            TotalAmountRupees: totalRupees,
            CgstRupees: cgstRupees,
            SgstRupees: sgstRupees,
            IgstRupees: igstRupees,
            CgstRate: cgstRate,
            SgstRate: sgstRate,
            IgstRate: igstRate,
            IsInterState: isInterState,
            SacCode: sub.SacCode ?? "998313",
            PaymentMethod: sub.PaymentMethod ?? (isTrial ? "Free Trial" : "Online UPI / Card"),
            PaymentRef: sub.PaymentRef ?? sub.RazorpaySubscriptionId ?? "N/A",
            SupplierName: "AR Smart Menu Technologies Pvt. Ltd.",
            SupplierAddress: "Floor 4, Tech Park, S.G. Highway, Ahmedabad, Gujarat - 380054",
            SupplierGstNumber: "24AABCA1234F1Z9",
            SupplierPan: "AABCA1234F",
            SupplierState: supplierState,
            SupplierStateCode: supplierStateCode,
            SupplierEmail: "billing@arsmartmenu.com",
            SupplierPhone: "+91 98765 43210",
            CustomerBusinessName: sub.CustomerBusinessName ?? business?.BusinessName ?? "Valued Restaurant Client",
            CustomerOwnerName: owner?.FullName,
            CustomerEmail: null,
            CustomerPhone: owner?.MobileNumber ?? owner?.WhatsAppNumber,
            CustomerGstNumber: !string.IsNullOrWhiteSpace(custGst) ? custGst : null,
            CustomerAddress: sub.CustomerAddress ?? (business != null ? $"{business.FullAddress}, {business.City}" : "India"),
            CustomerCity: business?.City ?? "Ahmedabad",
            CustomerState: custState,
            CustomerStateCode: custStateCode,
            IsGstRegistered: !string.IsNullOrWhiteSpace(custGst),
            AmountInWords: amountInWords,
            PlaceOfSupply: $"{custState} ({custStateCode})",
            GstRatePercent: effectiveGstRate
        );
    }

    public async Task<string> GenerateInvoiceHtmlAsync(
        Guid subscriptionId,
        Guid? requestingBusinessId = null,
        bool isAdmin = false,
        CancellationToken ct = default)
    {
        var inv = await GetInvoiceAsync(subscriptionId, requestingBusinessId, isAdmin, ct);
        return RenderInvoiceHtml(inv);
    }

    private static SubscriptionHistoryItemDto MapHistoryItem(Subscription sub)
    {
        var planName = sub.Plan?.Name ?? (sub.Plan?.Slug == "trial-7-days" ? "7-Day Free Trial" : "Custom Plan");
        var isTrial = sub.Plan?.Slug == "trial-7-days" || (sub.BaseAmountPaise == 0 && sub.TotalAmountPaise == 0 && (sub.Plan == null || sub.Plan.BasePricePaise == 0));
        var invoiceNum = !string.IsNullOrWhiteSpace(sub.InvoiceNumber)
            ? sub.InvoiceNumber
            : $"INV-{sub.CreatedAt:yyyyMM}-{sub.Id.ToString()[..6].ToUpper()}";

        var effectiveGstRate = sub.GstRatePercent > 0 ? sub.GstRatePercent : (_cachedGstRate ?? 18.0m);
        var basePaise = sub.BaseAmountPaise > 0 
            ? sub.BaseAmountPaise 
            : (isTrial ? 0 : (sub.Plan?.BasePricePaise ?? sub.Plan?.MonthlyPricePaise ?? 0));
        var gstPaise = sub.GstPaise > 0 
            ? sub.GstPaise 
            : (isTrial ? 0 : (sub.Plan?.GstPaise ?? (int)Math.Round(basePaise * (double)(effectiveGstRate / 100m))));
        var totalPaise = sub.TotalAmountPaise > 0 
            ? sub.TotalAmountPaise 
            : (isTrial ? 0 : (sub.Plan?.TotalPricePaise ?? (basePaise + gstPaise)));

        var durationDays = (sub.EndsAt - sub.StartsAt).Days;
        if (durationDays <= 0) durationDays = sub.Plan?.DurationDays ?? 30;

        return new SubscriptionHistoryItemDto(
            Id: sub.Id,
            BusinessId: sub.BusinessId,
            InvoiceNumber: invoiceNum,
            InvoiceDate: sub.CreatedAt != DateTime.MinValue ? sub.CreatedAt : sub.StartsAt,
            PlanName: planName,
            PlanSlug: sub.Plan?.Slug ?? "custom-plan",
            BillingCycle: sub.BillingCycle.ToString(),
            Status: sub.Status.ToString(),
            StartsAt: sub.StartsAt,
            EndsAt: sub.EndsAt,
            DurationDays: durationDays,
            BaseAmountPaise: basePaise,
            GstPaise: gstPaise,
            TotalAmountPaise: totalPaise,
            BaseAmountRupees: basePaise / 100.0,
            GstRupees: gstPaise / 100.0,
            TotalAmountRupees: totalPaise / 100.0,
            PaymentMethod: sub.PaymentMethod ?? (isTrial ? "Free Trial" : "Online UPI / Card"),
            PaymentRef: sub.PaymentRef ?? sub.RazorpaySubscriptionId,
            CustomerGstNumber: sub.CustomerGstNumber ?? sub.Business?.GstNumber,
            IsTrial: isTrial,
            SacCode: sub.SacCode ?? "998313",
            GstRatePercent: effectiveGstRate
        );
    }

    private static string GenerateInvoiceNumber(DateTime date)
    {
        return $"INV-{date:yyyyMM}-{Random.Shared.Next(1000, 9999)}";
    }

    private static string GetStateNameFromCode(string code, string defaultCityOrState)
    {
        return code switch
        {
            "01" => "Jammu and Kashmir",
            "02" => "Himachal Pradesh",
            "03" => "Punjab",
            "04" => "Chandigarh",
            "05" => "Uttarakhand",
            "06" => "Haryana",
            "07" => "Delhi",
            "08" => "Rajasthan",
            "09" => "Uttar Pradesh",
            "10" => "Bihar",
            "11" => "Sikkim",
            "12" => "Arunachal Pradesh",
            "13" => "Nagaland",
            "14" => "Manipur",
            "15" => "Mizoram",
            "16" => "Tripura",
            "17" => "Meghalaya",
            "18" => "Assam",
            "19" => "West Bengal",
            "20" => "Jharkhand",
            "21" => "Odisha",
            "22" => "Chhattisgarh",
            "23" => "Madhya Pradesh",
            "24" => "Gujarat",
            "26" => "Dadra and Nagar Haveli and Daman and Diu",
            "27" => "Maharashtra",
            "29" => "Karnataka",
            "30" => "Goa",
            "32" => "Kerala",
            "33" => "Tamil Nadu",
            "36" => "Telangana",
            "37" => "Andhra Pradesh",
            _ => !string.IsNullOrWhiteSpace(defaultCityOrState) ? defaultCityOrState : "Gujarat"
        };
    }

    private static string ConvertAmountToWords(double amount)
    {
        long wholePart = (long)Math.Floor(amount);
        int decimalPart = (int)Math.Round((amount - wholePart) * 100);

        string words = NumberToWords(wholePart) + " Rupees";
        if (decimalPart > 0)
        {
            words += " and " + NumberToWords(decimalPart) + " Paise";
        }
        words += " Only";
        return words;
    }

    private static string NumberToWords(long number)
    {
        if (number == 0) return "Zero";
        if (number < 0) return "Minus " + NumberToWords(Math.Abs(number));

        string words = "";

        if (number / 10000000 > 0)
        {
            words += NumberToWords(number / 10000000) + " Crore ";
            number %= 10000000;
        }

        if (number / 100000 > 0)
        {
            words += NumberToWords(number / 100000) + " Lakh ";
            number %= 100000;
        }

        if (number / 1000 > 0)
        {
            words += NumberToWords(number / 1000) + " Thousand ";
            number %= 1000;
        }

        if (number / 100 > 0)
        {
            words += NumberToWords(number / 100) + " Hundred ";
            number %= 100;
        }

        if (number > 0)
        {
            var unitsMap = new[] { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen" };
            var tensMap = new[] { "Zero", "Ten", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety" };

            if (number < 20)
                words += unitsMap[number];
            else
            {
                words += tensMap[number / 10];
                if (number % 10 > 0)
                    words += " " + unitsMap[number % 10];
            }
        }

        return words.Trim();
    }

    private static string RenderInvoiceHtml(SubscriptionInvoiceDto inv)
    {
        var isGst = !string.IsNullOrWhiteSpace(inv.CustomerGstNumber);
        var custGstDisplay = isGst ? inv.CustomerGstNumber! : "URP (Unregistered Consumer)";
        var formattedDate = inv.InvoiceDate.ToString("dd MMM yyyy");
        var formattedStarts = inv.StartsAt.ToString("dd MMM yyyy");
        var formattedEnds = inv.EndsAt.ToString("dd MMM yyyy");

        return $@"<!DOCTYPE html>
<html lang=""en"">
<head>
  <meta charset=""UTF-8"">
  <title>GST Tax Invoice - {inv.InvoiceNumber}</title>
  <style>
    @page {{
      size: A4 portrait;
      margin: 12mm 15mm;
    }}
    * {{
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      color: #1a1a1a;
      background: #f8fafc;
      margin: 0;
      padding: 20px;
      font-size: 12px;
      line-height: 1.4;
    }}
    .invoice-wrapper {{
      max-width: 800px;
      margin: 0 auto;
      background: #ffffff;
      border: 1.5px solid #0f172a;
      border-radius: 8px;
      padding: 24px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.06);
    }}
    .actions-bar {{
      max-width: 800px;
      margin: 0 auto 16px auto;
      display: flex;
      justify-content: flex-end;
      gap: 12px;
    }}
    .btn {{
      padding: 8px 16px;
      font-weight: 600;
      border-radius: 6px;
      cursor: pointer;
      border: 1px solid transparent;
      font-size: 13px;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }}
    .btn-primary {{
      background: #0f172a;
      color: #ffffff;
    }}
    .btn-secondary {{
      background: #f1f5f9;
      color: #0f172a;
      border-color: #cbd5e1;
    }}
    .header-table {{
      width: 100%;
      border-bottom: 2px solid #0f172a;
      padding-bottom: 12px;
      margin-bottom: 14px;
    }}
    .badge-gov {{
      display: inline-block;
      background: #10b981;
      color: #ffffff;
      font-weight: 700;
      font-size: 10px;
      letter-spacing: 0.5px;
      padding: 3px 8px;
      border-radius: 4px;
      margin-bottom: 6px;
      text-transform: uppercase;
    }}
    .section-title {{
      font-size: 11px;
      font-weight: 800;
      text-transform: uppercase;
      color: #475569;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 2px;
    }}
    .info-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 18px;
      margin-bottom: 16px;
    }}
    .info-box {{
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 10px 12px;
    }}
    table.data-table {{
      width: 100%;
      border-collapse: collapse;
      margin: 14px 0;
    }}
    table.data-table th {{
      background: #0f172a;
      color: #ffffff;
      font-size: 10.5px;
      font-weight: 700;
      text-transform: uppercase;
      padding: 8px 10px;
      text-align: left;
    }}
    table.data-table td {{
      padding: 9px 10px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 11.5px;
    }}
    .text-right {{ text-align: right; }}
    .text-center {{ text-align: center; }}
    .totals-table {{
      width: 100%;
      border-collapse: collapse;
      margin-top: 6px;
    }}
    .totals-table td {{
      padding: 4px 10px;
    }}
    .totals-row-final {{
      border-top: 2px solid #0f172a;
      border-bottom: 2px solid #0f172a;
      font-weight: 800;
      font-size: 13px;
      background: #f1f5f9;
    }}
    .words-box {{
      margin-top: 10px;
      padding: 8px 12px;
      background: #f8fafc;
      border: 1px dashed #cbd5e1;
      border-radius: 6px;
      font-size: 11px;
    }}
    .footer-declaration {{
      margin-top: 20px;
      padding-top: 12px;
      border-top: 1.5px solid #e2e8f0;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }}
    .stamp-box {{
      text-align: center;
      border: 1.5px dashed #0f172a;
      border-radius: 8px;
      padding: 10px 20px;
      background: #fbfcfe;
    }}
    @media print {{
      body {{
        background: #ffffff;
        padding: 0;
      }}
      .invoice-wrapper {{
        box-shadow: none;
        border: 1px solid #333;
        border-radius: 0;
        padding: 0;
      }}
      .no-print {{
        display: none !important;
      }}
    }}
  </style>
</head>
<body>
  <div class=""actions-bar no-print"">
    <button class=""btn btn-primary"" onclick=""window.print()"">🖨️ Print / Save as PDF</button>
  </div>

  <div class=""invoice-wrapper"">
    <div style=""display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #0f172a; padding-bottom: 12px; margin-bottom: 14px;"">
      <div>
        <div class=""badge-gov"">Original for Recipient • Tax Invoice</div>
        <h1 style=""margin: 0; font-size: 22px; font-weight: 900; color: #0f172a; letter-spacing: -0.5px;"">TAX INVOICE</h1>
        <div style=""font-size: 10px; color: #64748b; font-weight: 600;"">Issued under Section 31 of CGST Act, 2017 & Rule 46 of CGST Rules, 2017</div>
      </div>
      <div style=""text-align: right;"">
        <div style=""font-size: 15px; font-weight: 800; color: #0f172a;"">Invoice No: {inv.InvoiceNumber}</div>
        <div style=""font-size: 11px; color: #475569;"">Invoice Date: <strong>{formattedDate}</strong></div>
        <div style=""font-size: 11px; color: #475569;"">Place of Supply: <strong>{inv.PlaceOfSupply}</strong></div>
        <div style=""font-size: 10px; color: #10b981; font-weight: 700;"">Reverse Charge: NO</div>
      </div>
    </div>

    <div class=""info-grid"">
      <div class=""info-box"">
        <div class=""section-title"">Service Provider / Supplier Details</div>
        <div style=""font-weight: 800; font-size: 13px; color: #0f172a;"">{inv.SupplierName}</div>
        <div style=""color: #334155;"">{inv.SupplierAddress}</div>
        <div style=""margin-top: 4px;""><strong>GSTIN:</strong> <span style=""font-family: monospace; font-size: 12px; color: #0f172a;"">{inv.SupplierGstNumber}</span></div>
        <div><strong>PAN:</strong> {inv.SupplierPan} • <strong>State:</strong> {inv.SupplierState} (Code: {inv.SupplierStateCode})</div>
        <div style=""font-size: 10.5px; color: #64748b; margin-top: 2px;"">Email: {inv.SupplierEmail} • Helpdesk: {inv.SupplierPhone}</div>
      </div>

      <div class=""info-box"">
        <div class=""section-title"">Billed To / Buyer (Customer Details)</div>
        <div style=""font-weight: 800; font-size: 13px; color: #0f172a;"">{inv.CustomerBusinessName}</div>
        {(!string.IsNullOrWhiteSpace(inv.CustomerOwnerName) ? $"<div style=\"color: #475569;\">Attn: <strong>{inv.CustomerOwnerName}</strong></div>" : "")}
        <div style=""color: #334155;"">{inv.CustomerAddress}</div>
        <div style=""margin-top: 4px;""><strong>Buyer GSTIN:</strong> <span style=""font-family: monospace; font-size: 12px; color: {(isGst ? "#0f172a" : "#64748b")};"">{custGstDisplay}</span></div>
        <div><strong>State:</strong> {inv.CustomerState} (Code: {inv.CustomerStateCode}) • <strong>Country:</strong> India</div>
        {(!string.IsNullOrWhiteSpace(inv.CustomerPhone) ? $"<div style=\"font-size: 10.5px; color: #64748b;\">Phone: {inv.CustomerPhone}</div>" : "")}
      </div>
    </div>

    <table class=""data-table"">
      <thead>
        <tr>
          <th style=""width: 5%;"" class=""text-center"">#</th>
          <th style=""width: 45%;"">Description of SaaS Cloud Services</th>
          <th style=""width: 12%;"" class=""text-center"">HSN / SAC</th>
          <th style=""width: 18%;"" class=""text-right"">Taxable Value</th>
          <th style=""width: 20%;"" class=""text-right"">Total (INR)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class=""text-center"" style=""font-weight: 700;"">1</td>
          <td>
            <div style=""font-weight: 700; color: #0f172a; font-size: 12.5px;"">{inv.PlanName} Subscription ({inv.DurationDays} Days)</div>
            <div style=""color: #64748b; font-size: 10.5px; margin-top: 2px;"">
              3D AR Interactive Smart Menu, Diner Digital Ordering, Kitchen Ticketing (KOT) & Table Billing POS Platform Access.
            </div>
            <div style=""color: #0f172a; font-size: 10.5px; margin-top: 2px;"">
              <strong>Service Period:</strong> {formattedStarts} to {formattedEnds}
            </div>
          </td>
          <td class=""text-center"" style=""font-family: monospace; font-weight: 700;"">{inv.SacCode}</td>
          <td class=""text-right"" style=""font-weight: 600;"">₹{inv.BaseAmountRupees:N2}</td>
          <td class=""text-right"" style=""font-weight: 700;"">₹{inv.TotalAmountRupees:N2}</td>
        </tr>
      </tbody>
    </table>

    <div style=""display: flex; justify-content: space-between; align-items: flex-start; gap: 20px;"">
      <div style=""flex: 1;"">
        <div class=""words-box"">
          <div style=""font-size: 10px; font-weight: 700; color: #64748b; text-transform: uppercase;"">Total Amount in Words</div>
          <div style=""font-weight: 700; color: #0f172a; font-size: 12px; margin-top: 2px;"">{inv.AmountInWords}</div>
        </div>

        <div style=""margin-top: 12px; padding: 8px 12px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 11px;"">
          <div style=""font-weight: 700; color: #0f172a; margin-bottom: 4px;"">Payment & Transaction Reference</div>
          <div>Payment Method: <strong>{inv.PaymentMethod}</strong></div>
          <div>Transaction Ref / ID: <code style=""background: #e2e8f0; padding: 1px 4px; border-radius: 3px;"">{inv.PaymentRef}</code></div>
          <div>Status: <span style=""color: #10b981; font-weight: 700;"">PAID / SUCCESSFUL</span></div>
        </div>
      </div>

      <div style=""width: 320px;"">
        <table class=""totals-table"">
          <tr>
            <td style=""color: #475569;"">Total Taxable Value:</td>
            <td class=""text-right"" style=""font-weight: 600;"">₹{inv.BaseAmountRupees:N2}</td>
          </tr>
          {(inv.IsInterState ? $@"
          <tr>
            <td style=""color: #475569;"">Integrated GST (IGST @ {inv.IgstRate:0.##}%):</td>
            <td class=""text-right"" style=""font-weight: 600;"">₹{inv.IgstRupees:N2}</td>
          </tr>" : $@"
          <tr>
            <td style=""color: #475569;"">Central GST (CGST @ {inv.CgstRate:0.##}%):</td>
            <td class=""text-right"" style=""font-weight: 600;"">₹{inv.CgstRupees:N2}</td>
          </tr>
          <tr>
            <td style=""color: #475569;"">State GST (SGST @ {inv.SgstRate:0.##}%):</td>
            <td class=""text-right"" style=""font-weight: 600;"">₹{inv.SgstRupees:N2}</td>
          </tr>")}
          <tr class=""totals-row-final"">
            <td style=""padding: 8px 10px;"">Total Invoice Value (INR):</td>
            <td class=""text-right"" style=""padding: 8px 10px; color: #0f172a; font-size: 14px;"">₹{inv.TotalAmountRupees:N2}</td>
          </tr>
        </table>
      </div>
    </div>

    <div class=""footer-declaration"">
      <div style=""max-width: 480px; font-size: 10px; color: #64748b;"">
        <div style=""font-weight: 700; color: #334155; text-transform: uppercase; margin-bottom: 2px;"">Terms & Statutory Declaration</div>
        <div>1. Input Tax Credit (ITC) can be claimed by registered businesses under Section 16 & 17 of the CGST Act, 2017.</div>
        <div>2. This electronic document is valid for Income Tax audit, GST annual return filing (GSTR-9/3B/2B), and government compliance.</div>
        <div>3. Computer generated tax invoice issued electronically under the Information Technology Act, 2000. No physical signature required.</div>
      </div>

      <div class=""stamp-box"">
        <div style=""font-size: 11px; font-weight: 800; color: #0f172a;"">AR Smart Menu Technologies Pvt. Ltd.</div>
        <div style=""margin: 6px 0; color: #10b981; font-weight: 900; font-size: 16px;"">✔ VERIFIED</div>
        <div style=""font-size: 9.5px; color: #475569;"">Authorised Signatory</div>
      </div>
    </div>
  </div>
</body>
</html>";
    }
}
