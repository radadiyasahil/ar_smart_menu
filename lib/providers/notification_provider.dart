import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_model.dart';
import '../models/product_model.dart';

enum OwnerNotificationType {
  productLive,
  productRejected,
  productReview,
  businessApproved,
  businessRejected,
  planLimit,
  info,
}

class OwnerNotification {
  const OwnerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.productId,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final OwnerNotificationType type;
  final DateTime createdAt;
  final String? productId;
  final bool read;

  OwnerNotification copyWith({bool? read}) => OwnerNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        productId: productId,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'productId': productId,
        'read': read,
      };

  factory OwnerNotification.fromJson(Map<String, dynamic> json) {
    return OwnerNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: OwnerNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OwnerNotificationType.info,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      productId: json['productId'] as String?,
      read: json['read'] as bool? ?? false,
    );
  }
}

/// In-app alerts for product status, business approval, and plan limits.
class NotificationProvider extends ChangeNotifier {
  static const _notificationsKey = 'owner_notifications_v1';
  static const _productSnapshotKey = 'owner_product_status_snapshot';
  static const _businessStatusKey = 'owner_business_status_snapshot';
  static const _planWarnKey = 'owner_plan_limit_warned';

  List<OwnerNotification> _notifications = [];
  bool _hydrated = false;

  List<OwnerNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;

  Future<void> hydrate() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notificationsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _notifications = list
          .map((e) => OwnerNotification.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<void> sync({
    required List<ProductModel> products,
    BusinessModel? business,
    int? maxProducts,
  }) async {
    await hydrate();
    final prefs = await SharedPreferences.getInstance();
    final previousProducts = _readProductSnapshot(prefs);
    final previousBusinessStatus = prefs.getInt(_businessStatusKey);
    var changed = false;

    if (business != null && previousBusinessStatus != null) {
      if (business.status == BusinessStatus.active &&
          previousBusinessStatus != BusinessStatus.active.value) {
        _prepend(
          OwnerNotification(
            id: 'business-approved-${business.id}',
            title: 'Business approved',
            body: '${business.businessName} is active — add products and QR codes.',
            type: OwnerNotificationType.businessApproved,
            createdAt: DateTime.now(),
          ),
        );
        changed = true;
      } else if (business.isRejected &&
          previousBusinessStatus != BusinessStatus.rejected.value) {
        _prepend(
          OwnerNotification(
            id: 'business-rejected-${business.id}',
            title: 'Business needs changes',
            body: business.rejectionReason ??
                'Admin rejected your registration. Update details in Account.',
            type: OwnerNotificationType.businessRejected,
            createdAt: DateTime.now(),
          ),
        );
        changed = true;
      }
    }

    if (business != null) {
      await prefs.setInt(_businessStatusKey, business.status.value);
    }

    for (final product in products) {
      final prev = previousProducts[product.id];
      if (prev == null) continue;

      if (product.isLive && prev != ProductStatus.live.value) {
        _prepend(
          OwnerNotification(
            id: 'live-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
            title: '${product.name} is live',
            body: 'Customers can scan the QR and view your dish in AR.',
            type: OwnerNotificationType.productLive,
            createdAt: DateTime.now(),
            productId: product.id,
          ),
        );
        changed = true;
      } else if (product.isRejected && prev != ProductStatus.rejected.value) {
        _prepend(
          OwnerNotification(
            id: 'rejected-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
            title: '${product.name} rejected',
            body: product.rejectionReasonOnly ??
                'Admin asked for changes — open the product to see details.',
            type: OwnerNotificationType.productRejected,
            createdAt: DateTime.now(),
            productId: product.id,
          ),
        );
        changed = true;
      } else if (product.status == ProductStatus.review &&
          prev != ProductStatus.review.value) {
        _prepend(
          OwnerNotification(
            id: 'review-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
            title: '${product.name} in review',
            body: '3D model is ready — waiting for admin approval.',
            type: OwnerNotificationType.productReview,
            createdAt: DateTime.now(),
            productId: product.id,
          ),
        );
        changed = true;
      }
    }

    final nextSnapshot = {
      for (final product in products) product.id: product.status.value,
    };
    await prefs.setString(_productSnapshotKey, jsonEncode(nextSnapshot));

    if (maxProducts != null && maxProducts > 0) {
      final count = products.length;
      final warned = prefs.getBool(_planWarnKey) ?? false;
      if (count >= maxProducts) {
        if (!warned) {
          _prepend(
            OwnerNotification(
              id: 'plan-limit-$maxProducts',
              title: 'Product limit reached',
              body:
                  'You have $count of $maxProducts products on your plan. Upgrade to add more.',
              type: OwnerNotificationType.planLimit,
              createdAt: DateTime.now(),
            ),
          );
          changed = true;
          await prefs.setBool(_planWarnKey, true);
        }
      } else if (count >= (maxProducts * 0.85).ceil()) {
        final warnId = 'plan-near-$maxProducts-$count';
        if (!_notifications.any((n) => n.id == warnId)) {
          _prepend(
            OwnerNotification(
              id: warnId,
              title: 'Almost at product limit',
              body: '$count of $maxProducts slots used on your current plan.',
              type: OwnerNotificationType.planLimit,
              createdAt: DateTime.now(),
            ),
          );
          changed = true;
        }
      } else {
        await prefs.setBool(_planWarnKey, false);
      }
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].read) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    _notifications =
        _notifications.map((n) => n.copyWith(read: true)).toList();
    await _persist();
    notifyListeners();
  }

  Map<String, int> _readProductSnapshot(SharedPreferences prefs) {
    final raw = prefs.getString(_productSnapshotKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(key, value as int));
  }

  void _prepend(OwnerNotification notification) {
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications = [notification, ..._notifications].take(50).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_notificationsKey, encoded);
  }
}
