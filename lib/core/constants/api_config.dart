/// Backend API configuration — change for device/emulator as needed.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5232/api',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Temporary: skip OTP screen and auto-verify with [devOtpBypassCode].
  /// Set to false when MSG91 / real OTP is integrated.
  static const bool devSkipOtp = true;

  /// Must match backend `Otp:DevBypassCode` in appsettings.json.
  static const String devOtpBypassCode = '123456';
}
