import 'package:dio/dio.dart';

import '../../models/qr_code_model.dart';
import 'api_client.dart';

class QrService {
  QrService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<QrCodeModel>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/qrcodes');
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to load QR codes');
    }
    final data = envelope['data'] as List<dynamic>;
    return data
        .map((e) => QrCodeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QrCodeModel> generateForProduct(String productId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/qrcodes/generate',
      data: {'productId': productId},
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to generate QR');
    }
    return QrCodeModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }

  Future<void> deactivate(String qrId) async {
    final response = await _dio.post<Map<String, dynamic>>('/qrcodes/$qrId/deactivate');
    if (response.data?['success'] != true) {
      throw Exception(response.data?['error'] ?? 'Failed to deactivate QR');
    }
  }
}
