import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/table_orders_provider.dart';

/// Bottom navigation shell wrapping the main app tabs.
/// When not logged in, clicking anywhere on the screen displays a login prompt
/// dialog with an "Open Login Page" button.
/// Before approval by admin, all operational features (Home, Products, Billing, QR, Analytics)
/// are locked, and only the Business Status and Account KYC screens are accessible.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _isLoginPromptOpen = false;

  void _showLoginRequiredDialog(BuildContext context) {
    if (_isLoginPromptOpen) return;
    _isLoginPromptOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: AppColors.primaryOrange, size: 24),
            SizedBox(width: 8),
            Text('Login Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Please log in with your restaurant owner credentials to access and manage your AR menu, orders, table QR codes, and billing.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Open Login Page', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    ).then((_) {
      _isLoginPromptOpen = false;
    });
  }

  void _onTabTapped(int index, bool isAuthenticated, bool isApproved) {
    if (!isAuthenticated) {
      _showLoginRequiredDialog(context);
      return;
    }

    // Only Account tab (index 5) is accessible when not approved yet
    if (!isApproved && index != 5) {
      final isRejected = context.read<BusinessProvider>().isRejected;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRejected
                ? 'Your business was rejected by admin. Operational features are locked.'
                : 'Your business is awaiting admin approval. Operational features are locked.',
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View Status',
            textColor: AppColors.primaryOrange,
            onPressed: () => context.go(AppRoutes.businessStatus),
          ),
        ),
      );
      context.go(AppRoutes.businessStatus);
      return;
    }

    if (index == 2) {
      context.read<TableOrdersProvider>().clearAlertMessage();
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final ordersProvider = context.watch<TableOrdersProvider>();
    final totalAlerts = ordersProvider.totalAlertCount;
    final isAuthenticated = authProvider.isAuthenticated;
    final isApproved = businessProvider.isActive;
    final isDeactivated = businessProvider.isDeactivated;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navTheme = theme.navigationBarTheme;

    final bId = businessProvider.business?.id;
    if (isAuthenticated && isApproved && bId != null && bId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ordersProvider.startPolling(bId);
      });
    }

    // Guard against unapproved / rejected business accessing operational shell branches
    if (isAuthenticated && businessProvider.hasBusiness && !isApproved && widget.navigationShell.currentIndex != 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !context.read<BusinessProvider>().isActive && widget.navigationShell.currentIndex != 5) {
          context.go(AppRoutes.businessStatus);
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          if (!isAuthenticated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryOrange.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primaryOrange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You are not logged in. Click anywhere to log in.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primaryOrange,
                    ),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => context.go(AppRoutes.login),
                  ),
                ],
              ),
            ),
          if (isAuthenticated && businessProvider.hasBusiness && !isApproved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: (businessProvider.isRejected ? AppColors.error : AppColors.warning).withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(
                    businessProvider.isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                    size: 18,
                    color: businessProvider.isRejected ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      businessProvider.isRejected
                          ? 'Business Rejected by Admin: Operational features locked.'
                          : 'Pending Admin Approval: Operational features locked.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: businessProvider.isRejected ? AppColors.error : AppColors.warning,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: businessProvider.isRejected ? AppColors.error : AppColors.warning,
                    ),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('View Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => context.go(AppRoutes.businessStatus),
                  ),
                ],
              ),
            ),
          if (isAuthenticated && isApproved && isDeactivated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_filled, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Business Deactivated (Paused): Menus & operational features are locked.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.orange,
                    ),
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: const Text('Reactivate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      widget.navigationShell.goBranch(5);
                    },
                  ),
                ],
              ),
            ),
          if (ordersProvider.lastAlertMessage != null && widget.navigationShell.currentIndex != 2)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryOrange,
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ordersProvider.lastAlertMessage!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      ordersProvider.clearAlertMessage();
                      widget.navigationShell.goBranch(2);
                    },
                    child: const Text('Open Orders'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white),
                    onPressed: () => ordersProvider.clearAlertMessage(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                widget.navigationShell,
                if (!isAuthenticated)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showLoginRequiredDialog(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (idx) => _onTabTapped(idx, isAuthenticated, isApproved),
          backgroundColor: navTheme.backgroundColor,
          indicatorColor: navTheme.indicatorColor,
          destinations: [
            NavigationDestination(
              icon: Icon(!isApproved && isAuthenticated ? Icons.lock_outline : Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: 'nav_home'.tr(),
            ),
            NavigationDestination(
              icon: Icon(!isApproved && isAuthenticated ? Icons.lock_outline : Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: 'nav_products'.tr(),
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: totalAlerts > 0,
                label: Text('$totalAlerts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                backgroundColor: AppColors.primaryOrange,
                child: Icon(!isApproved && isAuthenticated ? Icons.lock_outline : Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: totalAlerts > 0,
                label: Text('$totalAlerts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                backgroundColor: AppColors.primaryOrange,
                child: const Icon(Icons.receipt_long),
              ),
              label: 'nav_billing'.tr(),
            ),
            NavigationDestination(
              icon: Icon(!isApproved && isAuthenticated ? Icons.lock_outline : Icons.qr_code_outlined),
              selectedIcon: const Icon(Icons.qr_code),
              label: 'nav_qr'.tr(),
            ),
            NavigationDestination(
              icon: Icon(!isApproved && isAuthenticated ? Icons.lock_outline : Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: 'nav_analytics'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: 'nav_account'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
