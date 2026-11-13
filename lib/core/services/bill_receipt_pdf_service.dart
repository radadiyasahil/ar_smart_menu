import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ar_smart_menu/models/bill_model.dart';

import 'receipt_stub_helper.dart'
    if (dart.library.js_interop) 'receipt_web_helper.dart' as platform_helper;

/// Service responsible for generating and printing/downloading professional restaurant receipts.
class BillReceiptPdfService {
  BillReceiptPdfService._();
  static final BillReceiptPdfService instance = BillReceiptPdfService._();

  /// Generates thermal POS format receipt bytes (80mm width)
  Future<Uint8List> generateReceiptPdf({
    required TableBill bill,
    required String businessName,
    String? address,
    String? gstNumber,
    String? fssaiNumber,
  }) async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = fmt.format(bill.paidAt ?? bill.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Dine-in Tax Invoice',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (address != null && address.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(address, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
              ],
              if (gstNumber != null && gstNumber.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text('GSTIN: $gstNumber', style: const pw.TextStyle(fontSize: 7.5)),
              ],
              if (fssaiNumber != null && fssaiNumber.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text('FSSAI: $fssaiNumber', style: const pw.TextStyle(fontSize: 7.5)),
              ],
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Order details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill #: ${bill.id}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text('Table: ${bill.tableNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: $timeStr', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  pw.Text(
                    bill.isPaid ? 'PAID' : 'OPEN',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: bill.isPaid ? PdfColors.green800 : PdfColors.orange800,
                    ),
                  ),
                ],
              ),
              if (bill.customerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Customer: ${bill.customerPhone}', style: const pw.TextStyle(fontSize: 7.5)),
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 3, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.5),

              // Item rows
              ...bill.items.map((i) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 5, child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 2, child: pw.Text('${i.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 2, child: pw.Text('Rs.${i.unitPrice}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 3, child: pw.Text('Rs.${i.total}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      ],
                    ),
                  )),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Calculation Totals
              _buildSummaryRow('Subtotal', 'Rs.${bill.subtotal}'),
              if (bill.discountAmount > 0)
                _buildSummaryRow('Discount', '- Rs.${bill.discountAmount}'),
              if (bill.gstRate > 0)
                _buildSummaryRow('GST (${bill.gstRate.toStringAsFixed(0)}%)', 'Rs.${bill.gstAmount}'),

              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.8),
              pw.SizedBox(height: 2),

              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PAYABLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Rs.${bill.grandTotal}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Payment Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(bill.paymentMode, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ],
              ),
              if (bill.paidAt != null) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Paid Time:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(fmt.format(bill.paidAt!), style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Text('Thank you for dining with us!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text('*** Please Visit Again ***', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              pw.SizedBox(height: 6),
              pw.Text('Powered by AR Smart Menu', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
    );
  }

  /// Direct print layout dialog (uses browser native print on Web, Printing.layoutPdf on Native)
  Future<void> printBill({
    required TableBill bill,
    required String businessName,
    String? address,
    String? gstNumber,
    String? fssaiNumber,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      bill: bill,
      businessName: businessName,
      address: address,
      gstNumber: gstNumber,
      fssaiNumber: fssaiNumber,
    );

    if (kIsWeb) {
      final html = generateReceiptHtml(
        bill: bill,
        businessName: businessName,
        address: address,
        gstNumber: gstNumber,
        fssaiNumber: fssaiNumber,
      );
      platform_helper.printReceiptDirect(
        pdfBytes: pdfBytes,
        htmlContent: html,
        title: 'Bill_${bill.tableNumber}_${bill.id}',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Bill_${bill.tableNumber}_${bill.id}',
      );
    }
  }

  /// Print Kitchen Order Ticket (KOT) for kitchen staff / cooks
  Future<void> printKot({
    required PendingTableOrder order,
    required String businessName,
  }) async {
    final pdfBytes = await generateKotPdf(
      order: order,
      businessName: businessName,
    );

    final cleanTable = order.tableNumber.replaceAll(RegExp(r'\s+'), '_');
    final title = 'KOT_${cleanTable}_R${order.round}_${order.id.length > 6 ? order.id.substring(0, 6) : order.id}';

    if (kIsWeb) {
      final html = generateKotHtml(
        order: order,
        businessName: businessName,
      );
      platform_helper.printReceiptDirect(
        pdfBytes: pdfBytes,
        htmlContent: html,
        title: title,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: title,
      );
    }
  }

  /// Generates Kitchen Order Ticket (KOT) PDF bytes formatted for 80mm/58mm thermal printers
  Future<Uint8List> generateKotPdf({
    required PendingTableOrder order,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = fmt.format(order.createdAt.toLocal());
    final displayTable = order.tableNumber.toLowerCase().startsWith('table')
        ? order.tableNumber.toUpperCase()
        : 'TABLE ${order.tableNumber.toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const pw.BoxDecoration(color: PdfColors.black),
                child: pw.Text(
                  '*** KITCHEN ORDER TICKET (KOT) ***',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    displayTable,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                  ),
                  if (order.round > 1)
                    pw.Text(
                      'ROUND ${order.round}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time: $timeStr', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Order: #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (order.customerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Customer: ${order.customerPhone}', style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 7, child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.8),
              ...order.items.map((i) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '${i.quantity} x',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        pw.Expanded(
                          flex: 7,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                i.name,
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              ),
                              if (i.modifiers.isNotEmpty)
                                pw.Text(
                                  '+ ${i.modifiers.join(', ')}',
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                                ),
                              if (i.notes.isNotEmpty)
                                pw.Text(
                                  '* Note: ${i.notes}',
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              if (order.instructions.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('KITCHEN NOTES / PREPARATION:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Text(order.instructions, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              ],
              pw.SizedBox(height: 4),
              pw.Text('*** SEND TO KITCHEN CHEF ***', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates clean HTML for 80mm/58mm thermal KOT ticket printing in browser
  String generateKotHtml({
    required PendingTableOrder order,
    required String businessName,
  }) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = fmt.format(order.createdAt.toLocal());
    final displayTable = order.tableNumber.toLowerCase().startsWith('table')
        ? order.tableNumber.toUpperCase()
        : 'TABLE ${order.tableNumber.toUpperCase()}';

    final itemsHtml = order.items.map((i) {
      final modsHtml = i.modifiers.isNotEmpty
          ? '<div style="font-size: 11px; font-weight: 500; color: #333; margin-top: 2px;">↳ ${i.modifiers.join(" • ")}</div>'
          : '';
      final notesHtml = i.notes.isNotEmpty
          ? '<div style="font-size: 11px; font-weight: bold; color: #b45309; margin-top: 1px;">↳ 📝 ${i.notes}</div>'
          : '';
      return '''
      <tr>
        <td style="padding: 6px 0; font-size: 15px; font-weight: bold; width: 45px; vertical-align: top;">${i.quantity}x</td>
        <td style="padding: 6px 0; font-size: 14px; font-weight: bold;">
          ${i.name}
          $modsHtml
          $notesHtml
        </td>
      </tr>
      ''';
    }).join('');

    final notesHtml = order.instructions.isNotEmpty
        ? '''
        <div style="margin: 8px 0; padding: 6px; border: 1.5px dashed #000; font-weight: bold; font-size: 13px;">
          <div>⚠️ KITCHEN NOTE:</div>
          <div style="font-size: 14px; margin-top: 2px;">${order.instructions}</div>
        </div>
        '''
        : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>KOT - $displayTable</title>
  <style>
    @media print {
      @page {
        margin: 0;
        size: 80mm auto;
      }
      body {
        margin: 0;
        padding: 8px 12px;
        width: 76mm;
      }
      .no-print {
        display: none !important;
      }
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Courier New', monospace;
      color: #000;
      background: #fff;
      max-width: 320px;
      margin: 0 auto;
      padding: 16px;
      font-size: 13px;
      line-height: 1.3;
    }
    .text-center { text-align: center; }
    .bold { font-weight: bold; }
    .title { font-size: 18px; font-weight: 900; margin: 0; }
    .badge { display: inline-block; background: #000; color: #fff; padding: 2px 8px; font-size: 12px; font-weight: 900; letter-spacing: 1px; margin: 4px 0; }
    .dashed { border-top: 1.5px dashed #000; margin: 8px 0; }
    .solid { border-top: 2px solid #000; margin: 6px 0; }
    .row { display: flex; justify-content: space-between; align-items: baseline; margin: 2px 0; }
    table { width: 100%; border-collapse: collapse; margin: 6px 0; }
    th { border-bottom: 1.5px solid #000; padding: 4px 0; font-size: 11px; text-transform: uppercase; text-align: left; }
    .table-title { font-size: 22px; font-weight: 900; }
    .round-tag { font-size: 14px; font-weight: 900; background: #eee; padding: 2px 6px; border: 1px solid #000; border-radius: 4px; }
    .btn-bar { margin-bottom: 16px; display: flex; gap: 8px; }
    .btn { flex: 1; padding: 8px; font-weight: bold; border-radius: 6px; cursor: pointer; border: 1px solid #333; }
    .btn-primary { background: #111; color: #fff; }
    .btn-sec { background: #f3f3f3; color: #111; }
  </style>
</head>
<body onload="setTimeout(function(){ window.focus(); window.print(); }, 250);">
  <div class="no-print btn-bar">
    <button class="btn btn-primary" onclick="window.print()">🖨️ Print KOT</button>
    <button class="btn btn-sec" onclick="window.close()">✕ Close</button>
  </div>
  <div class="text-center">
    <div class="title">${businessName.toUpperCase()}</div>
    <div class="badge">*** KITCHEN TICKET (KOT) ***</div>
  </div>
  <div class="solid"></div>
  <div class="row">
    <span class="table-title">$displayTable</span>
    ${order.round > 1 ? '<span class="round-tag">ROUND ${order.round}</span>' : ''}
  </div>
  <div class="row" style="font-size: 11px; color: #333; margin-top: 4px;">
    <span>Time: $timeStr</span>
    <span>#${order.id.length > 8 ? order.id.substring(0, 8) : order.id}</span>
  </div>
  ${order.customerPhone.isNotEmpty ? '<div style="font-size: 11px; margin-top: 2px;">Customer: <b>${order.customerPhone}</b></div>' : ''}
  <div class="dashed"></div>
  <table>
    <thead>
      <tr>
        <th style="width: 45px;">QTY</th>
        <th>ITEM</th>
      </tr>
    </thead>
    <tbody>
      $itemsHtml
    </tbody>
  </table>
  $notesHtml
  <div class="dashed"></div>
  <div class="text-center bold" style="font-size: 10px; margin-top: 6px; letter-spacing: 1px;">
    *** SEND TO KITCHEN CHEF ***
  </div>
</body>
</html>
''';
  }

  /// Generates pure ESC/POS binary command stream for direct thermal POS receipt printers (USB / Serial / Network TCP)
  Uint8List generateKotEscPos({
    required PendingTableOrder order,
    required String businessName,
  }) {
    final buffer = <int>[];

    // Helper closures
    void writeBytes(List<int> bytes) => buffer.addAll(bytes);
    void writeText(String text) => buffer.addAll(utf8.encode(text));
    void lineFeed([int lines = 1]) {
      for (var i = 0; i < lines; i++) {
        buffer.add(0x0A);
      }
    }

    // ESC @: Initialize printer
    writeBytes([0x1B, 0x40]);

    // ESC a 1: Center alignment
    writeBytes([0x1B, 0x61, 0x01]);

    // GS ! 0x11: Double width & height
    writeBytes([0x1D, 0x21, 0x11]);
    writeText(businessName.toUpperCase());
    lineFeed();

    // GS ! 0x00: Normal size
    writeBytes([0x1D, 0x21, 0x00]);
    // ESC E 1: Bold on
    writeBytes([0x1B, 0x45, 0x01]);
    writeText('*** KITCHEN ORDER TICKET (KOT) ***');
    lineFeed();
    writeBytes([0x1B, 0x45, 0x00]); // Bold off

    writeText('--------------------------------');
    lineFeed();

    // ESC a 0: Left alignment
    writeBytes([0x1B, 0x61, 0x00]);

    // Large Table Name
    writeBytes([0x1D, 0x21, 0x11]); // Double size
    final displayTable = order.tableNumber.toLowerCase().startsWith('table')
        ? order.tableNumber.toUpperCase()
        : 'TABLE ${order.tableNumber.toUpperCase()}';
    writeText(displayTable);
    if (order.round > 1) {
      writeText(' (R${order.round})');
    }
    lineFeed();

    // Normal size
    writeBytes([0x1D, 0x21, 0x00]);
    final fmt = DateFormat('dd MMM, hh:mm a');
    writeText('Time: ${fmt.format(order.createdAt.toLocal())}  Order: #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}');
    lineFeed();

    if (order.customerPhone.isNotEmpty) {
      writeText('Customer: ${order.customerPhone}');
      lineFeed();
    }

    writeText('--------------------------------');
    lineFeed();

    // Items table header
    writeBytes([0x1B, 0x45, 0x01]); // Bold
    writeText('QTY   ITEM DESCRIPTION');
    lineFeed();
    writeBytes([0x1B, 0x45, 0x00]); // Bold off
    writeText('--------------------------------');
    lineFeed();

    for (final item in order.items) {
      writeBytes([0x1B, 0x45, 0x01]);
      writeText('${item.quantity.toString().padRight(5)} ');
      writeBytes([0x1B, 0x45, 0x00]);
      writeText(item.name);
      lineFeed();
      if (item.modifiers.isNotEmpty) {
        writeText('      + ${item.modifiers.join(", ")}');
        lineFeed();
      }
      if (item.notes.isNotEmpty) {
        writeText('      * Note: ${item.notes}');
        lineFeed();
      }
    }

    writeText('--------------------------------');
    lineFeed();

    if (order.instructions.isNotEmpty) {
      writeBytes([0x1B, 0x45, 0x01]);
      writeText('NOTE: ${order.instructions}');
      lineFeed();
      writeBytes([0x1B, 0x45, 0x00]);
      writeText('--------------------------------');
      lineFeed();
    }

    // Feed and cut
    lineFeed(3);
    // GS V 66 0: Partial cut
    writeBytes([0x1D, 0x56, 0x42, 0x00]);

    return Uint8List.fromList(buffer);
  }

  /// Download PDF file (uses native Blob download on Web, Printing.sharePdf on Native)
  Future<void> downloadBillPdf({
    required TableBill bill,
    required String businessName,
    String? address,
    String? gstNumber,
    String? fssaiNumber,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      bill: bill,
      businessName: businessName,
      address: address,
      gstNumber: gstNumber,
      fssaiNumber: fssaiNumber,
    );

    final cleanName = 'Bill_${bill.tableNumber.replaceAll(RegExp(r'\s+'), '_')}_${bill.id}.pdf';

    if (kIsWeb) {
      platform_helper.downloadPdfFile(pdfBytes, cleanName);
    } else {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: cleanName,
      );
    }
  }

  /// Generates clean HTML for 80mm thermal receipt printing in browser
  String generateReceiptHtml({
    required TableBill bill,
    required String businessName,
    String? address,
    String? gstNumber,
    String? fssaiNumber,
  }) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final timeStr = fmt.format(bill.paidAt ?? bill.createdAt);

    final itemsHtml = bill.items.map((i) => '''
      <tr>
        <td style="padding: 3px 0;">${i.name}</td>
        <td style="padding: 3px 0; text-align: center;">${i.quantity}</td>
        <td style="padding: 3px 0; text-align: right;">Rs.${i.unitPrice}</td>
        <td style="padding: 3px 0; text-align: right; font-weight: bold;">Rs.${i.total}</td>
      </tr>
    ''').join('');

    final discountRow = bill.discountAmount > 0
        ? '''<div style="display: flex; justify-content: space-between; margin: 2px 0;"><span>Discount:</span><span>- Rs.${bill.discountAmount}</span></div>'''
        : '';

    final gstRow = bill.gstRate > 0
        ? '''<div style="display: flex; justify-content: space-between; margin: 2px 0;"><span>GST (${bill.gstRate.toStringAsFixed(0)}%):</span><span>Rs.${bill.gstAmount}</span></div>'''
        : '';

    final displayTable = bill.tableNumber.toLowerCase().startsWith('table')
        ? bill.tableNumber
        : 'Table ${bill.tableNumber}';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt - $displayTable</title>
  <style>
    @media print {
      @page {
        margin: 0;
        size: 80mm auto;
      }
      body {
        margin: 0;
        padding: 8px 12px;
        width: 76mm;
      }
      .no-print {
        display: none !important;
      }
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Courier New', monospace;
      color: #000;
      background: #fff;
      max-width: 320px;
      margin: 0 auto;
      padding: 16px;
      font-size: 12px;
      line-height: 1.4;
    }
    .text-center { text-align: center; }
    .bold { font-weight: bold; }
    .title { font-size: 18px; font-weight: 800; letter-spacing: 0.5px; margin: 0; }
    .subtitle { font-size: 10px; color: #555; text-transform: uppercase; letter-spacing: 1px; margin: 2px 0; }
    .dashed { border-top: 1px dashed #777; margin: 8px 0; }
    .solid { border-top: 1px solid #333; margin: 6px 0; }
    .row { display: flex; justify-content: space-between; margin: 2px 0; }
    table { width: 100%; border-collapse: collapse; margin: 4px 0; font-size: 11px; }
    th { border-bottom: 1px solid #333; padding: 4px 0; font-size: 10px; text-transform: uppercase; }
    .total-row { font-size: 15px; font-weight: 800; margin: 6px 0; }
    .btn-bar { margin-bottom: 16px; display: flex; gap: 8px; }
    .btn { flex: 1; padding: 8px; font-weight: bold; border-radius: 6px; cursor: pointer; border: 1px solid #333; }
    .btn-primary { background: #111; color: #fff; }
    .btn-sec { background: #f3f3f3; color: #111; }
  </style>
</head>
<body onload="setTimeout(function(){ window.focus(); window.print(); }, 300);">
  <div class="no-print btn-bar">
    <button class="btn btn-primary" onclick="window.print()">🖨️ Print Receipt</button>
    <button class="btn btn-sec" onclick="window.close()">✕ Close</button>
  </div>
  <div class="text-center">
    <div class="title">${businessName.toUpperCase()}</div>
    <div class="subtitle">Dine-in Tax Invoice</div>
    ${address != null && address.isNotEmpty ? '<div style="font-size: 10px; color: #666;">$address</div>' : ''}
    ${gstNumber != null && gstNumber.isNotEmpty ? '<div style="font-size: 10px;">GSTIN: $gstNumber</div>' : ''}
    ${fssaiNumber != null && fssaiNumber.isNotEmpty ? '<div style="font-size: 10px;">FSSAI: $fssaiNumber</div>' : ''}
  </div>
  <div class="dashed"></div>
  <div class="row">
    <span class="bold">Bill #: ${bill.id}</span>
    <span class="bold">Table: ${bill.tableNumber}</span>
  </div>
  <div class="row">
    <span style="color: #666; font-size: 10px;">Date: $timeStr</span>
    <span class="bold" style="color: ${bill.isPaid ? '#047857' : '#c2410c'}; font-size: 10px;">${bill.isPaid ? 'PAID' : 'OPEN'}</span>
  </div>
  ${bill.customerPhone.isNotEmpty ? '<div class="row" style="font-size: 10px;"><span>Customer:</span><span class="bold">${bill.customerPhone}</span></div>' : ''}
  <div class="dashed"></div>
  <table>
    <thead>
      <tr>
        <th style="text-align: left;">Item</th>
        <th style="text-align: center;">Qty</th>
        <th style="text-align: right;">Rate</th>
        <th style="text-align: right;">Amount</th>
      </tr>
    </thead>
    <tbody>
      $itemsHtml
    </tbody>
  </table>
  <div class="dashed"></div>
  <div class="row">
    <span>Subtotal:</span>
    <span class="bold">Rs.${bill.subtotal}</span>
  </div>
  $discountRow
  $gstRow
  <div class="solid"></div>
  <div class="row total-row">
    <span>TOTAL PAYABLE:</span>
    <span>Rs.${bill.grandTotal}</span>
  </div>
  <div class="dashed"></div>
  <div class="row" style="font-size: 11px;">
    <span>Payment Mode:</span>
    <span class="bold">${bill.paymentMode}</span>
  </div>
  ${bill.paidAt != null ? '<div class="row" style="font-size: 10px; color: #666;"><span>Paid Time:</span><span>${fmt.format(bill.paidAt!)}</span></div>' : ''}
  <div class="dashed"></div>
  <div class="text-center" style="margin-top: 10px;">
    <div style="font-style: italic; font-size: 11px;">Thank you for dining with us!</div>
    <div class="bold" style="font-size: 11px; margin-top: 2px;">*** Please Visit Again ***</div>
    <div style="font-size: 9px; color: #888; margin-top: 8px;">Powered by AR Smart Menu</div>
  </div>
</body>
</html>
''';
  }
}
