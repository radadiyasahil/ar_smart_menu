import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(100),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Business name *',
                    hintText: 'Spice Garden Restaurant',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Business name is required';
                    if (v.trim().length < 3) return 'Name must be at least 3 characters';
                    if (v.trim().length > 100) return 'Name cannot exceed 100 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<BusinessType>(
                  initialValue: _businessType,
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
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    hintText: 'Mumbai',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'City is required';
                    if (v.trim().length < 2) return 'City must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(250),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Full address *',
                    hintText: 'Shop 12, Main Road, Area, PIN',
                    prefixIcon: Icon(Icons.place_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Full address is required';
                    if (v.trim().length < 5) return 'Address must be at least 5 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _fssaiController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'FSSAI number (optional, 14 digits)',
                    hintText: '14-digit numeric license',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (v.trim().length != 14 || !RegExp(r'^\d{14}$').hasMatch(v.trim())) {
                      return 'FSSAI license must be exactly 14 numeric digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _gstController,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(15),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'GST number (optional, 15 characters)',
                    hintText: '22AAAAA0000A1Z5',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final trimmed = v.trim().toUpperCase();
                    if (trimmed.length != 15) {
                      return 'GSTIN must be exactly 15 characters';
                    }
                    if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$').hasMatch(trimmed)) {
                      return 'Enter a valid 15-character GSTIN format';
                    }
                    return null;
                  },
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
