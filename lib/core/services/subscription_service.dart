import 'package:dio/dio.dart';

import 'api_client.dart';

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.durationDays,
    required this.basePricePaise,
    required this.gstPaise,
    required this.totalPricePaise,
    this.originalPricePaise,
    required this.discountPercent,
    this.badge,
    required this.facilities,
    required this.maxProducts,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final int durationDays;
  final int basePricePaise;
  final int gstPaise;
  final int totalPricePaise;
  final int? originalPricePaise;
  final int discountPercent;
  final String? badge;
  final List<String> facilities;
  final int maxProducts;
  final int displayOrder;

  double get basePriceRupees => basePricePaise / 100.0;
  double get gstRupees => gstPaise / 100.0;
  double get totalPriceRupees => totalPricePaise / 100.0;
  double? get originalPriceRupees =>
      originalPricePaise != null ? originalPricePaise! / 100.0 : null;

  double get effectiveMonthlyRupees {
    if (durationDays <= 0) return 0.0;
    final months = durationDays / 30.0;
    return totalPriceRupees / months;
  }

  bool get isTrial => slug == 'trial-7-days';

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    final rawFac = json['facilities'];
    final facilitiesList = rawFac is List
        ? rawFac.map((e) => e.toString()).toList()
        : <String>[];

    return SubscriptionPlanModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationDays: json['durationDays'] as int? ?? 30,
      basePricePaise: json['basePricePaise'] as int? ?? 0,
      gstPaise: json['gstPaise'] as int? ?? 0,
      totalPricePaise: json['totalPricePaise'] as int? ?? 0,
      originalPricePaise: json['originalPricePaise'] as int?,
      discountPercent: json['discountPercent'] as int? ?? 0,
      badge: json['badge'] as String?,
      facilities: facilitiesList,
      maxProducts: json['maxProducts'] as int? ?? 50,
      displayOrder: json['displayOrder'] as int? ?? 1,
    );
  }
}

class SubscriptionInfoModel {
  const SubscriptionInfoModel({
    required this.id,
    required this.businessId,
    this.plan,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.daysRemaining,
    required this.isActive,
    required this.isTrial,
    required this.hasUsedTrial,
    this.cancelledAt,
  });

  final String id;
  final String businessId;
  final SubscriptionPlanModel? plan;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int daysRemaining;
  final bool isActive;
  final bool isTrial;
  final bool hasUsedTrial;
  final DateTime? cancelledAt;

  String get planName => plan?.name ?? (isTrial ? '7-Day Free Trial' : 'No Active Plan');
  int get maxProducts => plan?.maxProducts ?? 50;

  factory SubscriptionInfoModel.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>?;
    return SubscriptionInfoModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      plan: planJson != null ? SubscriptionPlanModel.fromJson(planJson) : null,
      status: json['status']?.toString() ?? 'Expired',
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? '') ?? DateTime.now(),
      daysRemaining: json['daysRemaining'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      hasUsedTrial: json['hasUsedTrial'] as bool? ?? false,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
    );
  }
}

class SubscriptionService {
  SubscriptionService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<SubscriptionPlanModel>> getPlans() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscriptions/plans');
      final envelope = response.data!;
      final list = envelope['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<SubscriptionInfoModel?> getCurrent() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscriptions/me');
      final envelope = response.data!;
      final data = envelope['data'];
      if (data == null) return null;
      return SubscriptionInfoModel.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<SubscriptionInfoModel> activateTrial() async {
    final response = await _dio.post<Map<String, dynamic>>('/subscriptions/activate-trial');
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['message'] ?? envelope['error'] ?? 'Failed to activate trial.');
    }
    return SubscriptionInfoModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }

  Future<SubscriptionInfoModel> activatePlan({
    required String planId,
    String paymentMethod = 'UPI',
    String? transactionRef,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/subscriptions/activate-plan',
      data: {
        'planId': planId,
        'paymentMethod': paymentMethod,
        'transactionRef': transactionRef,
      },
    );
    final envelope = response.data!;
    if (envelope['success'] != true) {
      throw Exception(envelope['message'] ?? envelope['error'] ?? 'Failed to activate plan.');
    }
    return SubscriptionInfoModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }
}
