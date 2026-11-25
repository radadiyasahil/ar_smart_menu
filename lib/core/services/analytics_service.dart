import 'package:dio/dio.dart';

import '../../models/analytics_model.dart';
import 'api_client.dart';

class AnalyticsService {
  AnalyticsService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  /// Combined single-roundtrip analytics endpoint (overview + chart + topProducts).
  Future<AnalyticsDashboardModel> getDashboard({
    String range = '7d',
    int limit = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/dashboard',
      queryParameters: {'range': range, 'limit': limit},
    );
    return ApiClient.parseOne(
      response.data!,
      AnalyticsDashboardModel.fromJson,
      fallbackError: 'Analytics dashboard request failed',
    );
  }

  Future<AnalyticsOverviewModel> getOverview({String range = '7d'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/overview',
      queryParameters: {'range': range},
    );
    return ApiClient.parseOne(
      response.data!,
      AnalyticsOverviewModel.fromJson,
      fallbackError: 'Analytics overview request failed',
    );
  }

  Future<List<AnalyticsChartPointModel>> getChart({String range = '7d'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/chart',
      queryParameters: {'range': range},
    );
    return ApiClient.parseList(
      response.data!,
      AnalyticsChartPointModel.fromJson,
      fallbackError: 'Analytics chart request failed',
    );
  }

  Future<List<TopProductAnalyticsModel>> getTopProducts({
    String range = '7d',
    int limit = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/top-products',
      queryParameters: {'range': range, 'limit': limit},
    );
    return ApiClient.parseList(
      response.data!,
      TopProductAnalyticsModel.fromJson,
      fallbackError: 'Top products request failed',
    );
  }
}
