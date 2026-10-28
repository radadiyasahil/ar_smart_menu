import 'package:dio/dio.dart';

import '../../models/business_model.dart';
import '../../models/user_model.dart';
import 'api_client.dart';

class AuthMeResult {
  const AuthMeResult({required this.user, this.business});

  final UserModel user;
  final BusinessModel? business;
}

class AuthService {
  AuthService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<String> sendOtp(String mobile) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/send-otp',
      data: {'mobile': mobile},
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to send OTP');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return data['otpId'] as String;
  }

  Future<({String token, UserModel user, bool isNewUser})> verifyOtp({
    required String mobile,
    required String otp,
    required String otpId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {'mobile': mobile, 'otp': otp, 'otpId': otpId},
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'OTP verification failed');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      isNewUser: data['isNewUser'] as bool? ?? false,
    );
  }

  /// Development login — single call, no OTP (backend Development only).
  Future<({String token, UserModel user, bool isNewUser})> devLogin(String mobile) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/dev-login',
      data: {'mobile': mobile},
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Login failed');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      isNewUser: data['isNewUser'] as bool? ?? false,
    );
  }

  Future<AuthMeResult> getMeProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to load profile');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    final businessJson = data['business'] as Map<String, dynamic>?;
    return AuthMeResult(
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      business: businessJson != null
          ? BusinessModel.fromSummaryJson(businessJson)
          : null,
    );
  }

  Future<UserModel> getMe() async {
    final profile = await getMeProfile();
    return profile.user;
  }

  Future<UserModel> updateMe({
    String? fullName,
    String? whatsAppNumber,
    String? languagePreference,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (whatsAppNumber != null) payload['whatsAppNumber'] = whatsAppNumber;
    if (languagePreference != null) payload['languagePreference'] = languagePreference;

    final response = await _dio.put<Map<String, dynamic>>(
      '/auth/me',
      data: payload,
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to update profile');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<String> refreshToken() async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/refresh-token');
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Failed to refresh token');
    }
    final data = envelope['data'] as Map<String, dynamic>;
    return data['token'] as String;
  }

  Future<void> logout() async {
    try {
      await _dio.post<Map<String, dynamic>>('/auth/logout');
    } catch (_) {
      // Best effort
    }
  }
}
