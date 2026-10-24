import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

typedef WebImageCallback = void Function(Uint8List bytes, String filename);

class WebPasteDropHelper {
  static JSFunction? _pasteListener, _dragOverListener, _dropListener;

  static void register({required WebImageCallback onImageReceived}) {
    unregister();

    _pasteListener = ((web.ClipboardEvent e) {
      final items = e.clipboardData?.items;
      if (items == null) return;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.type.startsWith('image/')) {
          final file = item.getAsFile();
          if (file != null) {
            e.preventDefault();
            _read(file).then((b) {
              if (b != null && b.isNotEmpty) onImageReceived(b, file.name.isNotEmpty ? file.name : 'pasted.png');
            });
            return;
          }
        }
      }
    }).toJS;

    _dragOverListener = ((web.DragEvent e) => e.preventDefault()).toJS;

    _dropListener = ((web.DragEvent e) {
      final files = e.dataTransfer?.files;
      if (files != null && files.length > 0) {
        e.preventDefault();
        for (var i = 0; i < files.length; i++) {
          final f = files.item(i);
          if (f != null && (f.type.startsWith('image/') || RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false).hasMatch(f.name))) {
            _read(f).then((b) { if (b != null && b.isNotEmpty) onImageReceived(b, f.name); });
            return;
          }
        }
      }
    }).toJS;

    try {
      web.window.addEventListener('paste', _pasteListener);
      web.window.addEventListener('dragover', _dragOverListener);
      web.window.addEventListener('drop', _dropListener);
    } catch (e) {
      debugPrint('WebPasteDropHelper register error: $e');
    }
  }

  static void unregister() {
    try {
      if (_pasteListener != null) web.window.removeEventListener('paste', _pasteListener);
      if (_dragOverListener != null) web.window.removeEventListener('dragover', _dragOverListener);
      if (_dropListener != null) web.window.removeEventListener('drop', _dropListener);
      _pasteListener = _dragOverListener = _dropListener = null;
    } catch (_) {}
  }

  static Future<Uint8List?> _read(web.Blob blob) async {
    try {
      return (await blob.arrayBuffer().toDart).toDart.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
