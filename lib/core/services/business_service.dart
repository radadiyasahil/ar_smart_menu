import 'package:dio/dio.dart';

import '../../models/business_model.dart';
import '../../models/user_model.dart';
import 'api_client.dart';

class BusinessService {
  BusinessService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<BusinessModel> create({
    required String businessName,
    required BusinessType businessType,
    required String city,
    required String fullAddress,
    String? fssaiNumber,
    String? gstNumber,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/businesses',
      data: {
        'businessName': businessName,
        'businessType': businessType.value,
        'city': city,
        'fullAddress': fullAddress,
        if (fssaiNumber != null && fssaiNumber.isNotEmpty) 'fssaiNumber': fssaiNumber,
        if (gstNumber != null && gstNumber.isNotEmpty) 'gstNumber': gstNumber,
      },
    );
    return _parseBusiness(response.data!);
  }

  Future<BusinessModel> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/businesses/me');
    return _parseBusiness(response.data!);
  }

  Future<BusinessModel> update({
    String? businessName,
    BusinessType? businessType,
    String? city,
    String? fullAddress,
    String? fssaiNumber,
    String? gstNumber,
    String? upiId,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/businesses/me',
      data: {
        if (businessName != null) 'businessName': businessName,
        if (businessType != null) 'businessType': businessType.value,
        if (city != null) 'city': city,
        if (fullAddress != null) 'fullAddress': fullAddress,
        if (fssaiNumber != null) 'fssaiNumber': fssaiNumber,
        if (gstNumber != null) 'gstNumber': gstNumber,
        if (upiId != null) 'upiId': upiId,
      },
    );
    return _parseBusiness(response.data!);
  }

  Future<UserModel> submitKyc({
    String? fullName,
    String? aadhaarLast4,
    String? panNumber,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/businesses/me/kyc',
      data: {
        if (fullName != null) 'fullName': fullName,
        if (aadhaarLast4 != null) 'aadhaarLast4': aadhaarLast4,
        if (panNumber != null) 'panNumber': panNumber,
      },
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<bool> verifyBank({
    required String bankAccountNumber,
    required String bankIfsc,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/businesses/me/verify-bank',
      data: {
        'bankAccountNumber': bankAccountNumber,
        'bankIfsc': bankIfsc,
      },
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;
    return data['verified'] as bool? ?? false;
  }

  BusinessModel _parseBusiness(Map<String, dynamic> envelope) {
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Business request failed');
    }
    return BusinessModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }
}
