import 'package:intl/intl.dart';

class BillItem {
  final String id;
  final String name;
  final int unitPrice; // in Rupees
  int quantity;
  final bool isCustom; // true for unlisted items like water bottle

  BillItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.isCustom = false,
  });

  int get total => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'isCustom': isCustom,
  };

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    id: json['id'] as String,
    name: json['name'] as String,
    unitPrice: json['unitPrice'] as int? ?? 0,
    quantity: json['quantity'] as int? ?? 1,
    isCustom: json['isCustom'] as bool? ?? false,
  );
}

class TableBill {
  final String id;
  final String tableNumber; // e.g. "1st floor", "Table 2"
  final DateTime createdAt;
  DateTime? paidAt;
  bool isPaid;
  String paymentMode; // "UPI (GPay)", "UPI (PhonePe)", "Cash", "Card"
  double gstRate; // e.g. 5.0
  int discountAmount; // in Rupees
  String customerPhone;
  List<BillItem> items;

  TableBill({
    required this.id,
    required this.tableNumber,
    required this.createdAt,
    this.paidAt,
    this.isPaid = false,
    this.paymentMode = 'UPI (GPay)',
    this.gstRate = 5.0,
    this.discountAmount = 0,
    this.customerPhone = '',
    List<BillItem>? items,
  }) : items = items ?? [];

  int get subtotal => items.fold(0, (sum, i) => sum + i.total);
  int get subtotalAfterDiscount => (subtotal - discountAmount).clamp(0, 9999999);
  int get gstAmount => (subtotalAfterDiscount * (gstRate / 100)).round();
  int get grandTotal => subtotalAfterDiscount + gstAmount;

  void addItem({required String id, required String name, required int unitPrice, int quantity = 1, bool isCustom = false}) {
    final idx = items.indexWhere((i) => (id.isNotEmpty && i.id == id) || i.name.toLowerCase() == name.toLowerCase());
    if (idx >= 0) {
      items[idx].quantity += quantity;
    } else {
      items.add(BillItem(id: id, name: name, unitPrice: unitPrice, quantity: quantity, isCustom: isCustom));
    }
  }

  void addItems(List<BillItem> newItems) {
    for (final it in newItems) {
      addItem(id: it.id, name: it.name, unitPrice: it.unitPrice, quantity: it.quantity, isCustom: it.isCustom);
    }
  }

  String toWhatsAppReceipt({required String businessName}) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = dateFormat.format(paidAt ?? DateTime.now());
    final tableLabel = tableNumber.toLowerCase().startsWith('table')
        ? tableNumber
        : 'Table $tableNumber';

    final lines = [
      '🧾 *BILL RECEIPT — $businessName*',
      '📍 *$tableLabel* • Bill #$id',
      '🕒 $timeStr',
      '────────────────────────',
      '*Items:*',
      ...items.map((i) => '▫️ ${i.quantity}x ${i.name}: ₹${i.total}'),
      '────────────────────────',
      'Subtotal: ₹$subtotal',
      if (discountAmount > 0) 'Discount: -₹$discountAmount',
      if (gstRate > 0) 'GST (${gstRate.toStringAsFixed(0)}%): ₹$gstAmount',
      '💰 *TOTAL PAID: ₹$grandTotal*',
      '────────────────────────',
      '✅ *Status:* PAID',
      '💳 *Paid via:* $paymentMode',
      '────────────────────────',
      '✨ *Thank you for dining with $businessName! Visit again!*',
    ];

    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tableNumber': tableNumber,
    'createdAt': createdAt.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'isPaid': isPaid,
    'paymentMode': paymentMode,
    'gstRate': gstRate,
    'discountAmount': discountAmount,
    'customerPhone': customerPhone,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory TableBill.fromJson(Map<String, dynamic> json) => TableBill(
    id: json['id'] as String,
    tableNumber: json['tableNumber'] as String? ?? 'Dine-in',
    createdAt: DateTime.parse(json['createdAt'] as String),
    paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
    isPaid: json['isPaid'] as bool? ?? false,
    paymentMode: json['paymentMode'] as String? ?? 'UPI (GPay)',
    gstRate: (json['gstRate'] as num?)?.toDouble() ?? 5.0,
    discountAmount: json['discountAmount'] as int? ?? 0,
    customerPhone: json['customerPhone'] as String? ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((i) => BillItem.fromJson(i as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class PendingTableOrder {
  final String id;
  final String businessId;
  final String tableNumber;
  final int round;
  final String status;
  final String instructions;
  final String customerPhone;
  final List<BillItem> items;
  final int totalAmount;
  final DateTime createdAt;

  PendingTableOrder({
    required this.id,
    required this.businessId,
    required this.tableNumber,
    required this.round,
    required this.status,
    required this.instructions,
    required this.customerPhone,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
  });

  factory PendingTableOrder.fromJson(Map<String, dynamic> json) => PendingTableOrder(
    id: json['id'] as String,
    businessId: json['businessId'] as String? ?? '',
    tableNumber: json['tableNumber'] as String? ?? 'Dine-in',
    round: json['round'] as int? ?? 1,
    status: json['status'] as String? ?? 'PENDING',
    instructions: json['instructions'] as String? ?? '',
    customerPhone: json['customerPhone'] as String? ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((i) => BillItem(
              id: (i['id'] as String?) ?? '',
              name: (i['name'] as String?) ?? '',
              unitPrice: (i['unitPrice'] as num?)?.toInt() ?? 0,
              quantity: (i['quantity'] as num?)?.toInt() ?? 1,
            ))
        .toList() ?? [],
    totalAmount: json['totalAmount'] as int? ?? 0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}
