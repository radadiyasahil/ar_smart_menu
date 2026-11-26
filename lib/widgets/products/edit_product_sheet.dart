import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../common/primary_button.dart';
import '../../core/utils/top_toast.dart';

/// Bottom sheet to edit details, photos, and 3D (.glb) models on dishes.
Future<void> showEditProductSheet(
  BuildContext context, {
  required ProductModel product,
  required ValueChanged<ProductModel> onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _EditProductSheet(
      product: product,
      onSaved: onSaved,
    ),
  );
}

class _EditProductSheet extends StatefulWidget {
  const _EditProductSheet({
    required this.product,
    required this.onSaved,
  });

  final ProductModel product;
  final ValueChanged<ProductModel> onSaved;

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  late ProductModel _product;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  ProductCategory? _category;
  bool _saving = false;
  bool _isMediaBusy = false;
  int _activeTab = 0; // 0: Details, 1: Photos & 3D Model
  late bool _isCustomizable;
  late bool _allowSpiceLevel;
  late bool _allowDietary;
  late List<ProductCustomAddon> _addons;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _nameController = TextEditingController(text: _product.name);
    _descriptionController =
        TextEditingController(text: _product.description ?? '');
    _priceController = TextEditingController(
      text: _product.pricePaise != null
          ? (_product.pricePaise! / 100).toStringAsFixed(
              _product.pricePaise! % 100 == 0 ? 0 : 2,
            )
          : '',
    );
    _category = _product.category;

    final cfg = _product.customizationConfig;
    _isCustomizable = cfg.isCustomizable;
    _allowSpiceLevel = cfg.allowSpiceLevel;
    _allowDietary = cfg.allowDietary;
    _addons = List<ProductCustomAddon>.from(cfg.addons);
  }

  void _showAddAddonDialog() {
    final nameCtl = TextEditingController();
    final priceCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Add-on', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Add-on Name *',
                hintText: 'e.g. Extra Cheese 🧀, Extra Mayo, Ice Cream Scoop',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (₹) *',
                prefixText: '₹ ',
                hintText: 'e.g. 30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtl.text.trim();
              final p = int.tryParse(priceCtl.text.trim());
              if (n.isNotEmpty && p != null && p >= 0) {
                setState(() {
                  _addons.add(ProductCustomAddon(
                    id: 'addon_${DateTime.now().millisecondsSinceEpoch}',
                    name: n,
                    price: p,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    final businessProvider = context.read<BusinessProvider>();
    if (businessProvider.isDeactivated || businessProvider.isSuspended) {
      TopToast.warning(context, 'Restaurant is deactivated. Reactivate to edit dishes.');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 2) {
      TopToast.warning(context, 'Product name must be at least 2 characters');
      return;
    }

    int? pricePaise;
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      final parsed = double.tryParse(priceText);
      if (parsed == null || parsed <= 0) {
        TopToast.warning(context, 'Enter a valid price greater than 0');
        return;
      }
      if (parsed > 100000) {
        TopToast.warning(context, 'Price cannot exceed ₹1,00,000');
        return;
      }
      pricePaise = (parsed * 100).round();
    }

    setState(() => _saving = true);
    try {
      final config = ProductCustomizationConfig(
        isCustomizable: _isCustomizable,
        allowSpiceLevel: _allowSpiceLevel,
        allowDietary: _allowDietary,
        addons: _addons,
      );
      final customizationJson = config.toJsonString();

      final updated = await context.read<ProductProvider>().updateProduct(
            id: _product.id,
            name: name,
            description: _descriptionController.text.trim(),
            pricePaise: pricePaise,
            category: _category,
            customizationJson: customizationJson,
          );
      if (mounted) {
        _product = updated;
        widget.onSaved(updated);
        Navigator.pop(context);
        TopToast.success(context, 'Product updated successfully');
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAnglePhoto(PhotoAngleType angle) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isMediaBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final res = await context.read<ProductProvider>().uploadPhoto(
            productId: _product.id,
            bytes: bytes,
            filename: file.name,
            angleType: angle,
          );
      if (mounted) {
        if (res.product != null) {
          setState(() => _product = res.product!);
          widget.onSaved(_product);
        }
        TopToast.success(context, '${angle.label} photo updated');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, formatApiError(e));
    } finally {
      if (mounted) setState(() => _isMediaBusy = false);
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text(
          'Are you sure you want to delete this photo from the dish?',
        ),
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
    if (confirmed != true) return;

    setState(() => _isMediaBusy = true);
    try {
      final updated = await context.read<ProductProvider>().deletePhoto(
            productId: _product.id,
            photoId: photoId,
          );
      if (mounted) {
        setState(() => _product = updated);
        widget.onSaved(updated);
        TopToast.success(context, 'Photo deleted');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, formatApiError(e));
    } finally {
      if (mounted) setState(() => _isMediaBusy = false);
    }
  }

  Future<void> _pickAndUploadGlb() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['glb'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) TopToast.error(context, 'Could not read GLB file');
        return;
      }

      setState(() => _isMediaBusy = true);
      final updated = await context.read<ProductProvider>().uploadModel(
            productId: _product.id,
            bytes: bytes,
            filename: file.name.isNotEmpty ? file.name : 'model.glb',
          );
      if (mounted) {
        setState(() => _product = updated);
        widget.onSaved(updated);
        TopToast.success(context, '3D Model (.glb) uploaded! Product is now Live in AR.');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, formatApiError(e));
    } finally {
      if (mounted) setState(() => _isMediaBusy = false);
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete 3D Model?'),
        content: const Text(
          'Are you sure you want to delete the 3D model (.glb)? AR view will be disabled until a new model is uploaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete 3D Model'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isMediaBusy = true);
    try {
      final updated = await context.read<ProductProvider>().deleteModel(_product.id);
      if (mounted) {
        setState(() => _product = updated);
        widget.onSaved(updated);
        TopToast.success(context, '3D model deleted');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, formatApiError(e));
    } finally {
      if (mounted) setState(() => _isMediaBusy = false);
    }
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'webm'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      if (bytes.length > 35 * 1024 * 1024) {
        if (mounted) TopToast.error(context, 'Video must be under 35MB');
        return;
      }

      setState(() => _isMediaBusy = true);
      final updated = await context.read<ProductProvider>().uploadVideo(
            productId: _product.id,
            bytes: bytes,
            filename: file.name.isNotEmpty ? file.name : 'video.mp4',
          );
      if (mounted) {
        setState(() => _product = updated);
        widget.onSaved(updated);
        TopToast.success(context, 'Walkaround video uploaded!');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, formatApiError(e));
    } finally {
      if (mounted) setState(() => _isMediaBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessType =
        context.read<BusinessProvider>().business?.businessType ??
            BusinessType.restaurant;
    final categories = ProductCategory.forBusinessType(businessType);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit "${_product.name}"',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 0
                                  ? AppColors.primaryOrange
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 16,
                                  color: _activeTab == 0 ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Details & Price',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _activeTab == 0 ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _activeTab == 1
                                  ? AppColors.primaryOrange
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 16,
                                  color: _activeTab == 1 ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Photos & 3D Model',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _activeTab == 1 ? Colors.white : Colors.grey,
                                  ),
                                ),
                                if (_product.model3d?.glbUrl != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 1 ? Colors.white24 : AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '3D',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: _activeTab == 1 ? Colors.white : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.md,
                bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
              ),
              child: _activeTab == 0
                  ? _buildDetailsTab(categories)
                  : _buildPhotosAnd3dTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(List<ProductCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Name *', counterText: ''),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Description', counterText: ''),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Price (₹) *',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<ProductCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: categories
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _category = value;
              if (value == ProductCategory.beverage ||
                  value == ProductCategory.dessert ||
                  value == ProductCategory.cake ||
                  value == ProductCategory.pastry ||
                  value == ProductCategory.mithai) {
                _allowSpiceLevel = false;
                _allowDietary = false;
              }
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        // Customization settings Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tune, size: 18, color: AppColors.primaryOrange),
                      SizedBox(width: 8),
                      Text(
                        'Dish Customization',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isCustomizable,
                    activeThumbColor: AppColors.primaryOrange,
                    onChanged: (val) => setState(() => _isCustomizable = val),
                  ),
                ],
              ),
              Text(
                _isCustomizable
                    ? 'Customers can customize spice, dietary preference, or add-ons.'
                    : 'Non-customizable item. Customers add directly to cart with 1-click.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              if (_isCustomizable) ...[
                const Divider(height: 20),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Spice Level (Mild / Medium / Spicy)', style: TextStyle(fontSize: 12.5)),
                  value: _allowSpiceLevel,
                  activeColor: AppColors.primaryOrange,
                  onChanged: (val) => setState(() => _allowSpiceLevel = val ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Dietary Option (Regular / Jain / Vegan)', style: TextStyle(fontSize: 12.5)),
                  value: _allowDietary,
                  activeColor: AppColors.primaryOrange,
                  onChanged: (val) => setState(() => _allowDietary = val ?? false),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Custom Add-ons (${_addons.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _showAddAddonDialog,
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add Add-on', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                if (_addons.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'No custom add-ons added. Tap "+ Add Add-on" to create options (e.g., Extra Cheese ₹40, Ice Cream Scoop ₹35).',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade400),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _addons.map((addon) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text('${addon.name} (+₹${addon.price})', style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _addons.removeWhere((a) => a.id == addon.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Save details',
          isLoading: _saving,
          onPressed: _saving ? null : _saveDetails,
        ),
      ],
    );
  }

  Widget _buildPhotosAnd3dTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isMediaBusy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(color: AppColors.primaryOrange),
          ),
        // Photos section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Product Photos (Angles)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_product.photos.length}/4 Photos',
              style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap any angle to update, replace, or remove a photo directly.',
          style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.1,
          children: PhotoAngleType.requiredForSubmit.map((angle) {
            final photo = _product.photoForAngle(angle);
            return _buildPhotoSlot(angle, photo);
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 3D Model (.glb) Raw Asset Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _product.model3d?.glbUrl != null
                  ? AppColors.success.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.view_in_ar, size: 20, color: AppColors.primaryOrange),
                      SizedBox(width: 8),
                      Text(
                        '3D Model (.glb Raw File)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_product.model3d?.glbUrl != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Active in AR',
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No 3D Model',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _product.model3d?.glbUrl != null
                    ? 'Raw GLB model is active on diner menus. You can replace it with an updated .glb scan or remove it.'
                    : 'Upload a ready .glb 3D scan directly to make this dish immediately interactive in AR.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.mediumGray),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_product.model3d?.glbUrl != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Replace .glb'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(color: AppColors.primaryOrange),
                        ),
                        onPressed: _isMediaBusy ? null : _pickAndUploadGlb,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete 3D Model'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                        onPressed: _isMediaBusy ? null : _deleteModel,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload .glb 3D File'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: _isMediaBusy ? null : _pickAndUploadGlb,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Walkaround Video Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Walkaround Video',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Upload a 10s video for AI 3D reconstruction (<35MB).',
                      style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.videocam_outlined, size: 16),
                label: const Text('Upload Video'),
                onPressed: _isMediaBusy ? null : _pickAndUploadVideo,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildPhotoSlot(PhotoAngleType angle, ProductPhotoModel? photo) {
    final hasPhoto = photo != null;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: hasPhoto ? AppColors.success.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            Image.network(
              photo.photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    angle.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Text('No photo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          // Angle label badge at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                angle.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Actions on top
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhoto)
                  GestureDetector(
                    onTap: _isMediaBusy ? null : () => _deletePhoto(photo.id),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                    ),
                  ),
                GestureDetector(
                  onTap: _isMediaBusy ? null : () => _uploadAnglePhoto(angle),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: hasPhoto ? AppColors.primaryOrange : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPhoto ? Icons.edit : Icons.add,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
