import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../../models/qr_code_model.dart';
import '../../providers/business_provider.dart';
import '../services/qr_service.dart';
import '../utils/api_error_utils.dart';

/// Opens the current authenticated Horeca business's AR digital menu (port 5174).
/// Dynamically queries the master QR code / menu slug for this owner.
Future<void> openHorecaMenuAr(BuildContext context, {String? table}) async {
  try {
    final qrService = QrService();
    final master = await qrService.getMasterQr();
    var url = master.webUrl.trim();

    if (url.isEmpty && master.slug.isNotEmpty) {
      url = '${AppConfig.webArDishBaseUrl.replaceAll(RegExp(r'/dish/?$'), '')}/menu/${master.slug}';
    }

    if (url.isEmpty) {
      if (!context.mounted) return;
      final business = context.read<BusinessProvider>().business;
      if (business != null && business.businessName.isNotEmpty) {
        final slug = business.businessName
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        url = '${AppConfig.webArDishBaseUrl.replaceAll(RegExp(r'/dish/?$'), '')}/menu/$slug';
      }
    }

    if (url.isNotEmpty) {
      if (table != null && table.isNotEmpty && !url.contains('table=')) {
        final sep = url.contains('?') ? '&' : '?';
        url = '$url${sep}table=$table';
      }
      final ok = await openArMenuUrl(url);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open WebAR menu. Ensure WebAR is running on http://localhost:5174.',
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find active AR menu for this business account.'),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    final business = context.read<BusinessProvider>().business;
    if (business != null && business.businessName.isNotEmpty) {
      final slug = business.businessName
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      var url = 'http://localhost:5174/menu/$slug';
      if (table != null && table.isNotEmpty) {
        url += '?table=$table';
      }
      await openArMenuUrl(url);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(formatApiError(e))),
    );
  }
}

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
  if (qr.webUrl.isNotEmpty) return qr.webUrl;
  if (qr.slug.isNotEmpty) return buildDishPreviewUrl(qr.slug);
  return null;
}

String buildDishPreviewUrl(String slug) =>
    '${AppConfig.webArDishBaseUrl.replaceAll(RegExp(r'/+$'), '')}/$slug';
