import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/hover_card.dart';

/// Owner account — business details, KYC, logout.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _kycLoading = false;
  bool _bankLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BusinessProvider>().loadFullBusinessDetails();
      final user = context.read<BusinessProvider>().user;
      if (user?.fullName != null) {
        _nameController.text = user!.fullName!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _submitKyc() async {
    setState(() => _kycLoading = true);
    try {
      await context.read<BusinessProvider>().submitKyc(
            fullName: _nameController.text.trim(),
            aadhaarLast4: _aadhaarController.text.trim(),
            panNumber: _panController.text.trim().toUpperCase(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC details submitted')),
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
    if (_accountController.text.trim().length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid account number')),
      );
      return;
    }
    if (_ifscController.text.trim().length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IFSC must be 11 characters')),
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
            content: Text(ok ? 'Bank verified' : 'Bank verification failed'),
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
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, AuthProvider>(
      builder: (context, businessProvider, authProvider, _) {
        final business = businessProvider.business;
        final user = businessProvider.user ?? authProvider.user;

        return Scaffold(
          appBar: AppBar(title: const Text('Account')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _SectionHeader(title: 'Profile', icon: Icons.person_outline),
                HoverCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(user?.mobileNumber ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user?.fullName ?? 'Owner'),
                    trailing: Chip(
                      label: Text(_kycLabel(user?.kycStatus ?? 0)),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (business != null) ...[
                  _SectionHeader(title: 'Business', icon: Icons.store),
                  _InfoRow(label: 'Name', value: business.businessName),
                  _InfoRow(label: 'Type', value: business.businessType.label),
                  _InfoRow(label: 'City', value: business.city),
                  _InfoRow(label: 'Address', value: business.fullAddress),
                  _InfoRow(label: 'Status', value: business.status.label),
                  if (business.bankPennyVerified)
                    const _InfoRow(label: 'Bank', value: 'Verified'),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _SectionHeader(title: 'KYC details', icon: Icons.verified_user_outlined),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name (as on Aadhaar)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _aadhaarController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar last 4 digits',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _panController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'PAN number',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Submit KYC',
                  isLoading: _kycLoading,
                  onPressed: businessProvider.hasBusiness ? _submitKyc : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(title: 'Preferences', icon: Icons.tune_outlined),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return SegmentedButton<ThemePreference>(
                      segments: ThemePreference.values
                          .map(
                            (option) => ButtonSegment(
                              value: option,
                              label: Text(option.label),
                              icon: Icon(
                                switch (option) {
                                  ThemePreference.light => Icons.light_mode,
                                  ThemePreference.dark => Icons.dark_mode,
                                  
                                },
                              ),
                            ),
                          )
                          .toList(),
                      selected: {themeProvider.preference},
                      onSelectionChanged: (selection) {
                        themeProvider.setPreference(selection.first);
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Consumer<NotificationProvider>(
                  builder: (context, notifications, _) {
                    return HoverCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () => context.push(AppRoutes.notifications),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined, color: AppColors.primaryOrange),
                        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          notifications.unreadCount > 0
                              ? '${notifications.unreadCount} unread'
                              : 'Product & business alerts',
                        ),
                        trailing: notifications.unreadCount > 0
                            ? Badge(
                                label: Text('${notifications.unreadCount}'),
                              )
                            : const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(title: 'Bank account', icon: Icons.account_balance),
                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Account number'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: 'IFSC code',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Verify bank (penny drop)',
                  isLoading: _bankLoading,
                  onPressed: businessProvider.hasBusiness ? _verifyBank : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Log out',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mediumGray, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
