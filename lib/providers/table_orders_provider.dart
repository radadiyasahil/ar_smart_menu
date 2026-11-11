import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/services/billing_service.dart';
import '../core/utils/kitchen_sound_alert.dart';
import '../models/bill_model.dart';

class TableOrdersProvider extends ChangeNotifier {
  TableOrdersProvider({BillingService? billingService})
      : _billingService = billingService ?? BillingService();

  final BillingService _billingService;

  List<PendingTableOrder> _pendingOrders = [];
  List<PendingTableOrder> _kitchenOrders = [];
  List<PendingTableOrder> _billRequests = [];
  List<WaiterCallItem> _waiterCalls = [];
  List<TableBill> _activeBills = [];

  final Set<String> _knownPendingOrderIds = {};
  final Set<String> _knownWaiterCallIds = {};
  bool _isFirstLoad = true;

  Timer? _pollingTimer;
  String? _businessId;
  String? _lastAlertMessage;
  bool _isPolling = false;

  List<PendingTableOrder> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<PendingTableOrder> get kitchenOrders => List.unmodifiable(_kitchenOrders);
  List<PendingTableOrder> get billRequests => List.unmodifiable(_billRequests);
  List<WaiterCallItem> get waiterCalls => List.unmodifiable(_waiterCalls);
  List<TableBill> get activeBills => List.unmodifiable(_activeBills);

  int get pendingCount => _pendingOrders.length;
  int get waiterCallsCount => _waiterCalls.length;
  int get billRequestsCount => _billRequests.length;
  int get totalAlertCount => pendingCount + waiterCallsCount + billRequestsCount;
  String? get lastAlertMessage => _lastAlertMessage;

  void clearAlertMessage() {
    _lastAlertMessage = null;
    notifyListeners();
  }

  void startPolling(String businessId) {
    if (businessId.isEmpty) return;
    if (_pollingTimer != null && _businessId == businessId) return;

    _businessId = businessId;
    _pollingTimer?.cancel();

    // Initial immediate fetch
    refresh();

    // 3-second recurring watcher
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      refresh();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _businessId = null;
    _isFirstLoad = true;
    _knownPendingOrderIds.clear();
    _knownWaiterCallIds.clear();
  }

  Future<void> refresh() async {
    final bId = _businessId;
    if (bId == null || bId.isEmpty || _isPolling) return;

    _isPolling = true;
    try {
      final all = await _billingService.getPendingOrders(bId);
      final calls = await _billingService.getWaiterCalls(bId);
      final bills = await _billingService.fetchActiveBills(bId);

      final newPending = all.where((o) => o.isPending).toList();
      final newKitchen = all.where((o) => o.isAccepted).toList();
      final newBillReqs = all
          .where((o) =>
              o.billRequested &&
              !o.isCancelled &&
              (o.isAccepted || o.isCompleted))
          .toList();

      // Detect brand new pending orders to trigger kitchen audio alert
      bool hasNewOrder = false;
      String? alertMsg;
      for (final ord in newPending) {
        if (!_knownPendingOrderIds.contains(ord.id)) {
          _knownPendingOrderIds.add(ord.id);
          if (!_isFirstLoad) {
            hasNewOrder = true;
            alertMsg = '🔔 New Order for ${ord.tableNumber} (₹${ord.totalAmount})';
          }
        }
      }

      // Detect brand new waiter calls to trigger audio alert
      bool hasNewCall = false;
      for (final call in calls) {
        final callId = '${call.tableNumber}_${call.createdAt}';
        if (!_knownWaiterCallIds.contains(callId)) {
          _knownWaiterCallIds.add(callId);
          if (!_isFirstLoad) {
            hasNewCall = true;
            alertMsg = '🔔 Waiter call at ${call.tableNumber}';
          }
        }
      }

      if (hasNewOrder) {
        KitchenSoundAlert.playNewOrderAlert();
      } else if (hasNewCall) {
        KitchenSoundAlert.playWaiterCallAlert();
      }

      _isFirstLoad = false;
      _pendingOrders = newPending;
      _kitchenOrders = newKitchen;
      _billRequests = newBillReqs;
      _waiterCalls = calls;
      _activeBills = bills;
      if (alertMsg != null) {
        _lastAlertMessage = alertMsg;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('TableOrdersProvider poll error: $e');
    } finally {
      _isPolling = false;
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
