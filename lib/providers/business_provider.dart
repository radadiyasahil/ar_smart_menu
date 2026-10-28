import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/auth_service.dart';
import '../core/services/business_service.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/subscription_service.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

class BusinessProvider extends ChangeNotifier {
  BusinessProvider({
    BusinessService? businessService,
    AuthService? authService,
    SubscriptionService? subscriptionService,
  })  : _businessService = businessService ?? BusinessService(),
        _authService = authService ?? AuthService(),
        _subscriptionService = subscriptionService ?? SubscriptionService();

  final BusinessService _businessService;
  final AuthService _authService;
  final SubscriptionService _subscriptionService;

  BusinessModel? _business;
  UserModel? _user;
  SubscriptionInfoModel? _subscription;
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isSyncing = false;
  String? _error;

  BusinessModel? get business => _business;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasBusiness => _business != null;
  bool get isPendingApproval => _business?.isPending ?? false;
  bool get isActive => _business?.isActive ?? false;
  bool get isRejected => _business?.isRejected ?? false;
  bool get isDeactivated => _business?.isDeactivated ?? false;
  bool get isSuspended => _business?.isSuspended ?? false;

  SubscriptionInfoModel? get subscription => _subscription;
  bool get hasActiveSubscription => _subscription != null && _subscription!.isActive;
  bool get isTrial => _subscription != null && _subscription!.isTrial;
  int get daysRemaining => _subscription?.daysRemaining ?? 0;
  bool get hasUsedTrial => _subscription?.hasUsedTrial ?? false;

  /// Instant startup from local storage — no API calls.
  Future<void> hydrateFromCache() async {
    _user = await LocalCacheService.loadUser();
    _business = await LocalCacheService.loadBusiness();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persistProfile() async {
    if (_user != null) await LocalCacheService.saveUser(_user!);
    await LocalCacheService.saveBusiness(_business);
    await LocalCacheService.markProfileSynced();
  }

  /// One API call (auth/me) — used after login or background sync.
  Future<void> loadProfile({bool forceNetwork = true}) async {
    if (!forceNetwork && _isLoaded) return;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final profile = await _authService.getMeProfile();
      _user = profile.user;
      _business = profile.business;
      _isLoaded = true;
      await _persistProfile();
      await loadSubscription();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Background refresh — skips if cache is fresh. Never blocks UI.
  Future<void> refreshProfileInBackground() async {
    if (_isSyncing) return;
    if (await LocalCacheService.isProfileFresh()) return;

    _isSyncing = true;
    notifyListeners();
    try {
      final profile = await _authService.getMeProfile();
      _user = profile.user;
      _business = profile.business;
      _isLoaded = true;
      await _persistProfile();
      await loadSubscription();
    } catch (_) {
      // Keep showing cached data
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Full business details — only when Account / KYC screen needs them.
  Future<void> loadFullBusinessDetails() async {
    if (_business == null) return;
    if (_business!.fullAddress.isNotEmpty &&
        (_business!.bankAccountNumber != null || _business!.fssaiNumber != null)) {
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      _business = await _businessService.getMe();
      await _persistProfile();
    } catch (_) {
      // Summary from cache is enough
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BusinessModel> registerBusiness({
    required String businessName,
    required BusinessType businessType,
    required String city,
    required String fullAddress,
    String? fssaiNumber,
    String? gstNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _business = await _businessService.create(
        businessName: businessName,
        businessType: businessType,
        city: city,
        fullAddress: fullAddress,
        fssaiNumber: fssaiNumber,
        gstNumber: gstNumber,
      );

      final newToken = await _authService.refreshToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', newToken);

      await loadProfile(forceNetwork: true);
      return _business!;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    if (!hasBusiness) {
      await loadProfile(forceNetwork: true);
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _business = await _businessService.getMe();
      final profile = await _authService.getMeProfile();
      _user = profile.user;

      if (_business?.isActive == true) {
        final newToken = await _authService.refreshToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', newToken);
      }
      await _persistProfile();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel> submitKyc({
    String? fullName,
    String? aadhaarLast4,
    String? panNumber,
  }) async {
    _user = await _businessService.submitKyc(
      fullName: fullName,
      aadhaarLast4: aadhaarLast4,
      panNumber: panNumber,
    );
    await LocalCacheService.saveUser(_user!);
    notifyListeners();
    return _user!;
  }

  Future<bool> verifyBank({
    required String accountNumber,
    required String ifsc,
  }) async {
    final verified = await _businessService.verifyBank(
      bankAccountNumber: accountNumber,
      bankIfsc: ifsc,
    );
    await refreshStatus();
    return verified;
  }

  Future<BusinessModel> setBusinessStatus(BusinessStatus status, {String? reason}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _business = await _businessService.updateStatus(status: status, reason: reason);
      await _persistProfile();
      return _business!;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? whatsAppNumber,
    String? languagePreference,
    String? businessName,
    BusinessType? businessType,
    String? city,
    String? fullAddress,
    String? fssaiNumber,
    String? gstNumber,
    String? upiId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (businessName != null ||
          businessType != null ||
          city != null ||
          fullAddress != null ||
          fssaiNumber != null ||
          gstNumber != null ||
          upiId != null) {
        _business = await _businessService.update(
          businessName: businessName,
          businessType: businessType,
          city: city,
          fullAddress: fullAddress,
          fssaiNumber: fssaiNumber,
          gstNumber: gstNumber,
          upiId: upiId,
        );
      }

      if (fullName != null || whatsAppNumber != null || languagePreference != null) {
        _user = await _authService.updateMe(
          fullName: fullName,
          whatsAppNumber: whatsAppNumber,
          languagePreference: languagePreference,
        );
      }

      await _persistProfile();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _business = null;
    _user = null;
    _subscription = null;
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadSubscription() async {
    try {
      _subscription = await _subscriptionService.getCurrent();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> activateTrial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _subscription = await _subscriptionService.activateTrial();
      await loadProfile(forceNetwork: true);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> activatePlan({
    required String planId,
    String paymentMethod = 'UPI',
    String? transactionRef,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _subscription = await _subscriptionService.activatePlan(
        planId: planId,
        paymentMethod: paymentMethod,
        transactionRef: transactionRef,
      );
      await loadProfile(forceNetwork: true);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
