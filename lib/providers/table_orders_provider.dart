import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/billing_service.dart';
import '../core/utils/kitchen_sound_alert.dart';
import '../models/bill_model.dart';

class TableOrdersProvider extends ChangeNotifier {
  TableOrdersProvider({BillingService? billingService})
      : _billingService = billingService ?? BillingService() {
    initAutoPrintKot();
  }

  final BillingService _billingService;

  List<PendingTableOrder> _pendingOrders = [];
  List<PendingTableOrder> _kitchenOrders = [];
  List<PendingTableOrder> _billRequests = [];
  List<WaiterCallItem> _waiterCalls = [];
  List<TableBill> _activeBills = [];

  final Set<String> _knownPendingOrderIds = {};
  final Set<String> _knownWaiterCallIds = {};
  final Set<String> _knownBillRequestOrderIds = {};
  final Map<String, String> _knownOrderStatuses = {};
  int _previousActiveBillsCount = 0;
  bool _isFirstLoad = true;

  Timer? _pollingTimer;
  String? _businessId;
  String? _lastAlertMessage;
  bool _isPolling = false;

  bool _autoPrintKot = false;
  bool get autoPrintKot => _autoPrintKot;

  /// Optional callback invoked when a new order arrives and auto-printing is enabled
  void Function(PendingTableOrder order)? onAutoPrintKot;

  Future<void> initAutoPrintKot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPrintKot = prefs.getBool('auto_print_kot_enabled') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setAutoPrintKot(bool value) async {
    _autoPrintKot = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_print_kot_enabled', value);
    } catch (_) {}
  }

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
    _knownBillRequestOrderIds.clear();
    _knownOrderStatuses.clear();
    _previousActiveBillsCount = 0;
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

      String? alertMsg;
      bool hasNewOrder = false;
      bool hasNewCall = false;
      bool hasNewBillReq = false;
      bool hasStatusChange = false;
      String? changedStatus;

      // 1. Detect brand new pending orders
      for (final ord in newPending) {
        if (!_knownPendingOrderIds.contains(ord.id)) {
          _knownPendingOrderIds.add(ord.id);
          if (!_isFirstLoad) {
            hasNewOrder = true;
            alertMsg = '🔔 New Order for ${ord.tableNumber} (₹${ord.totalAmount})';
            if (_autoPrintKot) {
              try {
                onAutoPrintKot?.call(ord);
              } catch (err) {
                debugPrint('Auto-print KOT error: $err');
              }
            }
          }
        }
      }

      // 2. Detect brand new waiter calls
      for (final call in calls) {
        final callId = '${call.tableNumber}_${call.createdAt}';
        if (!_knownWaiterCallIds.contains(callId)) {
          _knownWaiterCallIds.add(callId);
          if (!_isFirstLoad) {
            hasNewCall = true;
            alertMsg = '🙋 Waiter call at ${call.tableNumber}';
          }
        }
      }

      // 3. Detect brand new bill requests
      for (final req in newBillReqs) {
        if (!_knownBillRequestOrderIds.contains(req.id)) {
          _knownBillRequestOrderIds.add(req.id);
          if (!_isFirstLoad) {
            hasNewBillReq = true;
            alertMsg = '🧾 Bill requested for ${req.tableNumber}';
          }
        }
      }

      // 4. Detect order status transitions (e.g. accepted, completed, cancelled)
      if (!_isFirstLoad) {
        for (final ord in all) {
          final oldStatus = _knownOrderStatuses[ord.id];
          if (oldStatus != null && oldStatus != ord.status) {
            hasStatusChange = true;
            changedStatus = ord.status;
            if (ord.status == 'ACCEPTED') {
              alertMsg = '🍳 Table ${ord.tableNumber} order accepted to kitchen';
            } else if (ord.status == 'COMPLETED') {
              alertMsg = '✅ Table ${ord.tableNumber} order marked served';
            } else if (ord.status == 'CANCELLED') {
              alertMsg = '❌ Table ${ord.tableNumber} order was cancelled';
            }
          }
        }
      }

      // 5. Detect settled bills / closed tables
      bool hasSettledBill = false;
      if (!_isFirstLoad && _previousActiveBillsCount > 0 && bills.length < _previousActiveBillsCount) {
        hasSettledBill = true;
        alertMsg = '💰 Table bill settled & closed';
      }

      // Play the highest-priority audio tone
      if (hasNewOrder) {
        KitchenSoundAlert.playNewOrderAlert();
      } else if (hasNewCall) {
        KitchenSoundAlert.playWaiterCallAlert();
      } else if (hasNewBillReq) {
        KitchenSoundAlert.playBillRequestAlert();
      } else if (hasStatusChange && changedStatus != null) {
        KitchenSoundAlert.playOrderStatusChangedAlert(status: changedStatus);
      } else if (hasSettledBill) {
        KitchenSoundAlert.playBillSettledTone();
      }

      // Record known states
      for (final ord in all) {
        _knownOrderStatuses[ord.id] = ord.status;
      }
      _previousActiveBillsCount = bills.length;
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
