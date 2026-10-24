import 'dart:typed_data';

/// Callback when an image is pasted or dropped from the web browser
typedef WebImageCallback = void Function(Uint8List bytes, String filename);

abstract class WebPasteDropHelper {
  /// Initialize native web window paste and drop listeners.
  /// No-op on non-web platforms.
  static void register({
    required WebImageCallback onImageReceived,
  }) {
    // Stub implementation for non-web
  }

  /// Remove listeners
  static void unregister() {
    // Stub
  }
}
