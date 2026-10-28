import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/api_config.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/owner_navigation.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/gradient_card.dart';
import '../../widgets/common/primary_button.dart';

/// Mobile number login — dev mode skips OTP screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final auth = context.read<AuthProvider>();

      if (ApiConfig.devSkipOtp) {
        await auth.loginWithMobile(phone);
        if (mounted) await navigateOwnerAfterAuth(context);
      } else {
        final otpId = await auth.sendOtp(phone);
        if (mounted) {
          context.go('${AppRoutes.otp}?phone=$phone&otpId=$otpId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Hero card
                GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.storefront,
                        color: AppColors.white,
                        size: 40,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'app_name'.tr(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Manage products, QR codes & AR menus',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'login_title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'login_subtitle'.tr(),
                  style: const TextStyle(color: AppColors.mediumGray),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Phone input with country code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'mobile_number'.tr(),
                          hintText: '9876543210',
                          prefixIcon: const Icon(Icons.phone_android),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your mobile number';
                          }
                          final trimmed = value.trim();
                          if (trimmed.length != 10) {
                            return 'Mobile number must be exactly 10 digits';
                          }
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
                            return 'Enter a valid 10-digit mobile number (starts with 6-9)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                if (ApiConfig.devSkipOtp) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'Dev mode: OTP skipped. Enter mobile and tap Continue.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],

                PrimaryButton(
                  label: ApiConfig.devSkipOtp ? 'Continue' : 'send_otp'.tr(),
                  onPressed: _login,
                  isLoading: _isLoading,
                  icon: ApiConfig.devSkipOtp
                      ? Icons.login
                      : Icons.sms_outlined,
                ),

                const SizedBox(height: AppSpacing.lg),

                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
