import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/qr_code_model.dart';
import 'receipt_stub_helper.dart'
    if (dart.library.js_interop) 'receipt_web_helper.dart' as platform_helper;

/// Service for generating high-resolution Table Tent Scanner cards (A6 format).
/// Styled after the "VIEW OUR MENU !" restaurant table talker design (golden yellow theme,
/// prominent table number or master menu badge, high-contrast framed QR code, and restaurant branding).
class TableStandPdfService {
  TableStandPdfService._();
  static final TableStandPdfService instance = TableStandPdfService._();

  // Golden Yellow & Charcoal Theme from reference photo
  static const PdfColor goldenYellow = PdfColor.fromInt(0xFFFFB800);
  static const PdfColor warmAmber = PdfColor.fromInt(0xFFFFA000);
  static const PdfColor deepCharcoal = PdfColor.fromInt(0xFF1E1E1E);
  static const PdfColor accentOrange = PdfColor.fromInt(0xFFE65100);

  static bool isMasterQr(QrCodeModel qr) => qr.isMenu || !qr.isTable;

  static String getStandBadgeTitle(QrCodeModel qr) {
    if (isMasterQr(qr)) return 'MASTER MENU';
    final num = extractTableNumber(qr.slug, qr.productName, webUrl: qr.webUrl);
    return 'TABLE $num';
  }

  /// Generates a single table/master stand PDF (A6 format)
  Future<Uint8List> generateSingleStandPdf({
    required QrCodeModel qr,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(_buildPage(
      qr: qr,
      businessName: businessName,
    ));
    return pdf.save();
  }

  /// Generates a combined multi-page PDF containing all table stands
  Future<Uint8List> generateAllStandsPdf({
    required List<QrCodeModel> tableQrs,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    for (final qr in tableQrs) {
      pdf.addPage(_buildPage(
        qr: qr,
        businessName: businessName,
      ));
    }
    return pdf.save();
  }

  /// Downloads a table or master stand PDF directly
  Future<void> downloadStand({
    required QrCodeModel qr,
    required String businessName,
  }) async {
    final bytes = await generateSingleStandPdf(
      qr: qr,
      businessName: businessName,
    );
    final isMaster = isMasterQr(qr);
    final tableNumber = extractTableNumber(qr.slug, qr.productName, webUrl: qr.webUrl);
    final safeName = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    final fileName = isMaster
        ? '${safeName}_master_menu_stand.pdf'
        : '${safeName}_table_${tableNumber}_menu_stand.pdf';
    platform_helper.downloadPdfFile(bytes, fileName);
  }

  /// Downloads all table stands in a single PDF file
  Future<void> downloadAllStands({
    required List<QrCodeModel> tableQrs,
    required String businessName,
  }) async {
    final bytes = await generateAllStandsPdf(
      tableQrs: tableQrs,
      businessName: businessName,
    );
    final safeName = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    platform_helper.downloadPdfFile(bytes, '${safeName}_all_table_stands.pdf');
  }

  /// Direct print dialog for a table or master stand
  Future<void> printStand({
    required QrCodeModel qr,
    required String businessName,
  }) async {
    final bytes = await generateSingleStandPdf(
      qr: qr,
      businessName: businessName,
    );
    final html = generateStandHtml(
      qr: qr,
      businessName: businessName,
    );
    final isMaster = isMasterQr(qr);
    final tableNumber = extractTableNumber(qr.slug, qr.productName, webUrl: qr.webUrl);
    final title = isMaster
        ? '$businessName - Master Menu Stand'
        : '$businessName - Table $tableNumber Menu Stand';
    platform_helper.printReceiptDirect(
      pdfBytes: bytes,
      htmlContent: html,
      title: title,
    );
  }

  /// Direct print dialog for all table stands
  Future<void> printAllStands({
    required List<QrCodeModel> tableQrs,
    required String businessName,
  }) async {
    final bytes = await generateAllStandsPdf(
      tableQrs: tableQrs,
      businessName: businessName,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: '$businessName - All Table Menu Stands',
    );
  }

  pw.Page _buildPage({
    required QrCodeModel qr,
    required String businessName,
  }) {
    final badgeTitle = getStandBadgeTitle(qr);

    return pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        return pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: goldenYellow,
          child: pw.Column(
            children: [
              // Top Banner: VIEW OUR MENU !
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(16, 20, 16, 10),
                color: goldenYellow,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'VIEW',
                      style: pw.TextStyle(
                        color: deepCharcoal,
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'OUR MENU !',
                      style: pw.TextStyle(
                        color: deepCharcoal,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    // Table / Master Badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: deepCharcoal,
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      child: pw.Text(
                        badgeTitle,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Center Section: Framed QR Code
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  color: warmAmber,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // High-contrast white QR box
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(16),
                          border: pw.Border.all(color: PdfColors.white, width: 3),
                        ),
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qr.webUrl,
                              width: 150,
                              height: 150,
                              color: PdfColors.black,
                              backgroundColor: PdfColors.white,
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'POINT CAMERA TO SCAN',
                              style: pw.TextStyle(
                                color: deepCharcoal,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 12),

                      // Feature pill
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
                        decoration: pw.BoxDecoration(
                          color: deepCharcoal,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          '3D AR DISHES • WHATSAPP ORDER',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Section: Restaurant Branding Badge
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: goldenYellow,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Powered by',
                          style: pw.TextStyle(
                            color: deepCharcoal,
                            fontSize: 7.5,
                          ),
                        ),
                        pw.Text(
                          'AR SMART MENU',
                          style: pw.TextStyle(
                            color: deepCharcoal,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    // Restaurant Name / Logo Badge
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: deepCharcoal, width: 1.2),
                      ),
                      child: pw.Text(
                        businessName.toUpperCase(),
                        style: pw.TextStyle(
                          color: deepCharcoal,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Generates self-contained HTML for instant browser printing with exact styling matching the photo
  String generateStandHtml({
    required QrCodeModel qr,
    required String businessName,
  }) {
    final badgeTitle = getStandBadgeTitle(qr);
    final qrImgUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(qr.webUrl)}';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$businessName - $badgeTitle Stand</title>
  <style>
    @page {
      size: 105mm 148mm;
      margin: 0;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    body {
      background: #e8e8e8;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
    }
    .stand-card {
      width: 105mm;
      height: 148mm;
      background: linear-gradient(180deg, #FFB800 0%, #FFA000 35%, #E65100 100%);
      color: #1E1E1E;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      overflow: hidden;
      position: relative;
      box-shadow: 0 12px 36px rgba(0,0,0,0.25);
    }
    .header-banner {
      background: #FFB800;
      padding: 16px 14px 10px 14px;
      text-align: center;
    }
    .title-view {
      font-size: 32px;
      font-weight: 900;
      letter-spacing: 3px;
      line-height: 1.0;
      color: #1E1E1E;
    }
    .title-menu {
      font-size: 18px;
      font-weight: 900;
      letter-spacing: 2px;
      margin-top: 3px;
      color: #1E1E1E;
    }
    .table-badge {
      display: inline-block;
      margin-top: 6px;
      background: #1E1E1E;
      color: #ffffff;
      font-size: 13px;
      font-weight: 900;
      padding: 4px 20px;
      border-radius: 20px;
      letter-spacing: 1.5px;
      box-shadow: 0 3px 8px rgba(0,0,0,0.2);
    }
    .center-section {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      position: relative;
      padding: 10px 16px;
      background: radial-gradient(circle, rgba(255,255,255,0.15) 0%, rgba(0,0,0,0.15) 100%);
    }
    .qr-card {
      background: #ffffff;
      padding: 12px;
      border-radius: 20px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.28);
      display: flex;
      flex-direction: column;
      align-items: center;
      border: 3px solid #ffffff;
    }
    .qr-card img {
      width: 155px;
      height: 155px;
      display: block;
    }
    .scan-hint {
      margin-top: 6px;
      font-size: 8px;
      font-weight: 800;
      letter-spacing: 1px;
      color: #333333;
      text-transform: uppercase;
    }
    .features-pill {
      margin-top: 10px;
      background: #1E1E1E;
      color: #ffffff;
      font-size: 8px;
      font-weight: 800;
      letter-spacing: 1px;
      padding: 3px 12px;
      border-radius: 12px;
    }
    .footer-section {
      background: #FFB800;
      padding: 10px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .powered-tag {
      font-size: 8.5px;
      color: #333333;
      line-height: 1.2;
    }
    .powered-tag strong {
      display: block;
      font-size: 9.5px;
      color: #1E1E1E;
      font-weight: 900;
    }
    .logo-badge {
      background: #ffffff;
      border: 1.5px solid #1E1E1E;
      border-radius: 8px;
      padding: 5px 12px;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 1px;
      color: #1E1E1E;
      text-transform: uppercase;
      box-shadow: 0 2px 6px rgba(0,0,0,0.1);
    }
    @media print {
      body {
        background: transparent;
      }
      .stand-card {
        box-shadow: none;
        page-break-after: always;
      }
    }
  </style>
</head>
<body>
  <div class="stand-card">
    <div class="header-banner">
      <div class="title-view">VIEW</div>
      <div class="title-menu">OUR MENU !</div>
      <div><span class="table-badge">$badgeTitle</span></div>
    </div>

    <div class="center-section">
      <div class="qr-card">
        <img src="$qrImgUrl" alt="$badgeTitle QR">
        <div class="scan-hint">Point Camera to Scan</div>
      </div>
      <div class="features-pill">3D AR DISHES • WHATSAPP ORDER</div>
    </div>

    <div class="footer-section">
      <div class="powered-tag">
        Powered by
        <strong>AR SMART MENU</strong>
      </div>
      <div class="logo-badge">$businessName</div>
    </div>
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() {
        window.print();
      }, 500);
    };
  </script>
</body>
</html>
''';
  }

  static String extractTableNumber(String slug, String? productName, {String? webUrl}) {
    if (productName != null) {
      final m = RegExp(r'table\s*(\d+)', caseSensitive: false).firstMatch(productName);
      if (m != null) return m.group(1)!;
    }
    final m2 = RegExp(r'-t(\d+)$', caseSensitive: false).firstMatch(slug);
    if (m2 != null) return m2.group(1)!;
    if (webUrl != null) {
      final m3 = RegExp(r'[?&]table(?:Number)?=(\d+)', caseSensitive: false).firstMatch(webUrl);
      if (m3 != null) return m3.group(1)!;
    }
    final m4 = RegExp(r'(\d+)', caseSensitive: false).firstMatch(slug);
    if (m4 != null) return m4.group(1)!;
    return '1';
  }
}
