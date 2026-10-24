import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

/// Create product — POST /api/products.
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

  final Map<PhotoAngleType, Uint8List> _pendingPhotos = {};

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
      final created = await productProvider.createProduct(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            pricePaise: pricePaise,
            category: _category,
            vegStatus: _vegStatus,
            isSpicy: _isSpicy,
            isBestseller: _isBestseller,
            isNew: _isNew,
          );

      // Upload any photos attached during product creation
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
                  ? 'Product created with all 4 photos — submitted for AR processing!'
                  : count > 0
                      ? 'Product created with $count photo(s) — upload remaining on next screen.'
                      : 'Product created — add photos, short video, or .glb 3D model',
            ),
            backgroundColor: count >= 4 ? AppColors.success : null,
          ),
        );
        context.go(AppRoutes.productDetail(created.id));
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
    final businessType =
        context.watch<BusinessProvider>().business?.businessType ??
            BusinessType.restaurant;
    final categories = ProductCategory.forBusinessType(businessType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add product'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product details',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Add details below and attach the 4 AR photos via drag & drop, paste, or file selection.',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product name *',
                    hintText: 'Butter Chicken',
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Creamy tomato gravy with tender chicken',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price (₹)',
                    hintText: '299',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProductCategory>(
                  value: _category,
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
                  value: _vegStatus,
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
                  onChanged: (v) => setState(() => _isSpicy = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bestseller'),
                  value: _isBestseller,
                  onChanged: (v) => setState(() => _isBestseller = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as new'),
                  value: _isNew,
                  onChanged: (v) => setState(() => _isNew = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),

                // 4-Photo Upload Section (File, Drag&Drop, Paste)
                FourPhotoUploader(
                  title: 'Upload 4 Photos (Front, Top, Left, Right)',
                  subtitle:
                      'Choose from file, copy-paste (Ctrl+V), or drag & drop all 4 angles. Photos will be saved with this product.',
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

                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isSubmitting ? 'Saving product...' : 'Save product',
                  icon: Icons.check,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
