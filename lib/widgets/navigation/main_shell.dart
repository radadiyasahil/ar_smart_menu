import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';

/// Bottom navigation shell wrapping the main app tabs.
/// When not logged in, clicking anywhere on the screen displays a login prompt
/// dialog with an "Open Login Page" button.
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

  void _onTabTapped(int index, bool isAuthenticated) {
    if (!isAuthenticated) {
      _showLoginRequiredDialog(context);
      return;
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
    final isAuthenticated = authProvider.isAuthenticated;
    final isDeactivated = businessProvider.isDeactivated;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navTheme = theme.navigationBarTheme;

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
          if (isAuthenticated && isDeactivated)
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
                      widget.navigationShell.goBranch(4);
                    },
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
          onDestinationSelected: (idx) => _onTabTapped(idx, isAuthenticated),
          backgroundColor: navTheme.backgroundColor,
          indicatorColor: navTheme.indicatorColor,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: 'nav_home'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: 'nav_products'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.qr_code_outlined),
              selectedIcon: const Icon(Icons.qr_code),
              label: 'nav_qr'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
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
