import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/analytics_model.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../models/qr_code_model.dart';
import '../../models/user_model.dart';
import 'subscription_service.dart';

/// Multi-tier (RAM + SharedPreferences) device cache with TTLs for fast cold start
/// and zero redundant network traffic for semi-static settings & catalogs.
class LocalCacheService {
  LocalCacheService._();

  static const _userKey = 'cache_user_v1';
  static const _businessKey = 'cache_business_v1';
  static const _productsKey = 'cache_products_v1';
  static const _subscriptionKey = 'cache_subscription_v1';
  static const _profileSyncedKey = 'cache_profile_synced_at';
  static const _productsSyncedKey = 'cache_products_synced_at';
  static const _gstRateKey = 'cache_gst_rate_v1';
  static const _gstRateSyncedKey = 'cache_gst_rate_synced_at';
  static const _supportContactKey = 'cache_support_contact_v1';
  static const _supportSyncedKey = 'cache_support_synced_at';
  static const _plansKey = 'cache_subscription_plans_v1';
  static const _plansSyncedKey = 'cache_plans_synced_at';
  static const _qrCodesKey = 'cache_qr_codes_v1';
  static const _qrCodesSyncedKey = 'cache_qr_codes_synced_at';
  static const _analyticsPrefix = 'cache_analytics_dash_';

  /// Skip background refresh if synced within these TTL windows.
  static const profileStaleAfter = Duration(minutes: 5);
  static const productsStaleAfter = Duration(minutes: 3);
  static const gstStaleAfter = Duration(minutes: 10);
  static const supportStaleAfter = Duration(hours: 6);
  static const plansStaleAfter = Duration(minutes: 30);
  static const qrCodesStaleAfter = Duration(minutes: 15);
  static const analyticsStaleAfter = Duration(minutes: 2);

  // Fast RAM caches (avoid repeated SharedPreferences reads & JSON parsing)
  static double? _memGstRate;
  static DateTime? _memGstAt;
  static SupportContactModel? _memSupportContact;
  static DateTime? _memSupportAt;
  static List<SubscriptionPlanModel>? _memPlans;
  static DateTime? _memPlansAt;
  static List<QrCodeModel>? _memQrCodes;
  static DateTime? _memQrCodesAt;
  static final Map<String, ({AnalyticsDashboardModel data, DateTime at})> _memAnalytics = {};

  static bool _isFresh(DateTime? at, Duration ttl) =>
      at != null && DateTime.now().difference(at) < ttl;

  static Future<SubscriptionInfoModel?> loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subscriptionKey);
    if (raw == null) return null;
    try {
      return SubscriptionInfoModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSubscription(SubscriptionInfoModel? subscription) async {
    final prefs = await SharedPreferences.getInstance();
    if (subscription == null) {
      await prefs.remove(_subscriptionKey);
      return;
    }
    await prefs.setString(_subscriptionKey, jsonEncode(subscription.toJson()));
  }

  static Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<BusinessModel?> loadBusiness() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_businessKey);
    if (raw == null) return null;
    try {
      return BusinessModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBusiness(BusinessModel? business) async {
    final prefs = await SharedPreferences.getInstance();
    if (business == null) {
      await prefs.remove(_businessKey);
      return;
    }
    await prefs.setString(_businessKey, jsonEncode(business.toJson()));
  }

  static Future<List<ProductModel>> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_productsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProducts(List<ProductModel> products) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = products.map((p) => p.toJson()).toList();
    await prefs.setString(_productsKey, jsonEncode(payload));
    await prefs.setInt(
      _productsSyncedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── GST Rate Cache (10m RAM + SharedPreferences) ──────────────────────────

  static Future<double?> loadFreshGstRate() async {
    if (_memGstRate != null && _isFresh(_memGstAt, gstStaleAfter)) {
      return _memGstRate;
    }
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_gstRateSyncedKey);
    final rate = prefs.getDouble(_gstRateKey);
    if (rate != null && ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_isFresh(at, gstStaleAfter)) {
        _memGstRate = rate;
        _memGstAt = at;
        return rate;
      }
    }
    return null;
  }

  static Future<double?> loadAnyCachedGstRate() async {
    if (_memGstRate != null) return _memGstRate;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_gstRateKey);
  }

  static Future<void> saveGstRate(double rate) async {
    final now = DateTime.now();
    _memGstRate = rate;
    _memGstAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_gstRateKey, rate);
    await prefs.setInt(_gstRateSyncedKey, now.millisecondsSinceEpoch);
  }

  // ── Support Contact Cache (6h TTL) ────────────────────────────────────────

  static Future<SupportContactModel?> loadFreshSupportContact() async {
    if (_memSupportContact != null && _isFresh(_memSupportAt, supportStaleAfter)) {
      return _memSupportContact;
    }
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_supportSyncedKey);
    final raw = prefs.getString(_supportContactKey);
    if (raw != null && ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_isFresh(at, supportStaleAfter)) {
        try {
          final parsed = SupportContactModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          _memSupportContact = parsed;
          _memSupportAt = at;
          return parsed;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> saveSupportContact(SupportContactModel contact) async {
    final now = DateTime.now();
    _memSupportContact = contact;
    _memSupportAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _supportContactKey,
      jsonEncode({
        'whatsAppNumber': contact.whatsAppNumber,
        'email': contact.email,
        'phoneNumber': contact.phoneNumber,
        'helpMessage': contact.helpMessage,
      }),
    );
    await prefs.setInt(_supportSyncedKey, now.millisecondsSinceEpoch);
  }

  // ── Subscription Plans Cache (30m TTL) ────────────────────────────────────

  static Future<List<SubscriptionPlanModel>?> loadFreshPlans() async {
    if (_memPlans != null && _isFresh(_memPlansAt, plansStaleAfter)) {
      return _memPlans;
    }
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_plansSyncedKey);
    final raw = prefs.getString(_plansKey);
    if (raw != null && ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_isFresh(at, plansStaleAfter)) {
        try {
          final list = (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(SubscriptionPlanModel.fromJson)
              .toList(growable: false);
          _memPlans = list;
          _memPlansAt = at;
          return list;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> savePlans(List<SubscriptionPlanModel> plans) async {
    final now = DateTime.now();
    _memPlans = plans;
    _memPlansAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plansKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
    await prefs.setInt(_plansSyncedKey, now.millisecondsSinceEpoch);
  }

  // ── QR Codes Cache (15m TTL + instant invalidation on QR changes) ─────────

  static Future<List<QrCodeModel>?> loadFreshQrCodes() async {
    if (_memQrCodes != null && _isFresh(_memQrCodesAt, qrCodesStaleAfter)) {
      return _memQrCodes;
    }
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_qrCodesSyncedKey);
    final raw = prefs.getString(_qrCodesKey);
    if (raw != null && ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_isFresh(at, qrCodesStaleAfter)) {
        try {
          final list = (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(QrCodeModel.fromJson)
              .toList(growable: false);
          _memQrCodes = list;
          _memQrCodesAt = at;
          return list;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> saveQrCodes(List<QrCodeModel> codes) async {
    final now = DateTime.now();
    _memQrCodes = codes;
    _memQrCodesAt = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrCodesKey, jsonEncode(codes.map((q) => q.toJson()).toList()));
    await prefs.setInt(_qrCodesSyncedKey, now.millisecondsSinceEpoch);
  }

  static Future<void> invalidateQrCodes() async {
    _memQrCodes = null;
    _memQrCodesAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qrCodesKey);
    await prefs.remove(_qrCodesSyncedKey);
  }

  // ── Analytics Dashboard Cache (2m TTL per businessId + range) ─────────────

  static Future<AnalyticsDashboardModel?> loadFreshAnalyticsDashboard(
    String businessId,
    String range,
  ) async {
    final cacheKey = '${businessId}_$range';
    final mem = _memAnalytics[cacheKey];
    if (mem != null && _isFresh(mem.at, analyticsStaleAfter)) {
      return mem.data;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_analyticsPrefix$cacheKey');
    final ms = prefs.getInt('$_analyticsPrefix${cacheKey}_at');
    if (raw != null && ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (_isFresh(at, analyticsStaleAfter)) {
        try {
          final dash = AnalyticsDashboardModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          _memAnalytics[cacheKey] = (data: dash, at: at);
          return dash;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> saveAnalyticsDashboard(
    String businessId,
    String range,
    AnalyticsDashboardModel dash,
  ) async {
    final now = DateTime.now();
    final cacheKey = '${businessId}_$range';
    _memAnalytics[cacheKey] = (data: dash, at: now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_analyticsPrefix$cacheKey', jsonEncode(dash.toJson()));
    await prefs.setInt('$_analyticsPrefix${cacheKey}_at', now.millisecondsSinceEpoch);
  }

  static Future<void> markProfileSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _profileSyncedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<bool> isProfileFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_profileSyncedKey);
    if (ms == null) return false;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ms),
        ) <
        profileStaleAfter;
  }

  static Future<bool> isProductsFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_productsSyncedKey);
    if (ms == null) return false;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(ms),
        ) <
        productsStaleAfter;
  }

  static Future<void> clearAll() async {
    _memGstRate = null;
    _memGstAt = null;
    _memSupportContact = null;
    _memSupportAt = null;
    _memPlans = null;
    _memPlansAt = null;
    _memQrCodes = null;
    _memQrCodesAt = null;
    _memAnalytics.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_businessKey);
    await prefs.remove(_productsKey);
    await prefs.remove(_subscriptionKey);
    await prefs.remove(_profileSyncedKey);
    await prefs.remove(_productsSyncedKey);
    await prefs.remove(_gstRateKey);
    await prefs.remove(_gstRateSyncedKey);
    await prefs.remove(_supportContactKey);
    await prefs.remove(_supportSyncedKey);
    await prefs.remove(_plansKey);
    await prefs.remove(_plansSyncedKey);
    await prefs.remove(_qrCodesKey);
    await prefs.remove(_qrCodesSyncedKey);
    await prefs.remove('ar_history_table_bills_v1');
    await prefs.remove('ar_history_table_bills_v2');
    await prefs.remove('ar_active_table_bills_v1');
    await prefs.remove('owner_notifications_v1');
    await prefs.remove('owner_product_status_snapshot');
    await prefs.remove('owner_business_status_snapshot');
    await prefs.remove('owner_plan_limit_warned');
    for (final k in prefs.getKeys().where((k) => k.startsWith(_analyticsPrefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
