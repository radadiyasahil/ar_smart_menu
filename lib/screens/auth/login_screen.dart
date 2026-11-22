import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _showForgotPinModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPinBottomSheet(
        initialMobile: _loginPhoneController.text.trim(),
        onSuccess: (newPhone, newPin) {
          _loginPhoneController.text = newPhone;
          _loginPasswordController.text = newPin;
        },
      ),
    );
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

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showForgotPinModal,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.lock_reset, size: 16, color: AppColors.primaryOrange),
              label: const Text(
                'Forgot PIN?',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

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

class _ForgotPinBottomSheet extends StatefulWidget {
  const _ForgotPinBottomSheet({
    required this.initialMobile,
    required this.onSuccess,
  });

  final String initialMobile;
  final void Function(String mobile, String newPin) onSuccess;

  @override
  State<_ForgotPinBottomSheet> createState() => _ForgotPinBottomSheetState();
}

class _ForgotPinBottomSheetState extends State<_ForgotPinBottomSheet> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  final _otpController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  int _step = 0; // 0 = Phone, 1 = OTP & New PIN
  String? _otpId;
  bool _isSendingOtp = false;
  bool _isResettingPin = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  int _countdownSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialMobile);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() => _countdownSeconds = 0);
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    setState(() => _isSendingOtp = true);

    try {
      final auth = context.read<AuthProvider>();
      final otpId = await auth.sendOtp(phone);

      if (!mounted) return;
      setState(() {
        _otpId = otpId;
        _step = 1;
      });
      _startCountdown();
      TopToast.success(context, 'WhatsApp & SMS OTP sent to +91 $phone');
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _handleResetPin() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin != confirmPin) {
      TopToast.error(context, 'New PIN and Confirm PIN do not match');
      return;
    }

    if (_otpId == null) {
      TopToast.error(context, 'OTP session expired. Please request a new OTP.');
      setState(() => _step = 0);
      return;
    }

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    setState(() => _isResettingPin = true);

    try {
      final auth = context.read<AuthProvider>();
      await auth.resetPin(
        mobile: phone,
        otp: otp,
        otpId: _otpId!,
        newPin: newPin,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess(phone, newPin);
      TopToast.success(context, 'Security PIN reset successfully! Welcome back.');
      await navigateOwnerAfterAuth(context);
    } catch (e) {
      if (mounted) {
        TopToast.error(context, formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _isResettingPin = false);
    }
  }

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse(
      'https://wa.me/919876543210?text=Hi%20AR%20Smart%20Menu%20Support,%20I%20forgot%20my%20owner%20PIN%20and%20need%20assistance.',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        TopToast.show(context, 'Contact Admin Support on WhatsApp: +91 98765 43210');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2029) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and icon header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: AppColors.primaryOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Security PIN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verify via WhatsApp & SMS OTP to set a new PIN',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Step 0: Phone number confirmation & OTP dispatch
              if (_step == 0) ...[
                Form(
                  key: _phoneFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered Mobile Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF262833) : AppColors.lightGray,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: isDark ? Colors.white12 : AppColors.borderGray,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '+91',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: const InputDecoration(
                                hintText: '9876543210',
                                prefixIcon: Icon(Icons.phone_android),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your mobile number';
                                }
                                final trimmed = value.trim();
                                if (trimmed.length != 10) {
                                  return 'Enter exact 10 digits';
                                }
                                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
                                  return 'Enter a valid 10-digit number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF25D366).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_outlined,
                              color: Color(0xFF25D366),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'A 6-digit verification code will be sent immediately via WhatsApp & SMS.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E7E34),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Send WhatsApp & SMS OTP',
                        onPressed: _handleSendOtp,
                        isLoading: _isSendingOtp,
                        icon: Icons.send_rounded,
                      ),
                    ],
                  ),
                ),
              ],

              // Step 1: Enter OTP & Set New PIN
              if (_step == 1) ...[
                Form(
                  key: _resetFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active phone pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mark_chat_read_outlined,
                              color: AppColors.primaryOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Code sent to +91 ${_phoneController.text.trim()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _step = 0),
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  color: AppColors.primaryOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Enter 6-Digit OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 18,
                          letterSpacing: 6,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          hintText: '••••••',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length != 6) {
                            return 'Enter the 6-digit OTP';
                          }
                          return null;
                        },
                      ),

                      // Resend timer row
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_countdownSeconds > 0)
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: isDark ? Colors.white54 : AppColors.mediumGray,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Resend code in ${_countdownSeconds}s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white54 : AppColors.mediumGray,
                                    ),
                                  ),
                                ],
                              )
                            else
                              TextButton(
                                onPressed: _isSendingOtp ? null : _handleSendOtp,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Resend OTP via WhatsApp / SMS',
                                  style: TextStyle(
                                    color: AppColors.primaryOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      Text(
                        'New Security PIN (4-6 digits)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _newPinController,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter new 4-digit PIN',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.mediumGray,
                            ),
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 4) {
                            return 'PIN must be at least 4 digits';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Confirm New PIN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPinController,
                        obscureText: _obscureConfirmPin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Re-enter new 4-digit PIN',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.mediumGray,
                            ),
                            onPressed: () =>
                                setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please confirm your new PIN';
                          }
                          if (v.trim() != _newPinController.text.trim()) {
                            return 'PIN does not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      PrimaryButton(
                        label: 'Verify OTP & Set New PIN',
                        onPressed: _handleResetPin,
                        isLoading: _isResettingPin,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Emergency WhatsApp Admin Support link
              Center(
                child: TextButton.icon(
                  onPressed: _openWhatsAppSupport,
                  icon: const Icon(
                    Icons.support_agent_outlined,
                    size: 16,
                    color: AppColors.mediumGray,
                  ),
                  label: const Text(
                    "Didn't receive code? WhatsApp Admin Support",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                      decoration: TextDecoration.underline,
                    ),
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
