using System.Collections.Concurrent;
using System.IO.Compression;
using System.Text.RegularExpressions;
using ARSmartMenu.Application.DTOs;
using ARSmartMenu.Domain.Enums;
using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;

namespace ARSmartMenu.Infrastructure.Services;

public sealed record CachedSlugBusiness(
    Guid BusinessId,
    BusinessStatus Status,
    string BusinessName,
    double GstRate);

/// <summary>
/// Process-wide IMemoryCache facade providing fast zero-allocation/single-query lookups
/// for auth revocation, slug-to-business resolution, valid table numbers, platform settings,
/// subscription plans, and public AR menus — with O(1) per-business and global invalidation.
/// </summary>
public sealed partial class AppLookupCacheService
{
    private readonly IMemoryCache _cache;
    private readonly IServiceScopeFactory _scopeFactory;

    private readonly ConcurrentDictionary<Guid, long> _businessGenerations = new();
    private long _globalMenuGeneration = 1;

    private sealed record VersionedSlugEntry(CachedSlugBusiness? Target, long BusinessGen);
    private sealed record VersionedMenuEntry(PublicMenuResponse Menu, Guid BusinessId, long BusinessGen, long GlobalGen);

    [GeneratedRegex(@"-t(\d+)$", RegexOptions.IgnoreCase | RegexOptions.Compiled)]
    private static partial Regex SlugTableRegex();

    [GeneratedRegex(@"[?&]table(?:Number)?=(\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled)]
    private static partial Regex UrlTableRegex();

    [GeneratedRegex(@"(\d+)", RegexOptions.Compiled)]
    private static partial Regex DigitsRegex();

    public AppLookupCacheService(IMemoryCache cache, IServiceScopeFactory scopeFactory)
    {
        _cache = cache;
        _scopeFactory = scopeFactory;
    }

    private long GetBusinessGeneration(Guid businessId) =>
        _businessGenerations.GetOrAdd(businessId, 1L);

    // ── Shared Table Key Helpers ─────────────────────────────────────────────────────────────

    public static string NormalizeTableKey(string? tableNumber)
    {
        if (string.IsNullOrWhiteSpace(tableNumber))
            return string.Empty;

        var trimmed = tableNumber.Trim();
        var match = DigitsRegex().Match(trimmed);
        if (match.Success)
            return match.Groups[1].Value;

        if (trimmed.StartsWith("Table ", StringComparison.OrdinalIgnoreCase))
            return trimmed[6..].Trim();
        if (trimmed.StartsWith("Table", StringComparison.OrdinalIgnoreCase) && trimmed.Length > 5)
            return trimmed[5..].Trim();
        if (trimmed.StartsWith("T-", StringComparison.OrdinalIgnoreCase))
            return trimmed[2..].Trim();
        if (trimmed.StartsWith("T", StringComparison.OrdinalIgnoreCase) && trimmed.Length > 1 && char.IsDigit(trimmed[1]))
            return trimmed[1..].Trim();

        return trimmed.ToUpperInvariant();
    }

    public static bool IsTableMatch(string? candidate, string? target)
    {
        if (string.IsNullOrWhiteSpace(candidate) || string.IsNullOrWhiteSpace(target))
            return false;

        var cleanA = candidate.Trim();
        var cleanB = target.Trim();
        if (string.Equals(cleanA, cleanB, StringComparison.OrdinalIgnoreCase))
            return true;

        var keyA = NormalizeTableKey(cleanA);
        var keyB = NormalizeTableKey(cleanB);
        return keyA.Length > 0 && string.Equals(keyA, keyB, StringComparison.OrdinalIgnoreCase);
    }

    // ── JWT Revocation Cache (eliminates 1 DB query per HTTP request) ─────────────────────────

    public async Task<bool> IsTokenRevokedAsync(string jti, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(jti))
            return false;

        var key = $"revoked-jti:{jti}";
        if (_cache.TryGetValue(key, out bool revoked))
            return revoked;

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        revoked = await db.RevokedTokens
            .AsNoTracking()
            .AnyAsync(r => r.TokenId == jti, ct);

        _cache.Set(key, revoked, revoked ? TimeSpan.FromHours(12) : TimeSpan.FromMinutes(3));
        return revoked;
    }

    public void MarkTokenRevoked(string jti, DateTime expiresAtUtc)
    {
        if (string.IsNullOrWhiteSpace(jti))
            return;

        var ttl = expiresAtUtc - DateTime.UtcNow;
        if (ttl <= TimeSpan.Zero)
            ttl = TimeSpan.FromHours(1);

        _cache.Set($"revoked-jti:{jti}", true, ttl);
    }

    // ── Slug Resolution Cache (replaces 9x duplicated QR + Business loading) ─────────────────

    public async Task<CachedSlugBusiness?> ResolveSlugAsync(
        AppDbContext db,
        string slug,
        bool requireActiveQr = false,
        bool fallbackToAnyBusiness = false,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(slug))
            return null;

        var cleanSlug = slug.Trim().ToLowerInvariant();
        var cacheKey = $"slug-biz:{cleanSlug}:{requireActiveQr}:{fallbackToAnyBusiness}";

        if (_cache.TryGetValue(cacheKey, out VersionedSlugEntry? cached) && cached?.Target != null)
        {
            if (cached.BusinessGen == GetBusinessGeneration(cached.Target.BusinessId))
                return cached.Target;
        }

        // Single SQL JOIN projection — only loads the 4 scalar columns needed, zero entity tracking
        CachedSlugBusiness? resolved = await db.QrCodes
            .AsNoTracking()
            .Where(q => q.Slug == cleanSlug && (!requireActiveQr || q.IsActive))
            .Select(q => new CachedSlugBusiness(
                q.BusinessId,
                q.Business.Status,
                q.Business.BusinessName,
                q.Business.GstRate))
            .FirstOrDefaultAsync(ct);

        if (resolved == null)
        {
            if (Guid.TryParse(cleanSlug, out var parsedBizId))
            {
                resolved = await db.Businesses
                    .AsNoTracking()
                    .Where(b => b.Id == parsedBizId)
                    .Select(b => new CachedSlugBusiness(b.Id, b.Status, b.BusinessName, b.GstRate))
                    .FirstOrDefaultAsync(ct);
            }

            resolved ??= await db.Businesses
                .AsNoTracking()
                .Where(b => b.BusinessName == slug.Trim())
                .Select(b => new CachedSlugBusiness(b.Id, b.Status, b.BusinessName, b.GstRate))
                .FirstOrDefaultAsync(ct);

            if (resolved == null && fallbackToAnyBusiness)
            {
                resolved = await db.Businesses
                    .AsNoTracking()
                    .Select(b => new CachedSlugBusiness(b.Id, b.Status, b.BusinessName, b.GstRate))
                    .FirstOrDefaultAsync(ct);
            }
        }

        if (resolved != null)
        {
            var entry = new VersionedSlugEntry(resolved, GetBusinessGeneration(resolved.BusinessId));
            _cache.Set(cacheKey, entry, TimeSpan.FromMinutes(5));
        }

        return resolved;
    }

    // ── Valid Tables Cache (replaces repeated full QrCodes table scans) ───────────────────────

    public async Task<List<string>> GetValidTablesForBusinessAsync(
        AppDbContext db,
        Guid businessId,
        CancellationToken ct = default)
    {
        var key = $"valid-tables:{businessId}";
        if (_cache.TryGetValue(key, out List<string>? cached) && cached != null)
            return cached;

        var tableQrs = await db.QrCodes
            .AsNoTracking()
            .Where(q => q.BusinessId == businessId && q.QrType == QrType.Table && q.IsActive)
            .Select(q => new { q.Slug, q.WebUrl })
            .ToListAsync(ct);

        var validTables = new List<string>(tableQrs.Count);
        foreach (var qr in tableQrs)
        {
            var mSlug = SlugTableRegex().Match(qr.Slug);
            if (mSlug.Success)
            {
                validTables.Add(mSlug.Groups[1].Value);
                continue;
            }

            if (!string.IsNullOrEmpty(qr.WebUrl))
            {
                var mUrl = UrlTableRegex().Match(qr.WebUrl);
                if (mUrl.Success)
                {
                    validTables.Add(mUrl.Groups[1].Value);
                    continue;
                }
            }

            var mDigits = DigitsRegex().Match(qr.Slug);
            if (mDigits.Success)
                validTables.Add(mDigits.Groups[1].Value);
        }

        var result = validTables
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(t => int.TryParse(t, out var n) ? n : 999)
            .ToList();

        _cache.Set(key, result, TimeSpan.FromMinutes(10));
        return result;
    }

    public async Task<(bool IsValid, List<string> ValidTables)> ValidateTableForBusinessAsync(
        AppDbContext db,
        Guid businessId,
        string? tableNumber,
        CancellationToken ct = default)
    {
        var validTables = await GetValidTablesForBusinessAsync(db, businessId, ct);
        if (validTables.Count == 0)
            return (true, validTables);

        if (string.IsNullOrWhiteSpace(tableNumber))
            return (false, validTables);

        var clean = tableNumber.Trim();
        var digitMatch = DigitsRegex().Match(clean);
        var digit = digitMatch.Success ? digitMatch.Value : null;

        var matches = validTables.Any(t =>
            clean.Equals(t, StringComparison.OrdinalIgnoreCase) ||
            clean.Equals($"Table {t}", StringComparison.OrdinalIgnoreCase) ||
            clean.Equals($"Table{t}", StringComparison.OrdinalIgnoreCase) ||
            clean.Equals($"T-{t}", StringComparison.OrdinalIgnoreCase) ||
            clean.Equals($"T{t}", StringComparison.OrdinalIgnoreCase) ||
            (digit != null && digit == t));

        return (matches, validTables);
    }

    // ── Platform Settings & Plans Cache ──────────────────────────────────────────────────────

    public async Task<GstRateSettingDto> GetGstRateSettingAsync(AppDbContext db, CancellationToken ct = default)
    {
        const string key = "platform:gst-rate-dto";
        if (_cache.TryGetValue(key, out GstRateSettingDto? cached) && cached != null)
            return cached;

        var setting = await db.SystemSettings
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.Key == "Billing.GstRatePercent", ct);

        var rate = (setting != null && decimal.TryParse(setting.Value, out var parsedRate) && parsedRate >= 0)
            ? parsedRate
            : 18.0m;

        var halfRate = Math.Round(rate / 2m, 2);
        var dto = new GstRateSettingDto(
            GstRatePercent: rate,
            CgstRatePercent: halfRate,
            SgstRatePercent: halfRate,
            IgstRatePercent: rate,
            LastUpdated: setting?.UpdatedAt ?? setting?.CreatedAt,
            Description: setting?.Description ?? "GST percentage applied to subscription plans and customer invoices");

        _cache.Set(key, dto, TimeSpan.FromMinutes(15));
        return dto;
    }

    public async Task<decimal> GetGstRatePercentRawAsync(AppDbContext db, CancellationToken ct = default)
    {
        var dto = await GetGstRateSettingAsync(db, ct);
        return dto.GstRatePercent;
    }

    public void InvalidateGstRate()
    {
        _cache.Remove("platform:gst-rate-dto");
        InvalidatePlans();
        InvalidateAllMenus();
    }

    public async Task<SupportContactSettingDto> GetSupportContactSettingAsync(AppDbContext db, CancellationToken ct = default)
    {
        const string key = "platform:support-contact-dto";
        if (_cache.TryGetValue(key, out SupportContactSettingDto? cached) && cached != null)
            return cached;

        var settings = await db.SystemSettings
            .AsNoTracking()
            .Where(s => s.Key.StartsWith("Platform.Support"))
            .Select(s => new { s.Key, s.Value, s.UpdatedAt, s.CreatedAt })
            .ToListAsync(ct);

        var whatsapp = settings.FirstOrDefault(s => s.Key == "Platform.SupportWhatsApp")?.Value ?? "+91 98765 43210";
        var email = settings.FirstOrDefault(s => s.Key == "Platform.SupportEmail")?.Value ?? "support@arsmartmenu.com";
        var phone = settings.FirstOrDefault(s => s.Key == "Platform.SupportPhone")?.Value ?? "+91 98765 43210";
        var helpMsg = settings.FirstOrDefault(s => s.Key == "Platform.SupportHelpMessage")?.Value ?? "For assistance, queries, or account updates, reach out via:";

        var latestUpdate = settings
            .Select(s => s.UpdatedAt ?? s.CreatedAt)
            .DefaultIfEmpty(DateTime.UtcNow)
            .Max();

        var dto = new SupportContactSettingDto(
            WhatsAppNumber: whatsapp,
            Email: email,
            PhoneNumber: phone,
            HelpMessage: helpMsg,
            LastUpdated: latestUpdate);

        _cache.Set(key, dto, TimeSpan.FromMinutes(30));
        return dto;
    }

    public void InvalidateSupportContact() => _cache.Remove("platform:support-contact-dto");

    public IReadOnlyList<SubscriptionPlanDto>? GetCachedPlans() =>
        _cache.TryGetValue("platform:subscription-plans", out IReadOnlyList<SubscriptionPlanDto>? plans) ? plans : null;

    public void SetCachedPlans(IReadOnlyList<SubscriptionPlanDto> plans) =>
        _cache.Set("platform:subscription-plans", plans, TimeSpan.FromMinutes(15));

    public void InvalidatePlans() => _cache.Remove("platform:subscription-plans");

    // ── Public AR Menu Cache (O(1) business & global invalidation) ───────────────────────────

    public PublicMenuResponse? TryGetPublicMenu(string slug)
    {
        if (string.IsNullOrWhiteSpace(slug))
            return null;

        var key = $"public-menu:{slug.Trim().ToLowerInvariant()}";
        if (!_cache.TryGetValue(key, out VersionedMenuEntry? entry) || entry == null)
            return null;

        var currentBizGen = GetBusinessGeneration(entry.BusinessId);
        var currentGlobalGen = Interlocked.Read(ref _globalMenuGeneration);
        return (entry.BusinessGen == currentBizGen && entry.GlobalGen == currentGlobalGen)
            ? entry.Menu
            : null;
    }

    public void SetPublicMenu(string slug, Guid businessId, PublicMenuResponse menu)
    {
        if (string.IsNullOrWhiteSpace(slug))
            return;

        var key = $"public-menu:{slug.Trim().ToLowerInvariant()}";
        var entry = new VersionedMenuEntry(
            menu,
            businessId,
            GetBusinessGeneration(businessId),
            Interlocked.Read(ref _globalMenuGeneration));

        _cache.Set(key, entry, TimeSpan.FromSeconds(60));
    }

    public void InvalidateTables(Guid businessId) =>
        _cache.Remove($"valid-tables:{businessId}");

    public void InvalidateBusiness(Guid businessId)
    {
        _businessGenerations.AddOrUpdate(businessId, 2L, (_, v) => v + 1);
        InvalidateTables(businessId);
    }

    public void InvalidateAllMenus() =>
        Interlocked.Increment(ref _globalMenuGeneration);
}
