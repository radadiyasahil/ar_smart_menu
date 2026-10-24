import 'package:dio/dio.dart';
import '../../providers/notification_provider.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService({Dio? dio}) : _dio = dio ?? ApiClient.dio;
  final Dio _dio;

  Future<List<OwnerNotification>> getNotifications() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/notifications');
      final p = res.data?['data'] is Map<String, dynamic> ? res.data!['data'] as Map<String, dynamic> : res.data;
      final list = p?['notifications'] as List<dynamic>? ?? [];
      return list.map((e) => OwnerNotification.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<void> markRead(String id) async { try { await _dio.post('/notifications/$id/read'); } catch (_) {} }
  Future<void> markAllRead() async { try { await _dio.post('/notifications/read-all'); } catch (_) {} }
  Future<void> delete(String id) async { try { await _dio.delete('/notifications/$id'); } catch (_) {} }
}
