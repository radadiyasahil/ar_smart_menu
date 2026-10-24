import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/notification_service.dart';
import '../models/business_model.dart';
import '../models/product_model.dart';

enum OwnerNotificationType { productLive, productRejected, productReview, businessApproved, businessRejected, planLimit, info }

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

  final String id, title, body;
  final OwnerNotificationType type;
  final DateTime createdAt;
  final String? productId;
  final bool read;

  OwnerNotification copyWith({bool? read}) => OwnerNotification(
    id: id, title: title, body: body, type: type, createdAt: createdAt, productId: productId, read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body, 'type': type.name,
    'createdAt': createdAt.toIso8601String(), 'productId': productId, 'read': read,
  };

  factory OwnerNotification.fromJson(Map<String, dynamic> json) {
    final tStr = (json['type'] as String? ?? 'info').toLowerCase();
    final type = OwnerNotificationType.values.firstWhere(
      (e) => e.name.toLowerCase() == tStr,
      orElse: () => OwnerNotificationType.info,
    );
    return OwnerNotification(
      id: (json['id'] ?? '').toString(),
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      type: type,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      productId: json['productId']?.toString(),
      read: (json['read'] as bool?) ?? (json['isRead'] as bool?) ?? false,
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  static const _kNotifs = 'owner_notifications_v1';
  static const _kProdSnap = 'owner_product_status_snapshot';
  static const _kBizSnap = 'owner_business_status_snapshot';
  static const _kWarn = 'owner_plan_limit_warned';

  final _service = NotificationService();
  List<OwnerNotification> _notifications = [];
  bool _hydrated = false;

  List<OwnerNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> hydrate() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotifs);
    if (raw != null) {
      try {
        _notifications = (jsonDecode(raw) as List)
            .map((e) => OwnerNotification.fromJson(e as Map<String, dynamic>))
            .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {}
    }
    _hydrated = true;
    notifyListeners();
    await fetchRemote();
  }

  Future<void> fetchRemote() async {
    try {
      final remotes = await _service.getNotifications();
      if (remotes.isEmpty) return;
      final existing = {for (final n in _notifications) n.id: n};
      var changed = false;

      for (final r in remotes) {
        if (!existing.containsKey(r.id)) {
          _notifications.add(r);
          changed = true;
        } else if (existing[r.id]!.read != r.read) {
          final i = _notifications.indexWhere((n) => n.id == r.id);
          if (i != -1) { _notifications[i] = _notifications[i].copyWith(read: r.read); changed = true; }
        }
      }
      if (changed) {
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _persist();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> sync({required List<ProductModel> products, BusinessModel? business, int? maxProducts}) async {
    await hydrate();
    final prefs = await SharedPreferences.getInstance();
    final prevProds = _readSnapshot(prefs, _kProdSnap);
    final prevBiz = prefs.getInt(_kBizSnap);
    var changed = false;

    if (business != null) {
      if (prevBiz != null) {
        if (business.status == BusinessStatus.active && prevBiz != BusinessStatus.active.value) {
          _prepend(OwnerNotification(id: 'biz-ok-${business.id}', title: 'Business approved', body: '${business.businessName} is active.', type: OwnerNotificationType.businessApproved, createdAt: DateTime.now()));
          changed = true;
        } else if (business.isRejected && prevBiz != BusinessStatus.rejected.value) {
          _prepend(OwnerNotification(id: 'biz-rej-${business.id}', title: 'Business needs changes', body: business.rejectionReason ?? 'Registration rejected.', type: OwnerNotificationType.businessRejected, createdAt: DateTime.now()));
          changed = true;
        }
      }
      await prefs.setInt(_kBizSnap, business.status.value);
    }

    for (final p in products) {
      final prev = prevProds[p.id];
      final isTrans = prev != null && prev != p.status.value;
      final isInitial = prev == null && _notifications.isEmpty && (p.isLive || p.isRejected);

      if (isTrans || isInitial) {
        if (p.isLive && (prev == null || prev != ProductStatus.live.value)) {
          _prepend(OwnerNotification(id: 'live-${p.id}-${DateTime.now().millisecondsSinceEpoch}', title: '${p.name} is now LIVE in AR!', body: 'Customers can scan QR to view in 3D.', type: OwnerNotificationType.productLive, createdAt: DateTime.now(), productId: p.id));
          changed = true;
        } else if (p.isRejected && (prev == null || prev != ProductStatus.rejected.value)) {
          _prepend(OwnerNotification(id: 'rej-${p.id}-${DateTime.now().millisecondsSinceEpoch}', title: '${p.name} rejected', body: p.rejectionReasonOnly ?? 'Admin requested changes.', type: OwnerNotificationType.productRejected, createdAt: DateTime.now(), productId: p.id));
          changed = true;
        } else if (p.status == ProductStatus.review && (prev == null || prev != ProductStatus.review.value)) {
          _prepend(OwnerNotification(id: 'rev-${p.id}-${DateTime.now().millisecondsSinceEpoch}', title: '${p.name} in review', body: '3D model waiting for admin approval.', type: OwnerNotificationType.productReview, createdAt: DateTime.now(), productId: p.id));
          changed = true;
        }
      }
    }
    await prefs.setString(_kProdSnap, jsonEncode({for (final p in products) p.id: p.status.value}));

    if (maxProducts != null && maxProducts > 0) {
      final warned = prefs.getBool(_kWarn) ?? false;
      if (products.length >= maxProducts && !warned) {
        _prepend(OwnerNotification(id: 'plan-$maxProducts', title: 'Product limit reached', body: 'You have used $maxProducts slots on your plan.', type: OwnerNotificationType.planLimit, createdAt: DateTime.now()));
        changed = true;
        await prefs.setBool(_kWarn, true);
      } else if (products.length < maxProducts) {
        await prefs.setBool(_kWarn, false);
      }
    }

    await fetchRemote();
    if (changed) { await _persist(); notifyListeners(); }
  }

  Future<void> markRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i < 0 || _notifications[i].read) return;
    _notifications[i] = _notifications[i].copyWith(read: true);
    await _persist();
    notifyListeners();
    await _service.markRead(id);
  }

  Future<void> markAllRead() async {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    await _persist();
    notifyListeners();
    await _service.markAllRead();
  }

  Map<String, int> _readSnapshot(SharedPreferences p, String key) {
    try {
      final raw = p.getString(key);
      return raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    } catch (_) { return {}; }
  }

  void _prepend(OwnerNotification n) {
    if (!_notifications.any((item) => item.id == n.id)) _notifications = [n, ..._notifications].take(50).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotifs, jsonEncode(_notifications.map((n) => n.toJson()).toList()));
  }
}
