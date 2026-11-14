import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../core/utils/owner_navigation.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/gradient_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../core/utils/top_toast.dart';

/// Restaurant Owner Login & Registration screen.
/// Uses Mobile Number + Password / PIN without OTP.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  // Register controllers
  final _registerNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerObscurePassword = true;
  bool _registerObscureConfirm = true;

  bool _isRegisterMode = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _loginPhoneController.text.trim();
      final password = _loginPasswordController.text.trim();
      final auth = context.read<AuthProvider>();

      await auth.loginWithPassword(mobile: phone, password: password);
      if (mounted) {
        await navigateOwnerAfterAuth(context);
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _registerPhoneController.text.trim();
      final password = _registerPasswordController.text.trim();
      final name = _registerNameController.text.trim();
      final auth = context.read<AuthProvider>();

      await auth.registerWithPassword(
        mobile: phone,
        password: password,
        fullName: name.isNotEmpty ? name : null,
      );
      if (mounted) {
        await navigateOwnerAfterAuth(context);
      }
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCountryCodePrefix() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isRegisterMode) {
                  setState(() => _isRegisterMode = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isRegisterMode ? AppColors.primaryOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: !_isRegisterMode
                      ? [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: !_isRegisterMode ? AppColors.white : AppColors.darkGray,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isRegisterMode) {
                  setState(() => _isRegisterMode = true);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isRegisterMode ? AppColors.primaryOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: _isRegisterMode
                      ? [
                          BoxShadow(
                            color: AppColors.primaryOrange.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Register (New)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isRegisterMode ? AppColors.white : AppColors.darkGray,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'login_title'.tr(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Enter your mobile number and password / PIN to sign in.',
            style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Phone input with +91 prefix
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCountryCodePrefix(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _loginPhoneController,
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
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Password / PIN field
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _loginObscurePassword,
            decoration: InputDecoration(
              labelText: 'Password / PIN',
              hintText: 'Enter your password or 4-digit PIN',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.mediumGray,
                ),
                onPressed: () {
                  setState(() => _loginObscurePassword = !_loginObscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your password or PIN';
              }
              if (value.trim().length < 4) {
                return 'Password/PIN must be at least 4 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Sign In',
            onPressed: _handleLogin,
            isLoading: _isLoading,
            icon: Icons.login,
          ),

          const SizedBox(height: AppSpacing.md),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _isRegisterMode = true);
              },
              child: const Text.rich(
                TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: AppColors.mediumGray),
                  children: [
                    TextSpan(
                      text: 'Register here',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Restaurant Account',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Register with your mobile number and set your password or PIN.',
            style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Owner Name
          TextFormField(
            controller: _registerNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name / Owner Name',
              hintText: 'e.g. Rahul Sharma',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty && value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // Phone input with +91 prefix
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCountryCodePrefix(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _registerPhoneController,
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
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Create Password / PIN field
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _registerObscurePassword,
            decoration: InputDecoration(
              labelText: 'Create Password / PIN',
              hintText: 'At least 4 characters or 4-digit PIN',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerObscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.mediumGray,
                ),
                onPressed: () {
                  setState(() => _registerObscurePassword = !_registerObscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please set a password or PIN';
              }
              if (value.trim().length < 4) {
                return 'Password/PIN must be at least 4 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // Confirm Password / PIN field
          TextFormField(
            controller: _registerConfirmPasswordController,
            obscureText: _registerObscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password / PIN',
              hintText: 'Re-enter your password or PIN',
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerObscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.mediumGray,
                ),
                onPressed: () {
                  setState(() => _registerObscureConfirm = !_registerObscureConfirm);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password or PIN';
              }
              if (value.trim() != _registerPasswordController.text.trim()) {
                return 'Passwords / PINs do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Register & Continue',
            onPressed: _handleRegister,
            isLoading: _isLoading,
            icon: Icons.person_add_alt_1,
          ),

          const SizedBox(height: AppSpacing.md),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() => _isRegisterMode = false);
              },
              child: const Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: AppColors.mediumGray),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

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
                      'Manage products, live tables, orders & billing',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Mode toggle (Sign In vs Register)
              _buildModeToggle(),

              const SizedBox(height: AppSpacing.xl),

              // Selected form
              _isRegisterMode ? _buildRegisterForm() : _buildLoginForm(),

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
    );
  }
}
