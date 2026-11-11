import 'package:dio/dio.dart';

import '../constants/api_config.dart';

/// User-friendly message from API / network errors.
String formatApiError(Object error) {
  if (error is DioException) {
    if (error.error is String && (error.error as String).isNotEmpty) {
      return error.error as String;
    }

    final data = error.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach API at ${ApiConfig.baseUrl}. '
          'Start the backend: dotnet run in ARSmartMenu.API';
    }

    if (error.response?.statusCode == 401) {
      return 'Login failed. Check mobile number and try again.';
    }

    return error.message ?? 'Network error. Is the backend running?';
  }

  return error.toString().replaceFirst('Exception: ', '');
}
