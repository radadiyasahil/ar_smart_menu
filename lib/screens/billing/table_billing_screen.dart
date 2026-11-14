import '../../core/services/qr_service.dart';
import '../../core/services/table_stand_pdf_service.dart';
import '../../models/qr_code_model.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/billing_service.dart';
import '../../core/services/bill_receipt_pdf_service.dart';
import '../../core/utils/kitchen_sound_alert.dart';
import '../../models/bill_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/table_orders_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum TableFloorStatus {
  available,

  orderPending,

  cooking,

  dining,

  billRequested,
}

class TableBillingScreen extends StatefulWidget {
  const TableBillingScreen({super.key});

  @override
  State<TableBillingScreen> createState() => _TableBillingScreenState();
}

class _TableBillingScreenState extends State<TableBillingScreen>
    with SingleTickerProviderStateMixin {
  final _billingService = BillingService();

  late final TabController _tabController = TabController(
    length: 5,

    vsync: this,
  );

  final _qrService = QrService();

  List<QrCodeModel> _configuredTableQrs = [];

  String _floorFilter =
      'all'; // 'all', 'available', 'occupied', 'bill_requested'

  final _phoneController = TextEditingController();

  List<TableBill> _activeBills = [];

  List<TableBill> _historyBills = [];

  List<PendingTableOrder> _pendingOrders = [];

  List<PendingTableOrder> _kitchenOrders = [];

  List<PendingTableOrder> _billRequests = [];

  List<WaiterCallItem> _waiterCalls = [];

  List<QuickCustomPreset> _quickPresets = [];

  Timer? _pollingTimer;

  bool _loading = true;

  int _selectedTableIndex = 0;

  String get _businessId =>
      context.read<BusinessProvider>().business?.id.toString() ?? '';

  @override
  void initState() {
    super.initState();

    _initScreenData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final ordersProv = context.read<TableOrdersProvider>();
        ordersProv.onAutoPrintKot = (order) {
          _printKot(order);
        };
      }
    });

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),

      (_) => _loadPendingOrders(),
    );
  }

  Future<void> _initScreenData() async {
    await _loadConfiguredQrs();
    await _loadBills();
    await _loadPendingOrders();
  }

  static String _canonicalTableName(String raw) {
    var clean = raw.trim();
    if (clean.isEmpty) return 'Table 1';

    // Strip duplicate leading 'Table' words: e.g. 'Table Table 1' -> 'Table 1'
    while (RegExp(r'^table\s+table\s*', caseSensitive: false).hasMatch(clean)) {
      clean = clean
          .replaceFirst(RegExp(r'^table\s+', caseSensitive: false), '')
          .trim();
    }

    // Pure number: '2' -> 'Table 2'
    final m1 = RegExp(r'^(\d+)$').firstMatch(clean);
    if (m1 != null) {
      return 'Table ${int.parse(m1.group(1)!)}';
    }

    // 'table 2', 'Table 02', 't-2', 't2', 'tbl 2' -> 'Table 2'
    final m2 = RegExp(
      r'^(?:table|t|tbl)[-_\s]*(\d+)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (m2 != null) {
      return 'Table ${int.parse(m2.group(1)!)}';
    }

    return clean;
  }

  static bool _isSameTable(String a, String b) {
    return _canonicalTableName(a).toLowerCase() ==
        _canonicalTableName(b).toLowerCase();
  }

  static bool _isToday(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> _loadConfiguredQrs() async {
    try {
      final allQrs = await _qrService.list();

      if (mounted) {
        setState(() {
          _configuredTableQrs = allQrs.where((q) => q.isTable).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading table QRs: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();

    _tabController.dispose();

    _phoneController.dispose();

    try {
      final ordersProv = context.read<TableOrdersProvider>();
      if (ordersProv.onAutoPrintKot != null) {
        ordersProv.onAutoPrintKot = null;
      }
    } catch (_) {}

    super.dispose();
  }

  Future<void> _loadBills({bool showLoading = true}) async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }

    await _loadConfiguredQrs();

    final active = await _billingService.getActiveBills(bId);

    final history = await _billingService.getCompletedHistory(bId);

    final presets = await _billingService.getQuickPresets(bId);
    if (bId.isNotEmpty) {
      try {
        final serverTodayBills = await _billingService.fetchTodayHistoryOrders(bId);
        for (final s in serverTodayBills) {
          final alreadyExists = history.any((h) =>
              h.id == s.id ||
              (_isSameTable(h.tableNumber, s.tableNumber) &&
                  (h.paidAt ?? h.createdAt).toLocal().difference((s.paidAt ?? s.createdAt).toLocal()).inMinutes.abs() < 5));
          if (!alreadyExists) {
            history.add(s);
          }
        }
        history.sort((a, b) => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt));
        await _billingService.saveHistoryBills(history, bId);
      } catch (e) {
        debugPrint('Error syncing today history bills: $e');
      }
    }

    // Do not show any default table when 0 items; clean up empty tables from storage
    active.removeWhere((b) => b.items.isEmpty);

    // Normalize table names and merge any duplicate active tables
    final uniqueActive = <TableBill>[];
    for (final b in active) {
      b.tableNumber = _canonicalTableName(b.tableNumber);
      final existingIdx = uniqueActive.indexWhere(
        (u) => _isSameTable(u.tableNumber, b.tableNumber),
      );
      if (existingIdx >= 0) {
        uniqueActive[existingIdx].addItems(b.items);
      } else {
        uniqueActive.add(b);
      }
    }

    await _billingService.saveActiveBills(uniqueActive, bId);

    if (!mounted) return;

    final previouslySelectedTableNum = (_activeBills.isNotEmpty &&
            _selectedTableIndex >= 0 &&
            _selectedTableIndex < _activeBills.length)
        ? _activeBills[_selectedTableIndex].tableNumber
        : null;

    setState(() {
      _activeBills = uniqueActive;

      _historyBills = history;

      _quickPresets = presets
          .where((p) => p.name.trim().isNotEmpty && p.defaultPrice > 0)
          .toList();

      if (previouslySelectedTableNum != null) {
        final matchingIdx = uniqueActive.indexWhere(
          (b) => _isSameTable(b.tableNumber, previouslySelectedTableNum),
        );
        if (matchingIdx >= 0) {
          _selectedTableIndex = matchingIdx;
        } else if (_selectedTableIndex >= uniqueActive.length) {
          _selectedTableIndex = uniqueActive.isEmpty ? 0 : uniqueActive.length - 1;
        }
      } else if (_selectedTableIndex >= uniqueActive.length) {
        _selectedTableIndex = uniqueActive.isEmpty ? 0 : uniqueActive.length - 1;
      }

      _syncPhone();

      _loading = false;
    });
  }

  bool _isFetchingPendingOrders = false;

  Future<void> _loadPendingOrders() async {
    if (_isFetchingPendingOrders) return;
    _isFetchingPendingOrders = true;

    try {
      final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';

      if (bId.isNotEmpty) {
        final all = await _billingService.getPendingOrders(bId);
        final calls = await _billingService.getWaiterCalls(bId);

        if (_historyBills.isEmpty) {
          try {
            final serverTodayBills = await _billingService.fetchTodayHistoryOrders(bId);
            if (serverTodayBills.isNotEmpty && mounted) {
              setState(() {
                _historyBills = serverTodayBills;
              });
              await _billingService.saveHistoryBills(serverTodayBills, bId);
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _pendingOrders = all.where((o) => o.isPending).toList();

            _kitchenOrders = all.where((o) => o.isAccepted).toList();

            final rawBillReqs = all
                .where(
                  (o) =>
                      o.billRequested &&
                      !o.isCancelled &&
                      (o.isAccepted || o.isCompleted),
                )
                .toList();

            // Deduplicate bill requests so each table only appears once with consolidated details
            final uniqueBillReqs = <PendingTableOrder>[];
            for (final o in rawBillReqs) {
              final idx = uniqueBillReqs.indexWhere(
                (u) => _isSameTable(u.tableNumber, o.tableNumber),
              );
              if (idx >= 0) {
                final prev = uniqueBillReqs[idx];
                final combinedItems = [...prev.items, ...o.items];
                final combinedAmount = prev.totalAmount + o.totalAmount;
                final latestReqAt = (o.billRequestedAt != null &&
                        (prev.billRequestedAt == null ||
                            o.billRequestedAt!.isAfter(prev.billRequestedAt!)))
                    ? o.billRequestedAt
                    : prev.billRequestedAt;

                uniqueBillReqs[idx] = PendingTableOrder(
                  id: o.id,
                  businessId: o.businessId,
                  tableNumber: _canonicalTableName(o.tableNumber),
                  round: o.round > prev.round ? o.round : prev.round,
                  status: o.status,
                  instructions: o.instructions.isNotEmpty
                      ? o.instructions
                      : prev.instructions,
                  customerPhone: o.customerPhone.isNotEmpty
                      ? o.customerPhone
                      : prev.customerPhone,
                  items: combinedItems,
                  totalAmount: combinedAmount,
                  billRequested: true,
                  billRequestedAt: latestReqAt,
                  createdAt: prev.createdAt.isBefore(o.createdAt)
                      ? prev.createdAt
                      : o.createdAt,
                );
              } else {
                uniqueBillReqs.add(
                  PendingTableOrder(
                    id: o.id,
                    businessId: o.businessId,
                    tableNumber: _canonicalTableName(o.tableNumber),
                    round: o.round,
                    status: o.status,
                    instructions: o.instructions,
                    customerPhone: o.customerPhone,
                    items: List.from(o.items),
                    totalAmount: o.totalAmount,
                    billRequested: o.billRequested,
                    billRequestedAt: o.billRequestedAt,
                    createdAt: o.createdAt,
                  ),
                );
              }
            }
            _billRequests = uniqueBillReqs;

            _waiterCalls = calls;

            // Automatically ensure tables with pending orders, kitchen orders, or bill requests exist in active bills
            for (final order in (_pendingOrders + _kitchenOrders + _billRequests)) {
              final canonical = _canonicalTableName(order.tableNumber);
              final existingIdx = _activeBills.indexWhere(
                (b) => _isSameTable(b.tableNumber, canonical),
              );
              if (existingIdx < 0) {
                final billId = 'ORD-${order.id.length > 5 ? order.id.substring(0, 5) : order.id}';
                final newBill = TableBill(
                  id: billId,
                  tableNumber: canonical,
                  createdAt: order.createdAt,
                  customerPhone: order.customerPhone,
                );
                if (!order.isPending) {
                  newBill.addItems(order.items);
                }
                _activeBills.add(newBill);
              }
            }
            if (_activeBills.isNotEmpty && _selectedTableIndex >= _activeBills.length) {
              _selectedTableIndex = _activeBills.length - 1;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
    } finally {
      _isFetchingPendingOrders = false;
    }
  }

  bool _isManualRefreshing = false;
  DateTime? _lastRefreshedAt;

  Future<void> _manualRefresh() async {
    if (_isManualRefreshing) return;
    setState(() => _isManualRefreshing = true);

    try {
      await _loadBills(showLoading: false);
      await _loadPendingOrders();

      if (mounted) {
        setState(() {
          _lastRefreshedAt = DateTime.now();
        });

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Billing updated • ${_activeBills.length} active table${_activeBills.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    } catch (e) {
      debugPrint('Manual refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isManualRefreshing = false);
      }
    }
  }

  Future<void> _attendWaiterCall(String tableNumber) async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    if (bId.isEmpty) return;
    final success = await _billingService.attendWaiterCall(bId, tableNumber);
    await _loadPendingOrders();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attended waiter request for ${_canonicalTableName(tableNumber)}.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _verifyNewParty(String tableNumber) async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    if (bId.isEmpty) return;
    final success = await _billingService.verifyNewParty(bId, tableNumber);
    await _loadPendingOrders();
    await _loadBills();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${_canonicalTableName(tableNumber)} verified & reset for New Party!'),
          backgroundColor: const Color(0xFF8B5CF6),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _markOrderServed(PendingTableOrder order) async {
    final success = await _billingService.markOrderServed(order.id);
    if (success) {
      KitchenSoundAlert.playOrderServedChime();
    }

    await _loadPendingOrders();

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_canonicalTableName(order.tableNumber)} (Round ${order.round}) marked as SERVED! Customer updated.',
          ),

          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _markCurrentTableServed() async {
    final bill = _currentBill;

    if (bill == null) return;

    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';

    if (bId.isEmpty) return;

    final success = await _billingService.markTableOrdersServed(
      bId,

      bill.tableNumber,
    );

    final rawDigits = bill.tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isNotEmpty && rawDigits != bill.tableNumber) {
      await _billingService.markTableOrdersServed(bId, rawDigits);
    }

    await _loadPendingOrders();

    if (mounted && success) {
      KitchenSoundAlert.playOrderServedChime();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All dishes for ${_canonicalTableName(bill.tableNumber)} marked as SERVED! Customer view updated.',
          ),

          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _acceptPendingOrder(PendingTableOrder order) async {
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;

    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot accept orders while business is deactivated. Please reactivate your business.',
          ),

          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    await _billingService.acceptOrder(order.id);
    KitchenSoundAlert.playOrderAcceptedChime();

    final canonicalOrderTable = _canonicalTableName(order.tableNumber);

    final existingIdx = _activeBills.indexWhere(
      (b) => _isSameTable(b.tableNumber, canonicalOrderTable),
    );

    TableBill targetBill;

    if (existingIdx >= 0) {
      targetBill = _activeBills[existingIdx];
      targetBill.tableNumber = canonicalOrderTable;

      _selectedTableIndex = existingIdx;
    } else {
      final billId = await _billingService.generateNextBillId(_getInitials());

      targetBill = TableBill(
        id: billId,

        tableNumber: canonicalOrderTable,

        createdAt: DateTime.now(),
      );

      _activeBills.add(targetBill);

      _selectedTableIndex = _activeBills.length - 1;
    }

    targetBill.addItems(order.items);

    if (order.customerPhone.isNotEmpty) {
      targetBill.customerPhone = order.customerPhone;
    }

    _syncPhone();

    await _save();

    await _loadPendingOrders();
    await _loadBills();

    // Customer tracks order live in WebAR experience; no return WhatsApp message sent upon acceptance.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order for $canonicalOrderTable accepted into kitchen! Dishes added to bill.',
          ),

          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _discardPendingOrder(PendingTableOrder order) async {
    await _billingService.cancelOrder(order.id);
    KitchenSoundAlert.playOrderCancelledTone();

    _billRequests.removeWhere(
      (o) => _isSameTable(o.tableNumber, order.tableNumber),
    );

    await _loadPendingOrders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order for ${_canonicalTableName(order.tableNumber)} declined.',
          ),
        ),
      );
    }
  }

  TableFloorStatus _getTableStatus(String tableName) {
    final hasBillReq = _billRequests.any(
      (r) => _isSameTable(r.tableNumber, tableName),
    );

    if (hasBillReq) return TableFloorStatus.billRequested;

    final hasPending = _pendingOrders.any(
      (p) => _isSameTable(p.tableNumber, tableName),
    );

    if (hasPending) return TableFloorStatus.orderPending;

    final hasKitchen = _kitchenOrders.any(
      (k) => _isSameTable(k.tableNumber, tableName),
    );

    if (hasKitchen) return TableFloorStatus.cooking;

    final bill = _findActiveBill(tableName);

    if (bill != null && bill.items.isNotEmpty) return TableFloorStatus.dining;

    return TableFloorStatus.available;
  }

  TableBill? _findActiveBill(String tableName) {
    for (final b in _activeBills) {
      if (_isSameTable(b.tableNumber, tableName)) return b;
    }

    return null;
  }

  List<String> get _allFloorTableNames {
    final names = <String>{};

    for (final b in _activeBills) {
      if (b.tableNumber.trim().isNotEmpty && b.items.isNotEmpty) {
        names.add(_canonicalTableName(b.tableNumber));
      }
    }

    for (final o in _pendingOrders) {
      if (o.tableNumber.trim().isNotEmpty) {
        names.add(_canonicalTableName(o.tableNumber));
      }
    }

    for (final o in _kitchenOrders) {
      if (o.tableNumber.trim().isNotEmpty) {
        names.add(_canonicalTableName(o.tableNumber));
      }
    }

    for (final o in _billRequests) {
      if (o.tableNumber.trim().isNotEmpty) {
        names.add(_canonicalTableName(o.tableNumber));
      }
    }

    for (final c in _waiterCalls) {
      if (c.tableNumber.trim().isNotEmpty) {
        names.add(_canonicalTableName(c.tableNumber));
      }
    }

    for (final qr in _configuredTableQrs) {
      final tNum = TableStandPdfService.extractTableNumber(
        qr.slug,
        qr.productName,
        webUrl: qr.webUrl,
      );

      if (tNum.isNotEmpty) {
        names.add(_canonicalTableName(tNum));
      }
    }

    final list = names.toList();

    list.sort((a, b) {
      final na = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;

      final nb = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;

      if (na != nb) return na.compareTo(nb);

      return a.compareTo(b);
    });

    return list;
  }

  Future<void> _openTableChatDirect(String tableName) async {
    final canonicalName = _canonicalTableName(tableName);
    int existingIdx = _activeBills.indexWhere(
      (b) => _isSameTable(b.tableNumber, canonicalName),
    );

    if (existingIdx < 0) {
      // Find orders for this table to populate the bill
      final tableOrders = (_kitchenOrders + _billRequests + _pendingOrders)
          .where((o) => _isSameTable(o.tableNumber, canonicalName) && !o.isCancelled)
          .toList();

      final billId = await _billingService.generateNextBillId(_getInitials());
      final newBill = TableBill(
        id: billId,
        tableNumber: canonicalName,
        createdAt: DateTime.now(),
      );
      for (final order in tableOrders) {
        newBill.addItems(order.items);
        if (order.customerPhone.isNotEmpty) {
          newBill.customerPhone = order.customerPhone;
        }
      }
      _activeBills.add(newBill);
      await _save();
      existingIdx = _activeBills.length - 1;
    }

    setState(() {
      _selectedTableIndex = existingIdx;
      _syncPhone();
    });
    _tabController.animateTo(1);
  }

  Future<void> _openTableFromFloor(String tableName) async {
    final canonicalName = _canonicalTableName(tableName);

    final existingIdx = _activeBills.indexWhere(
      (b) => _isSameTable(b.tableNumber, canonicalName),
    );

    if (existingIdx >= 0) {
      setState(() {
        _selectedTableIndex = existingIdx;

        _syncPhone();
      });

      _tabController.animateTo(1);

      return;
    }

    final hasPending = _pendingOrders.any(
      (p) => _isSameTable(p.tableNumber, canonicalName),
    );
    if (hasPending) {
      await _openTableChatDirect(canonicalName);
      return;
    }

    final hasBillReq = _billRequests.any(
      (r) => _isSameTable(r.tableNumber, canonicalName),
    );
    if (hasBillReq) {
      await _openTableChatDirect(canonicalName);
      return;
    }

    final hasKitchen = _kitchenOrders.any(
      (k) => _isSameTable(k.tableNumber, canonicalName),
    );
    if (hasKitchen) {
      await _openTableChatDirect(canonicalName);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,

      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Text(
          'Open $canonicalName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        content: Text(
          'Start a new dining & billing session for $canonicalName?',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Open Table'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = await _billingService.generateNextBillId(_getInitials());

    setState(() {
      _activeBills.add(
        TableBill(
          id: id,
          tableNumber: canonicalName,
          createdAt: DateTime.now(),
        ),
      );

      _selectedTableIndex = _activeBills.length - 1;

      _syncPhone();
    });

    await _save();

    _tabController.animateTo(1);
  }

  void _syncPhone() =>
      _phoneController.text = _currentBill?.customerPhone ?? '';

  String _getInitials() {
    final b = context.read<BusinessProvider>().business?.businessName ?? 'MC';

    final parts = b.trim().split(RegExp(r'\s+'));

    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (b.length >= 2 ? b.substring(0, 2).toUpperCase() : 'BILL');
  }

  TableBill? get _currentBill =>
      _activeBills.isNotEmpty && _selectedTableIndex < _activeBills.length
      ? _activeBills[_selectedTableIndex]
      : null;

  Future<void> _save() async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    await _billingService.saveActiveBills(_activeBills, bId);

    setState(() {});
  }

  void _addQuickPreset(QuickCustomPreset p) {
    final bill = _currentBill;

    if (bill == null || p.name.trim().isEmpty || p.defaultPrice <= 0) return;

    final isDeactivated = context.read<BusinessProvider>().isDeactivated;

    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business is deactivated. Reactivate to add items to bills.',
          ),

          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final newItem = BillItem(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      name: p.name,
      unitPrice: p.defaultPrice,
      quantity: 1,
      isCustom: true,
    );
    bill.addItem(
      id: newItem.id,
      name: newItem.name,
      unitPrice: newItem.unitPrice,
      isCustom: true,
    );

    _save();

    if (_businessId.isNotEmpty) {
      _billingService.addItemsToTable(
        _businessId,
        bill.tableNumber,
        items: [newItem],
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${p.name}" to bill!'),

        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteQuickPreset(QuickCustomPreset p) async {
    final updated = await _billingService.deleteQuickPreset(p.name, _businessId);

    setState(() => _quickPresets = updated
        .where((x) => x.name.trim().isNotEmpty && x.defaultPrice > 0)
        .toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${p.name}" from Quick Items List.')),
      );
    }
  }

    Future<void> _showAddCustomPresetDialog() async {
    await _showAddCustomDishDialog();
  }

  Future<void> _showAddCustomDishDialog({bool addToBillDirectly = true}) async {
    final nameCtl = TextEditingController();
    final priceCtl = TextEditingController();
    int quantity = 1;
    bool saveToQuickList = true;
    bool addToCurrentBill = addToBillDirectly && _currentBill != null;

    final bill = _currentBill;
    final tableName = bill != null ? _canonicalTableName(bill.tableNumber) : '';
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E202A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: AppColors.primaryOrange, size: 22),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Add Unlisted / Custom Item',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add unlisted items (e.g. Mineral Water, Extra Roti, Salad, Parcel Box) directly to the bill.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Dish / Item Name',
                    hintText: 'e.g. Mineral Water (1L)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceCtl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Price (₹)',
                          hintText: 'e.g. 20',
                          labelStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2D3A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (quantity > 1) {
                                      setDlgState(() => quantity--);
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setDlgState(() => quantity++);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (bill != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Add to current bill ($tableName)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    value: addToCurrentBill,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (val) =>
                        setDlgState(() => addToCurrentBill = val ?? true),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Save to Quick Items list (for 1-tap adding)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: saveToQuickList,
                  activeColor: AppColors.primaryOrange,
                  onChanged: (val) =>
                      setDlgState(() => saveToQuickList = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              onPressed: () async {
                final n = nameCtl.text.trim();
                final p = int.tryParse(priceCtl.text.trim()) ?? 0;

                if (n.length < 2) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Item name must be at least 2 characters.'),
                    ),
                  );
                  return;
                }

                if (p <= 0 || p > 100000) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid price between ₹1 and ₹1,00,000.',
                      ),
                    ),
                  );
                  return;
                }

                if (addToCurrentBill && bill != null) {
                  final newItem = BillItem(
                    id: 'c-${DateTime.now().millisecondsSinceEpoch}',
                    name: n,
                    unitPrice: p,
                    quantity: quantity,
                    isCustom: true,
                  );
                  bill.addItem(
                    id: newItem.id,
                    name: newItem.name,
                    unitPrice: newItem.unitPrice,
                    quantity: newItem.quantity,
                    isCustom: true,
                  );
                  await _save();
                  if (_businessId.isNotEmpty) {
                    _billingService.addItemsToTable(
                      _businessId,
                      bill.tableNumber,
                      items: [newItem],
                    );
                  }
                }

                if (saveToQuickList) {
                  final updated = await _billingService.addQuickPreset(
                    QuickCustomPreset(n, p),
                    _businessId,
                  );
                  setState(() => _quickPresets = updated
                      .where((x) => x.name.trim().isNotEmpty && x.defaultPrice > 0)
                      .toList());
                }

                if (ctx.mounted) Navigator.pop(ctx);

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      addToCurrentBill && bill != null
                          ? 'Added $quantity× "$n (₹$p)" to $tableName bill!'
                          : 'Saved "$n (₹$p)" to Quick Items list!',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
              child: Text(
                addToCurrentBill && bill != null
                    ? 'Add to Bill'
                    : 'Save to Quick List',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenuPicker() async {
    final bill = _currentBill;

    if (bill == null) return;

    final isDeactivated = context.read<BusinessProvider>().isDeactivated;

    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business is currently deactivated. Reactivate to add menu items.',
          ),

          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final products = context
        .read<ProductProvider>()
        .products
        .where((p) => p.isLive)
        .toList();

    await showModalBottomSheet(
      context: context,

      backgroundColor: const Color(0xFF161821),

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),

      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,

        maxChildSize: 0.9,

        expand: false,

        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  const Text(
                    'Select Dish from Menu',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 16,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),

                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Option to add unlisted / custom dish directly
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddCustomDishDialog();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt,
                          size: 16,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '+ Add Unlisted / Custom Item',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'e.g. Water Bottle, Extra Roti, Chutney, Parcel Box',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.primaryOrange,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),

                        child: Column(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            Icon(
                              Icons.restaurant_menu,

                              size: 48,

                              color: Colors.grey,
                            ),

                            SizedBox(height: 12),

                            Text(
                              'No Live Dishes Available',

                              style: TextStyle(
                                color: Colors.white,

                                fontSize: 16,

                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              'Only active dishes with "Live" status can be billed to customers.',

                              textAlign: TextAlign.center,

                              style: TextStyle(
                                color: Colors.grey,

                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: sc,

                      itemCount: products.length,

                      separatorBuilder: (_, _) =>
                          const Divider(color: Colors.white10, height: 1),

                      itemBuilder: (_, i) {
                        final p = products[i];

                        final price = p.pricePaise != null
                            ? (p.pricePaise! / 100).round()
                            : 0;

                        return ListTile(
                          title: Text(
                            p.name,

                            style: const TextStyle(
                              color: Colors.white,

                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          subtitle: Text(
                            '₹$price',

                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                            ),
                          ),

                          trailing: FilledButton.tonal(
                            onPressed: () {
                              final newItem = BillItem(
                                id: p.id,
                                name: p.name,
                                unitPrice: price,
                                quantity: 1,
                              );
                              bill.addItem(
                                id: newItem.id,
                                name: newItem.name,
                                unitPrice: newItem.unitPrice,
                              );

                              _save();

                              if (_businessId.isNotEmpty) {
                                _billingService.addItemsToTable(
                                  _businessId,
                                  bill.tableNumber,
                                  items: [newItem],
                                );
                              }

                              Navigator.pop(ctx);
                            },

                            child: const Text('Add'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTableDialog() async {
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;

    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot open tables while business is deactivated. Please reactivate your business.',
          ),

          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final ctl = TextEditingController();

    await showDialog(
      context: context,

      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),

        title: const Text(
          'Open New Table / Session',

          style: TextStyle(color: Colors.white, fontSize: 16),
        ),

        content: TextField(
          controller: ctl,

          autofocus: true,

          style: const TextStyle(color: Colors.white),

          decoration: const InputDecoration(
            labelText: 'Table Number / Name',

            hintText: 'e.g. Table 4, Rooftop',
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),

            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),

            onPressed: () async {
              final raw = ctl.text.trim();

              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a table number or name.'),
                  ),
                );

                return;
              }

              final t = _canonicalTableName(raw);

              final existingIdx = _activeBills.indexWhere(
                (b) => _isSameTable(b.tableNumber, t),
              );

              if (existingIdx >= 0) {
                setState(() {
                  _selectedTableIndex = existingIdx;
                  _syncPhone();
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _tabController.animateTo(1);
                return;
              }

              final id = await _billingService.generateNextBillId(
                _getInitials(),
              );

              setState(() {
                _activeBills.add(
                  TableBill(id: id, tableNumber: t, createdAt: DateTime.now()),
                );

                _selectedTableIndex = _activeBills.length - 1;

                _syncPhone();
              });

              await _save();

              if (ctx.mounted) Navigator.pop(ctx);
              _tabController.animateTo(1);
            },

            child: const Text('Open Table'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final bill = _currentBill;

    if (bill == null || bill.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 item to the bill.'),
        ),
      );

      return;
    }

    final isDeactivated = context.read<BusinessProvider>().isDeactivated;

    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Business is deactivated. Operations are paused until reactivated.',
          ),

          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final phone = _phoneController.text.trim();

    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^[6-9]\d{9}$');

      if (!phoneRegex.hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter a valid 10-digit mobile number starting with 6-9.',
            ),

            backgroundColor: Colors.redAccent,
          ),
        );

        return;
      }
    }

    final bName =
        context.read<BusinessProvider>().business?.businessName ??
        'Our Restaurant';

    bill.paidAt = DateTime.now();

    bill.isPaid = true;

    bill.customerPhone = phone;

    await _billingService.shareBillViaWhatsApp(
      bill: bill,

      businessName: bName,

      recipientPhone: bill.customerPhone,
    );

    if (mounted) _showSettleDialog(bill);
  }

  String _generateDynamicUpiUri(TableBill bill) {
    final biz = context.read<BusinessProvider>().business;
    final upiId = (biz?.upiId?.isNotEmpty == true) ? biz!.upiId! : 'restaurant@upi';
    final bName = biz?.businessName ?? 'Restaurant';
    final amount = bill.grandTotal.toStringAsFixed(2);
    final note = 'Table_${bill.tableNumber}_Bill_${bill.id}';
    return 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(bName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}';
  }

  void _showDynamicUpiQrDialog(TableBill bill) {
    if (bill.grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Table total is ₹0. Please add items to the table before generating a payment QR.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    try {
      final upiUri = _generateDynamicUpiUri(bill);
      final biz = context.read<BusinessProvider>().business;
      final hasRealUpi = biz?.upiId?.trim().isNotEmpty == true;
      final upiId = hasRealUpi ? biz!.upiId!.trim() : 'restaurant@upi';
      final isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? const Color(0xFF1E202A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: Color(0xFF60A5FA), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_canonicalTableName(bill.tableNumber)} • Dynamic UPI QR',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Bill #${bill.id}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amount Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pre-filled Amount:',
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${bill.grandTotal}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Crisp White QR Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: QrImageView(
                        data: upiUri,
                        version: QrVersions.auto,
                        size: 190,
                        backgroundColor: Colors.white,
                        errorStateBuilder: (cxt, err) => const Center(
                          child: Text(
                            'QR Error',
                            style: TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // UPI ID & Copy action
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'UPI: $upiId',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: upiUri));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📋 UPI payment link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy, size: 14, color: Color(0xFF60A5FA)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!hasRealUpi) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tip: Set your official UPI ID in Account to receive direct bank transfers.',
                              style: TextStyle(color: Colors.amber, fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Text(
                    'Diners scan with GPay, PhonePe, or Paytm with pre-filled amount.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),

                  const SizedBox(height: 18),

                  // Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: upiUri));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📋 UPI payment link copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF60A5FA),
                            side: const BorderSide(color: Color(0xFF60A5FA)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Settle as Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            bill.paymentMode = 'UPI';
                            Navigator.pop(ctx);
                            _archiveBill(bill);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Error showing UPI QR dialog: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open UPI QR: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSettleDialog(TableBill bill) {
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      String currentMode = bill.paymentMode.isNotEmpty ? bill.paymentMode : 'Cash';
      if (currentMode.toUpperCase().contains('UPI') ||
          currentMode.toUpperCase().contains('GPAY') ||
          currentMode.toUpperCase().contains('PHONEPE')) {
        currentMode = 'UPI';
      } else if (currentMode.toUpperCase().contains('CASH')) {
        currentMode = 'Cash';
      } else if (currentMode.toUpperCase().contains('CARD')) {
        currentMode = 'Card';
      } else {
        currentMode = 'Other';
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          String selectedMode = currentMode;
          return StatefulBuilder(
            builder: (dialogCtx, setDialogState) => Dialog(
              backgroundColor: isDark ? const Color(0xFF1E202A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settle ${_canonicalTableName(bill.tableNumber)}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total Payable: ₹${bill.grandTotal}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.grey,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Select Payment Method:',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _dialogPaymentOption(
                            label: '💵 Cash',
                            isSelected: selectedMode == 'Cash',
                            onTap: () {
                              setDialogState(() => selectedMode = 'Cash');
                              bill.paymentMode = 'Cash';
                              setState(() {});
                              _save();
                            },
                          ),
                          _dialogPaymentOption(
                            label: '📱 UPI / QR',
                            isSelected: selectedMode == 'UPI',
                            onTap: () {
                              setDialogState(() => selectedMode = 'UPI');
                              bill.paymentMode = 'UPI';
                              setState(() {});
                              _save();
                            },
                          ),
                          _dialogPaymentOption(
                            label: '💳 Card',
                            isSelected: selectedMode == 'Card',
                            onTap: () {
                              setDialogState(() => selectedMode = 'Card');
                              bill.paymentMode = 'Card';
                              setState(() {});
                              _save();
                            },
                          ),
                          _dialogPaymentOption(
                            label: '🔄 Other',
                            isSelected: selectedMode == 'Other',
                            onTap: () {
                              setDialogState(() => selectedMode = 'Other');
                              bill.paymentMode = 'Other';
                              setState(() {});
                              _save();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Payment will be recorded as: $selectedMode',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Closing the table will mark order as PAID and free this table for new guests.',
                              style: TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      if (selectedMode == 'UPI' && bill.grandTotal > 0) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6),
                              ],
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: QrImageView(
                                    data: _generateDynamicUpiUri(bill),
                                    version: QrVersions.auto,
                                    size: 140,
                                    backgroundColor: Colors.white,
                                    errorStateBuilder: (cxt, err) => const Center(
                                      child: Text(
                                        'QR Error',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Scan to Pay ₹${bill.grandTotal}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.print, size: 14),
                              label: const Text('Receipt', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                bill.paymentMode = selectedMode;
                                _printBill(bill);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: Text(
                                'Settle ($selectedMode)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                bill.paymentMode = selectedMode;
                                Navigator.pop(ctx);
                                _archiveBill(bill);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('Error showing settle dialog: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Settle dialog: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _dialogPaymentOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : const Color(0xFF2A2D3A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF10B981) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }


  Future<void> _printBill(TableBill bill) async {
    if (bill.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot print an empty bill.')),
      );

      return;
    }

    final biz = context.read<BusinessProvider>().business;

    final bName = biz?.businessName ?? 'Our Restaurant';

    try {
      await BillReceiptPdfService.instance.printBill(
        bill: bill,

        businessName: bName,

        address: biz?.fullAddress.isNotEmpty == true
            ? biz!.fullAddress
            : biz?.city,

        gstNumber: biz?.gstNumber,

        fssaiNumber: biz?.fssaiNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    }
  }

  Future<void> _printKot(PendingTableOrder order) async {
    if (order.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot print an empty order ticket.')),
        );
      }
      return;
    }

    final biz = context.read<BusinessProvider>().business;
    final bName = biz?.businessName ?? 'Our Restaurant';

    try {
      await BillReceiptPdfService.instance.printKot(
        order: order,
        businessName: bName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('KOT Print error: $e')));
      }
    }
  }

  Future<void> _downloadBill(TableBill bill) async {
    if (bill.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot download an empty bill.')),
      );

      return;
    }

    final biz = context.read<BusinessProvider>().business;

    final bName = biz?.businessName ?? 'Our Restaurant';

    try {
      await BillReceiptPdfService.instance.downloadBillPdf(
        bill: bill,

        businessName: bName,

        address: biz?.fullAddress.isNotEmpty == true
            ? biz!.fullAddress
            : biz?.city,

        gstNumber: biz?.gstNumber,

        fssaiNumber: biz?.fssaiNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt PDF for ${_canonicalTableName(bill.tableNumber)} downloaded!',
            ),

            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download error: $e')));
      }
    }
  }

  void _showReceiptPreviewDialog(TableBill bill) {
    final biz = context.read<BusinessProvider>().business;

    final bName = biz?.businessName ?? 'Our Restaurant';

    final address = biz?.fullAddress.isNotEmpty == true
        ? biz!.fullAddress
        : (biz?.city ?? '');

    final gst = biz?.gstNumber ?? '';

    final fssai = biz?.fssaiNumber ?? '';

    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    showDialog(
      context: context,

      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,

        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(16),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),

                blurRadius: 20,

                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // Top preview bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,

                  vertical: 12,
                ),

                decoration: const BoxDecoration(
                  color: Color(0xFF1E202A),

                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.receipt_long,

                          color: AppColors.primaryOrange,

                          size: 18,
                        ),

                        SizedBox(width: 8),

                        Text(
                          'Receipt Preview',

                          style: TextStyle(
                            color: Colors.white,

                            fontWeight: FontWeight.bold,

                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.close,

                        color: Colors.grey,

                        size: 20,
                      ),

                      padding: EdgeInsets.zero,

                      constraints: const BoxConstraints(),

                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Scrollable Thermal Receipt Card
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),

                  child: Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: Colors.grey.shade300),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,

                      children: [
                        Text(
                          bName.toUpperCase(),

                          style: const TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: 16,

                            letterSpacing: 0.5,

                            color: Colors.black87,
                          ),

                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 2),

                        const Text(
                          'DINE-IN TAX INVOICE',

                          style: TextStyle(
                            fontSize: 10,

                            color: Colors.grey,

                            letterSpacing: 1,
                          ),
                        ),

                        if (address.isNotEmpty)
                          Text(
                            address,

                            style: const TextStyle(
                              fontSize: 9,

                              color: Colors.grey,
                            ),

                            textAlign: TextAlign.center,
                          ),

                        if (gst.isNotEmpty)
                          Text(
                            'GSTIN: $gst',

                            style: const TextStyle(
                              fontSize: 9,

                              color: Colors.grey,
                            ),
                          ),

                        if (fssai.isNotEmpty)
                          Text(
                            'FSSAI: $fssai',

                            style: const TextStyle(
                              fontSize: 9,

                              color: Colors.grey,
                            ),
                          ),

                        const SizedBox(height: 8),

                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - -',

                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),

                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            Text(
                              'Bill #: ${bill.id}',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 11,

                                color: Colors.black87,
                              ),
                            ),

                            Text(
                              _canonicalTableName(bill.tableNumber),

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 11,

                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            Text(
                              fmt.format(bill.paidAt ?? bill.createdAt),

                              style: const TextStyle(
                                fontSize: 10,

                                color: Colors.grey,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,

                                vertical: 1,
                              ),

                              decoration: BoxDecoration(
                                color: bill.isPaid
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),

                                borderRadius: BorderRadius.circular(4),
                              ),

                              child: Text(
                                bill.isPaid ? 'PAID' : 'OPEN',

                                style: TextStyle(
                                  color: bill.isPaid
                                      ? const Color(0xFF10B981)
                                      : Colors.orange,

                                  fontSize: 10,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (bill.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),

                          Align(
                            alignment: Alignment.centerLeft,

                            child: Text(
                              'Customer: ${bill.customerPhone}',

                              style: const TextStyle(
                                fontSize: 10,

                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 6),

                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - -',

                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),

                        const SizedBox(height: 6),

                        // Item headers
                        const Row(
                          children: [
                            Expanded(
                              flex: 5,

                              child: Text(
                                'ITEM',

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 10,

                                  color: Colors.black87,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 2,

                              child: Text(
                                'QTY',

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 10,

                                  color: Colors.black87,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 2,

                              child: Text(
                                'RATE',

                                textAlign: TextAlign.right,

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 10,

                                  color: Colors.black87,
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,

                              child: Text(
                                'AMT',

                                textAlign: TextAlign.right,

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 10,

                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(
                          height: 10,

                          thickness: 0.5,

                          color: Colors.black26,
                        ),

                        ...bill.items.map(
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),

                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,

                                  child: Text(
                                    i.name,

                                    style: const TextStyle(
                                      fontSize: 11,

                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 2,

                                  child: Text(
                                    '${i.quantity}',

                                    textAlign: TextAlign.center,

                                    style: const TextStyle(
                                      fontSize: 11,

                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 2,

                                  child: Text(
                                    '₹${i.unitPrice}',

                                    textAlign: TextAlign.right,

                                    style: const TextStyle(
                                      fontSize: 11,

                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                Expanded(
                                  flex: 3,

                                  child: Text(
                                    '₹${i.total}',

                                    textAlign: TextAlign.right,

                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,

                                      fontSize: 11,

                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - -',

                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),

                        const SizedBox(height: 4),

                        // Calculations
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            const Text(
                              'Subtotal',

                              style: TextStyle(
                                fontSize: 11,

                                color: Colors.grey,
                              ),
                            ),

                            Text(
                              '₹${bill.subtotal}',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 11,

                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        if (bill.discountAmount > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                'Discount',

                                style: TextStyle(
                                  fontSize: 11,

                                  color: Colors.grey,
                                ),
                              ),

                              Text(
                                '-₹${bill.discountAmount}',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 11,

                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                        if (bill.gstRate > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Text(
                                'GST (${bill.gstRate.toStringAsFixed(0)}%)',

                                style: const TextStyle(
                                  fontSize: 11,

                                  color: Colors.grey,
                                ),
                              ),

                              Text(
                                '₹${bill.gstAmount}',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 11,

                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                        const Divider(
                          height: 10,

                          thickness: 1,

                          color: Colors.black38,
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            const Text(
                              'TOTAL PAYABLE',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 12,

                                color: Colors.black87,
                              ),
                            ),

                            Text(
                              '₹${bill.grandTotal}',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 15,

                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - -',

                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),

                        const SizedBox(height: 4),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [
                            const Text(
                              'Payment Mode:',

                              style: TextStyle(
                                fontSize: 10,

                                color: Colors.grey,
                              ),
                            ),

                            Text(
                              bill.paymentMode,

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,

                                fontSize: 10,

                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Thank you for dining with us!',

                          style: TextStyle(
                            fontSize: 10,

                            fontStyle: FontStyle.italic,

                            color: Colors.grey,
                          ),
                        ),

                        const Text(
                          '*** Please Visit Again ***',

                          style: TextStyle(
                            fontSize: 10,

                            fontWeight: FontWeight.bold,

                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Powered by AR Smart Menu',

                          style: TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: Colors.grey.shade100,

                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),

                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),

                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E202A),
                        ),

                        icon: const Icon(Icons.print_rounded, size: 16),

                        label: const Text('Print Bill'),

                        onPressed: () {
                          Navigator.pop(ctx);

                          _printBill(bill);
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),

                        label: const Text('Download PDF'),

                        onPressed: () {
                          Navigator.pop(ctx);

                          _downloadBill(bill);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveBill(TableBill bill) async {
    try {
      // Only accepted orders with items should be archived to history!
      if (bill.items.isEmpty || bill.grandTotal <= 0) {
        // Discard empty/unplaced session without polluting history
        _deleteActiveTable(bill);
        return;
      }

      final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';

      bill.paidAt ??= DateTime.now();
      bill.isPaid = true;

      await _billingService.archiveBill(bill, bId);

      if (bId.isNotEmpty) {
        try {
          await _billingService.closeTableSession(bId, bill.tableNumber);
          final rawDigits = bill.tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
          if (rawDigits.isNotEmpty && rawDigits != bill.tableNumber) {
            await _billingService.closeTableSession(bId, rawDigits);
          }
        } catch (sessionErr) {
          debugPrint('Notice: Error closing remote table session: $sessionErr');
        }
      }

      if (mounted) {
        setState(() {
          _activeBills.removeWhere(
            (b) => b.id == bill.id || _isSameTable(b.tableNumber, bill.tableNumber),
          );

          _historyBills.removeWhere((b) => b.id == bill.id);

          _historyBills.insert(0, bill);

          if (_selectedTableIndex >= _activeBills.length) {
            _selectedTableIndex = _activeBills.isNotEmpty
                ? _activeBills.length - 1
                : 0;
          }

          _billRequests.removeWhere(
            (o) => _isSameTable(o.tableNumber, bill.tableNumber),
          );

          _kitchenOrders.removeWhere(
            (o) => _isSameTable(o.tableNumber, bill.tableNumber),
          );

          _pendingOrders.removeWhere(
            (o) => _isSameTable(o.tableNumber, bill.tableNumber),
          );

          _syncPhone();
        });
      }

      await _save();

      await _loadPendingOrders();
      await _loadBills();

      if (mounted) {
        KitchenSoundAlert.playBillSettledTone();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_canonicalTableName(bill.tableNumber)} completed! Saved to paid history.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error archiving bill: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete settlement: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteActiveTable(TableBill bill) async {
    final confirmed = bill.items.isEmpty
        ? true
        : await showDialog<bool>(
            context: context,

            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E202A),

              title: const Text(
                'Discard / Delete Table?',

                style: TextStyle(color: Colors.white, fontSize: 16),
              ),

              content: Text(
                'Discard ${_canonicalTableName(bill.tableNumber)}?\n\nThis table order will be discarded and will NOT appear in history or revenue.',

                style: const TextStyle(
                  color: Colors.grey,

                  fontSize: 13,

                  height: 1.4,
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),

                  child: const Text(
                    'Keep',

                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),

                  onPressed: () => Navigator.pop(ctx, true),

                  child: const Text('Discard'),
                ),
              ],
            ),
          );

    if (confirmed != true) return;

    if (!mounted) return;

    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';

    if (bId.isNotEmpty) {
      await _billingService.closeTableSession(bId, bill.tableNumber);
      final rawDigits = bill.tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (rawDigits.isNotEmpty && rawDigits != bill.tableNumber) {
        await _billingService.closeTableSession(bId, rawDigits);
      }
    }

    setState(() {
      _activeBills.removeWhere(
        (b) => b.id == bill.id || _isSameTable(b.tableNumber, bill.tableNumber),
      );

      if (_selectedTableIndex >= _activeBills.length) {
        _selectedTableIndex = _activeBills.isNotEmpty
            ? _activeBills.length - 1
            : 0;
      }

      _billRequests.removeWhere(
        (o) => _isSameTable(o.tableNumber, bill.tableNumber),
      );

      _kitchenOrders.removeWhere(
        (o) => _isSameTable(o.tableNumber, bill.tableNumber),
      );

      _pendingOrders.removeWhere(
        (o) => _isSameTable(o.tableNumber, bill.tableNumber),
      );

      _syncPhone();
    });

    await _save();

    await _loadPendingOrders();
    await _loadBills();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_canonicalTableName(bill.tableNumber)} discarded without saving to history.',
          ),
        ),
      );
    }
  }

  Future<void> _removeHistoryBill(TableBill bill) async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),

        title: const Text(
          'Remove from History?',

          style: TextStyle(color: Colors.white, fontSize: 16),
        ),

        content: Text(
          'Remove bill #${bill.id} (${_canonicalTableName(bill.tableNumber)}) from history?',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),

            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),

          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _historyBills.removeWhere((b) => b.id == bill.id));

      await _billingService.saveHistoryBills(_historyBills, bId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill removed from history.')),
        );
      }
    }
  }

  Widget _box({
    required Widget child,

    bool isDark = true,

    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A22) : Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),

      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final bName =
        context.watch<BusinessProvider>().business?.businessName ??
        'Minalo cafe';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Table Billing & Receipts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bName,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Auto-sync',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _isManualRefreshing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: _lastRefreshedAt != null
                      ? 'Refresh (Last: ${_lastRefreshedAt!.hour.toString().padLeft(2, '0')}:${_lastRefreshedAt!.minute.toString().padLeft(2, '0')}:${_lastRefreshedAt!.second.toString().padLeft(2, '0')})'
                      : 'Refresh Billing & Orders',
                  onPressed: _manualRefresh,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,

          isScrollable: true,

          tabAlignment: TabAlignment.start,

          indicatorColor: AppColors.primaryOrange,

          labelColor: AppColors.primaryOrange,

          unselectedLabelColor: Colors.grey,

          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.table_bar_outlined, size: 16),

                  const SizedBox(width: 6),

                  const Text('Floor & Traffic'),

                  if (_activeBills.isNotEmpty) ...[
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        '${_activeBills.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: const [
                  Icon(Icons.forum_outlined, size: 16),

                  SizedBox(width: 6),

                  Text('Table Chat & Bill'),
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.soup_kitchen_outlined, size: 16),

                  const SizedBox(width: 6),

                  const Text('Orders & Kitchen'),

                  if (_pendingOrders.isNotEmpty ||
                      _kitchenOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: _pendingOrders.isNotEmpty
                            ? Colors.orange
                            : Colors.blue,

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        '${_pendingOrders.length + _kitchenOrders.length}',

                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.receipt_long_outlined, size: 16),

                  const SizedBox(width: 6),

                  const Text('Bill Requests'),

                  if (_billRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        '${_billRequests.length}',

                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.history, size: 16),

                  const SizedBox(width: 6),

                  Text(
                    'Today\'s History (${_historyBills.where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0 && _isToday(b.paidAt ?? b.createdAt)).length})',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          : TabBarView(
              controller: _tabController,

              children: [
                _buildFloorTab(isDark),

                _buildTableChatTab(isDark, bName),

                _buildKitchenTab(isDark),

                _buildBillRequestsTab(isDark),

                _buildHistoryTab(isDark, bName),
              ],
            ),
    );
  }

  // ==========================================

  // TAB 1: FLOOR & TRAFFIC VIEW

  // ==========================================

  Widget _buildFloorTab(bool isDark) {
    final allTables = _allFloorTableNames;

    final availableCount = allTables
        .where((t) => _getTableStatus(t) == TableFloorStatus.available)
        .length;

    final occupiedCount = allTables.length - availableCount;

    final billReqCount = _billRequests.length;

    final isDeactivated = context.watch<BusinessProvider>().isDeactivated;

    List<String> filteredTables;

    if (_floorFilter == 'available') {
      filteredTables = allTables
          .where((t) => _getTableStatus(t) == TableFloorStatus.available)
          .toList();
    } else if (_floorFilter == 'occupied') {
      filteredTables = allTables
          .where((t) => _getTableStatus(t) != TableFloorStatus.available)
          .toList();
    } else if (_floorFilter == 'bill_requested') {
      filteredTables = allTables
          .where((t) => _getTableStatus(t) == TableFloorStatus.billRequested)
          .toList();
    } else {
      filteredTables = allTables;
    }

    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _manualRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
        if (isDeactivated) ...[
          Container(
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),

              borderRadius: BorderRadius.circular(10),

              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),

            child: Row(
              children: const [
                Icon(
                  Icons.pause_circle_outline,
                  color: Colors.orange,
                  size: 22,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Restaurant is Deactivated. Diner ordering & active table billing are paused.',

                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],

        // Filter chips + Add Table Action
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,

          child: Row(
            children: [
              _buildFloorFilterChip('all', 'All (${allTables.length})', isDark),

              const SizedBox(width: 6),

              _buildFloorFilterChip(
                'available',
                '🟢 Available ($availableCount)',
                isDark,
              ),

              const SizedBox(width: 6),

              _buildFloorFilterChip(
                'occupied',
                '🔴 Occupied ($occupiedCount)',
                isDark,
              ),

              const SizedBox(width: 6),

              _buildFloorFilterChip(
                'bill_requested',
                '🔔 Bill Req ($billReqCount)',
                isDark,
              ),

              const SizedBox(width: 10),

              ActionChip(
                avatar: const Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.primaryOrange,
                ),

                label: const Text(
                  'Add Table',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                backgroundColor: isDark
                    ? const Color(0xFF1E202A)
                    : Colors.grey.shade200,

                onPressed: _showAddTableDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Table Cards Grid
        if (allTables.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Floor Tables Configured',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Generate Table QR codes from QR Manager or tap "+ Add Table" to start tracking tables.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (filteredTables.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),

              child: Text(
                'No tables match this filter.',

                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,

            physics: const NeverScrollableScrollPhysics(),

            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 650 ? 3 : 2,

              crossAxisSpacing: 10,

              mainAxisSpacing: 10,

              childAspectRatio: 1.15,
            ),

            itemCount: filteredTables.length,

            itemBuilder: (ctx, i) {
              final tName = filteredTables[i];

              final status = _getTableStatus(tName);

              final bill = _findActiveBill(tName);

              return _buildFloorTableCard(tName, status, bill, isDark);
            },
          ),
      ],
    ),
  );
  }

  Widget _buildFloorFilterChip(String key, String label, bool isDark) {
    final sel = _floorFilter == key;

    return ChoiceChip(
      selected: sel,

      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: sel
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),

      selectedColor: AppColors.primaryOrange,

      backgroundColor: isDark ? const Color(0xFF1E202A) : Colors.grey.shade200,

      side: BorderSide.none,

      onSelected: (_) => setState(() => _floorFilter = key),
    );
  }

  Widget _buildFloorTableCard(
    String tableName,
    TableFloorStatus status,
    TableBill? bill,
    bool isDark,
  ) {
    Color statusColor;

    String statusLabel;

    IconData statusIcon;

    switch (status) {
      case TableFloorStatus.billRequested:
        statusColor = Colors.redAccent;

        statusLabel = 'Bill Req 🔔';

        statusIcon = Icons.receipt_long;

        break;

      case TableFloorStatus.orderPending:
        statusColor = Colors.amber;

        statusLabel = 'Ticket In';

        statusIcon = Icons.pending_actions;

        break;

      case TableFloorStatus.cooking:
        statusColor = Colors.orangeAccent;

        statusLabel = 'Cooking';

        statusIcon = Icons.soup_kitchen;

        break;

      case TableFloorStatus.dining:
        statusColor = const Color(0xFF10B981);

        statusLabel = 'Dining';

        statusIcon = Icons.restaurant;

        break;

      case TableFloorStatus.available:
        statusColor = Colors.green;

        statusLabel = 'Available';

        statusIcon = Icons.check_circle_outline;

        break;
    }

    final isOccupied = status != TableFloorStatus.available;

    final kitchenOrdersForTable = _kitchenOrders.where((o) => _isSameTable(o.tableNumber, tableName)).toList();
    final pendingOrdersForTable = _pendingOrders.where((o) => _isSameTable(o.tableNumber, tableName)).toList();
    final kitchenTotal = kitchenOrdersForTable.fold<double>(0.0, (sum, o) => sum + o.totalAmount);
    final pendingTotal = pendingOrdersForTable.fold<double>(0.0, (sum, o) => sum + o.totalAmount);
    final displayTotal = (bill != null && bill.grandTotal > 0)
        ? bill.grandTotal
        : (kitchenTotal + pendingTotal);
    final itemCount = (bill != null && bill.items.isNotEmpty)
        ? bill.items.length
        : (kitchenOrdersForTable.fold<int>(0, (sum, o) => sum + o.items.length) +
            pendingOrdersForTable.fold<int>(0, (sum, o) => sum + o.items.length));

    final waiterCall = _waiterCalls.cast<WaiterCallItem?>().firstWhere(
      (c) => c != null && _isSameTable(c.tableNumber, tableName),
      orElse: () => null,
    );

    final timeStr = bill != null
        ? DateFormat('hh:mm a').format(bill.createdAt)
        : '';

    return InkWell(
      onTap: () => _openTableFromFloor(tableName),

      borderRadius: BorderRadius.circular(16),

      child: Container(
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181A24) : Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: (waiterCall != null && waiterCall.isNewPartyClaim)
                ? const Color(0xFFA78BFA)
                : (waiterCall != null
                    ? Colors.amberAccent
                    : (status == TableFloorStatus.billRequested
                        ? Colors.redAccent
                        : (isOccupied
                              ? statusColor.withValues(alpha: 0.5)
                              : (isDark ? Colors.white10 : Colors.grey.shade300)))),

            width: (waiterCall != null || status == TableFloorStatus.billRequested) ? 2 : 1.2,
          ),

          boxShadow: [
            if (waiterCall != null && waiterCall.isNewPartyClaim)
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              )
            else if (waiterCall != null)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 1,
              )
            else if (status == TableFloorStatus.billRequested)
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Expanded(
                  child: Text(
                    tableName,

                    style: TextStyle(
                      fontSize: 15,

                      fontWeight: FontWeight.bold,

                      color: isDark ? Colors.white : Colors.black87,
                    ),

                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),

                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),

                      const SizedBox(width: 4),

                      Text(
                        statusLabel,

                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (waiterCall != null) ...[
              if (waiterCall.isNewPartyClaim)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA78BFA), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt, color: Color(0xFFA78BFA), size: 13),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'New Party Waiting',
                          style: TextStyle(
                            color: Color(0xFFDDD6FE),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _verifyNewParty(tableName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            '1-Tap Verify ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.amber.withValues(alpha: 0.2)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.amberAccent : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          waiterCall.note.isNotEmpty ? waiterCall.note : 'Waiter Call',
                          style: TextStyle(
                            color: isDark ? Colors.amberAccent : const Color(0xFF78350F),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _attendWaiterCall(tableName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Attended ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (isOccupied) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    '₹${displayTotal.toStringAsFixed(displayTotal.truncateToDouble() == displayTotal ? 0 : 2)}',

                    style: TextStyle(
                      fontSize: 18,

                      fontWeight: FontWeight.w900,

                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    bill != null && bill.items.isNotEmpty
                        ? '${bill.items.length} items • Seated $timeStr'
                        : (itemCount > 0 ? '$itemCount items • Active session' : 'Active session'),

                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),

                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Empty table\nReady for guests',

                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],

            Container(
              width: double.infinity,

              padding: const EdgeInsets.symmetric(vertical: 6),

              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: isOccupied
                    ? AppColors.primaryOrange.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(8),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(
                    isOccupied
                        ? Icons.forum_outlined
                        : Icons.add_circle_outline,

                    size: 13,

                    color: isOccupied ? AppColors.primaryOrange : Colors.green,
                  ),

                  const SizedBox(width: 5),

                  Text(
                    isOccupied ? 'View Chat & Bill' : 'Open Table',

                    style: TextStyle(
                      fontSize: 11,

                      fontWeight: FontWeight.bold,

                      color: isOccupied
                          ? AppColors.primaryOrange
                          : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================

  // TAB 2: WHATSAPP-STYLE TABLE CHAT & BILL

  // ==========================================

  Widget _buildTableChatTab(bool isDark, String bName) {
    final bill = _currentBill;

    final isDeactivated = context.watch<BusinessProvider>().isDeactivated;

    return Column(
      children: [
        // Horizontal Table Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

          color: isDark ? const Color(0xFF141620) : Colors.grey.shade100,

          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            child: Row(
              children: [
                ..._activeBills.asMap().entries.map((e) {
                  final sel = e.key == _selectedTableIndex;

                  final hasPending = _pendingOrders.any(
                    (p) => _isSameTable(p.tableNumber, e.value.tableNumber),
                  );

                  final hasKitchen = _kitchenOrders.any(
                    (k) => _isSameTable(k.tableNumber, e.value.tableNumber),
                  );

                  final hasBillReq = _billRequests.any(
                    (r) => _isSameTable(r.tableNumber, e.value.tableNumber),
                  );

                  final hasWaiterCall = _waiterCalls.any(
                    (c) => _isSameTable(c.tableNumber, e.value.tableNumber),
                  );

                  final isNewParty = _waiterCalls.any(
                    (c) => _isSameTable(c.tableNumber, e.value.tableNumber) && c.isNewPartyClaim,
                  );

                  final displayTable = _canonicalTableName(e.value.tableNumber);

                  final isHighlighted = hasPending || hasBillReq || hasWaiterCall;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),

                    child: ChoiceChip(
                      selectedColor: isNewParty
                          ? const Color(0xFF8B5CF6)
                          : (isHighlighted
                              ? Colors.amber.shade700
                              : AppColors.primaryOrange),

                      backgroundColor: isNewParty
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                          : (isHighlighted
                              ? Colors.amber.withValues(alpha: 0.25)
                              : (isDark
                                    ? const Color(0xFF1E202A)
                                    : Colors.grey.shade200)),

                      side: isNewParty
                          ? BorderSide(
                              color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                              width: 1.5,
                            )
                          : (isHighlighted
                              ? BorderSide(
                                  color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                                  width: 1.5,
                                )
                              : BorderSide.none),

                      avatar: isNewParty
                          ? Icon(
                              Icons.people_alt,
                              size: 14,
                              color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF5B21B6),
                            )
                          : (hasPending
                              ? const Icon(
                                  Icons.assignment_late,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : (hasWaiterCall
                                  ? Icon(
                                      Icons.notifications_active,
                                      size: 14,
                                      color: isDark ? Colors.amberAccent : const Color(0xFF78350F),
                                    )
                                  : (hasBillReq
                                      ? Icon(
                                          Icons.receipt_long,
                                          size: 14,
                                          color: isDark ? Colors.amberAccent : const Color(0xFF78350F),
                                        )
                                      : (hasKitchen
                                          ? const Icon(
                                              Icons.soup_kitchen,
                                              size: 14,
                                              color: Colors.orange,
                                            )
                                          : null)))),

                      label: Text(
                        isNewParty
                            ? '$displayTable 👥 New Party (₹${e.value.grandTotal})'
                            : (hasPending
                                ? '$displayTable 📥 New (₹${e.value.grandTotal})'
                                : (hasWaiterCall
                                    ? '$displayTable 🔔 (₹${e.value.grandTotal})'
                                    : (hasBillReq
                                        ? '$displayTable 🧾 (₹${e.value.grandTotal})'
                                        : (hasKitchen
                                            ? '$displayTable 🍳 (₹${e.value.grandTotal})'
                                            : '$displayTable (₹${e.value.grandTotal})')))),

                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      selected: sel,

                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _selectedTableIndex = e.key;
                            _syncPhone();
                          });
                        }
                      },
                    ),
                  );
                }),

                ActionChip(
                  avatar: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.primaryOrange,
                  ),

                  label: const Text(
                    'Add Table',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  backgroundColor: isDark
                      ? const Color(0xFF1E202A)
                      : Colors.grey.shade200,

                  onPressed: _showAddTableDialog,
                ),
              ],
            ),
          ),
        ),

        // Body: WhatsApp chat or empty state
        Expanded(
          child: bill == null
              ? _buildNoTableChatState(isDark)
              : _buildWhatsAppChatLayout(bill, isDark, isDeactivated),
        ),
      ],
    );
  }

  Widget _buildNoTableChatState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              width: 64,

              height: 64,

              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.forum_outlined,
                size: 32,
                color: AppColors.primaryOrange,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'No Active Table Selected',

              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Select an active table above or check the Floor & Traffic view to see table activity.',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(0),

                  icon: const Icon(Icons.table_bar_outlined, size: 16),

                  label: const Text('View Floor & Tables'),
                ),

                const SizedBox(width: 10),

                FilledButton.icon(
                  onPressed: _showAddTableDialog,

                  icon: const Icon(Icons.add, size: 16),

                  label: const Text('Add Table'),

                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppChatLayout(
    TableBill bill,
    bool isDark,
    bool isDeactivated,
  ) {
    final timeStr = DateFormat('hh:mm a').format(bill.createdAt);

    final hasBillReq = _billRequests.any(
      (r) => _isSameTable(r.tableNumber, bill.tableNumber),
    );

    final kitchenDishes = _kitchenOrders
        .where((o) => _isSameTable(o.tableNumber, bill.tableNumber))
        .toList();

    final pendingForTable = _pendingOrders
        .where((o) => _isSameTable(o.tableNumber, bill.tableNumber))
        .toList();

    final waiterCall = _waiterCalls.cast<WaiterCallItem?>().firstWhere(
      (c) => c != null && _isSameTable(c.tableNumber, bill.tableNumber),
      orElse: () => null,
    );

    final canonicalTable = _canonicalTableName(bill.tableNumber);

    return Column(
      children: [
        // WhatsApp Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),

            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),

          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,

                    backgroundColor: isDark
                        ? const Color(0xFF2A3942)
                        : const Color(0xFF128C7E),

                    child: Text(
                      canonicalTable
                              .replaceAll(RegExp(r'[^0-9]'), '')
                              .isNotEmpty
                          ? 'T${canonicalTable.replaceAll(RegExp(r'[^0-9]'), '')}'
                          : 'TB',

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,

                    right: 0,

                    child: Container(
                      width: 10,

                      height: 10,

                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),

                        shape: BoxShape.circle,

                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      '$canonicalTable • Bill #${bill.id}',

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),

                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    Text(
                      hasBillReq
                          ? '🔔 Bill Requested • Total: ₹${bill.grandTotal}'
                          : 'Dining Session • Started at $timeStr',

                      style: TextStyle(
                        color: hasBillReq ? Colors.amberAccent : Colors.white70,

                        fontSize: 11,

                        fontWeight: hasBillReq
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Preview Receipt',

                icon: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white,
                  size: 20,
                ),

                onPressed: () => _showReceiptPreviewDialog(bill),
              ),

              IconButton(
                tooltip: 'Print',

                icon: const Icon(
                  Icons.print_outlined,
                  color: Colors.white,
                  size: 20,
                ),

                onPressed: () => _printBill(bill),
              ),

              IconButton(
                tooltip: 'Discard Table',

                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),

                onPressed: () => _deleteActiveTable(bill),
              ),
            ],
          ),
        ),

        if (pendingForTable.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.amber.shade900.withValues(alpha: 0.35)
                  : const Color(0xFFFEF3C7),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.amber.shade800 : const Color(0xFFFCD34D),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_late,
                  color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${pendingForTable.length} New Order Ticket(s) waiting for acceptance! Accept or review below 👇',
                    style: TextStyle(
                      color: isDark ? Colors.amberAccent : const Color(0xFF78350F),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (waiterCall != null)
          if (waiterCall.isNewPartyClaim)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF6D28D9).withValues(alpha: 0.35)
                    : const Color(0xFFEDE9FE),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFFC4B5FD),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt,
                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👥 New Party Seated at Table!',
                          style: TextStyle(
                            color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF4C1D95),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          waiterCall.note.isNotEmpty
                              ? waiterCall.note
                              : 'Customer tapped "We are a New Party". Verify to settle previous orders and start fresh session.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF5B21B6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _verifyNewParty(bill.tableNumber),
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('1-Tap Verify & Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.shade900.withValues(alpha: 0.35)
                    : const Color(0xFFFEF3C7),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.amber.shade800 : const Color(0xFFFCD34D),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔔 Waiter Call / Assistance Requested',
                          style: TextStyle(
                            color: isDark ? Colors.amberAccent : const Color(0xFF78350F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Diner note: "${waiterCall.note}"',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _attendWaiterCall(bill.tableNumber),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Attended ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

        // Chat Message Timeline (WhatsApp Wallpaper Canvas)
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),

            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              children: [
                // Date pill
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),

                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF182229)
                          : const Color(0xFFD1D7DB),

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      'TODAY • ${canonicalTable.toUpperCase()} DINING TIMELINE',

                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),

                // Table opened system pill
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),

                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF182229) : Colors.white,

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),

                    child: Text(
                      '🍽️ Dining table opened at $timeStr',

                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Active orders / Rounds message bubble
                if (bill.items.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,

                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),

                      margin: const EdgeInsets.only(bottom: 12),

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2C34) : Colors.white,

                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),

                          topRight: Radius.circular(16),

                          bottomRight: Radius.circular(16),

                          bottomLeft: Radius.circular(4),
                        ),

                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.restaurant_menu,
                                    size: 14,
                                    color: AppColors.primaryOrange,
                                  ),

                                  SizedBox(width: 5),

                                  Text(
                                    'Ordered Dishes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),

                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),

                                  borderRadius: BorderRadius.circular(6),
                                ),

                                child: Text(
                                  '${bill.items.length} items',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 16, thickness: 0.5),

                          ...bill.items.asMap().entries.map((entry) {
                            final idx = entry.key;

                            final item = entry.value;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),

                              child: Row(
                                children: [
                                  Container(
                                    width: 22,

                                    height: 22,

                                    alignment: Alignment.center,

                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2A3942)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),

                                    child: Text(
                                      '${item.quantity}×',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    '₹${item.total}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        bill.items.removeAt(idx);

                                        _save();
                                      });
                                    },

                                    child: const Padding(
                                      padding: EdgeInsets.all(2),

                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const Divider(height: 16, thickness: 0.5),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                'Items Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),

                              Text(
                                '₹${bill.subtotal}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          Align(
                            alignment: Alignment.bottomRight,

                            child: Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),

                                const SizedBox(width: 4),

                                const Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: Color(0xFF53BDEB),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ==========================================
                // 1. INCOMING ORDER TICKETS (ACCEPT / DISCARD)
                // ==========================================
                ...pendingForTable.map((order) {
                  final orderTime = DateFormat('hh:mm a').format(order.createdAt.toLocal());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E202A) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade600,
                        width: 1.5,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.assignment_late, color: Colors.amber, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Incoming Order • Round ${order.round}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              orderTime,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (order.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📱 Diner: ${order.customerPhone}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                        if (order.instructions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '📝 Note: "${order.instructions}"',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        const Divider(height: 14),
                        ...order.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '• ${it.quantity}x ${it.name}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '₹${it.total}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              if (it.modifiers.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 1),
                                  child: Text(
                                    '↳ ${it.modifiers.join(" • ")}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF60A5FA),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (it.notes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 1),
                                  child: Text(
                                    '↳ 📝 "${it.notes}"',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: isDark ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )),
                        const Divider(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.soup_kitchen, size: 15),
                                label: const Text(
                                  'Accept to Kitchen 🍳',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () => _acceptPendingOrder(order),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              icon: const Icon(Icons.print_rounded, size: 15),
                              label: const Text('KOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _printKot(order),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onPressed: () => _discardPendingOrder(order),
                              child: const Text('Discard', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                // ==========================================
                // 2. COOKING IN KITCHEN (READY TO SERVE STATUS & BUTTON)
                // ==========================================
                ...kitchenDishes.map((order) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF182229) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.soup_kitchen, color: Colors.orange, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Cooking in Kitchen • Round ${order.round}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '🍳 Preparing',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...order.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${it.quantity}x ${it.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        )),
                        const Divider(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text(
                              'Ready to Serve / Mark Served ✅',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _markOrderServed(order),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (kitchenDishes.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark All Rounds as Served ✅'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _markCurrentTableServed,
                    ),
                  ),

                // Bill Requested Alert Bubble
                if (hasBillReq)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2215)
                          : const Color(0xFFFFFBEB),

                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 1.5,
                      ),

                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),

                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: const [
                              Text(
                                '🧾 Customer Requested Bill',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.amber,
                                ),
                              ),

                              SizedBox(height: 2),

                              Text(
                                'The diner requested the final bill via WebAR and is waiting for payment.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // WhatsApp Chat Bottom Action Dock (Billing Toolbar)
        Container(
          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),

            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // Quick unlisted items row
              if (_quickPresets.any((p) => p.name.trim().isNotEmpty && p.defaultPrice > 0)) ...[
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._quickPresets
                          .where((p) => p.name.trim().isNotEmpty && p.defaultPrice > 0)
                          .map(
                        (preset) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            avatar: const Icon(
                              Icons.bolt,
                              size: 13,
                              color: AppColors.primaryOrange,
                            ),
                            label: Text(
                              '+ ${preset.name} (₹${preset.defaultPrice})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            onPressed: () => _addQuickPreset(preset),
                            onDeleted: () => _deleteQuickPreset(preset),
                            deleteIconColor: Colors.redAccent,
                            deleteIcon: const Icon(Icons.close, size: 12),
                          ),
                        ),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        avatar: const Icon(Icons.add, size: 13),
                        label: const Text(
                          'Custom...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _showAddCustomPresetDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Total Payable: ₹${bill.grandTotal}',

                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF10B981),
                        ),
                      ),

                      Text(
                        'Subtotal ₹${bill.subtotal} + Tax ₹${bill.gstAmount}',

                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  OutlinedButton.icon(
                    onPressed: _showMenuPicker,

                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.primaryOrange,
                    ),

                    label: const Text(
                      'Add Dish',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),

                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryOrange),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

                            // Payment Method Selector Row
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162127) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payment, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text(
                      'Payment Method:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPaymentChip(bill, 'Cash', '💵 Cash'),
                            const SizedBox(width: 6),
                            _buildPaymentChip(bill, 'UPI', '📱 UPI'),
                            const SizedBox(width: 6),
                            _buildPaymentChip(bill, 'Card', '💳 Card'),
                            const SizedBox(width: 6),
                            _buildPaymentChip(bill, 'Other', '🔄 Other'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row
              Row(
                children: [
                  if (kitchenDishes.isNotEmpty) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _markCurrentTableServed,

                        icon: const Icon(Icons.check_circle_outline, size: 16),

                        label: const Text(
                          'Mark Served ✅',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                  ],

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showSettleDialog(bill),

                      icon: const Icon(Icons.receipt_long, size: 16),

                      label: Text(
                        'Close & Settle (₹${bill.grandTotal})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  OutlinedButton.icon(
                    onPressed: () => _showDynamicUpiQrDialog(bill),
                    icon: const Icon(Icons.qr_code_scanner, size: 15),
                    label: const Text('UPI QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF60A5FA),
                      side: const BorderSide(color: Color(0xFF60A5FA)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),

                  const SizedBox(width: 6),

                  InkWell(
                    onTap: _shareWhatsApp,

                    borderRadius: BorderRadius.circular(10),

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: const Icon(
                        Icons.send,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================

  // TAB 3: KITCHEN & ORDERS VIEW

  // ==========================================

  Widget _buildKitchenTab(bool isDark) {
    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _manualRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),

                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),

                  child: const Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 10),

                Text(
                  'Incoming Order Tickets (${_pendingOrders.length})',

                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Builder(
              builder: (ctx) {
                final ordersProv = ctx.watch<TableOrdersProvider>();
                final isAuto = ordersProv.autoPrintKot;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ordersProv.setAutoPrintKot(!isAuto),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAuto
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAuto ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: isAuto ? const Color(0xFF10B981) : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAuto ? 'Auto-KOT: ON' : 'Auto-KOT: OFF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAuto ? const Color(0xFF10B981) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_pendingOrders.isEmpty)
          _box(
            isDark: isDark,

            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),

                child: Text(
                  'No pending order tickets. All incoming tickets have been processed.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ..._pendingOrders.map((o) => _buildPendingOrderCard(o)),

        const SizedBox(height: 24),

        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),

              child: const Icon(
                Icons.soup_kitchen,
                color: Colors.blue,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              'Cooking in Kitchen (${_kitchenOrders.length})',

              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_kitchenOrders.isEmpty)
          _box(
            isDark: isDark,

            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),

                child: Text(
                  'Kitchen queue is clear. No active cooking orders.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ..._kitchenOrders.map((o) => _buildKitchenOrderCard(o)),
      ],
    ),
  );
  }

  // ==========================================

  // TAB 4: BILL REQUESTS VIEW

  // ==========================================

  Widget _buildBillRequestsTab(bool isDark) {
    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _manualRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),

              child: const Icon(
                Icons.receipt_long,
                color: Colors.amber,
                size: 20,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              'Final Bill Requests (${_billRequests.length})',

              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_billRequests.isEmpty)
          _box(
            isDark: isDark,

            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green.withValues(alpha: 0.6),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'No Pending Bill Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'When dining guests request their final bill in WebAR, their table will appear here for 1-tap checkout.',

                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._billRequests.map((req) {
            final bill = _findActiveBill(req.tableNumber);

            final timeStr = req.billRequestedAt != null
                ? DateFormat('hh:mm a').format(req.billRequestedAt!)
                : DateFormat('hh:mm a').format(req.createdAt);

            final amount = (bill != null && bill.grandTotal > 0)
                ? bill.grandTotal
                : req.totalAmount;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),

              padding: const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1B15)
                    : const Color(0xFFFFFBEB),

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: Colors.amber.shade600, width: 1.5),

                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),

                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                _canonicalTableName(req.tableNumber),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),

                              Text(
                                'Requested at $timeStr',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Text(
                        '₹$amount',

                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            var targetBill = bill;
                            if (targetBill == null) {
                              await _openTableChatDirect(req.tableNumber);
                              targetBill = _findActiveBill(req.tableNumber);
                            }
                            if (targetBill != null) {
                              _showSettleDialog(targetBill);
                            } else {
                              _closeTableSessionDirect(req.tableNumber);
                            }
                          },

                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),

                          label: Text(
                            'Settle & Close (₹$amount)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),

                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      OutlinedButton.icon(
                        onPressed: () => _openTableChatDirect(req.tableNumber),

                        icon: const Icon(Icons.forum_outlined, size: 16),

                        label: const Text(
                          'View Chat',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
  }

  Future<void> _closeTableSessionDirect(String tableNumber) async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';

    if (bId.isNotEmpty) {
      await _billingService.closeTableSession(bId, tableNumber);
      final canonical = _canonicalTableName(tableNumber);
      if (canonical != tableNumber) {
        await _billingService.closeTableSession(bId, canonical);
      }
      final rawDigits = tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (rawDigits.isNotEmpty &&
          rawDigits != tableNumber &&
          rawDigits != canonical) {
        await _billingService.closeTableSession(bId, rawDigits);
      }
    }

    setState(() {
      _billRequests.removeWhere(
        (o) => _isSameTable(o.tableNumber, tableNumber),
      );

      _kitchenOrders.removeWhere(
        (o) => _isSameTable(o.tableNumber, tableNumber),
      );

      _pendingOrders.removeWhere(
        (o) => _isSameTable(o.tableNumber, tableNumber),
      );

      _activeBills.removeWhere((b) => _isSameTable(b.tableNumber, tableNumber));

      if (_selectedTableIndex >= _activeBills.length) {
        _selectedTableIndex = _activeBills.isNotEmpty
            ? _activeBills.length - 1
            : 0;
      }

      _syncPhone();
    });

    await _loadPendingOrders();

    if (mounted) {
      KitchenSoundAlert.playBillSettledTone();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_canonicalTableName(tableNumber)} closed and settled.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildKitchenOrderCard(PendingTableOrder o) {
    final timeStr = DateFormat('hh:mm a').format(o.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: const Color(0xFF1B2620),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Row(
                children: [
                  Text(
                    _canonicalTableName(o.tableNumber),

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      fontSize: 13,

                      color: Colors.white,
                    ),
                  ),

                  if (o.round > 1) ...[
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,

                        vertical: 1,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),

                        borderRadius: BorderRadius.circular(4),
                      ),

                      child: Text(
                        'Round ${o.round}',

                        style: const TextStyle(
                          fontSize: 9,

                          color: Colors.amber,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,

                      vertical: 2,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),

                      borderRadius: BorderRadius.circular(4),
                    ),

                    child: const Text(
                      '🍳 Preparing',

                      style: TextStyle(
                        fontSize: 9,

                        color: Colors.orange,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              Text(
                timeStr,

                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ...o.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${i.quantity}x ${i.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (i.modifiers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 1),
                      child: Text(
                        '↳ ${i.modifiers.join(" • ")}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (i.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 1),
                      child: Text(
                        '↳ 📝 "${i.notes}"',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.amberAccent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (o.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),

            Text(
              '📝 Note: ${o.instructions}',

              style: const TextStyle(
                fontSize: 11,

                color: Colors.amberAccent,

                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 8),

                    visualDensity: VisualDensity.compact,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  icon: const Icon(Icons.check_circle_rounded, size: 16),

                  label: const Text(
                    'Mark as Served to Table ✅',

                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),

                  onPressed: () => _markOrderServed(o),
                ),
              ),

              const SizedBox(width: 8),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 15),
                label: const Text('KOT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _printKot(o),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrderCard(PendingTableOrder o) {
    final timeStr = DateFormat('hh:mm a').format(o.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: Colors.white12),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Row(
                children: [
                  Text(
                    _canonicalTableName(o.tableNumber),

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,

                      fontSize: 13,

                      color: Colors.white,
                    ),
                  ),

                  if (o.round > 1) ...[
                    const SizedBox(width: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,

                        vertical: 1,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),

                        borderRadius: BorderRadius.circular(4),
                      ),

                      child: Text(
                        'Round ${o.round}',

                        style: const TextStyle(
                          fontSize: 9,

                          color: Colors.amber,

                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              Text(
                timeStr,

                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),

          if (o.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 3),

            Row(
              children: [
                const Icon(Icons.phone, size: 12, color: Color(0xFF25D366)),

                const SizedBox(width: 4),

                Text(
                  'Customer: ${o.customerPhone}',

                  style: const TextStyle(
                    fontSize: 11,

                    color: Color(0xFF25D366),

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 6),

          ...o.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${i.quantity}x ${i.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (i.modifiers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 1),
                      child: Text(
                        '↳ ${i.modifiers.join(" • ")}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (i.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 1),
                      child: Text(
                        '↳ 📝 "${i.notes}"',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.amberAccent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (o.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),

            Text(
              '📝 Note: ${o.instructions}',

              style: const TextStyle(
                fontSize: 11,

                color: Colors.amberAccent,

                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 8),

                    visualDensity: VisualDensity.compact,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),

                  icon: const Icon(Icons.soup_kitchen, size: 15),

                  label: const Text(
                    'Accept to Kitchen 🍳',

                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),

                  onPressed: () => _acceptPendingOrder(o),
                ),
              ),

              const SizedBox(width: 6),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: const Text('KOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _printKot(o),
              ),

              const SizedBox(width: 6),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,

                  side: const BorderSide(color: Colors.redAccent),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,

                    vertical: 8,
                  ),

                  visualDensity: VisualDensity.compact,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                onPressed: () => _discardPendingOrder(o),

                child: const Text('Discard', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsDialog(TableBill bill) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final formattedTime = fmt.format((bill.paidAt ?? bill.createdAt).toLocal());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(0xFF10B981),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_canonicalTableName(bill.tableNumber)} • #${bill.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Mode',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            bill.paymentMode.isNotEmpty ? bill.paymentMode : 'Paid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (bill.customerPhone.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Customer Phone',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              bill.customerPhone,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ORDERED ITEMS (${bill.items.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 8),
                ...bill.items.map((item) {
                  final lineTotal = item.unitPrice * item.quantity;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.quantity}×',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '₹${item.unitPrice} = ₹$lineTotal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '₹${bill.subtotal}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (bill.gstAmount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GST (${bill.gstRate.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '₹${bill.gstAmount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (bill.discountAmount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Discount',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                        Text(
                          '-₹${bill.discountAmount}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Paid',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        '₹${bill.grandTotal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Receipt'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _printBill(bill);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark, String bName) {
    final validBills = _historyBills
        .where((b) =>
            b.isPaid &&
            b.items.isNotEmpty &&
            b.grandTotal > 0 &&
            _isToday(b.paidAt ?? b.createdAt))
        .toList();

    if (validBills.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryOrange,
        onRefresh: _manualRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'No Paid Orders in Today\'s History',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final totalRev = validBills.fold(0, (sum, b) => sum + b.grandTotal);
    final fmt = DateFormat('dd MMM, hh:mm a');

    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _manualRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${validBills.length} Today\'s Settled Orders',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Today\'s Revenue: ₹$totalRev',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...validBills.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _box(
              isDark: isDark,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_canonicalTableName(b.tableNumber)} • #${b.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${fmt.format((b.paidAt ?? b.createdAt).toLocal())} • ${b.items.length} items • ${b.paymentMode}${b.customerPhone.isNotEmpty ? ' • 📱 ${b.customerPhone}' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${b.grandTotal}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      size: 16,
                      color: Color(0xFF25D366),
                    ),
                    tooltip: 'Share on WhatsApp',
                    onPressed: () => _billingService.shareBillViaWhatsApp(
                      bill: b,
                      businessName: bName,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 17,
                      color: AppColors.primaryOrange,
                    ),
                    tooltip: 'View Ordered Items',
                    onPressed: () => _showOrderDetailsDialog(b),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.download_outlined,
                      size: 16,
                      color: Colors.white70,
                    ),
                    tooltip: 'Download PDF',
                    onPressed: () => _downloadBill(b),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    tooltip: 'Remove from History',
                    onPressed: () => _removeHistoryBill(b),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildPaymentChip(TableBill bill, String mode, String label) {
    final current = bill.paymentMode.toUpperCase();
    final isSelected = current == mode.toUpperCase() ||
        (mode == 'UPI' &&
            (current.contains('UPI') ||
                current.contains('GPAY') ||
                current.contains('PHONEPE'))) ||
        (mode == 'Cash' && current.contains('CASH')) ||
        (mode == 'Card' && current.contains('CARD'));

    return InkWell(
      onTap: () {
        setState(() {
          bill.paymentMode = mode;
        });
        _save();
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
