import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/products/four_photo_uploader.dart';
import '../../widgets/products/bulk_import_dialog.dart';

/// Create product — POST /api/products.
/// Supports Point 1: "Smart AR Priority" (Standard dish listing vs Hero 3D AR dish)
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  ProductCategory _category = ProductCategory.mainCourse;
  VegStatus _vegStatus = VegStatus.notApplicable;
  bool _categoryInitialized = false;
  bool _isSpicy = false;
  bool _isBestseller = false;
  bool _isNew = true;
  bool _isSubmitting = false;

  // Point 1: Smart AR Priority
  // Default is false for fast standard item listing; toggle on for Hero 3D AR items.
  bool _enable3dAr = false;
  Uint8List? _singlePhotoBytes;
  String? _singlePhotoFilename;

  final Map<PhotoAngleType, Uint8List> _pendingPhotos = {};
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int? _parsePricePaise() {
    final text = _priceController.text.trim();
    if (text.isEmpty) return null;
    final rupees = double.tryParse(text);
    if (rupees == null || rupees < 0) return null;
    return (rupees * 100).round();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoryInitialized) {
      final businessType =
          context.read<BusinessProvider>().business?.businessType ??
              BusinessType.restaurant;
      _category = ProductCategory.forBusinessType(businessType).first;
      _categoryInitialized = true;
    }
  }

  Future<void> _pickSinglePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _singlePhotoBytes = bytes;
          _singlePhotoFilename = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final pricePaise = _parsePricePaise();
    if (_priceController.text.trim().isNotEmpty && pricePaise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final productProvider = context.read<ProductProvider>();

      // Point 1: Standard items go LIVE directly; 3D items go to Draft/Submitted for photogrammetry
      final created = await productProvider.createProduct(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        pricePaise: pricePaise,
        category: _category,
        vegStatus: _vegStatus,
        isSpicy: _isSpicy,
        isBestseller: _isBestseller,
        isNew: _isNew,
        enable3dAr: _enable3dAr,
        status: _enable3dAr ? ProductStatus.draft : ProductStatus.live,
      );

      if (_enable3dAr) {
        // Upload 4 photos for 3D reconstruction
        if (_pendingPhotos.isNotEmpty) {
          for (final entry in _pendingPhotos.entries) {
            try {
              await productProvider.uploadPhoto(
                productId: created.id,
                bytes: entry.value,
                filename: '${entry.key.name}.jpg',
                angleType: entry.key,
              );
            } catch (e) {
              debugPrint('Failed to upload photo for ${entry.key}: $e');
            }
          }
        }

        if (mounted) {
          final count = _pendingPhotos.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count >= 4
                    ? 'Hero 3D product created — submitted for AR processing!'
                    : count > 0
                        ? 'Product created with $count photo(s) — upload remaining on next screen.'
                        : 'Product created — add 4 photos or upload .glb 3D model',
              ),
              backgroundColor: count >= 4 ? AppColors.success : null,
            ),
          );
          context.go(AppRoutes.productDetail(created.id));
        }
      } else {
        // Standard item: upload optional single photo if provided
        if (_singlePhotoBytes != null) {
          try {
            await productProvider.uploadPhoto(
              productId: created.id,
              bytes: _singlePhotoBytes!,
              filename: _singlePhotoFilename ?? 'display_photo.jpg',
              angleType: PhotoAngleType.front,
            );
          } catch (e) {
            debugPrint('Failed to upload single photo: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Dish created and is now LIVE on your customer menu!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.products);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final businessType =
        context.watch<BusinessProvider>().business?.businessType ??
            BusinessType.restaurant;
    final categories = ProductCategory.forBusinessType(businessType);

    final businessProvider = context.watch<BusinessProvider>();
    final isDeactivated = businessProvider.isDeactivated || businessProvider.isSuspended;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add product'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            icon: const Icon(Icons.playlist_add, size: 20),
            label: const Text('Bulk Import', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: isDeactivated
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Business is deactivated. Reactivate to import dishes.')),
                    );
                  }
                : () => BulkImportDialog.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryOrange.withValues(alpha: 0.12),
                        Colors.amber.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.primaryOrange, size: 26),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Have a full menu with 20+ dishes?',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Use Bulk Menu Import to add all items at once via Excel/CSV or paste your paper menu card text.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                          foregroundColor: AppColors.primaryOrange,
                        ),
                        onPressed: isDeactivated
                            ? null
                            : () => BulkImportDialog.show(context),
                        child: const Text('Bulk Import', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                if (isDeactivated)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_outline, color: AppColors.error),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Restaurant Operations Paused: Adding new dishes is locked. Please reactivate your business from Account Settings to resume.',
                            style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Product details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add dish details below. Standard items go live immediately without waiting for 3D processing.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ==========================================
                // Point 1: Smart AR Priority Switch Card
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _enable3dAr
                        ? AppColors.primaryOrange.withValues(alpha: 0.1)
                        : (isDark ? const Color(0xFF252837) : const Color(0xFFF4F5F7)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _enable3dAr
                          ? AppColors.primaryOrange
                          : (isDark ? Colors.white12 : Colors.black12),
                      width: _enable3dAr ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _enable3dAr ? Icons.auto_awesome : Icons.restaurant,
                            color: _enable3dAr
                                ? AppColors.primaryOrange
                                : (isDark ? Colors.white70 : Colors.black87),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _enable3dAr
                                      ? 'Hero / Signature Dish (Interactive 3D AR)'
                                      : 'Standard Menu Item (Fast Listing)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _enable3dAr
                                      ? 'Requires 4 angle photos for 3D model generation.'
                                      : 'Instant Live! No 4-photo requirement.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enable3dAr,
                            activeThumbColor: AppColors.primaryOrange,
                            activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                            onChanged: (val) {
                              setState(() => _enable3dAr = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _enable3dAr
                              ? AppColors.primaryOrange.withValues(alpha: 0.12)
                              : (isDark ? Colors.black26 : Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _enable3dAr ? Icons.info_outline : Icons.check_circle_outline,
                              size: 15,
                              color: _enable3dAr ? AppColors.primaryOrange : const Color(0xFF20BF6B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _enable3dAr
                                    ? 'Tag this as a signature dish. Customers can view it in 3D AR.'
                                    : '80% of items (roti, rice, regular drinks) don\'t need 3D models and go live instantly.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _enable3dAr
                                      ? AppColors.primaryOrange
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _nameController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(100),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Product name *',
                    hintText: 'Margherita Pizza / Butter Chicken',
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Product name is required';
                    if (v.trim().length < 2) return 'Product name must be at least 2 characters';
                    if (v.trim().length > 100) return 'Product name cannot exceed 100 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(500),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Fresh ingredients, herbs, and seasonings',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Price (₹) *',
                    hintText: '299',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Price is required';
                    }
                    final price = double.tryParse(v.trim());
                    if (price == null || price <= 0) {
                      return 'Enter a valid price greater than 0';
                    }
                    if (price > 100000) {
                      return 'Price cannot exceed ₹1,00,000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProductCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<VegStatus>(
                  initialValue: _vegStatus,
                  decoration: const InputDecoration(
                    labelText: 'Veg / Non-veg',
                    prefixIcon: Icon(Icons.eco_outlined),
                  ),
                  items: VegStatus.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _vegStatus = v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Spicy'),
                  value: _isSpicy,
                  activeThumbColor: AppColors.primaryOrange,
                  activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _isSpicy = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bestseller'),
                  value: _isBestseller,
                  activeThumbColor: AppColors.primaryOrange,
                  activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _isBestseller = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as new'),
                  value: _isNew,
                  activeThumbColor: AppColors.primaryOrange,
                  activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _isNew = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),

                // ==========================================
                // Media Section: 4-Angle (Hero AR) vs Single Photo (Standard)
                // ==========================================
                if (_enable3dAr) ...[
                  // 4-Photo Upload Section (File, Drag&Drop, Paste)
                  FourPhotoUploader(
                    title: 'Upload 4 Photos (Front, Top, Left, Right)',
                    subtitle:
                        'Choose from file, copy-paste (Ctrl+V), or drag & drop all 4 angles. Photos will be used to generate the 3D model.',
                    localPhotoBytes: _pendingPhotos,
                    onPhotoSelected: (angle, bytes, filename) async {
                      setState(() {
                        _pendingPhotos[angle] = bytes;
                      });
                    },
                    onPhotoRemoved: (angle) {
                      setState(() {
                        _pendingPhotos.remove(angle);
                      });
                    },
                  ),
                ] else ...[
                  // Standard Dish: Single Photo (Optional)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Display Photo (Optional)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add a single photo for your digital menu card. You can also skip this and add it later.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : AppColors.mediumGray,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_singlePhotoBytes != null)
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                            image: DecorationImage(
                              image: MemoryImage(_singlePhotoBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                                onPressed: _pickSinglePhoto,
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                                ),
                                icon: const Icon(Icons.delete, size: 18, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _singlePhotoBytes = null;
                                    _singlePhotoFilename = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: _pickSinglePhoto,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 130,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252837) : const Color(0xFFF9F9FA),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 36,
                                  color: AppColors.primaryOrange,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap to select a display photo',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'JPG, PNG under 10MB',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: isDeactivated
                      ? 'Business Deactivated (Locked)'
                      : _isSubmitting
                          ? 'Saving product...'
                          : _enable3dAr
                              ? 'Save Hero 3D Dish'
                              : 'Save & Publish Live',
                  icon: _enable3dAr ? Icons.auto_awesome : Icons.check_circle_outline,
                  isLoading: _isSubmitting,
                  onPressed: isDeactivated ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
