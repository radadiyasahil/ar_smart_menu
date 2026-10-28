import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/ar_preview.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/business_provider.dart';
import 'dart:typed_data';
import '../../widgets/products/edit_product_sheet.dart';
import '../../widgets/products/four_photo_uploader.dart';

/// Product detail — photos, draft → submitted flow, sold-out, delete.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _picker = ImagePicker();

  ProductModel? _product;
  bool _isLoading = true;
  bool _isUploading = false;
  PhotoAngleType? _uploadingAngle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      ProductModel? product;
      for (final p in context.read<ProductProvider>().products) {
        if (p.id == widget.productId) {
          product = p;
          break;
        }
      }
      product ??= await context.read<ProductProvider>().fetchProduct(widget.productId);
      _product = product;
    } catch (e) {
      _error = formatApiError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadPhotoBytes(
    PhotoAngleType angle,
    Uint8List bytes,
    String filename,
  ) async {
    final product = _product;
    if (product == null || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadingAngle = angle;
    });

    try {
      final result = await context.read<ProductProvider>().uploadPhoto(
            productId: product.id,
            bytes: bytes,
            filename: filename,
            angleType: angle,
          );

      final updated = result.product;
      if (updated != null) {
        setState(() => _product = updated);
      } else {
        await _load();
      }

      if (mounted) {
        final count = _product?.photos.length ?? 0;
        final message = result.autoSubmitted
            ? 'All 4 photos uploaded — product submitted for AR processing!'
            : (result.message ??
                'Photo uploaded ($count/${ProductModel.photosRequiredForSubmit})');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.autoSubmitted ? AppColors.success : null,
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
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingAngle = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadGlb() async {
    final product = _product;
    if (product == null || _isUploading) return;

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['glb'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read 3D file data')),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      if (!mounted) return;
      final updated = await context.read<ProductProvider>().uploadModel(
            productId: product.id,
            bytes: bytes,
            filename: file.name.isNotEmpty ? file.name : 'model.glb',
          );

      if (mounted) {
        setState(() {
          _product = updated;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('3D Model uploaded successfully! Dish is now Live in AR.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final product = _product;
    if (product == null || _isUploading) return;

    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 35 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video must be under 35 MB to conserve storage.'),
            ),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      if (!mounted) return;
      final updated = await context.read<ProductProvider>().uploadVideo(
            productId: product.id,
            bytes: bytes,
            filename: picked.name.isNotEmpty ? picked.name : 'walkaround.mp4',
          );

      if (mounted) {
        setState(() {
          _product = updated;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Walkaround video uploaded! Status updated to Processing.'),
            backgroundColor: AppColors.primaryOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    }
  }

  Future<void> _toggleLiveStatus(ProductStatus targetStatus) async {
    final product = _product;
    if (product == null) return;
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business is deactivated. Reactivate business to change live status.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final updated = await context.read<ProductProvider>().setProductStatus(product.id, targetStatus);
      setState(() => _product = updated);
      if (mounted) {
        final isLive = targetStatus == ProductStatus.live;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isLive
                ? '${product.name} is now LIVE on AR menu!'
                : '${product.name} removed from Live menu (Paused).'),
            backgroundColor: isLive ? AppColors.success : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    }
  }

  Future<void> _toggleSoldOut() async {
    final product = _product;
    if (product == null) return;
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business is deactivated. Reactivate business to update availability.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final updated = await context.read<ProductProvider>().toggleSoldOut(
            product.id,
            soldOut: !product.soldOutToday,
          );
      setState(() => _product = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    }
  }

  Future<void> _delete() async {
    final isDeactivated = context.read<BusinessProvider>().isDeactivated;
    if (isDeactivated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business is deactivated. Reactivate business to delete products.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${_product?.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isLoading = true);
      await context.read<ProductProvider>().deleteProduct(widget.productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
        context.go(AppRoutes.products);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Product'),
        actions: [
          if (_product != null &&
              (_product!.isLive ||
                  _product!.status == ProductStatus.review ||
                  _product!.status == ProductStatus.submitted))
            IconButton(
              tooltip: 'Preview in AR',
              icon: const Icon(Icons.view_in_ar_outlined),
              onPressed: () => previewProductInAr(
                context,
                productId: widget.productId,
                productName: _product!.name,
              ),
            ),
          if (_product != null)
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showEditProductSheet(
                context,
                product: _product!,
                onSaved: (updated) => setState(() => _product = updated),
              ),
            ),
          if (_product != null && _product!.isLive)
            IconButton(
              tooltip: 'Remove from Live (Pause)',
              icon: const Icon(Icons.pause_circle_outline),
              onPressed: () => _toggleLiveStatus(ProductStatus.paused),
            ),
          if (_product != null && _product!.isPaused)
            IconButton(
              tooltip: 'Publish to Live Menu',
              icon: const Icon(Icons.play_circle_fill, color: AppColors.success),
              onPressed: () => _toggleLiveStatus(ProductStatus.live),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
          if (_product != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _product == null) {
      return Center(child: Text(_error ?? 'Product not found'));
    }

    final product = _product!;
    final photoCount = product.photos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(product: product, photoCount: photoCount),
          const SizedBox(height: AppSpacing.lg),
          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            product.priceLabel,
            style: const TextStyle(
              fontSize: 20,
              color: AppColors.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: product.isHero
                      ? Colors.purple.withValues(alpha: 0.15)
                      : Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: product.isHero
                        ? Colors.purple.withValues(alpha: 0.4)
                        : Colors.blueGrey.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      product.isHero ? Icons.auto_awesome : Icons.restaurant,
                      size: 13,
                      color: product.isHero ? Colors.purpleAccent : Colors.blueGrey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      product.isHero
                          ? 'Hero / Signature Dish (3D AR)'
                          : 'Normal Dish (Standard 2D)',
                      style: TextStyle(
                        color: product.isHero ? Colors.purpleAccent : Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (product.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.category!.label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Dish Type', value: product.isHero ? 'Hero 3D AR Dish' : 'Normal / Standard (2D)'),
          _InfoRow(label: 'Status', value: product.status.label),
          _InfoRow(label: 'Category', value: product.category?.label ?? '—'),
          _InfoRow(label: 'Veg status', value: product.vegStatus.label),
          if (product.isLive || product.canUploadPhotos) ...[
            const SizedBox(height: AppSpacing.lg),
            FourPhotoUploader(
              title: product.isLive ? 'Replace AR photos' : 'AR photos (4 Required)',
              remotePhotoUrls: {
                for (final angle in PhotoAngleType.requiredForSubmit)
                  angle: product.photoForAngle(angle)?.photoUrl,
              },
              isUploading: _isUploading,
              uploadingAngle: _uploadingAngle,
              showReplaceHint: product.isLive,
              onPhotoSelected: (angle, bytes, filename) =>
                  _uploadPhotoBytes(angle, bytes, filename),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: AppColors.primaryOrange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Direct 3D & Video Upload',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload a ready .glb 3D scan (instant live) or a short 10s walkaround video (<35MB).',
                    style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.view_in_ar, size: 18),
                          label: const Text('Upload .glb (3D)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            side: const BorderSide(color: AppColors.primaryOrange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isUploading ? null : _pickAndUploadGlb,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.videocam_outlined, size: 18),
                          label: const Text('Upload Video'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isUploading ? null : _pickAndUploadVideo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (product.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Photos',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: product.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final photo = product.photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.network(
                      photo.photoUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 100,
                        color: AppColors.lightGray,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (product.description != null && product.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.description!,
              style: const TextStyle(height: 1.5, color: AppColors.mediumGray),
            ),
          ],
          if (product.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rejected by admin',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (product.rejectionReasonOnly != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      product.rejectionReasonOnly!,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                  if (product.rejectionImprovementNotes != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'What to improve',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      product.rejectionImprovementNotes!,
                      style: const TextStyle(
                        height: 1.45,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Upload new photos below and resubmit.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (product.isLive || product.isPaused) ...[
            const SizedBox(height: AppSpacing.md),
            if (product.isLive)
              OutlinedButton.icon(
                onPressed: () => previewProductInAr(
                  context,
                  productId: product.id,
                  productName: product.name,
                ),
                icon: const Icon(Icons.view_in_ar_outlined),
                label: const Text('Preview in AR browser'),
              ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: (product.isLive ? AppColors.success : Colors.orange.shade700).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: (product.isLive ? AppColors.success : Colors.orange.shade700).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        product.isLive ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                        color: product.isLive ? AppColors.success : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.isLive ? 'Live on Diner Menu' : 'Removed from Live (Paused)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: product.isLive ? AppColors.success : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.isLive
                        ? 'This dish is currently visible and orderable by diners scanning table QR codes.'
                        : 'This dish is hidden from diners. All photos and 3D models are fully preserved. You can make it live again anytime with 1 click.',
                    style: const TextStyle(fontSize: 12, color: AppColors.mediumGray, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  if (product.isLive)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade400),
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Remove from Live (Pause Dish)'),
                      onPressed: () => _toggleLiveStatus(ProductStatus.paused),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      icon: const Icon(Icons.play_circle_fill, size: 18),
                      label: const Text('Publish back to Live Menu'),
                      onPressed: () => _toggleLiveStatus(ProductStatus.live),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sold out today'),
              subtitle: const Text('Hide this item from today''s menu temporarily'),
              value: product.soldOutToday,
              onChanged: (_) => _toggleSoldOut(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.product, required this.photoCount});

  final ProductModel product;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    if (photoCount < ProductModel.photosRequiredForSubmit &&
        (product.isSubmitted ||
            product.status == ProductStatus.processing ||
            product.status == ProductStatus.review)) {
      return _banner(
        color: AppColors.warning,
        icon: Icons.photo_camera_outlined,
        text:
            'Upload ${ProductModel.photosRequiredForSubmit - photoCount} more photo(s) below — ${ProductModel.photosRequiredForSubmit} required before AR processing.',
      );
    }
    if (product.isSubmitted || product.status == ProductStatus.processing) {
      return _banner(
        color: AppColors.info,
        icon: Icons.send_outlined,
        text: 'Submitted for AR processing — 3D model generation in progress.',
      );
    }
    if (product.isPaused) {
      return _banner(
        color: Colors.orange.shade700,
        icon: Icons.pause_circle_outline,
        text: 'Paused (Off Menu) â€” hidden from customers. Click "Publish back to Live" anytime to restore.',
      );
    }
    if (product.isLive) {
      return _banner(
        color: AppColors.success,
        icon: Icons.check_circle_outline,
        text: 'Live on your AR menu. Scroll down to replace photos if needed.',
      );
    }
    if (product.isDraft) {
      return _banner(
        color: AppColors.warning,
        icon: Icons.photo_camera_outlined,
        text: photoCount < ProductModel.photosRequiredForSubmit
            ? 'Draft — upload ${ProductModel.photosRequiredForSubmit - photoCount} more photo(s) to submit.'
            : 'Draft — ready to submit (refresh if status has not updated).',
      );
    }
    if (product.status == ProductStatus.rejected) {
      return _banner(
        color: AppColors.error,
        icon: Icons.error_outline,
        text: product.rejectionImprovementNotes != null
            ? 'Rejected — see admin feedback below, then upload new photos.'
            : 'Rejected — see reason below, upload new photos and resubmit.',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mediumGray),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
