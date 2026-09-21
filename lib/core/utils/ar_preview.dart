import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../../models/qr_code_model.dart';
import '../services/qr_service.dart';
import '../utils/api_error_utils.dart';

/// Opens the owner's dish in the WebAR browser experience (port 5174).
Future<void> previewProductInAr(
  BuildContext context, {
  required String productId,
  String? productName,
}) async {
  try {
    final qrService = QrService();
    final codes = await qrService.list();
    QrCodeModel? match;
    for (final code in codes) {
      if (code.productId == productId && code.isActive) {
        match = code;
        break;
      }
    }

    final url = _resolvePreviewUrl(match);
    if (url == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productName != null
                ? 'Generate a QR code for "$productName" first (QR tab).'
                : 'Generate a QR code for this product first (QR tab).',
          ),
        ),
      );
      return;
    }

    final launched = await openArMenuUrl(url);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open AR menu. Start WebAR with npm run dev in webar-experience (http://localhost:5174).',
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(formatApiError(e))),
    );
  }
}

/// Opens a WebAR URL. On Flutter web this must use a new tab (`_blank`).
Future<bool> openArMenuUrl(String url) async {
  final uri = Uri.parse(url);
  if (kIsWeb) {
    return launchUrl(uri, webOnlyWindowName: '_blank');
  }

  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}

String? _resolvePreviewUrl(QrCodeModel? qr) {
  if (qr == null) return null;
  if (qr.slug.isNotEmpty) return buildDishPreviewUrl(qr.slug);
  if (qr.webUrl.isNotEmpty) return qr.webUrl;
  return null;
}

String buildDishPreviewUrl(String slug) =>
    '${AppConfig.webArDishBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$slug';
