import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';

/// Shared Dio client for ASP.NET Core API (ApiResponse envelope) with in-memory token cache
/// and common envelope parsing helpers.
class ApiClient {
  ApiClient._();

  static String? _cachedToken;
  static bool _tokenLoaded = false;

  static void setCachedToken(String? token) {
    _cachedToken = (token != null && token.isNotEmpty) ? token : null;
    _tokenLoaded = true;
  }

  static void clearCachedToken() {
    _cachedToken = null;
    _tokenLoaded = true;
  }

  static Future<String?> _resolveToken() async {
    if (_tokenLoaded) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('auth_token');
    _tokenLoaded = true;
    return _cachedToken;
  }

  /// Validates the standard API envelope and throws on `success != true`.
  static void ensureSuccess(
    Map<String, dynamic> envelope, {
    String fallbackError = 'Request failed',
  }) {
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? envelope['message'] ?? fallbackError);
    }
  }

  /// Parses a single JSON object inside an `ApiResponse<T>` envelope.
  static T parseOne<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson, {
    String fallbackError = 'Request failed',
  }) {
    ensureSuccess(envelope, fallbackError: fallbackError);
    return fromJson(envelope['data'] as Map<String, dynamic>);
  }

  /// Parses a JSON array inside an `ApiResponse<List<T>>` envelope.
  static List<T> parseList<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson, {
    String fallbackError = 'Request failed',
  }) {
    ensureSuccess(envelope, fallbackError: fallbackError);
    final list = envelope['data'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConfig.baseUrl;
          final token = await _resolveToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final data = error.response?.data;
          if (data is Map && data['error'] is String) {
            error = DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: data['error'],
            );
          }
          handler.next(error);
        },
      ),
    );
}
