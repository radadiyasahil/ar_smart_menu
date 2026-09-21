import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/auth_service.dart';
import '../core/services/local_cache_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService();

  final AuthService _authService;

  UserModel? _user;
  String? _token;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Instant startup — token + cached user, no network.
  Future<void> hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _user = await LocalCacheService.loadUser();
    notifyListeners();
  }

  Future<void> loadSession() async {
    await hydrateFromCache();
    if (_token == null) return;

    try {
      _user = await _authService.getMe();
      await LocalCacheService.saveUser(_user!);
    } catch (_) {
      if (_user == null) await clearSession();
    }
    notifyListeners();
  }

  Future<String> sendOtp(String mobile) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _authService.sendOtp(mobile);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp({
    required String mobile,
    required String otp,
    required String otpId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.verifyOtp(
        mobile: mobile,
        otp: otp,
        otpId: otpId,
      );
      await _saveSession(result.token, result.user);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithMobile(String mobile) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.devLogin(mobile);
      await _saveSession(result.token, result.user);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession(String token, UserModel user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await LocalCacheService.saveUser(user);
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await LocalCacheService.clearAll();
    notifyListeners();
  }
}
