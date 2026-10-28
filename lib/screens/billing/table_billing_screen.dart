import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/billing_service.dart';
import '../../core/services/bill_receipt_pdf_service.dart';
import '../../models/bill_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';

class TableBillingScreen extends StatefulWidget {
  const TableBillingScreen({super.key});

  @override
  State<TableBillingScreen> createState() => _TableBillingScreenState();
}

class _TableBillingScreenState extends State<TableBillingScreen> with SingleTickerProviderStateMixin {
  final _billingService = BillingService();
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _phoneController = TextEditingController();

  List<TableBill> _activeBills = [];
  List<TableBill> _historyBills = [];
  List<PendingTableOrder> _pendingOrders = [];
  List<QuickCustomPreset> _quickPresets = [];
  Timer? _pollingTimer;

  bool _loading = true;
  int _selectedTableIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBills();
    _loadPendingOrders();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadPendingOrders());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() => _loading = true);
    final active = await _billingService.getActiveBills();
    final history = await _billingService.getCompletedHistory();
    final presets = await _billingService.getQuickPresets();

    if (active.isEmpty) {
      final billId = await _billingService.generateNextBillId(_getInitials());
      active.add(TableBill(
        id: billId,
        tableNumber: 'Table 1',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ));
      await _billingService.saveActiveBills(active);
    }

    setState(() {
      _activeBills = active;
      _historyBills = history;
      _quickPresets = presets;
      if (_selectedTableIndex >= _activeBills.length) _selectedTableIndex = 0;
      _syncPhone();
      _loading = false;
    });
  }

  Future<void> _loadPendingOrders() async {
    final bId = context.read<BusinessProvider>().business?.id.toString() ?? '';
    if (bId.isNotEmpty) {
      final pending = await _billingService.getPendingOrders(bId);
      if (mounted) setState(() => _pendingOrders = pending);
    }
  }

  Future<void> _acceptPendingOrder(PendingTableOrder order) async {
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot accept orders while business is deactivated. Please reactivate your business.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    await _billingService.acceptOrder(order.id);

    final cleanOrderTable = order.tableNumber.trim().toLowerCase();
    final existingIdx = _activeBills.indexWhere((b) => b.tableNumber.trim().toLowerCase() == cleanOrderTable);

    TableBill targetBill;
    if (existingIdx >= 0) {
      targetBill = _activeBills[existingIdx];
      _selectedTableIndex = existingIdx;
    } else {
      final billId = await _billingService.generateNextBillId(_getInitials());
      targetBill = TableBill(id: billId, tableNumber: order.tableNumber, createdAt: DateTime.now());
      _activeBills.add(targetBill);
      _selectedTableIndex = _activeBills.length - 1;
    }

    targetBill.addItems(order.items);
    if (order.customerPhone.isNotEmpty) targetBill.customerPhone = order.customerPhone;
    _syncPhone();
    await _save();
    await _loadPendingOrders();
    // Customer tracks order live in WebAR experience; no return WhatsApp message sent upon acceptance.

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order for Table ${order.tableNumber} accepted! Items added to bill.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _discardPendingOrder(PendingTableOrder order) async {
    await _billingService.cancelOrder(order.id);
    await _loadPendingOrders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order for Table ${order.tableNumber} discarded.')),
      );
    }
  }

  void _syncPhone() => _phoneController.text = _currentBill?.customerPhone ?? '';

  String _getInitials() {
    final b = context.read<BusinessProvider>().business?.businessName ?? 'MC';
    final parts = b.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : (b.length >= 2 ? b.substring(0, 2).toUpperCase() : 'BILL');
  }

  TableBill? get _currentBill =>
      _activeBills.isNotEmpty && _selectedTableIndex < _activeBills.length ? _activeBills[_selectedTableIndex] : null;

  Future<void> _save() async {
    await _billingService.saveActiveBills(_activeBills);
    setState(() {});
  }

  void _addQuickPreset(QuickCustomPreset p) {
    final bill = _currentBill;
    if (bill == null) return;
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Business is deactivated. Reactivate to add items to bills.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    bill.addItem(id: 'c-${DateTime.now().millisecondsSinceEpoch}', name: p.name, unitPrice: p.defaultPrice, isCustom: true);
    _save();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "${p.name}" to bill!'), duration: const Duration(seconds: 1)));
  }

  Future<void> _deleteQuickPreset(QuickCustomPreset p) async {
    final updated = await _billingService.deleteQuickPreset(p.name);
    setState(() => _quickPresets = updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed "${p.name}" from Quick Items List.')));
    }
  }

  Future<void> _showAddCustomPresetDialog() async {
    final nameCtl = TextEditingController();
    final priceCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primaryOrange, size: 20),
            SizedBox(width: 8),
            Text('Add to Quick Items List', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save your custom unlisted item in Quick Items list so you can tap and add it to any table bill anytime.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Mineral Water, Masala Papad'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Price (₹)', hintText: 'e.g. 20'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () async {
              final n = nameCtl.text.trim();
              final p = int.tryParse(priceCtl.text.trim()) ?? 0;
              if (n.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item name must be at least 2 characters.')),
                );
                return;
              }
              if (p <= 0 || p > 100000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price between ₹1 and ₹1,00,000.')),
                );
                return;
              }
              final updated = await _billingService.addQuickPreset(QuickCustomPreset(n, p));
              setState(() => _quickPresets = updated);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added "$n (₹$p)" to Quick Items List! Tap the chip anytime to add to any bill.'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save to Quick List'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenuPicker() async {
    final bill = _currentBill;
    if (bill == null) return;
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Business is currently deactivated. Reactivate to add menu items.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final products = context.read<ProductProvider>().products.where((p) => p.isLive).toList();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161821),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  const Text('Select Dish from Menu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No Live Dishes Available',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Only active dishes with "Live" status can be billed to customers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                controller: sc,
                itemCount: products.length,
                separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (_, i) {
                  final p = products[i];
                  final price = p.pricePaise != null ? (p.pricePaise! / 100).round() : 0;
                  return ListTile(
                    title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('₹$price', style: const TextStyle(color: AppColors.primaryOrange)),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        bill.addItem(id: p.id, name: p.name, unitPrice: price);
                        _save();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot open tables while business is deactivated. Please reactivate your business.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final ctl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        title: const Text('Open New Table / Session', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Table Number / Name', hintText: 'e.g. Table 4, Rooftop'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () async {
              final t = ctl.text.trim();
              if (t.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a table number or name.')),
                );
                return;
              }
              if (t.isNotEmpty) {
                final id = await _billingService.generateNextBillId(_getInitials());
                setState(() {
                  _activeBills.add(TableBill(id: id, tableNumber: t, createdAt: DateTime.now()));
                  _selectedTableIndex = _activeBills.length - 1;
                  _syncPhone();
                });
                await _save();
                if (ctx.mounted) Navigator.pop(ctx);
              }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 item to the bill.')));
      return;
    }
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Business is deactivated. Operations are paused until reactivated.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^[6-9]\d{9}$');
      if (!phoneRegex.hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number starting with 6-9.'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }
    final bName = context.read<BusinessProvider>().business?.businessName ?? 'Our Restaurant';
    bill.paidAt = DateTime.now();
    bill.isPaid = true;
    bill.customerPhone = phone;

    await _billingService.shareBillViaWhatsApp(bill: bill, businessName: bName, recipientPhone: bill.customerPhone);
    if (mounted) _showSettleDialog(bill);
  }

  void _showSettleDialog(TableBill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        title: const Text('Payment Recorded & Shared', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Bill #${bill.id} for ${bill.tableNumber} is marked PAID (₹${bill.grandTotal}).\n\nClose this dining session so table is ready for next customer visit?', style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print, size: 14),
            label: const Text('Print Physical Bill'),
            onPressed: () => _printBill(bill),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep Active', style: TextStyle(color: Colors.grey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              Navigator.pop(ctx);
              _archiveBill(bill);
            },
            child: const Text('Close Table (Vacant)'),
          ),
        ],
      ),
    );
  }

  Future<void> _printBill(TableBill bill) async {
    if (bill.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot print an empty bill.')));
      return;
    }
    final biz = context.read<BusinessProvider>().business;
    final bName = biz?.businessName ?? 'Our Restaurant';
    try {
      await BillReceiptPdfService.instance.printBill(
        bill: bill,
        businessName: bName,
        address: biz?.fullAddress.isNotEmpty == true ? biz!.fullAddress : biz?.city,
        gstNumber: biz?.gstNumber,
        fssaiNumber: biz?.fssaiNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print error: $e')));
      }
    }
  }

  Future<void> _downloadBill(TableBill bill) async {
    if (bill.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot download an empty bill.')));
      return;
    }
    final biz = context.read<BusinessProvider>().business;
    final bName = biz?.businessName ?? 'Our Restaurant';
    try {
      await BillReceiptPdfService.instance.downloadBillPdf(
        bill: bill,
        businessName: bName,
        address: biz?.fullAddress.isNotEmpty == true ? biz!.fullAddress : biz?.city,
        gstNumber: biz?.gstNumber,
        fssaiNumber: biz?.fssaiNumber,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt PDF for Table ${bill.tableNumber} downloaded!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download error: $e')));
      }
    }
  }

  void _showReceiptPreviewDialog(TableBill bill) {
    final biz = context.read<BusinessProvider>().business;
    final bName = biz?.businessName ?? 'Our Restaurant';
    final address = biz?.fullAddress.isNotEmpty == true ? biz!.fullAddress : (biz?.city ?? '');
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E202A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppColors.primaryOrange, size: 18),
                        SizedBox(width: 8),
                        Text('Receipt Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
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
                        Text(bName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5, color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        const Text('DINE-IN TAX INVOICE', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
                        if (address.isNotEmpty) Text(address, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
                        if (gst.isNotEmpty) Text('GSTIN: $gst', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        if (fssai.isNotEmpty) Text('FSSAI: $fssai', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bill #: ${bill.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            Text('Table: ${bill.tableNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fmt.format(bill.paidAt ?? bill.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: bill.isPaid ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(bill.isPaid ? 'PAID' : 'OPEN', style: TextStyle(color: bill.isPaid ? const Color(0xFF10B981) : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (bill.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Customer: ${bill.customerPhone}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 6),

                        // Item headers
                        const Row(
                          children: [
                            Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                            Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                            Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                            Expanded(flex: 3, child: Text('AMT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                          ],
                        ),
                        const Divider(height: 10, thickness: 0.5, color: Colors.black26),
                        ...bill.items.map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                children: [
                                  Expanded(flex: 5, child: Text(i.name, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  Expanded(flex: 2, child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  Expanded(flex: 2, child: Text('₹${i.unitPrice}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                  Expanded(flex: 3, child: Text('₹${i.total}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                                ],
                              ),
                            )),
                        const SizedBox(height: 6),
                        const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),

                        // Calculations
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text('₹${bill.subtotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                        ]),
                        if (bill.discountAmount > 0)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Discount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('-₹${bill.discountAmount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                          ]),
                        if (bill.gstRate > 0)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('GST (${bill.gstRate.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${bill.gstAmount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                          ]),
                        const Divider(height: 10, thickness: 1, color: Colors.black38),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('TOTAL PAYABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                          Text('₹${bill.grandTotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                        ]),
                        const SizedBox(height: 6),
                        const Text('- - - - - - - - - - - - - - - - - - - - - - - - - - - -', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Payment Mode:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(bill.paymentMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Thank you for dining with us!', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                        const Text('*** Please Visit Again ***', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        const Text('Powered by AR Smart Menu', style: TextStyle(fontSize: 8, color: Colors.grey)),
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
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E202A)),
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
    // Only accepted orders with items should be archived to history!
    if (bill.items.isEmpty || bill.grandTotal <= 0) {
      // Discard empty/unplaced session without polluting history
      _deleteActiveTable(bill);
      return;
    }

    bill.paidAt ??= DateTime.now();
    bill.isPaid = true;
    await _billingService.archiveBill(bill);
    setState(() {
      _activeBills.removeWhere((b) => b.id == bill.id);
      _historyBills.removeWhere((b) => b.id == bill.id);
      _historyBills.insert(0, bill);
      if (_selectedTableIndex >= _activeBills.length) _selectedTableIndex = _activeBills.isNotEmpty ? _activeBills.length - 1 : 0;
      _syncPhone();
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Table ${bill.tableNumber} completed! Saved to paid history.'), backgroundColor: const Color(0xFF10B981)));
    }
  }

  Future<void> _deleteActiveTable(TableBill bill) async {
    final confirmed = bill.items.isEmpty
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E202A),
              title: const Text('Discard / Delete Table?', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: Text(
                'Discard Table ${bill.tableNumber}?\n\nThis table order will be discarded and will NOT appear in history or revenue.',
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );

    if (confirmed != true) return;

    setState(() {
      _activeBills.removeWhere((b) => b.id == bill.id);
      if (_selectedTableIndex >= _activeBills.length) {
        _selectedTableIndex = _activeBills.isNotEmpty ? _activeBills.length - 1 : 0;
      }
      _syncPhone();
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table ${bill.tableNumber} discarded without saving to history.'),
        ),
      );
    }
  }

  Future<void> _removeHistoryBill(TableBill bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202A),
        title: const Text('Remove from History?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Remove bill #${bill.id} (${bill.tableNumber}) from history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
      await _billingService.saveHistoryBills(_historyBills);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill removed from history.')));
      }
    }
  }

  Widget _box({required Widget child, bool isDark = true, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bName = context.watch<BusinessProvider>().business?.businessName ?? 'Minalo cafe';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Table Billing & Receipts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(bName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryOrange,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Active Tables (${_activeBills.length})'),
            Tab(text: 'Today\'s History (${_historyBills.where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0).length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTab(isDark),
                _buildHistoryTab(isDark, bName),
              ],
            ),
    );
  }

  Widget _buildActiveTab(bool isDark) {
    final bill = _currentBill;
    final timeStr = bill != null ? DateFormat('hh:mm a').format(bill.createdAt) : '';
    final isDeactivated = context.watch<BusinessProvider>().isDeactivated;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (isDeactivated) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Restaurant is Deactivated. Diner ordering & active table billing are paused.',
                    style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // 1. Pending incoming orders alert
        if (_pendingOrders.isNotEmpty) ...[
          _buildPendingOrdersBanner(isDark),
          const SizedBox(height: 14),
        ],

        // 2. Table selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._activeBills.asMap().entries.map((e) {
                final sel = e.key == _selectedTableIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selectedColor: AppColors.primaryOrange,
                    backgroundColor: isDark ? const Color(0xFF1E202A) : Colors.grey.shade200,
                    label: Text('${e.value.tableNumber} (₹${e.value.grandTotal})',
                        style: TextStyle(color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold)),
                    selected: sel,
                    onSelected: (v) {
                      if (v) setState(() { _selectedTableIndex = e.key; _syncPhone(); });
                    },
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16, color: AppColors.primaryOrange),
                label: const Text('Add Table', style: TextStyle(color: AppColors.primaryOrange)),
                backgroundColor: isDark ? const Color(0xFF1E202A) : Colors.grey.shade200,
                onPressed: _showAddTableDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (bill == null) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No active tables. Open a table above.', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ] else ...[
          // Header
          _box(
            isDark: isDark,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.receipt_long, color: AppColors.primaryOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Table ${bill.tableNumber} • Bill #${bill.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          Text('Started at $timeStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          if (bill.customerPhone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 10, color: Color(0xFF25D366)),
                                  const SizedBox(width: 3),
                                  Text(bill.customerPhone, style: const TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.grey, size: 20),
                  tooltip: 'Preview Receipt',
                  onPressed: () => _showReceiptPreviewDialog(bill),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, color: Colors.grey, size: 20),
                  tooltip: 'Print Physical Bill',
                  onPressed: () => _printBill(bill),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.grey, size: 20),
                  tooltip: 'Download PDF',
                  onPressed: () => _downloadBill(bill),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Discard / Delete Table',
                  onPressed: () => _deleteActiveTable(bill),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items list
          _box(
            isDark: isDark,
            padding: EdgeInsets.zero,
            child: bill.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No items in bill yet. Add dishes below.', style: TextStyle(color: Colors.grey, fontSize: 13))),
                  )
                : Column(
                    children: bill.items.asMap().entries.map((e) {
                      final idx = e.key;
                      final it = e.value;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          if (it.isCustom) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                              child: const Text('Unlisted', style: TextStyle(fontSize: 8, color: Colors.purpleAccent)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text('₹${it.unitPrice} each', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (it.quantity > 1) { it.quantity--; } else { bill.items.removeAt(idx); }
                                        _save();
                                      },
                                    ),
                                    Text('${it.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryOrange),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () { it.quantity++; _save(); },
                                    ),
                                  ],
                                ),
                                SizedBox(width: 50, child: Text('₹${it.total}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              ],
                            ),
                          ),
                          if (idx < bill.items.length - 1) Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // Quick add unlisted presets
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.primaryOrange, size: 15),
                  SizedBox(width: 4),
                  Text('Quick Add Unlisted Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPresets
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InputChip(
                              backgroundColor: isDark ? const Color(0xFF222533) : Colors.grey.shade200,
                              label: Text('+ ${p.name} (₹${p.defaultPrice})', style: const TextStyle(fontSize: 11)),
                              onPressed: () => _addQuickPreset(p),
                              onDeleted: () => _deleteQuickPreset(p),
                              deleteIconColor: Colors.grey,
                              deleteIcon: const Icon(Icons.close, size: 13),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Custom Item...'),
                      onPressed: _showAddCustomPresetDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restaurant_menu, size: 16),
                      label: const Text('Add from Menu'),
                      onPressed: _showMenuPicker,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Totals card
          _box(
            isDark: isDark,
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Subtotal', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('₹${bill.subtotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Text('GST Tax: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    DropdownButton<double>(
                      value: bill.gstRate,
                      dropdownColor: isDark ? const Color(0xFF222533) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 0.0, child: Text('0%')),
                        DropdownMenuItem(value: 5.0, child: Text('5%')),
                        DropdownMenuItem(value: 12.0, child: Text('12%')),
                        DropdownMenuItem(value: 18.0, child: Text('18%')),
                      ],
                      onChanged: (v) { if (v != null) { setState(() => bill.gstRate = v); _save(); } },
                    ),
                  ]),
                  Text('₹${bill.gstAmount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                const Divider(height: 14, color: Colors.white12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total Payable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('₹${bill.grandTotal}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payment Mode & WhatsApp action
          _box(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paid Via:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: ['UPI (GPay)', 'UPI (PhonePe)', 'Cash', 'Card'].map((m) {
                    final sel = bill.paymentMode == m;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () { setState(() => bill.paymentMode = m); _save(); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primaryOrange.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                              border: Border.all(color: sel ? AppColors.primaryOrange : Colors.white12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(m.replaceAll('UPI (', '').replaceAll(')', ''),
                                  style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? AppColors.primaryOrange : Colors.grey)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  maxLength: 10,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: bill.customerPhone.isNotEmpty
                        ? 'Customer Mobile (Synced from Order)'
                        : 'Customer Mobile (10 Digits)',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: const Icon(Icons.phone, size: 16),
                    suffixIcon: _phoneController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _phoneController.clear();
                              bill.customerPhone = '';
                              _save();
                            },
                          )
                        : null,
                    helperText: bill.customerPhone.isNotEmpty ? '✓ Synced from order — ready to send directly!' : null,
                    helperStyle: const TextStyle(color: Color(0xFF25D366), fontSize: 11),
                  ),
                  onChanged: (v) {
                    bill.customerPhone = v;
                    _save();
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text('Send Paid Bill on WhatsApp (₹${bill.grandTotal})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _shareWhatsApp,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Physical Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _printBill(bill),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _downloadBill(bill),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.grey),
                      label: const Text('Preview Receipt Layout', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      onPressed: () => _showReceiptPreviewDialog(bill),
                    ),
                    TextButton(
                      onPressed: () => _archiveBill(bill),
                      child: const Text('Mark Paid & Close', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingOrdersBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_pendingOrders.length} New Order${_pendingOrders.length > 1 ? 's' : ''} Received (Pending to Serve)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const Text('Tap accept to add items into table bill & reply on WhatsApp.',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                onPressed: _loadPendingOrders,
                tooltip: 'Refresh orders',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._pendingOrders.map((o) => _buildPendingOrderCard(o)),
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
                  Text('Table ${o.tableNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  if (o.round > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('Round ${o.round}', style: const TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          if (o.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.phone, size: 12, color: Color(0xFF25D366)),
                const SizedBox(width: 4),
                Text('Customer: ${o.customerPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          ...o.items.map((i) => Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text('• ${i.quantity}x ${i.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
              )),
          if (o.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('📝 Note: ${o.instructions}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontStyle: FontStyle.italic)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Accept & Send WhatsApp Reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () => _acceptPendingOrder(o),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildHistoryTab(bool isDark, String bName) {
    final validBills = _historyBills.where((b) => b.isPaid && b.items.isNotEmpty && b.grandTotal > 0).toList();
    if (validBills.isEmpty) {
      return const Center(child: Text('No Paid Orders in History', style: TextStyle(color: Colors.grey)));
    }
    final totalRev = validBills.fold(0, (sum, b) => sum + b.grandTotal);
    final fmt = DateFormat('dd MMM, hh:mm a');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${validBills.length} Settled Orders', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Total Revenue: ₹$totalRev', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...validBills.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _box(
                isDark: isDark,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b.tableNumber} • #${b.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${fmt.format(b.paidAt ?? b.createdAt)} • ${b.items.length} items • ${b.paymentMode}${b.customerPhone.isNotEmpty ? ' • 📱 ${b.customerPhone}' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text('₹${b.grandTotal}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                    IconButton(
                      icon: const Icon(Icons.share, size: 16, color: Color(0xFF25D366)),
                      tooltip: 'Share on WhatsApp',
                      onPressed: () => _billingService.shareBillViaWhatsApp(bill: b, businessName: bName),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white70),
                      tooltip: 'Print Physical Bill',
                      onPressed: () => _printBill(b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, size: 16, color: Colors.white70),
                      tooltip: 'Download PDF',
                      onPressed: () => _downloadBill(b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                      tooltip: 'Remove from History',
                      onPressed: () => _removeHistoryBill(b),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
