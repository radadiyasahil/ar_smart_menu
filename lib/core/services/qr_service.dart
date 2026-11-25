import 'package:dio/dio.dart';

import '../../models/qr_code_model.dart';
import 'api_client.dart';
import 'local_cache_service.dart';

class QrService {
  QrService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<QrCodeModel>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await LocalCacheService.loadFreshQrCodes();
      if (cached != null) return cached;
    }

    final response = await _dio.get<Map<String, dynamic>>('/qrcodes');
    final list = ApiClient.parseList(
      response.data!,
      QrCodeModel.fromJson,
      fallbackError: 'Failed to load QR codes',
    );
    await LocalCacheService.saveQrCodes(list);
    return list;
  }

  Future<QrCodeModel> getMasterQr() async {
    final response = await _dio.get<Map<String, dynamic>>('/qrcodes/master');
    return ApiClient.parseOne(
      response.data!,
      QrCodeModel.fromJson,
      fallbackError: 'Failed to get master QR',
    );
  }

  Future<List<QrCodeModel>> generateTableQrs({int count = 3}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/qrcodes/tables',
      queryParameters: {'count': count},
    );
    final list = ApiClient.parseList(
      response.data!,
      QrCodeModel.fromJson,
      fallbackError: 'Failed to generate table QRs',
    );
    await LocalCacheService.invalidateQrCodes();
    return list;
  }

  Future<QrCodeModel> generateForProduct(String productId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/qrcodes/generate',
      data: {'productId': productId},
    );
    final model = ApiClient.parseOne(
      response.data!,
      QrCodeModel.fromJson,
      fallbackError: 'Failed to generate QR',
    );
    await LocalCacheService.invalidateQrCodes();
    return model;
  }

  Future<void> clearTableQrs() async {
    final response = await _dio.delete<Map<String, dynamic>>('/qrcodes/tables');
    ApiClient.ensureSuccess(
      response.data!,
      fallbackError: 'Failed to clear table QRs',
    );
    await LocalCacheService.invalidateQrCodes();
  }

  Future<void> deactivate(String qrId) async {
    final response = await _dio.post<Map<String, dynamic>>('/qrcodes/$qrId/deactivate');
    ApiClient.ensureSuccess(
      response.data ?? const {},
      fallbackError: 'Failed to deactivate QR',
    );
    await LocalCacheService.invalidateQrCodes();
  }
}
