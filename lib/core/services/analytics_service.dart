import 'package:dio/dio.dart';

import '../../models/analytics_model.dart';
import 'api_client.dart';

class AnalyticsService {
  AnalyticsService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<AnalyticsOverviewModel> getOverview({String range = '7d'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/overview',
      queryParameters: {'range': range},
    );
    return _parseOne(response.data!, AnalyticsOverviewModel.fromJson);
  }

  Future<List<AnalyticsChartPointModel>> getChart({String range = '7d'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/chart',
      queryParameters: {'range': range},
    );
    return _parseList(response.data!, AnalyticsChartPointModel.fromJson);
  }

  Future<List<TopProductAnalyticsModel>> getTopProducts({
    String range = '7d',
    int limit = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/top-products',
      queryParameters: {'range': range, 'limit': limit},
    );
    return _parseList(response.data!, TopProductAnalyticsModel.fromJson);
  }

  List<T> _parseList<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _ensureSuccess(envelope);
    final data = envelope['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  T _parseOne<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    _ensureSuccess(envelope);
    return fromJson(envelope['data'] as Map<String, dynamic>);
  }

  void _ensureSuccess(Map<String, dynamic> envelope) {
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Analytics request failed');
    }
  }
}
