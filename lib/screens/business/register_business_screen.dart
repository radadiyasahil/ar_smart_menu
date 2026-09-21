import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/business_model.dart';
import '../../providers/business_provider.dart';
import '../../widgets/common/primary_button.dart';

/// Register a new business — sends approval request to admin.
class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({super.key});

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _gstController = TextEditingController();

  BusinessType _businessType = BusinessType.restaurant;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _fssaiController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<BusinessProvider>().registerBusiness(
            businessName: _nameController.text.trim(),
            businessType: _businessType,
            city: _cityController.text.trim(),
            fullAddress: _addressController.text.trim(),
            fssaiNumber: _fssaiController.text.trim(),
            gstNumber: _gstController.text.trim(),
          );
      if (mounted) context.go(AppRoutes.businessStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register your business'),
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
                  'Tell us about your business',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Your request will be sent to admin for approval. '
                  'You can complete KYC while waiting.',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Business name *',
                    hintText: 'Spice Garden Restaurant',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<BusinessType>(
                  value: _businessType,
                  decoration: const InputDecoration(
                    labelText: 'Business type *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: BusinessType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _businessType = v);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    hintText: 'Mumbai',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Full address *',
                    hintText: 'Shop 12, Main Road, Area, PIN',
                    prefixIcon: Icon(Icons.place_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _fssaiController,
                  decoration: const InputDecoration(
                    labelText: 'FSSAI number (optional)',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _gstController,
                  decoration: const InputDecoration(
                    labelText: 'GST number (optional)',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Submit for approval',
                  icon: Icons.send_outlined,
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
