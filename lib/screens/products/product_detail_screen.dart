import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/ar_preview.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/products/edit_product_sheet.dart';

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

  Future<void> _pickAndUpload(PhotoAngleType angle) async {
    final product = _product;
    if (product == null || _isUploading) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _isUploading = true;
      _uploadingAngle = angle;
    });

    try {
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'photo.jpg';
      final productId = product.id;

      if (!mounted) return;
      final result = await context.read<ProductProvider>().uploadPhoto(
            productId: productId,
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
            : (result.message ?? 'Photo uploaded ($count/${ProductModel.photosRequiredForSubmit})');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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

  Future<void> _uploadNextSuggested() async {
    final angle = _product?.nextSuggestedAngle;
    if (angle != null) {
      await _pickAndUpload(angle);
    }
  }

  Future<void> _toggleSoldOut() async {
    final product = _product;
    if (product == null) return;

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
      await context.read<ProductProvider>().deleteProduct(widget.productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted')),
        );
        context.go(AppRoutes.products);
      }
    } catch (e) {
      if (mounted) {
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
    final progress = photoCount / ProductModel.photosRequiredForSubmit;

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
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Status', value: product.status.label),
          _InfoRow(label: 'Category', value: product.category?.label ?? '—'),
          _InfoRow(label: 'Veg status', value: product.vegStatus.label),
          if (product.isLive || product.canUploadPhotos) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.isLive ? 'Replace AR photos' : 'AR photos ($photoCount/${ProductModel.photosRequiredForSubmit})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!product.isLive)
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (!product.isLive) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: AppColors.lightGray,
                color: AppColors.primaryOrange,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.isLive
                  ? 'Tap any photo below to replace it (front, top, left, right).'
                  : product.missingPhotoSlots > 0
                      ? 'Tap each empty slot below to upload — ${product.missingPhotoSlots} angle(s) left (front, top, left, right).'
                      : 'All 4 angles uploaded. Product will auto-submit for 3D processing.',
              style: const TextStyle(fontSize: 13, color: AppColors.mediumGray, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.1,
              children: PhotoAngleType.requiredForSubmit.map((angle) {
                final existing = product.photoForAngle(angle);
                final isSlotUploading =
                    _isUploading && _uploadingAngle == angle;
                return _PhotoSlot(
                  angle: angle,
                  photoUrl: existing?.photoUrl,
                  isUploading: isSlotUploading,
                  isEmpty: existing == null,
                  showReplaceHint: product.isLive && existing != null,
                  onTap: _isUploading
                      ? null
                      : () => _pickAndUpload(angle),
                );
              }).toList(),
            ),
            if (!product.isLive) ...[
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: _isUploading ? 'Uploading...' : 'Upload next photo',
                icon: Icons.add_photo_alternate_outlined,
                isLoading: _isUploading,
                onPressed: _isUploading || product.nextSuggestedAngle == null
                    ? null
                    : _uploadNextSuggested,
              ),
            ],
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
          if (product.isLive) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => previewProductInAr(
                context,
                productId: product.id,
                productName: product.name,
              ),
              icon: const Icon(Icons.view_in_ar_outlined),
              label: const Text('Preview in AR browser'),
            ),
            const SizedBox(height: AppSpacing.xl),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sold out today'),
              subtitle: const Text('Hide this item from today\'s menu'),
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

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.angle,
    this.photoUrl,
    required this.isUploading,
    required this.isEmpty,
    this.showReplaceHint = false,
    required this.onTap,
  });

  final PhotoAngleType angle;
  final String? photoUrl;
  final bool isUploading;
  final bool isEmpty;
  final bool showReplaceHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null;

    return Material(
      color: isEmpty
          ? AppColors.primaryOrange.withValues(alpha: 0.08)
          : AppColors.lightGray.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: AppColors.primaryOrange.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap to upload',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryOrange.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      angle.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (showReplaceHint)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Replace',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (isEmpty)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  angle.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isUploading)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            if (hasPhoto)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
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
