import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';

/// Local persistence for fast cold start — show cached data first, sync in background.
class LocalCacheService {
  LocalCacheService._();

  static const _userKey = 'cache_user_v1';
  static const _businessKey = 'cache_business_v1';
  static const _productsKey = 'cache_products_v1';
  static const _profileSyncedKey = 'cache_profile_synced_at';
  static const _productsSyncedKey = 'cache_products_synced_at';

  /// Skip background profile refresh if synced within this window.
  static const profileStaleAfter = Duration(minutes: 5);
  static const productsStaleAfter = Duration(minutes: 3);

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_businessKey);
    await prefs.remove(_productsKey);
    await prefs.remove(_profileSyncedKey);
    await prefs.remove(_productsSyncedKey);
  }
}
