import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/business_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/primary_button.dart';

enum _AccountView { profile, settings, editProfile }
enum _ProfileTab { overview, business, kyc }

/// Modern, sleek Account screen inspired by high-end dark mobile UI
/// featuring My Profile view, Settings view, and full Edit Profile capabilities.
/// Completely non-scrollable to prevent unwanted up/down page movement.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  _AccountView _currentView = _AccountView.profile;
  _AccountView _previousView = _AccountView.profile;
  _ProfileTab _selectedTab = _ProfileTab.overview;

  // Edit Profile form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _upiController = TextEditingController();
  final _fssaiController = TextEditingController();
  final _gstController = TextEditingController();

  // KYC & Bank controllers
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _isSaving = false;
  bool _kycLoading = false;
  bool _bankLoading = false;
  bool _notificationsPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    final businessProvider = context.read<BusinessProvider>();
    await businessProvider.loadFullBusinessDetails();

    final user = businessProvider.user;
    final business = businessProvider.business;
    final prefs = await SharedPreferences.getInstance();

    if (user != null) {
      _nameController.text = user.fullName ?? '';
      _phoneController.text = user.whatsAppNumber ?? user.mobileNumber;
    }
    if (business != null) {
      _businessNameController.text = business.businessName;
      _cityController.text = business.city;
      _addressController.text = business.fullAddress;
      _upiController.text = business.upiId ?? '';
      _fssaiController.text = business.fssaiNumber ?? '';
      _gstController.text = business.gstNumber ?? '';
      _accountController.text = business.bankAccountNumber ?? '';
      _ifscController.text = business.bankIfsc ?? '';
    }

    _emailController.text = prefs.getString('profile_email') ?? 'owner@${business?.city.toLowerCase() ?? "restaurant"}.com';
    final savedUsername = prefs.getString('profile_username');
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
    } else if (business != null) {
      _usernameController.text = '@${business.businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase()}';
    } else {
      _usernameController.text = '@restaurant_owner';
    }

    _notificationsPaused = prefs.getBool('notifications_paused') ?? false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _businessNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _upiController.dispose();
    _fssaiController.dispose();
    _gstController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _toggleBusinessActive(dynamic business) async {
    final businessProvider = context.read<BusinessProvider>();
    final isCurrentlyActive = business.status == BusinessStatus.active;

    if (isCurrentlyActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate Business?'),
          content: const Text(
            'Your restaurant and table QR menus will be temporarily paused for diners.\n\nAll your dishes, 3D models, bills, and settings are preserved.\n\nYou can reactivate anytime with 1 click.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deactivate Business'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      try {
        await businessProvider.setBusinessStatus(BusinessStatus.deactivated, reason: 'Owner paused application use');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Business deactivated. Diners cannot view active menu.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else {
      try {
        await businessProvider.setBusinessStatus(BusinessStatus.active);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Business reactivated! You are now live for diners.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final businessName = _businessNameController.text.trim();
    final city = _cityController.text.trim();
    final fullAddress = _addressController.text.trim();
    final upiId = _upiController.text.trim();
    final fssaiNumber = _fssaiController.text.trim();
    final gstNumber = _gstController.text.trim().toUpperCase();

    if (fullName.isEmpty || fullName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid full name (at least 2 characters)'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (phone.isEmpty || phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number (starts with 6-9)'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (email.isNotEmpty && !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (businessName.isEmpty || businessName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant name must be at least 3 characters'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (city.isEmpty || city.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('City must be at least 2 characters'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (fullAddress.isEmpty || fullAddress.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address must be at least 5 characters'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (upiId.isNotEmpty && !RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$').hasMatch(upiId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID (e.g. restaurant@upi)'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (fssaiNumber.isNotEmpty && (fssaiNumber.length != 14 || !RegExp(r'^\d{14}$').hasMatch(fssaiNumber))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FSSAI license must be exactly 14 numeric digits'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (gstNumber.isNotEmpty && gstNumber.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GSTIN must be exactly 15 characters'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final businessProvider = context.read<BusinessProvider>();
      await businessProvider.updateProfile(
        fullName: fullName,
        whatsAppNumber: phone,
        businessName: businessName,
        city: city,
        fullAddress: fullAddress,
        upiId: upiId,
        fssaiNumber: fssaiNumber,
        gstNumber: gstNumber,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_email', _emailController.text.trim());
      await prefs.setString('profile_username', _usernameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _currentView = _previousView;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitKyc() async {
    final name = _nameController.text.trim();
    final aadhaar = _aadhaarController.text.trim();
    final pan = _panController.text.trim().toUpperCase();

    if (name.isEmpty || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name as on identity documents'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (aadhaar.length != 4 || !RegExp(r'^\d{4}$').hasMatch(aadhaar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aadhaar Last 4 must be exactly 4 numeric digits'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (pan.length != 10 || !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-character PAN number (e.g. ABCDE1234F)'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _kycLoading = true);
    try {
      await context.read<BusinessProvider>().submitKyc(
            fullName: name,
            aadhaarLast4: aadhaar,
            panNumber: pan,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC details submitted for review'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _kycLoading = false);
    }
  }

  Future<void> _verifyBank() async {
    final account = _accountController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();

    if (account.length < 9 || account.length > 18 || !RegExp(r'^\d{9,18}$').hasMatch(account)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account number must be between 9 and 18 numeric digits'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (ifsc.length != 11 || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 11-character IFSC code (e.g. SBIN0001234)'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _bankLoading = true);
    try {
      final ok = await context.read<BusinessProvider>().verifyBank(
            accountNumber: _accountController.text.trim(),
            ifsc: _ifscController.text.trim().toUpperCase(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Bank account verified successfully' : 'Bank verification failed'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _bankLoading = false);
    }
  }

  Future<void> _logout() async {
    context.read<BusinessProvider>().clear();
    context.read<ProductProvider>().clear();
    await context.read<AuthProvider>().clearSession();
    if (mounted) context.go(AppRoutes.login);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your owner account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  String _kycLabel(int status) {
    switch (status) {
      case 0:
        return 'Pending';
      case 1:
        return 'Submitted';
      case 2:
        return 'Verified';
      case 3:
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentView == _AccountView.profile,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            _currentView = _previousView;
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101012) : const Color(0xFFF7F7F9),
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            physics: const NeverScrollableScrollPhysics(),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (_currentView) {
                    _AccountView.profile => _buildMyProfileView(context, isDark),
                    _AccountView.settings => _buildSettingsView(context, isDark),
                    _AccountView.editProfile => _buildEditProfileView(context, isDark),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 1: "My profile" (Fixed, non-scrolling)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMyProfileView(BuildContext context, bool isDark) {
    final business = context.watch<BusinessProvider>().business;
    final user = context.watch<BusinessProvider>().user ?? context.watch<AuthProvider>().user;

    final displayName = user?.fullName != null && user!.fullName!.isNotEmpty
        ? user.fullName!
        : (business?.businessName ?? 'Restaurant Owner');
    final usernameTag = _usernameController.text.isNotEmpty
        ? _usernameController.text
        : '@${(business?.businessName ?? "restaurant").replaceAll(" ", "").toLowerCase()}';
    final cityText = business?.city.isNotEmpty == true ? business!.city : 'India';

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;

    return ListView(
      key: const ValueKey('profile_view'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Top Bar: "My profile" on left, counter badge & settings gear on right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              children: [
                // Quick Info / City Counter Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 15, color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        cityText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Settings Gear Icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    tooltip: 'Settings',
                    onPressed: () {
                      setState(() {
                        _previousView = _AccountView.profile;
                        _currentView = _AccountView.settings;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Centered Profile Avatar with Orange Border
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryOrange,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: isDark ? const Color(0xFF2A2A2E) : Colors.orange.shade50,
                  child: const Icon(
                    Icons.restaurant,
                    size: 34,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Name with Verified Checkmark Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    color: AppColors.primaryOrange,
                    size: 18,
                  ),
                ],
              ),

              const SizedBox(height: 2),

              // Subtitle
              Text(
                '$usernameTag • 3D AR Digital Menu',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              // Quick "Edit Profile" pill button
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF26262B) : Colors.orange.shade50,
                  foregroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _previousView = _AccountView.profile;
                    _currentView = _AccountView.editProfile;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Pill Segment Tabs: Overview, Business, KYC & Bank
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPillTab(
              label: 'Overview',
              icon: Icons.dashboard_outlined,
              isSelected: _selectedTab == _ProfileTab.overview,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _ProfileTab.overview),
            ),
            const SizedBox(width: 8),
            _buildPillTab(
              label: 'Business',
              icon: Icons.storefront_outlined,
              isSelected: _selectedTab == _ProfileTab.business,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _ProfileTab.business),
            ),
            const SizedBox(width: 8),
            _buildPillTab(
              label: 'KYC & Bank',
              icon: Icons.verified_user_outlined,
              isSelected: _selectedTab == _ProfileTab.kyc,
              isDark: isDark,
              onTap: () => setState(() => _selectedTab = _ProfileTab.kyc),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Tab Content Cards
        if (_selectedTab == _ProfileTab.overview) ...[
          // Restaurant Showcase Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                      child: const Icon(Icons.store, color: AppColors.primaryOrange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            business?.businessName ?? 'Restaurant Profile',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            '${business?.businessType.label ?? "Restaurant"} • $cityText',
                            style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        business?.status.label ?? 'Active',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (business?.fullAddress.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.mediumGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          business!.fullAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Subscription & Plans Card
          Consumer<BusinessProvider>(
            builder: (context, bp, _) {
              final isSub = bp.hasActiveSubscription;
              final isTrial = bp.isTrial;
              final days = bp.daysRemaining;

              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSub ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFFF5353).withValues(alpha: 0.4),
                  ),
                ),
                child: ListTile(
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: (isSub ? const Color(0xFF10B981) : const Color(0xFFFF5353)).withValues(alpha: 0.15),
                    radius: 18,
                    child: Icon(
                      isSub ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                      color: isSub ? const Color(0xFF10B981) : const Color(0xFFFF5353),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      const Text('Subscription & Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isSub ? const Color(0xFF10B981) : const Color(0xFFFF5353)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSub ? (isTrial ? '7-DAY TRIAL' : 'ACTIVE') : 'NO PLAN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSub ? const Color(0xFF10B981) : const Color(0xFFFF5353),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    isSub
                        ? '${bp.subscription?.planName ?? "Active"} • $days days remaining'
                        : 'Choose 7-day free trial or 3/6/12 month plan (+18% GST)',
                    style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => context.push(AppRoutes.subscription),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // POS Table Billing Quick Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                radius: 18,
                child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
              ),
              title: const Text('Table Billing & POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Manage bills, add items & send WhatsApp receipts', style: TextStyle(fontSize: 11, color: AppColors.mediumGray)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => context.push(AppRoutes.billing),
            ),
          ),

          const SizedBox(height: 8),

          // QR Menu Stands Quick Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
                radius: 18,
                child: const Icon(Icons.qr_code_2, color: AppColors.primaryOrange, size: 20),
              ),
              title: const Text('QR Menu Stands', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Download & print table tents with 3D AR scanners', style: TextStyle(fontSize: 11, color: AppColors.mediumGray)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => context.push(AppRoutes.qr),
            ),
          ),
        ] else if (_selectedTab == _ProfileTab.business) ...[
          // Business Details Tab
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Business Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                      icon: const Icon(Icons.edit, size: 13),
                      label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _previousView = _AccountView.profile;
                          _currentView = _AccountView.editProfile;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 14),
                _buildInfoRow('Restaurant Name', business?.businessName ?? '—', isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Business Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (business?.isActive == true ? AppColors.success : Colors.orange).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          business?.status.label ?? '—',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: business?.isActive == true ? AppColors.success : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (business != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            foregroundColor: business.isActive ? Colors.red.shade400 : AppColors.success,
                          ),
                          onPressed: () => _toggleBusinessActive(business),
                          child: Text(
                            business.isActive ? 'Deactivate' : 'Reactivate',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildInfoRow('Business Type', business?.businessType.label ?? 'Restaurant', isDark),
                _buildInfoRow('City', business?.city ?? '—', isDark),
                _buildInfoRow('Full Address', business?.fullAddress ?? '—', isDark),
                _buildInfoRow('UPI Payment ID', business?.upiId ?? 'Not configured', isDark),
                _buildInfoRow('FSSAI Number', business?.fssaiNumber ?? 'Not provided', isDark),
                _buildInfoRow('GSTIN', business?.gstNumber ?? 'Not provided', isDark),
              ],
            ),
          ),
        ] else if (_selectedTab == _ProfileTab.kyc) ...[
          // KYC & Bank Details Tab
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('KYC Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      label: Text(
                        _kycLabel(user?.kycStatus ?? 0),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: user?.kycStatus == 2 ? AppColors.success : AppColors.primaryOrange,
                        ),
                      ),
                      backgroundColor: (user?.kycStatus == 2 ? AppColors.success : AppColors.primaryOrange).withValues(alpha: 0.12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Full Name (as on Aadhaar)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aadhaarController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Aadhaar Last 4',
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _panController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'PAN Number (10 chars)',
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Submit KYC',
                  isLoading: _kycLoading,
                  onPressed: _submitKyc,
                ),
                const Divider(height: 20),
                const Text('Bank Account & Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _accountController,
                        keyboardType: TextInputType.number,
                        maxLength: 18,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(18),
                        ],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Account Number (9-18 digits)',
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _ifscController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'IFSC Code (11 chars)',
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Verify Bank (Penny Drop)',
                  isLoading: _bankLoading,
                  onPressed: _verifyBank,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 2: "Settings" (Fixed, non-scrolling)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSettingsView(BuildContext context, bool isDark) {
    final business = context.watch<BusinessProvider>().business;
    final user = context.watch<BusinessProvider>().user ?? context.watch<AuthProvider>().user;
    final themeProvider = context.watch<ThemeProvider>();

    final displayName = user?.fullName != null && user!.fullName!.isNotEmpty
        ? user.fullName!
        : (business?.businessName ?? 'Restaurant Owner');
    final usernameTag = _usernameController.text.isNotEmpty
        ? _usernameController.text
        : '@${(business?.businessName ?? "restaurant").replaceAll(" ", "").toLowerCase()}';

    final groupBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final groupBorder = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;

    return ListView(
      key: const ValueKey('settings_view'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Top Header: Back Arrow & Centered "Settings"
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _currentView = _AccountView.profile),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),

        const SizedBox(height: 12),

        // Profile Preview Card at the top (tapping opens Edit Profile!)
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _previousView = _AccountView.settings;
              _currentView = _AccountView.editProfile;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: groupBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: groupBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDark ? const Color(0xFF2A2A2E) : Colors.orange.shade50,
                  child: const Icon(Icons.person, color: AppColors.primaryOrange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        usernameTag,
                        style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Restaurant Operations & Business Status
        if (business != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: groupBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: business.isActive
                    ? AppColors.success.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (business.isActive ? AppColors.success : Colors.orange).withValues(alpha: 0.15),
                  child: Icon(
                    business.isActive ? Icons.storefront : Icons.store_mall_directory_outlined,
                    color: business.isActive ? AppColors.success : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.isActive ? 'Business Active & Live' : 'Business Deactivated / Paused',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: business.isActive ? AppColors.success : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        business.isActive
                            ? 'Accepting diner QR orders'
                            : 'Diners see restaurant is paused',
                        style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: business.isActive ? Colors.red.shade400 : AppColors.success,
                  ),
                  onPressed: () => _toggleBusinessActive(business),
                  child: Text(
                    business.isActive ? 'Deactivate' : 'Reactivate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Group 1: Notifications & General Settings
        Container(
          decoration: BoxDecoration(
            color: groupBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: groupBorder),
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                icon: Icons.notifications_paused_outlined,
                title: 'Pause notifications',
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _notificationsPaused,
                    activeThumbColor: AppColors.primaryOrange,
                    activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.5),
                    onChanged: (val) async {
                      setState(() => _notificationsPaused = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notifications_paused', val);
                    },
                  ),
                ),
              ),
              Divider(height: 1, indent: 48, color: groupBorder),
              _buildSettingsRow(
                icon: Icons.tune_outlined,
                title: 'General settings & Billing',
                trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                onTap: () => context.push(AppRoutes.billing),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Group 2: Appearance & Preferences
        Container(
          decoration: BoxDecoration(
            color: groupBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: groupBorder),
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: themeProvider.isDark,
                    activeThumbColor: AppColors.primaryOrange,
                    activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.5),
                    onChanged: (val) {
                      themeProvider.setPreference(val ? ThemePreference.dark : ThemePreference.light);
                    },
                  ),
                ),
              ),
              Divider(height: 1, indent: 48, color: groupBorder),
              _buildSettingsRow(
                icon: Icons.translate,
                title: 'Language',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('English', style: TextStyle(fontSize: 11, color: AppColors.mediumGray)),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                  ],
                ),
                onTap: () => _showLanguageDialog(),
              ),
              Divider(height: 1, indent: 48, color: groupBorder),
              _buildSettingsRow(
                icon: Icons.support_agent_outlined,
                title: 'My Contact & Support',
                trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                onTap: () => _showSupportDialog(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Group 3: Legal & Help
        Container(
          decoration: BoxDecoration(
            color: groupBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: groupBorder),
          ),
          child: Column(
            children: [
              _buildSettingsRow(
                icon: Icons.help_outline,
                title: 'FAQ',
                trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                onTap: () => _showInfoModal('Frequently Asked Questions', '• How to use AR menu?\nCustomers point phone camera to scan table QR code. No app needed.\n\n• How to place orders?\nCustomers select dishes and order via WhatsApp.\n\n• How to manage bills?\nGo to Table Billing & POS to view live orders and collect payments.'),
              ),
              Divider(height: 1, indent: 48, color: groupBorder),
              _buildSettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms of service',
                trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                onTap: () => _showInfoModal('Terms of Service', 'AR Smart Menu provides interactive 3D digital menu and ordering technology for restaurants and Horeca businesses.'),
              ),
              Divider(height: 1, indent: 48, color: groupBorder),
              _buildSettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'User policy',
                trailing: const Icon(Icons.chevron_right, color: AppColors.mediumGray, size: 18),
                onTap: () => _showInfoModal('User Policy', 'Your data and customer orders are securely protected and encrypted.'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Bottom Logout Pill Button
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black87,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFFF3B30), size: 16),
            label: const Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCREEN 3: "Edit Profile" (Fixed, non-scrolling)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEditProfileView(BuildContext context, bool isDark) {
    final groupBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final groupBorder = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;

    return ListView(
      key: const ValueKey('edit_profile_view'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Top Header: Back Arrow & Centered "Edit Profile"
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _currentView = _previousView),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),

        const SizedBox(height: 12),

        // Profile Avatar with Edit Camera Badge
        Center(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: isDark ? const Color(0xFF2A2A2E) : Colors.orange.shade50,
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Form Card
        Container(
          decoration: BoxDecoration(
            color: groupBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: groupBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              _buildEditProfileField(
                label: 'Full name',
                controller: _nameController,
                hint: 'Your Name',
                maxLength: 60,
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'Phone number',
                controller: _phoneController,
                hint: '9876543210 (10 digits)',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'Email',
                controller: _emailController,
                hint: 'youremail@email.com',
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'Username',
                controller: _usernameController,
                hint: '@yourname',
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'Restaurant',
                controller: _businessNameController,
                hint: 'Restaurant Name',
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'City',
                controller: _cityController,
                hint: 'City',
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'Address',
                controller: _addressController,
                hint: 'Full Address',
                isDark: isDark,
              ),
              Divider(height: 1, color: groupBorder),
              _buildEditProfileField(
                label: 'UPI ID',
                controller: _upiController,
                hint: 'restaurant@upi',
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Save Changes CTA Button
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryOrange,
                Color(0xFFFF8533),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 8),

        // Discard Changes Button
        Center(
          child: TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => setState(() => _currentView = _previousView),
            child: Text(
              'Discard Changes',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPillTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange
              : (isDark ? const Color(0xFF1E1E22) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryOrange
                : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade300),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('English (Default)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('हिन्दी (Hindi)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ગુજરાતી (Gujarati)'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Support & Contact'),
        content: const Text('For assistance, queries, or account updates, reach out via:\n\nWhatsApp: +91 98765 43210\nEmail: support@arsmartmenu.com'),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInfoModal(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
