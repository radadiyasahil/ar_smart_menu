import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../models/business_model.dart';
import '../../models/product_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../common/primary_button.dart';

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    int? pricePaise;
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      final parsed = double.tryParse(priceText);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price')),
        );
        return;
      }
      pricePaise = (parsed * 100).round();
    }

    setState(() => _saving = true);
    try {
      final updated = await context.read<ProductProvider>().updateProduct(
            id: widget.product.id,
            name: name,
            description: _descriptionController.text.trim(),
            pricePaise: pricePaise,
            category: _category,
          );
      if (mounted) {
        widget.onSaved(updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
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

    return Padding(
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
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (₹)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<ProductCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Save changes',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
