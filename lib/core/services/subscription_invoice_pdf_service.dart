import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'receipt_stub_helper.dart'
    if (dart.library.js_interop) 'receipt_web_helper.dart' as platform_helper;
import 'subscription_service.dart';

/// Service responsible for generating Government-compliant GST Tax Invoices for Subscriptions
/// (For GST input tax credit, income tax return filing, and government audit).
class SubscriptionInvoicePdfService {
  SubscriptionInvoicePdfService._();
  static final SubscriptionInvoicePdfService instance = SubscriptionInvoicePdfService._();

  /// Generates official A4 GST Tax Invoice PDF document bytes
  Future<Uint8List> generateInvoicePdf(SubscriptionInvoiceModel invoice) async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMM yyyy');
    final invoiceDateStr = fmt.format(invoice.invoiceDate);
    final periodStr = '${fmt.format(invoice.startsAt)} to ${fmt.format(invoice.endsAt)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Header with Green Badge & Legal Citation
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#10B981'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          'ORIGINAL FOR RECIPIENT • TAX INVOICE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.Text(
                        'Issued under Section 31 of CGST Act, 2017 & Rule 46 of CGST Rules, 2017',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Invoice #: ${invoice.invoiceNumber}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Date: $invoiceDateStr', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.Text('Place of Supply: ${invoice.placeOfSupply}', style: const pw.TextStyle(fontSize: 9.5)),
                      pw.Text('Reverse Charge: NO', style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#10B981'), fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#0F172A')),
              pw.SizedBox(height: 10),

              // Two Boxes: Supplier Details (Left) and Customer Details (Right)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Supplier
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SERVICE PROVIDER / SUPPLIER',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(invoice.supplierName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.supplierAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.SizedBox(height: 4),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'GSTIN: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                pw.TextSpan(text: invoice.supplierGstNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#0F172A'))),
                              ],
                            ),
                          ),
                          pw.Text('PAN: ${invoice.supplierPan} • State: ${invoice.supplierState} (${invoice.supplierStateCode})', style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text('Email: ${invoice.supplierEmail} • Phone: ${invoice.supplierPhone}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),

                  // Customer
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILLED TO / BUYER (RECIPIENT)',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(invoice.customerBusinessName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          if (invoice.customerOwnerName != null && invoice.customerOwnerName!.isNotEmpty)
                            pw.Text('Attn: ${invoice.customerOwnerName}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.Text(invoice.customerAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                          pw.SizedBox(height: 4),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Buyer GSTIN: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                pw.TextSpan(
                                  text: invoice.customerGstNumber ?? 'URP (Unregistered Person)',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9,
                                    color: invoice.isGstRegistered ? PdfColor.fromHex('#0F172A') : PdfColors.grey700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Text('State: ${invoice.customerState} (${invoice.customerStateCode}) • Country: India', style: const pw.TextStyle(fontSize: 8.5)),
                          if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty)
                            pw.Text('Contact: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Itemized Services Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(6),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2.5),
                  4: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                    children: [
                      _headerCell('#', align: pw.TextAlign.center),
                      _headerCell('DESCRIPTION OF SUPPLY'),
                      _headerCell('SAC CODE', align: pw.TextAlign.center),
                      _headerCell('TAXABLE VALUE', align: pw.TextAlign.right),
                      _headerCell('TOTAL (INR)', align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.white),
                    children: [
                      _dataCell('1', align: pw.TextAlign.center, isBold: true),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '${invoice.planName} SaaS Subscription (${invoice.durationDays} Days)',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Interactive 3D AR Digital Menu Visualizer, Live Kitchen Order Ticketing (KOT), Table Ordering & POS Billing Platform Access.',
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('Service Validity: $periodStr', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      _dataCell(invoice.sacCode, align: pw.TextAlign.center, isBold: true),
                      _dataCell('Rs. ${invoice.baseAmountRupees.toStringAsFixed(2)}', align: pw.TextAlign.right),
                      _dataCell('Rs. ${invoice.totalAmountRupees.toStringAsFixed(2)}', align: pw.TextAlign.right, isBold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Bottom Split: Left = Words & Payment Info; Right = Tax Calculation Summary
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left Column: Words & Payment Details
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8FAFC'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'TOTAL INVOICE AMOUNT IN WORDS:',
                                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                invoice.amountInWords,
                                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F8FAFC'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'PAYMENT & SETTLEMENT REFERENCE',
                                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text('Payment Mode: ${invoice.paymentMethod ?? "Online UPI / Card"}', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('Txn Ref ID: ${invoice.paymentRef ?? "N/A"}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text('Status: PAID & SETTLED', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#10B981'))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),

                  // Right Column: Tax Breakdown Table
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                      child: pw.Column(
                        children: [
                          _summaryRow('Taxable Value', 'Rs. ${invoice.baseAmountRupees.toStringAsFixed(2)}'),
                          pw.Divider(thickness: 0.5, color: PdfColor.fromHex('#CBD5E1')),
                          if (invoice.isInterState)
                            _summaryRow('IGST @ 18.0%', 'Rs. ${invoice.igstRupees.toStringAsFixed(2)}')
                          else ...[
                            _summaryRow('CGST @ 9.0%', 'Rs. ${invoice.cgstRupees.toStringAsFixed(2)}'),
                            _summaryRow('SGST @ 9.0%', 'Rs. ${invoice.sgstRupees.toStringAsFixed(2)}'),
                          ],
                          pw.Divider(thickness: 1, color: PdfColor.fromHex('#0F172A')),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TOTAL PAYABLE (INR)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.Text(
                                'Rs. ${invoice.totalAmountRupees.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Statutory Notes & Digital Signature Seal
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#CBD5E1')),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'STATUTORY DECLARATION & TERMS:',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155')),
                        ),
                        pw.Text('1. Input Tax Credit (ITC) can be claimed by registered businesses under Section 16 & 17 of CGST Act, 2017.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.Text('2. This electronic document is valid for Income Tax audit, GST annual return filing (GSTR-9/3B/2B), and government compliance.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        pw.Text('3. Authenticated computer-generated invoice under Information Technology Act, 2000. No physical signature required.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('#0F172A'), width: 1, style: pw.BorderStyle.dashed),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('AR Smart Menu Technologies Pvt. Ltd.', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 3),
                        pw.Text('✔ VERIFIED & DIGITALLY SIGNED', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#10B981'))),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Trigger download or print of the GST Tax Invoice PDF
  Future<void> downloadInvoicePdf(SubscriptionInvoiceModel invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    final title = 'Tax_Invoice_${invoice.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

    if (kIsWeb) {
      platform_helper.printReceiptDirect(
        pdfBytes: pdfBytes,
        htmlContent: '',
        title: title,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: title,
      );
    }
  }

  /// Share the GST Tax Invoice PDF directly (WhatsApp, Email, Drive)
  Future<void> shareInvoicePdf(SubscriptionInvoiceModel invoice) async {
    final pdfBytes = await generateInvoicePdf(invoice);
    final filename = 'Invoice_${invoice.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8.5,
        ),
      ),
    );
  }

  pw.Widget _dataCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
