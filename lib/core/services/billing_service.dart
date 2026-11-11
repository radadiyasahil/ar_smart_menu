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
  factory QuickCustomPreset.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['Name'] ?? json['title'] ?? json['itemName'] ?? json['dishName'] ?? '').toString().trim();
    final rawPrice = json['defaultPrice'] ?? json['price'] ?? json['Price'] ?? json['amount'] ?? 0;
    final price = (rawPrice is num)
        ? rawPrice.toInt()
        : (int.tryParse(rawPrice.toString()) ?? 0);
    return QuickCustomPreset(rawName, price);
  }
}

class BillingService {
  static const String _activeBillsBaseKey = 'ar_active_table_bills_v1';
  static const String _historyBillsBaseKey = 'ar_history_table_bills_v1';
  static const String _billCounterBaseKey = 'ar_bill_counter_v1';
  static const String _customPresetsBaseKey = 'ar_custom_quick_presets_v1';

  static String _activeKey(String? bId) =>
      (bId != null && bId.isNotEmpty) ? 'ar_active_table_bills_$bId' : _activeBillsBaseKey;
  static String _historyKey(String? bId) =>
      (bId != null && bId.isNotEmpty) ? 'ar_history_table_bills_$bId' : _historyBillsBaseKey;
  static String _counterKey(String? bId) =>
      (bId != null && bId.isNotEmpty) ? 'ar_bill_counter_$bId' : _billCounterBaseKey;
  static String _presetsKey(String? bId) =>
      (bId != null && bId.isNotEmpty) ? 'ar_custom_quick_presets_$bId' : _customPresetsBaseKey;

  static const List<QuickCustomPreset> defaultPresets = [
    QuickCustomPreset('Water Bottle (1L)', 20),
    QuickCustomPreset('Cold Drink (Can)', 40),
    QuickCustomPreset('Extra Butter Roti', 15),
    QuickCustomPreset('Packaging / Parcel Box', 10),
    QuickCustomPreset('Extra Dip / Chutney', 20),
    QuickCustomPreset('Mineral Water (500ml)', 10),
  ];

  Future<List<QuickCustomPreset>> getQuickPresets([String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_presetsKey(businessId)) ??
        ((businessId != null && businessId.isNotEmpty)
            ? prefs.getString(_customPresetsBaseKey)
            : null);
    if (jsonStr == null || jsonStr.isEmpty) {
      await saveQuickPresets(defaultPresets, businessId);
      return List.from(defaultPresets);
    }
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final valid = list
          .map((e) => QuickCustomPreset.fromJson(e as Map<String, dynamic>))
          .where((p) => p.name.trim().isNotEmpty && p.defaultPrice > 0)
          .toList();
      if (valid.isEmpty) {
        await saveQuickPresets(defaultPresets, businessId);
        return List.from(defaultPresets);
      }
      if (valid.length != list.length) {
        await saveQuickPresets(valid, businessId);
      }
      return valid;
    } catch (_) {
      await saveQuickPresets(defaultPresets, businessId);
      return List.from(defaultPresets);
    }
  }

  Future<void> saveQuickPresets(List<QuickCustomPreset> presets, [String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = presets.where((p) => p.name.trim().isNotEmpty && p.defaultPrice > 0).toList();
    await prefs.setString(_presetsKey(businessId), jsonEncode(valid.map((p) => p.toJson()).toList()));
  }

  Future<List<QuickCustomPreset>> addQuickPreset(QuickCustomPreset preset, [String? businessId]) async {
    final cleanName = preset.name.trim();
    if (cleanName.isEmpty || preset.defaultPrice <= 0) {
      return getQuickPresets(businessId);
    }
    final cleanPreset = QuickCustomPreset(cleanName, preset.defaultPrice);
    final list = await getQuickPresets(businessId);
    final idx = list.indexWhere((p) => p.name.toLowerCase() == cleanName.toLowerCase());
    if (idx >= 0) {
      list[idx] = cleanPreset;
    } else {
      list.add(cleanPreset);
    }
    await saveQuickPresets(list, businessId);
    return list;
  }

  Future<List<QuickCustomPreset>> deleteQuickPreset(String name, [String? businessId]) async {
    final list = await getQuickPresets(businessId);
    final target = name.trim().toLowerCase();
    list.removeWhere((p) => p.name.trim().toLowerCase() == target);
    if (list.isEmpty) {
      await saveQuickPresets(defaultPresets, businessId);
      return List.from(defaultPresets);
    }
    await saveQuickPresets(list, businessId);
    return list;
  }

  Future<String> generateNextBillId(String businessInitials, [String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _counterKey(businessId);
    final count = (prefs.getInt(key) ?? 1000) + 1;
    await prefs.setInt(key, count);
    final prefix = businessInitials.isNotEmpty ? businessInitials.toUpperCase() : 'BILL';
    return '$prefix-$count';
  }

  Future<List<TableBill>> getCachedActiveBills([String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_activeKey(businessId));
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => TableBill.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading active bills: $e');
      return [];
    }
  }

  Future<List<TableBill>> getActiveBills([String? businessId]) async {
    if (businessId != null && businessId.isNotEmpty) {
      try {
        final serverBills = await fetchActiveBills(businessId);
        if (serverBills.isNotEmpty) return serverBills;
      } catch (_) {}
    }
    return getCachedActiveBills(businessId);
  }

  /// Synthesizes active table bills from the backend database for seamless multi-device sync
  Future<List<TableBill>> fetchActiveBills(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final orders = await getPendingOrders(businessId);
      final acceptedOrders = orders
          .where((o) => !o.isCancelled && (o.isAccepted || o.isCompleted))
          .toList();

      final groupedByTable = <String, List<PendingTableOrder>>{};
      for (final ord in acceptedOrders) {
        final cleanTable = ord.tableNumber.trim().isNotEmpty ? ord.tableNumber.trim() : 'Dine-in';
        groupedByTable.putIfAbsent(cleanTable, () => []).add(ord);
      }

      final resultBills = <TableBill>[];
      for (final entry in groupedByTable.entries) {
        final tableOrders = entry.value;
        final firstOrder = tableOrders.first;
        final combinedItems = <BillItem>[];

        for (final ord in tableOrders) {
          for (final it in ord.items) {
            final idx = combinedItems.indexWhere((c) =>
                (it.id.isNotEmpty && c.id == it.id) ||
                c.name.toLowerCase() == it.name.toLowerCase());
            if (idx >= 0) {
              combinedItems[idx].quantity += it.quantity;
            } else {
              combinedItems.add(BillItem(
                id: it.id,
                name: it.name,
                unitPrice: it.unitPrice,
                quantity: it.quantity,
              ));
            }
          }
        }

        final bill = TableBill(
          id: 'TBL-${firstOrder.id.length > 6 ? firstOrder.id.substring(0, 6) : firstOrder.id}',
          tableNumber: entry.key,
          createdAt: firstOrder.createdAt,
          customerPhone: tableOrders
              .firstWhere((o) => o.customerPhone.isNotEmpty, orElse: () => firstOrder)
              .customerPhone,
          items: combinedItems,
        );
        resultBills.add(bill);
      }

      if (resultBills.isNotEmpty) {
        await saveActiveBills(resultBills, businessId);
      }
      return resultBills;
    } catch (e) {
      debugPrint('Error fetching active bills from server: $e');
      return getCachedActiveBills(businessId);
    }
  }

  Future<void> saveActiveBills(List<TableBill> bills, [String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(bills.map((b) => b.toJson()).toList());
    await prefs.setString(_activeKey(businessId), jsonStr);
  }

  Future<List<TableBill>> getCompletedHistory([String? businessId]) async {
    if (businessId == null || businessId.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKey(businessId);
    final jsonStr = prefs.getString(key);
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
      await prefs.setString(key, jsonEncode(bills.map((b) => b.toJson()).toList()));
      return bills;
    } catch (e) {
      debugPrint('Error loading history bills: $e');
      return [];
    }
  }

  Future<void> saveHistoryBills(List<TableBill> bills, [String? businessId]) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = bills.where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0).toList();
    final jsonStr = jsonEncode(sanitized.map((b) => b.toJson()).toList());
    await prefs.setString(_historyKey(businessId), jsonStr);
  }

  Future<void> archiveBill(TableBill bill, [String? businessId]) async {
    // Only archive actual orders with items
    if (bill.items.isEmpty || bill.grandTotal <= 0) return;
    final history = await getCompletedHistory(businessId);
    history.removeWhere((b) => b.id == bill.id);
    history.insert(0, bill);
    // Keep last 100 bills
    if (history.length > 100) history.removeRange(100, history.length);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(history.map((b) => b.toJson()).toList());
    await prefs.setString(_historyKey(businessId), jsonStr);
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

  /// Fetches active table orders (pending, preparing, and bill requests)
  Future<List<PendingTableOrder>> getPendingOrders(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final res = await ApiClient.dio.get('/businesses/$businessId/table-orders?status=ACTIVE');
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

  /// Mark order as served to table
  Future<bool> markOrderServed(String orderId) async {
    try {
      final res = await ApiClient.dio.post('/orders/$orderId/serve');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking order served: $e');
      return false;
    }
  }

  /// Marks all accepted orders for a table as served
  Future<bool> markTableOrdersServed(String businessId, String tableNumber) async {
    try {
      final safeTable = Uri.encodeComponent(tableNumber.trim());
      final res = await ApiClient.dio.post('/businesses/$businessId/table/$safeTable/serve-all');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking table orders served: $e');
      return false;
    }
  }

  /// Closes table session in backend (completes all orders, clears bill request)
  Future<bool> closeTableSession(String businessId, String tableNumber) async {
    try {
      final safeTable = Uri.encodeComponent(tableNumber.trim());
      final res = await ApiClient.dio.post('/businesses/$businessId/table/$safeTable/close');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error closing table session: $e');
      return false;
    }
  }

  /// Fetches active waiter calls for a business
  Future<List<WaiterCallItem>> getWaiterCalls(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final res = await ApiClient.dio.get('/businesses/$businessId/waiter-calls');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List<dynamic>;
        return list.map((e) => WaiterCallItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching waiter calls: $e');
    }
    return [];
  }

  /// Marks a table's waiter call as attended / cleared
  Future<bool> attendWaiterCall(String businessId, String tableNumber) async {
    try {
      final safeTable = Uri.encodeComponent(tableNumber.trim());
      final res = await ApiClient.dio.post('/businesses/$businessId/table/$safeTable/attend-waiter');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error attending waiter call: $e');
      return false;
    }
  }

  /// Adds unlisted/custom items (e.g. Water Bottle, Extra Roti) directly to a live table session
  Future<bool> addItemsToTable(
    String businessId,
    String tableNumber, {
    required List<BillItem> items,
    String? instructions,
  }) async {
    try {
      final safeTable = Uri.encodeComponent(tableNumber.trim());
      final res = await ApiClient.dio.post(
        '/businesses/$businessId/table/$safeTable/add-items',
        data: {
          'items': items.map((i) => {
            'id': i.id,
            'name': i.name,
            'quantity': i.quantity,
            'unitPrice': i.unitPrice,
          }).toList(),
          'instructions': instructions ?? 'Added by restaurant staff',
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding items to table: $e');
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

  /// Fetches today's completed / paid table orders from backend to restore history on login/re-login
  Future<List<TableBill>> fetchTodayHistoryOrders(String businessId) async {
    if (businessId.isEmpty) return [];
    try {
      final res = await ApiClient.dio.get('/businesses/$businessId/table-orders?status=TODAY');
      final data = res.data;
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List<dynamic>;
        final orders = list.map((e) => PendingTableOrder.fromJson(e as Map<String, dynamic>)).toList();
        final bills = <TableBill>[];
        for (final o in orders) {
          if (o.isCancelled) continue;
          final isFinished = o.status == 'PAID' || o.status == 'SETTLED' || o.status == 'COMPLETED';
          if (!isFinished) continue;
          final bill = TableBill(
            id: 'ORD-${o.id.length > 6 ? o.id.substring(0, 6) : o.id}',
            tableNumber: o.tableNumber,
            createdAt: o.createdAt,
            paidAt: o.completedAt ?? o.createdAt,
            isPaid: true,
            paymentMode: 'Online / Paid',
            customerPhone: o.customerPhone,
            items: o.items.map((i) => BillItem(
              id: i.id,
              name: i.name,
              unitPrice: i.unitPrice,
              quantity: i.quantity,
            )).toList(),
          );
          if (bill.items.isNotEmpty) bills.add(bill);
        }
        return bills;
      }
    } catch (e) {
      debugPrint('Error fetching today history orders: $e');
    }
    return [];
  }
}
