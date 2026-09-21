import 'package:dio/dio.dart';

import 'api_client.dart';

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.planName,
    required this.maxProducts,
    required this.status,
  });

  final String planName;
  final int maxProducts;
  final String status;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? {};
    return SubscriptionInfo(
      planName: plan['name'] as String? ?? 'Free',
      maxProducts: plan['maxProducts'] as int? ?? 20,
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class SubscriptionService {
  SubscriptionService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<SubscriptionInfo?> getCurrent() async {
    final response = await _dio.get<Map<String, dynamic>>('/subscriptions/me');
    final envelope = response.data!;
    if (envelope['success'] != true) return null;
    final data = envelope['data'];
    if (data == null) return null;
    return SubscriptionInfo.fromJson(data as Map<String, dynamic>);
  }
}
