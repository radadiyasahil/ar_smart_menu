import 'package:flutter/foundation.dart';

/// Backend API configuration — change for device/emulator as needed.
abstract final class ApiConfig {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:5232/api';
      }
    }
    return 'http://localhost:5232/api';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Temporary: skip OTP screen and auto-verify with [devOtpBypassCode].
  /// Set to false when MSG91 / real OTP is integrated.
  static const bool devSkipOtp = true;

  /// Must match backend `Otp:DevBypassCode` in appsettings.json.
  static const String devOtpBypassCode = '123456';
}
