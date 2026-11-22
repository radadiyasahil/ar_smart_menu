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
    this.gstRatePercent = 18.0,
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
  final double gstRatePercent;

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
      gstRatePercent: (json['gstRatePercent'] as num?)?.toDouble() ?? 18.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'durationDays': durationDays,
    'basePricePaise': basePricePaise,
    'gstPaise': gstPaise,
    'totalPricePaise': totalPricePaise,
    'originalPricePaise': originalPricePaise,
    'discountPercent': discountPercent,
    'badge': badge,
    'facilities': facilities,
    'maxProducts': maxProducts,
    'displayOrder': displayOrder,
  };
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'plan': plan?.toJson(),
    'status': status,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'daysRemaining': daysRemaining,
    'isActive': isActive,
    'isTrial': isTrial,
    'hasUsedTrial': hasUsedTrial,
    'cancelledAt': cancelledAt?.toIso8601String(),
  };
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

  Future<List<SubscriptionHistoryItemModel>> getHistory() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscriptions/history');
      final envelope = response.data!;
      final list = envelope['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => SubscriptionHistoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<SubscriptionInvoiceModel> getInvoice(String subscriptionId) async {
    final response = await _dio.get<Map<String, dynamic>>('/subscriptions/$subscriptionId/invoice');
    final envelope = response.data!;
    if (envelope['success'] != true || envelope['data'] == null) {
      throw Exception(envelope['message'] ?? envelope['error'] ?? 'Failed to load invoice.');
    }
    return SubscriptionInvoiceModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }

  Future<SupportContactModel> getSupportContact() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/subscriptions/support-contact');
      final envelope = response.data;
      if (envelope != null && envelope['data'] != null) {
        return SupportContactModel.fromJson(envelope['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return SupportContactModel.defaultContact;
  }
}

class SupportContactModel {
  const SupportContactModel({
    required this.whatsAppNumber,
    required this.email,
    required this.phoneNumber,
    required this.helpMessage,
  });

  final String whatsAppNumber;
  final String email;
  final String phoneNumber;
  final String helpMessage;

  factory SupportContactModel.fromJson(Map<String, dynamic> json) {
    return SupportContactModel(
      whatsAppNumber: json['whatsAppNumber']?.toString() ?? '+91 98765 43210',
      email: json['email']?.toString() ?? 'support@arsmartmenu.com',
      phoneNumber: json['phoneNumber']?.toString() ?? '+91 98765 43210',
      helpMessage: json['helpMessage']?.toString() ?? 'For assistance, queries, or account updates, reach out via:',
    );
  }

  static const defaultContact = SupportContactModel(
    whatsAppNumber: '+91 98765 43210',
    email: 'support@arsmartmenu.com',
    phoneNumber: '+91 98765 43210',
    helpMessage: 'For assistance, queries, or account updates, reach out via:',
  );
}

class SubscriptionHistoryItemModel {
  const SubscriptionHistoryItemModel({
    required this.id,
    required this.businessId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.planName,
    required this.planSlug,
    required this.billingCycle,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.durationDays,
    required this.baseAmountRupees,
    required this.gstRupees,
    required this.totalAmountRupees,
    this.paymentMethod,
    this.paymentRef,
    this.customerGstNumber,
    required this.isTrial,
    this.sacCode = '998313',
    this.gstRatePercent = 18.0,
  });

  final String id;
  final String businessId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String planName;
  final String planSlug;
  final String billingCycle;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationDays;
  final double baseAmountRupees;
  final double gstRupees;
  final double totalAmountRupees;
  final String? paymentMethod;
  final String? paymentRef;
  final String? customerGstNumber;
  final bool isTrial;
  final String sacCode;
  final double gstRatePercent;

  factory SubscriptionHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionHistoryItemModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? 'N/A',
      invoiceDate: DateTime.tryParse(json['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
      planName: json['planName'] as String? ?? 'Subscription Plan',
      planSlug: json['planSlug'] as String? ?? '',
      billingCycle: json['billingCycle']?.toString() ?? 'Monthly',
      status: json['status']?.toString() ?? 'Active',
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? '') ?? DateTime.now(),
      durationDays: json['durationDays'] as int? ?? 30,
      baseAmountRupees: (json['baseAmountRupees'] as num?)?.toDouble() ??
          ((json['baseAmountPaise'] as num?)?.toDouble() ?? 0.0) / 100.0,
      gstRupees: (json['gstRupees'] as num?)?.toDouble() ??
          ((json['gstPaise'] as num?)?.toDouble() ?? 0.0) / 100.0,
      totalAmountRupees: (json['totalAmountRupees'] as num?)?.toDouble() ??
          ((json['totalAmountPaise'] as num?)?.toDouble() ?? 0.0) / 100.0,
      paymentMethod: json['paymentMethod'] as String?,
      paymentRef: json['paymentRef'] as String?,
      customerGstNumber: json['customerGstNumber'] as String?,
      isTrial: json['isTrial'] as bool? ?? false,
      sacCode: json['sacCode'] as String? ?? '998313',
      gstRatePercent: (json['gstRatePercent'] as num?)?.toDouble() ?? 18.0,
    );
  }
}

class SubscriptionInvoiceModel {
  const SubscriptionInvoiceModel({
    required this.id,
    required this.businessId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.planName,
    required this.planSlug,
    required this.billingCycle,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.durationDays,
    required this.baseAmountRupees,
    required this.gstRupees,
    required this.totalAmountRupees,
    required this.cgstRupees,
    required this.sgstRupees,
    required this.igstRupees,
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
    required this.isInterState,
    required this.sacCode,
    this.paymentMethod,
    this.paymentRef,
    required this.supplierName,
    required this.supplierAddress,
    required this.supplierGstNumber,
    required this.supplierPan,
    required this.supplierState,
    required this.supplierStateCode,
    required this.supplierEmail,
    required this.supplierPhone,
    required this.customerBusinessName,
    this.customerOwnerName,
    this.customerEmail,
    this.customerPhone,
    this.customerGstNumber,
    required this.customerAddress,
    required this.customerCity,
    required this.customerState,
    required this.customerStateCode,
    required this.isGstRegistered,
    required this.amountInWords,
    required this.placeOfSupply,
    this.gstRatePercent = 18.0,
  });

  final String id;
  final String businessId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String planName;
  final String planSlug;
  final String billingCycle;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationDays;
  final double baseAmountRupees;
  final double gstRupees;
  final double totalAmountRupees;
  final double cgstRupees;
  final double sgstRupees;
  final double igstRupees;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final bool isInterState;
  final String sacCode;
  final String? paymentMethod;
  final String? paymentRef;
  final String supplierName;
  final String supplierAddress;
  final String supplierGstNumber;
  final String supplierPan;
  final String supplierState;
  final String supplierStateCode;
  final String supplierEmail;
  final String supplierPhone;
  final String customerBusinessName;
  final String? customerOwnerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerGstNumber;
  final String customerAddress;
  final String customerCity;
  final String customerState;
  final String customerStateCode;
  final bool isGstRegistered;
  final String amountInWords;
  final String placeOfSupply;
  final double gstRatePercent;

  factory SubscriptionInvoiceModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionInvoiceModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? 'N/A',
      invoiceDate: DateTime.tryParse(json['invoiceDate']?.toString() ?? '') ?? DateTime.now(),
      planName: json['planName'] as String? ?? '',
      planSlug: json['planSlug'] as String? ?? '',
      billingCycle: json['billingCycle']?.toString() ?? 'Monthly',
      status: json['status']?.toString() ?? 'Active',
      startsAt: DateTime.tryParse(json['startsAt']?.toString() ?? '') ?? DateTime.now(),
      endsAt: DateTime.tryParse(json['endsAt']?.toString() ?? '') ?? DateTime.now(),
      durationDays: json['durationDays'] as int? ?? 30,
      baseAmountRupees: (json['baseAmountRupees'] as num?)?.toDouble() ?? 0.0,
      gstRupees: (json['gstRupees'] as num?)?.toDouble() ?? 0.0,
      totalAmountRupees: (json['totalAmountRupees'] as num?)?.toDouble() ?? 0.0,
      cgstRupees: (json['cgstRupees'] as num?)?.toDouble() ?? 0.0,
      sgstRupees: (json['sgstRupees'] as num?)?.toDouble() ?? 0.0,
      igstRupees: (json['igstRupees'] as num?)?.toDouble() ?? 0.0,
      cgstRate: (json['cgstRate'] as num?)?.toDouble() ?? 9.0,
      sgstRate: (json['sgstRate'] as num?)?.toDouble() ?? 9.0,
      igstRate: (json['igstRate'] as num?)?.toDouble() ?? 18.0,
      isInterState: json['isInterState'] as bool? ?? false,
      sacCode: json['sacCode'] as String? ?? '998313',
      paymentMethod: json['paymentMethod'] as String?,
      paymentRef: json['paymentRef'] as String?,
      supplierName: json['supplierName'] as String? ?? 'AR Smart Menu Technologies Pvt. Ltd.',
      supplierAddress: json['supplierAddress'] as String? ?? 'Floor 4, Tech Park, S.G. Highway, Ahmedabad - 380054',
      supplierGstNumber: json['supplierGstNumber'] as String? ?? '24AABCA1234F1Z9',
      supplierPan: json['supplierPan'] as String? ?? 'AABCA1234F',
      supplierState: json['supplierState'] as String? ?? 'Gujarat',
      supplierStateCode: json['supplierStateCode'] as String? ?? '24',
      supplierEmail: json['supplierEmail'] as String? ?? 'billing@arsmartmenu.com',
      supplierPhone: json['supplierPhone'] as String? ?? '+91 98765 43210',
      customerBusinessName: json['customerBusinessName'] as String? ?? 'Restaurant Client',
      customerOwnerName: json['customerOwnerName'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerGstNumber: json['customerGstNumber'] as String?,
      customerAddress: json['customerAddress'] as String? ?? 'India',
      customerCity: json['customerCity'] as String? ?? '',
      customerState: json['customerState'] as String? ?? 'Gujarat',
      customerStateCode: json['customerStateCode'] as String? ?? '24',
      isGstRegistered: json['isGstRegistered'] as bool? ?? false,
      amountInWords: json['amountInWords'] as String? ?? 'Zero Rupees',
      placeOfSupply: json['placeOfSupply'] as String? ?? 'Gujarat (24)',
      gstRatePercent: (json['gstRatePercent'] as num?)?.toDouble() ?? 18.0,
    );
  }
}
