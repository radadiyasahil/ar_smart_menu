import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/qr_service.dart';
import '../../core/services/table_stand_pdf_service.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/ar_preview.dart';
import '../../models/qr_code_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/hover_card.dart';

enum QrViewMode { master, tables, products }

class QrCodesScreen extends StatefulWidget {
  const QrCodesScreen({super.key});

  @override
  State<QrCodesScreen> createState() => _QrCodesScreenState();
}

class _QrCodesScreenState extends State<QrCodesScreen> {
  final _qrService = QrService();

  QrViewMode _mode = QrViewMode.master;
  QrCodeModel? _masterQr;
  List<QrCodeModel> _tableQrs = [];
  List<QrCodeModel> _productQrs = [];

  bool _loading = true;
  bool _generatingTables = false;
  bool _hasGeneratedTables = false;
  int _tableCount = 3;
  String? _error;
  String? _generatingProductId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(background: true);
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final master = await _qrService.getMasterQr();
      final allCodes = await _qrService.list();

      setState(() {
        _masterQr = master;
        _productQrs = allCodes.where((q) => q.isProduct).toList();
        // Do not auto-display table scanners until user clicks "Generate QRs"
      });
    } catch (e) {
      _error = formatApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateTables() async {
    final businessProvider = context.read<BusinessProvider>();
    if (businessProvider.isDeactivated || businessProvider.isSuspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant operations are deactivated. Please reactivate your business to generate table QRs.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _generatingTables = true);
    try {
      final tables = await _qrService.generateTableQrs(count: _tableCount);
      // Sort numerically: Table 1, Table 2, Table 3... (instead of alphabetical t1, t10, t2)
      tables.sort((a, b) {
        final na = int.tryParse(TableStandPdfService.extractTableNumber(a.slug, a.productName, webUrl: a.webUrl)) ?? 0;
        final nb = int.tryParse(TableStandPdfService.extractTableNumber(b.slug, b.productName, webUrl: b.webUrl)) ?? 0;
        return na.compareTo(nb);
      });
      setState(() {
        _tableQrs = tables;
        _hasGeneratedTables = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_tableCount Table QR codes generated!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingTables = false);
    }
  }

  Future<void> _generateProductQr(String productId, String productName) async {
    setState(() => _generatingProductId = productId);
    try {
      final qr = await _qrService.generateForProduct(productId);
      setState(() {
        _productQrs = [qr, ..._productQrs.where((c) => c.productId != productId)];
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

  Future<void> _downloadAllStands(String businessName) async {
    try {
      await TableStandPdfService.instance.downloadAllStands(
        tableQrs: _tableQrs,
        businessName: businessName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded all Table Stands PDF!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download stands: $e')),
        );
      }
    }
  }

  Future<void> _printAllStands(String businessName) async {
    try {
      await TableStandPdfService.instance.printAllStands(
        tableQrs: _tableQrs,
        businessName: businessName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print stands: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().business;
    final businessName = business?.businessName ?? 'Restaurant Menu';
    final city = business?.city ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Menu Stands'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ),

                  // Mode Selector
                  Center(
                    child: SegmentedButton<QrViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: QrViewMode.master,
                          label: Text('Master QR'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                        ButtonSegment(
                          value: QrViewMode.tables,
                          label: Text('Table QRs'),
                          icon: Icon(Icons.table_restaurant_outlined),
                        ),
                        ButtonSegment(
                          value: QrViewMode.products,
                          label: Text('Dishes'),
                          icon: Icon(Icons.restaurant_menu_outlined),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (set) => setState(() => _mode = set.first),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Mode 1: Master Restaurant QR ────────────────────────────
                  if (_mode == QrViewMode.master) ...[
                    const Text(
                      'Single Master Menu QR',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Print and place this single QR code on all tables, the billing counter, or flyers. Scanning opens your full 3D AR menu.',
                      style: TextStyle(color: AppColors.mediumGray, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_masterQr != null)
                      _MasterQrStandCard(
                        businessName: businessName,
                        city: city,
                        qr: _masterQr!,
                      )
                    else
                      const Center(child: Text('Master QR not ready. Tap refresh.')),
                  ],

                  // ── Mode 2: Table-Wise QRs ──────────────────────────────────
                  if (_mode == QrViewMode.tables) ...[
                    const Text(
                      'Individual Table QR Codes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Generate separate QR stands for each dining table (Table 1, Table 2...). Orders automatically identify the table number.',
                      style: TextStyle(color: AppColors.mediumGray, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Table count configurator
                    HoverCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      borderRadius: AppSpacing.radiusMd,
                      child: Row(
                        children: [
                          const Icon(Icons.table_restaurant, color: AppColors.primaryOrange),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Number of Tables', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Currently configured: $_tableCount tables',
                                    style: const TextStyle(fontSize: 12, color: AppColors.mediumGray)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _tableCount > 1 && !_generatingTables
                                ? () => setState(() => _tableCount--)
                                : null,
                          ),
                          Text('$_tableCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _tableCount < 50 && !_generatingTables
                                ? () => setState(() => _tableCount++)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                            onPressed: _generatingTables || (context.read<BusinessProvider>().isDeactivated || context.read<BusinessProvider>().isSuspended) ? null : _generateTables,
                            child: Text(_generatingTables ? 'Generating...' : 'Generate QRs'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    if (!_hasGeneratedTables) ...[
                      // Shown BEFORE user clicks "Generate QRs"
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.table_restaurant_outlined, size: 48, color: AppColors.primaryOrange),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Table Scanners Generated Yet',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select the number of tables (default is 3) and click "Generate QRs" above to create and view your table scanners.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.mediumGray, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_tableQrs.isEmpty) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No table QRs found. Click "Generate QRs" above.',
                            style: TextStyle(color: AppColors.mediumGray),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Batch Actions Bar
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: Text('Download All (${_tableQrs.length}) Stands (PDF)'),
                            onPressed: () => _downloadAllStands(businessName),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Print All Stands'),
                            onPressed: () => _printAllStands(businessName),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Generated Table Stands (${_tableQrs.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Column(
                        children: _tableQrs
                            .map((tQr) => _TableQrCard(
                                  qr: tQr,
                                  businessName: businessName,
                                ))
                            .toList(),
                      ),
                    ],
                  ],

                  // ── Mode 3: Product-by-Product QRs ──────────────────────────
                  if (_mode == QrViewMode.products) ...[
                    const Text(
                      'Individual Dish QRs (Optional)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'For special promotional table tents or flyers focused on a single hero dish.',
                      style: TextStyle(color: AppColors.mediumGray, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Consumer<ProductProvider>(
                      builder: (context, provider, _) {
                        final products = provider.products;
                        if (products.isEmpty) {
                          return const Text('No products available.', style: TextStyle(color: AppColors.mediumGray));
                        }
                        return Column(
                          children: products.map((product) {
                            final existing = _productQrs.firstWhere(
                              (q) => q.productId == product.id && q.isActive,
                              orElse: () => const QrCodeModel(
                                id: '',
                                businessId: '',
                                slug: '',
                                webUrl: '',
                                isActive: false,
                              ),
                            );
                            final hasQr = existing.id.isNotEmpty;

                            return HoverCard(
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${product.priceLabel} • ${product.status.label}',
                                            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray)),
                                      ],
                                    ),
                                  ),
                                  if (hasQr)
                                    IconButton(
                                      tooltip: 'Open in AR',
                                      icon: const Icon(Icons.open_in_browser, color: AppColors.primaryOrange),
                                      onPressed: () => openArMenuUrl(existing.webUrl),
                                    )
                                  else
                                    FilledButton(
                                      onPressed: _generatingProductId == product.id
                                          ? null
                                          : () => _generateProductQr(product.id, product.name),
                                      child: Text(_generatingProductId == product.id ? '...' : 'Generate'),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Standalone preview card for Master Restaurant QR
/// Includes direct options to Download Stand (PDF), Print Stand, Open Menu, and Copy Link.
class _MasterQrStandCard extends StatelessWidget {
  const _MasterQrStandCard({
    required this.businessName,
    required this.city,
    required this.qr,
  });

  final String businessName;
  final String city;
  final QrCodeModel qr;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryOrange, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.25 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '3D AR DIGITAL MENU',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              businessName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (city.isNotEmpty)
              Text(
                '📍 $city',
                style: const TextStyle(fontSize: 13, color: AppColors.mediumGray),
              ),
            const SizedBox(height: 20),

            // Crisp White QR Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderGray),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: qr.webUrl,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan with your phone camera',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Text(
              'No app installation needed • View dishes on your table in 3D',
              style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Primary Actions: Download Stand (PDF) & Print Stand
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Download Stand', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => TableStandPdfService.instance.downloadStand(
                      qr: qr,
                      businessName: businessName,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print Stand', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => TableStandPdfService.instance.printStand(
                      qr: qr,
                      businessName: businessName,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Secondary Actions: Open AR Preview & Copy Link
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.open_in_browser, size: 17),
                    label: const Text('Open Menu'),
                    onPressed: () => openArMenuUrl(qr.webUrl),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.copy, size: 17),
                    label: const Text('Copy Link'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qr.webUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Menu link copied to clipboard!')),
                      );
                    },
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

/// Existing clean horizontal card design for each Table QR in the Owner App.
/// Includes direct actions to Download Stand (PDF), Print Stand, Preview in AR, and Copy Link.
class _TableQrCard extends StatelessWidget {
  const _TableQrCard({
    required this.qr,
    required this.businessName,
  });

  final QrCodeModel qr;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final tableNumber = TableStandPdfService.extractTableNumber(qr.slug, qr.productName, webUrl: qr.webUrl);
    final tableTitle = qr.productName != null && qr.productName!.isNotEmpty
        ? qr.productName!
        : 'Table $tableNumber';

    return HoverCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppSpacing.radiusMd,
      child: Row(
        children: [
          // Table QR Thumbnail
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: QrImageView(
              data: qr.webUrl,
              size: 56,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Table Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tableTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  businessName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  qr.webUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Actions: Download Stand (PDF) with new golden yellow design, Print, Preview, Copy
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Stand', style: TextStyle(fontSize: 12)),
            onPressed: () => TableStandPdfService.instance.downloadStand(
              qr: qr,
              businessName: businessName,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Print Stand',
            icon: const Icon(Icons.print, size: 20),
            onPressed: () => TableStandPdfService.instance.printStand(
              qr: qr,
              businessName: businessName,
            ),
          ),
          IconButton(
            tooltip: 'Preview AR Menu',
            icon: const Icon(Icons.open_in_browser, color: AppColors.primaryOrange, size: 20),
            onPressed: () => openArMenuUrl(qr.webUrl),
          ),
          IconButton(
            tooltip: 'Copy Table Link',
            icon: const Icon(Icons.copy, size: 19),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qr.webUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$tableTitle link copied!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
