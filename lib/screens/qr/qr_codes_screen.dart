import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/qr_service.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/ar_preview.dart';
import '../../models/product_model.dart';
import '../../models/qr_code_model.dart';
import '../../providers/product_provider.dart';
/// QR codes — list, generate for submitted/live products.
class QrCodesScreen extends StatefulWidget {
  const QrCodesScreen({super.key});

  @override
  State<QrCodesScreen> createState() => _QrCodesScreenState();
}

class _QrCodesScreenState extends State<QrCodesScreen> {
  final _qrService = QrService();

  List<QrCodeModel> _codes = [];
  bool _loading = true;
  String? _error;
  String? _generatingProductId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(background: true);
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _codes = await _qrService.list();
    } catch (e) {
      _error = formatApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate(String productId, String productName) async {
    setState(() => _generatingProductId = productId);
    try {
      final qr = await _qrService.generateForProduct(productId);
      setState(() {
        _codes = [qr, ..._codes.where((c) => c.productId != productId)];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR generated for $productName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingProductId = null);
    }
  }

  bool _canGenerateQr(ProductModel product) {
    return product.status == ProductStatus.submitted ||
        product.status == ProductStatus.review ||
        product.status == ProductStatus.live;
  }

  QrCodeModel? _qrForProduct(String productId) {
    for (final code in _codes) {
      if (code.productId == productId && code.isActive) return code;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        final products = productProvider.products.where(_canGenerateQr).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('QR Codes'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                        ),
                      const Text(
                        'Generate QR for submitted products',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'After admin publishes, scan opens your WebAR menu dish page.',
                        style: TextStyle(color: AppColors.mediumGray, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (products.isEmpty)
                        const Text(
                          'No submitted products yet. Upload 4 photos on a product first.',
                          style: TextStyle(color: AppColors.mediumGray),
                        )
                      else
                        ...products.map((product) {
                          final existing = _qrForProduct(product.id);
                          return _ProductQrCard(
                            product: product,
                            qr: existing,
                            isGenerating: _generatingProductId == product.id,
                            onGenerate: () => _generate(product.id, product.name),
                          );
                        }),
                      if (_codes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'Your QR codes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._codes.map((qr) => _QrDetailCard(qr: qr)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _ProductQrCard extends StatelessWidget {
  const _ProductQrCard({
    required this.product,
    required this.qr,
    required this.isGenerating,
    required this.onGenerate,
  });

  final ProductModel product;
  final QrCodeModel? qr;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    product.status.label,
                    style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  ),
                ],
              ),
            ),
            if (qr != null)
              const Icon(Icons.check_circle, color: AppColors.success)
            else
              FilledButton(
                onPressed: isGenerating ? null : onGenerate,
                child: Text(isGenerating ? '...' : 'Generate'),
              ),
          ],
        ),
      ),
    );
  }
}

class _QrDetailCard extends StatelessWidget {
  const _QrDetailCard({required this.qr});

  final QrCodeModel qr;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              qr.productName ?? qr.slug,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: QrImageView(
                data: qr.webUrl,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              qr.webUrl,
              style: const TextStyle(fontSize: 12, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = buildDishPreviewUrl(qr.slug);
                      final launched = await openArMenuUrl(url);
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open AR menu. Start webar-experience on port 5174.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.view_in_ar_outlined, size: 16),
                    label: const Text('Preview AR'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qr.webUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
