import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bill_model.dart';
import 'api_client.dart';

class QuickCustomPreset {
  final String name;
  final int defaultPrice;
  const QuickCustomPreset(this.name, this.defaultPrice);

  Map<String, dynamic> toJson() => {'name': name, 'defaultPrice': defaultPrice};
  factory QuickCustomPreset.fromJson(Map<String, dynamic> json) =>
      QuickCustomPreset(json['name'] as String? ?? '', json['defaultPrice'] as int? ?? 0);
}

class BillingService {
  static const String _activeBillsKey = 'ar_active_table_bills_v1';
  static const String _historyBillsKey = 'ar_history_table_bills_v1';
  static const String _billCounterKey = 'ar_bill_counter_v1';
  static const String _customPresetsKey = 'ar_custom_quick_presets_v1';

  static const List<QuickCustomPreset> defaultPresets = [
    QuickCustomPreset('Water Bottle (1L)', 20),
    QuickCustomPreset('Cold Drink (Can)', 40),
    QuickCustomPreset('Extra Butter Roti', 15),
    QuickCustomPreset('Packaging / Parcel Box', 10),
    QuickCustomPreset('Extra Dip / Chutney', 20),
    QuickCustomPreset('Mineral Water (500ml)', 10),
  ];

  Future<List<QuickCustomPreset>> getQuickPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_customPresetsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      await saveQuickPresets(defaultPresets);
      return List.from(defaultPresets);
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => QuickCustomPreset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return List.from(defaultPresets);
    }
  }

  Future<void> saveQuickPresets(List<QuickCustomPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customPresetsKey, jsonEncode(presets.map((p) => p.toJson()).toList()));
  }

  Future<List<QuickCustomPreset>> addQuickPreset(QuickCustomPreset preset) async {
    final list = await getQuickPresets();
    final idx = list.indexWhere((p) => p.name.toLowerCase() == preset.name.toLowerCase());
    if (idx >= 0) {
      list[idx] = preset;
    } else {
      list.add(preset);
    }
    await saveQuickPresets(list);
    return list;
  }

  Future<List<QuickCustomPreset>> deleteQuickPreset(String name) async {
    final list = await getQuickPresets();
    list.removeWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    await saveQuickPresets(list);
    return list;
  }

  Future<String> generateNextBillId(String businessInitials) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_billCounterKey) ?? 1000) + 1;
    await prefs.setInt(_billCounterKey, count);
    final prefix = businessInitials.isNotEmpty ? businessInitials.toUpperCase() : 'BILL';
    return '$prefix-$count';
  }

  Future<List<TableBill>> getActiveBills() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_activeBillsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => TableBill.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading active bills: $e');
      return [];
    }
  }

  Future<void> saveActiveBills(List<TableBill> bills) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(bills.map((b) => b.toJson()).toList());
    await prefs.setString(_activeBillsKey, jsonStr);
  }

  Future<List<TableBill>> getCompletedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyBillsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final bills = list
          .map((e) => TableBill.fromJson(e as Map<String, dynamic>))
          // Only show actual accepted & paid bills (exclude empty/discarded/deleted orders)
          .where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0)
          .toList();
      bills.sort((a, b) => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt));
      // Save sanitized list back to storage
      await prefs.setString(_historyBillsKey, jsonEncode(bills.map((b) => b.toJson()).toList()));
      return bills;
    } catch (e) {
      debugPrint('Error loading history bills: $e');
      return [];
    }
  }

  Future<void> saveHistoryBills(List<TableBill> bills) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = bills.where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0).toList();
    final jsonStr = jsonEncode(sanitized.map((b) => b.toJson()).toList());
    await prefs.setString(_historyBillsKey, jsonStr);
  }

  Future<void> archiveBill(TableBill bill) async {
    // Only archive actual orders with items
    if (bill.items.isEmpty || bill.grandTotal <= 0) return;
    final history = await getCompletedHistory();
    history.removeWhere((b) => b.id == bill.id);
    history.insert(0, bill);
    // Keep last 100 bills
    if (history.length > 100) history.removeRange(100, history.length);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(history.map((b) => b.toJson()).toList());
    await prefs.setString(_historyBillsKey, jsonStr);
  }

  Future<bool> _launchWhatsApp(String text, [String? recipientPhone]) async {
    final cleanPhone = (recipientPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final phone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final encoded = Uri.encodeComponent(text);
    final urlStr = phone.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$phone&text=$encoded'
        : 'https://api.whatsapp.com/send?text=$encoded';
    final uri = Uri.parse(urlStr);
    return kIsWeb ? launchUrl(uri, webOnlyWindowName: '_blank') : launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Sends the formatted bill receipt via WhatsApp.
  Future<bool> shareBillViaWhatsApp({
    required TableBill bill,
    required String businessName,
    String? recipientPhone,
  }) => _launchWhatsApp(bill.toWhatsAppReceipt(businessName: businessName), recipientPhone ?? bill.customerPhone);

  /// Sends return confirmation message on WhatsApp: only the single requested confirmation note
  Future<bool> sendReturnConfirmationWhatsApp({String? customerPhone}) =>
      _launchWhatsApp('⏳ We received your order! We will prepare and serve it as soon as possible. Please wait! 👨‍🍳✨', customerPhone);

  /// Fetches pending table orders submitted via WebAR
  Future<List<PendingTableOrder>> getPendingOrders(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final res = await ApiClient.dio.get('/businesses/$businessId/table-orders?status=PENDING');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List<dynamic>;
        return list.map((e) => PendingTableOrder.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching pending table orders: $e');
    }
    return [];
  }

  /// Mark order accepted in kitchen
  Future<bool> acceptOrder(String orderId) async {
    try {
      final res = await ApiClient.dio.post('/orders/$orderId/accept');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error accepting order: $e');
      return false;
    }
  }

  /// Discard / cancel order
  Future<bool> cancelOrder(String orderId) async {
    try {
      final res = await ApiClient.dio.post('/orders/$orderId/cancel');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }
}
