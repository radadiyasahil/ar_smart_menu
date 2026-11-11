import 'dart:typed_data';

void downloadPdfFile(Uint8List bytes, String filename) {
  // Native fallback: handled via Printing.sharePdf
}

void downloadTextFile(String content, String filename, {String mimeType = 'text/csv;charset=utf-8;'}) {
  // Native fallback
}

void printReceiptDirect({
  required Uint8List pdfBytes,
  required String htmlContent,
  required String title,
}) {
  // Native fallback: handled via Printing.layoutPdf
}
