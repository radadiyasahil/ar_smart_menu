import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Bottom sheet to edit name, price, description on live (or any) products.
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
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  ProductCategory? _category;
  bool _saving = false;
  late bool _isCustomizable;
  late bool _allowSpiceLevel;
  late bool _allowDietary;
  late List<ProductCustomAddon> _addons;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController =
        TextEditingController(text: widget.product.description ?? '');
    _priceController = TextEditingController(
      text: widget.product.pricePaise != null
          ? (widget.product.pricePaise! / 100).toStringAsFixed(
              widget.product.pricePaise! % 100 == 0 ? 0 : 2,
            )
          : '',
    );
    _category = widget.product.category;

    final cfg = widget.product.customizationConfig;
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

  Future<void> _save() async {
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
            id: widget.product.id,
            name: name,
            description: _descriptionController.text.trim(),
            pricePaise: pricePaise,
            category: _category,
            customizationJson: customizationJson,
          );
      if (mounted) {
        widget.onSaved(updated);
        Navigator.pop(context);
        TopToast.success(context, 'Product updated');
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit product details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
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
            label: 'Save changes',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    ),
  );
  }
}
