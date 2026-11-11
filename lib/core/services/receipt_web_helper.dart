import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadPdfFile(Uint8List bytes, String filename) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

void downloadTextFile(String content, String filename, {String mimeType = 'text/csv;charset=utf-8;'}) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

void printReceiptDirect({
  required Uint8List pdfBytes,
  required String htmlContent,
  required String title,
}) {
  final printWindow = web.window.open('', '_blank', 'width=420,height=700');
  if (printWindow != null) {
    printWindow.document.open();
    printWindow.document.write(htmlContent.toJS);
    printWindow.document.close();
  } else {
    // If popups are blocked by browser, open the generated PDF blob directly
    final blob = web.Blob([pdfBytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
  }
}
