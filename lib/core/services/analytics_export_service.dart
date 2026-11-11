import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_model.dart';
import '../../models/bill_model.dart';
import '../../models/business_model.dart';
import 'receipt_stub_helper.dart'
    if (dart.library.js_interop) 'receipt_web_helper.dart' as platform_helper;

/// Generates and downloads audit-ready restaurant financial and sales reports
/// in Excel-compatible spreadsheet (.csv) format with UTF-8 BOM encoding.
class AnalyticsExportService {
  AnalyticsExportService._();
  static final AnalyticsExportService instance = AnalyticsExportService._();

  Future<void> exportFinancialReport({
    required BusinessModel? business,
    required AnalyticsOverviewModel? overview,
    required List<AnalyticsChartPointModel> chartPoints,
    required List<TopProductAnalyticsModel> topProducts,
    required List<TableBill> bills,
    required AnalyticsRange range,
  }) async {
    final bName = business?.businessName ?? 'Restaurant';
    final city = business?.city ?? '';
    final address = business?.fullAddress ?? '';
    final gst = business?.gstNumber ?? 'N/A';
    final fssai = business?.fssaiNumber ?? 'N/A';
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final fileDateStr = DateFormat('yyyyMMdd_HHmm').format(now);

    final sb = StringBuffer();
    // Prepend UTF-8 BOM so Microsoft Excel automatically recognizes Indian Rupee symbols & UTF-8 characters
    sb.write('\uFEFF');

    // ─────────────────────────────────────────────────────────────
    // SECTION 1: RESTAURANT & AUDIT FINANCIAL HEADER
    // ─────────────────────────────────────────────────────────────
    sb.writeln('AR SMART MENU - FINANCIAL AUDIT & REVENUE REPORT');
    sb.writeln('Business Name,"${_escape(bName)}"');
    sb.writeln('Address / Location,"${_escape('$city, $address')}"');
    sb.writeln('GSTIN / Tax ID,"${_escape(gst)}"');
    sb.writeln('FSSAI License,"${_escape(fssai)}"');
    sb.writeln('Report Period,"${_escape(range.label)}"');
    sb.writeln('Generated On,"$dateStr"');
    sb.writeln('Currency,"INR (₹)"');
    sb.writeln();

    // ─────────────────────────────────────────────────────────────
    // SECTION 2: KEY FINANCIAL AUDIT METRICS
    // ─────────────────────────────────────────────────────────────
    final grossRevenue = overview?.totalRevenue ?? 0;
    final totalOrders = overview?.totalOrders ?? 0;
    final aov = overview?.averageOrderValue ?? 0.0;
    final estGst = (grossRevenue * 0.05).round();
    final netSales = grossRevenue - estGst;

    sb.writeln('--- FINANCIAL SUMMARY ---');
    sb.writeln('Metric,Amount (INR),Unit / Details');
    sb.writeln('Total Gross Revenue (Sales),$grossRevenue,INR');
    sb.writeln('Estimated GST / Taxes (5%),$estGst,INR');
    sb.writeln('Net Revenue (Excl. Tax),$netSales,INR');
    sb.writeln('Total Orders Completed,$totalOrders,Orders');
    sb.writeln('Average Order Value (AOV),${aov.toStringAsFixed(2)},INR per order');
    sb.writeln('Total Dine-in QR Scans,${overview?.totalScans ?? 0},Scans');
    sb.writeln('Unique Diners / Visitors,${overview?.uniqueVisitors ?? 0},Guests');
    sb.writeln('AR Menu Conversion Rate,${(overview?.conversionRate ?? 0).toStringAsFixed(2)}%,Scans to Views');
    sb.writeln();

    // ─────────────────────────────────────────────────────────────
    // SECTION 3: PERIODIC BREAKDOWN (SALES LEDGER)
    // ─────────────────────────────────────────────────────────────
    sb.writeln('--- PERIODIC SALES & ORDER BREAKDOWN ---');
    sb.writeln('Date / Period,Orders,QR Scans,3D Dish Views,Gross Revenue (INR),Est. GST 5% (INR),Net Revenue (INR)');
    if (chartPoints.isEmpty) {
      sb.writeln('No transaction records in selected range,,,,,,');
    } else {
      for (final p in chartPoints) {
        final dayGst = (p.revenue * 0.05).round();
        final dayNet = p.revenue - dayGst;
        sb.writeln('${p.date},${p.orders},${p.scans},${p.views},${p.revenue},$dayGst,$dayNet');
      }
    }
    sb.writeln();

    // ─────────────────────────────────────────────────────────────
    // SECTION 4: MENU ITEMS & DISH SALES PERFORMANCE
    // ─────────────────────────────────────────────────────────────
    sb.writeln('--- DISH & MENU SALES BREAKDOWN ---');
    sb.writeln('Dish / Product Name,Quantity Sold,AR Scans,3D Views,Conversion Rate,Total Revenue (INR),% Share of Sales');
    if (topProducts.isEmpty) {
      sb.writeln('No dish sales recorded in selected range,,,,,,');
    } else {
      for (final prod in topProducts) {
        final share = grossRevenue > 0
            ? ((prod.totalRevenue / grossRevenue) * 100).toStringAsFixed(1)
            : '0.0';
        sb.writeln('"${_escape(prod.productName)}",${prod.orderCount},${prod.scans},${prod.views},${prod.conversionRate.toStringAsFixed(1)}%,${prod.totalRevenue},$share%');
      }
    }
    sb.writeln();

    // ─────────────────────────────────────────────────────────────
    // SECTION 5: COMPLETED ORDER-LEVEL AUDIT TRAIL
    // ─────────────────────────────────────────────────────────────
    if (bills.isNotEmpty) {
      sb.writeln('--- COMPLETED BILLS & ORDER AUDIT TRAIL ---');
      sb.writeln('Bill / Order ID,Table Number,Date & Time,Customer Phone,Payment Mode,Items Count,Total Amount (INR)');
      for (final b in bills) {
        final billTime = DateFormat('yyyy-MM-dd HH:mm').format(b.paidAt ?? b.createdAt);
        final phone = b.customerPhone.isNotEmpty ? b.customerPhone : 'Walk-in';
        sb.writeln('"${_escape(b.id)}","${_escape(b.tableNumber)}","$billTime","${_escape(phone)}","${_escape(b.paymentMode)}",${b.items.length},${b.grandTotal}');
      }
      sb.writeln();
    }

    final csvContent = sb.toString();
    final cleanFileName = 'Financial_Audit_Report_${_cleanFilename(bName)}_${range.apiValue}_$fileDateStr.csv';

    if (kIsWeb) {
      platform_helper.downloadTextFile(
        csvContent,
        cleanFileName,
        mimeType: 'text/csv;charset=utf-8;',
      );
    } else {
      // In native mode, downloadTextFile handles platform-specific sharing or fallback
      platform_helper.downloadTextFile(
        csvContent,
        cleanFileName,
        mimeType: 'text/csv;charset=utf-8;',
      );
    }
  }

  static String _escape(String value) {
    return value.replaceAll('"', '""');
  }

  static String _cleanFilename(String raw) {
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}
