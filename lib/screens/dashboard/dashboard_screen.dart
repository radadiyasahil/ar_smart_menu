import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/ar_preview.dart';
import '../../core/utils/owner_notifications_sync.dart';
import '../../core/utils/subscription_guard.dart';
import '../../core/utils/top_toast.dart';
import '../../models/product_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/table_orders_provider.dart';
import '../../widgets/common/hover_card.dart';

/// Owner home dashboard styled after modern dark food discovery apps.
/// Features crisp borders and slim light glowing hover effects on all cards and menus.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _dailyItemFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = context.read<BusinessProvider>();
      b.loadSubscription();
      if (b.isActive) {
        context.read<ProductProvider>().loadProducts(background: true).then((_) {
          if (mounted) {
            syncOwnerNotifications(
              productProvider: context.read<ProductProvider>(),
              businessProvider: b,
              notificationProvider: context.read<NotificationProvider>(),
              subscriptionService: SubscriptionService(),
            );
          }
        });
      }
    });
  }

  Future<void> _openWebAr() async {
    await openHorecaMenuAr(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer4<BusinessProvider, ProductProvider, AnalyticsProvider, TableOrdersProvider>(
      builder: (context, business, products, analytics, orders, _) {
        if (!business.isActive && business.hasBusiness) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRoutes.businessStatus);
          });
        }

        final bName = business.business?.businessName ?? 'Restaurant';
        final city = business.business?.city ?? '';

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: () async {
                await products.loadProducts(force: true);
                if (mounted) await analytics.refresh();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                children: [
                  _buildHeader(theme, isDark, bName, city, business.business?.logoUrl),
                  const SizedBox(height: 14),
                  _buildSearchBar(theme, isDark),
                  const SizedBox(height: 16),
                  _buildDailyOperationsHub(theme, isDark, products, orders),
                  const SizedBox(height: 16),
                  _buildHeroBanner(theme, isDark, products),
                  const SizedBox(height: 20),
                  _buildPulseCard(theme, isDark, products, analytics),
                  const SizedBox(height: 20),
                  _build3DModelsShowcase(theme, isDark, products),
                  const SizedBox(height: 20),
                  _buildDailyUseItemsSection(theme, isDark, products),
                  const SizedBox(height: 16),
                  _buildSubscriptionStatusBanner(business, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 1. Header (Avatar, Location, Notification & AR) ──────────────────────

  Widget _buildHeader(ThemeData theme, bool isDark, String name, String city, String? logoUrl) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final btnBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.account),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.2),
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                image: (logoUrl != null && logoUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(logoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (logoUrl == null || logoUrl.isEmpty)
                  ? const Icon(Icons.restaurant, color: AppColors.primaryOrange, size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.mediumGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        city.isNotEmpty ? '$name, $city' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? Colors.white70 : AppColors.mediumGray,
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openWebAr,
            icon: const Icon(Icons.view_in_ar, size: 14, color: AppColors.primaryOrange),
            label: const Text(
              'Customer AR',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange.withValues(alpha: isDark ? 0.12 : 0.08),
              side: const BorderSide(color: AppColors.primaryOrange, width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 6),
          Consumer<NotificationProvider>(
            builder: (_, notifs, _) => HoverCard(
              borderRadius: 22,
              onTap: () => context.push(AppRoutes.notifications),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: btnBg,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: Center(
                  child: Badge(
                    isLabelVisible: notifs.unreadCount > 0,
                    label: Text('${notifs.unreadCount}'),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: isDark ? Colors.white : AppColors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. Search & Filter Bar ───────────────────────────────────────────────

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        borderRadius: 28,
        onTap: () => context.go(AppRoutes.products),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: isDark ? Colors.white54 : AppColors.mediumGray),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search Dish, Restaurant...',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : AppColors.mediumGray,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 3. Hero Banner (Interactive 3D AR Digital Menu) ──────────────────────

  Widget _buildHeroBanner(ThemeData theme, bool isDark, ProductProvider products) {
    final live3dCount = products.products.where((p) => p.photos.length >= 4).length;
    final totalDishes = products.products.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        borderRadius: 22,
        onTap: _openWebAr,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -15,
                bottom: -15,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.view_in_ar_rounded,
                      size: 78,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 110, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            live3dCount > 0
                                ? '$live3dCount Dishes in 3D AR'
                                : '$totalDishes Menu Items Live',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Interactive 3D AR\nDigital Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Guests scan table QRs to view dishes in full 3D AR directly on their tables.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _openWebAr,
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open Customer View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 4. Real-Time 3D Pulse Stats ──────────────────────────────────────────

  Widget _buildPulseCard(ThemeData theme, bool isDark, ProductProvider prod, AnalyticsProvider a) {
    final scans = a.totalScans;
    final orders = a.totalOrders;
    final live3d = prod.products.where((p) => p.photos.length >= 4).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        borderRadius: 18,
        onTap: () => context.go(AppRoutes.analytics),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flash_on, color: AppColors.primaryOrange, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '3D Pulse • Live Overview',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    'Analytics →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.primaryOrangeLight : AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('QR Scans', '$scans', 'Total Visits', AppColors.primaryOrangeLight),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  _statItem('Orders', '$orders', 'Table Orders', AppColors.info),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  _statItem('3D Dishes', '$live3d', 'Ready in AR', AppColors.accentGreen),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String val, String sub, Color color) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.mediumGray, fontSize: 11)),
        Text(sub, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── 4b. Daily Operations Hub & Fast Operational Actions ────────────────
  Widget _buildDailyOperationsHub(ThemeData theme, bool isDark, ProductProvider products, TableOrdersProvider orders) {
    final activeTables = orders.activeBills.length;
    final pendingOrders = orders.pendingCount;
    final kitchenOrders = orders.kitchenOrders.length;
    final soldOut = products.products.where((p) => p.soldOutToday).length;

    final tiles = [
      (
        icon: Icons.table_restaurant_rounded,
        color: const Color(0xFF10B981),
        title: '$activeTables Active',
        subtitle: 'Table Billing & POS',
        caption: activeTables > 0 ? '$activeTables seated tables' : 'All tables open',
        badge: activeTables > 0 ? 'Live' : null,
        onTap: () => context.go(AppRoutes.billing),
      ),
      (
        icon: Icons.soup_kitchen_rounded,
        color: const Color(0xFFF59E0B),
        title: '${pendingOrders + kitchenOrders} Tickets',
        subtitle: 'Kitchen & KOT',
        caption: '$pendingOrders new • $kitchenOrders cooking',
        badge: pendingOrders > 0 ? '$pendingOrders New' : null,
        onTap: () => context.go(AppRoutes.billing),
      ),
      (
        icon: Icons.inventory_2_outlined,
        color: soldOut > 0 ? AppColors.error : const Color(0xFF06B6D4),
        title: soldOut > 0 ? '$soldOut Sold Out' : 'All In Stock',
        subtitle: 'Daily Stock (86)',
        caption: '${products.products.length} menu items total',
        badge: soldOut > 0 ? '86 Alert' : 'Ready',
        onTap: () => context.go(AppRoutes.products),
      ),
      (
        icon: Icons.add_photo_alternate_rounded,
        color: const Color(0xFF8B5CF6),
        title: '+ Add Dish',
        subtitle: 'Upload 3D AR Dish',
        caption: 'Capture 4 angle photos',
        badge: 'New',
        onTap: () {
          if (checkSubscriptionGuard(context, featureName: 'adding dishes')) context.push(AppRoutes.addProduct);
        },
      ),
    ];

    return Column(
      children: [
        _sectionHeader(
          icon: Icons.bolt_rounded,
          iconColor: AppColors.accentGreen,
          title: 'Daily Operations & Quick Actions',
          actionLabel: 'POS View →',
          onAction: () => context.go(AppRoutes.billing),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _operationTile(tiles[0], isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _operationTile(tiles[1], isDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _operationTile(tiles[2], isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _operationTile(tiles[3], isDark)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _operationTile(
    ({IconData icon, Color color, String title, String subtitle, String caption, String? badge, VoidCallback onTap}) tile,
    bool isDark,
  ) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return HoverCard(
      borderRadius: 16,
      onTap: tile.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tile.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tile.icon, color: tile.color, size: 20),
                ),
                if (tile.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: tile.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tile.badge!,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tile.color),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tile.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.black),
            ),
            const SizedBox(height: 2),
            Text(
              tile.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              tile.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. Plan & Subscription Banner ─────────────────────────────────────────
  Widget _buildSubscriptionStatusBanner(BusinessProvider business, bool isDark) {
    final sub = business.subscription;
    final isSubActive = business.hasActiveSubscription;
    final isTrial = business.isTrial;
    final days = business.daysRemaining;
    final isExpired = sub != null && sub.status == 'Expired';

    final Color bannerColor = isSubActive
        ? const Color(0xFF10B981)
        : (isExpired ? const Color(0xFFEF4444) : const Color(0xFFFF5353));

    final String message = isSubActive
        ? (isTrial ? '7-Day Free Trial Active • $days days left' : '${sub?.planName ?? "Plan Active"} • $days days left')
        : (isExpired ? 'Subscription Expired • Renew now' : 'Upgrade to Growth Plan for 3D AR Models');

    final String actionLabel = isSubActive ? (isTrial ? 'Upgrade' : 'Manage') : (isExpired ? 'Renew' : 'View Plans');
    final IconData icon = isSubActive
        ? (isTrial ? Icons.stars_rounded : Icons.check_circle_rounded)
        : (isExpired ? Icons.lock_clock_rounded : Icons.flash_on_rounded);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: bannerColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: bannerColor),
              ),
            ),
            InkWell(
              onTap: () => context.push(AppRoutes.subscription),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. Featured 3D AR Dish Models Showcase ───────────────────────────────
  Widget _build3DModelsShowcase(ThemeData theme, bool isDark, ProductProvider products) {
    final modelDishes = products.products.where((p) => p.photos.length >= 4 || p.isHero).toList();
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.view_in_ar_rounded,
          iconColor: AppColors.primaryOrange,
          title: 'Featured 3D AR Models',
          badge: '${modelDishes.length} Ready',
          badgeColor: const Color(0xFF6366F1),
          actionLabel: 'WebAR Menu →',
          onAction: _openWebAr,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        if (modelDishes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.view_in_ar_rounded, color: AppColors.primaryOrange, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No 3D Models Added Yet',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Add 4 angle photos to turn any dish into an interactive 3D model for diners.',
                          style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (checkSubscriptionGuard(context, featureName: 'adding dishes')) {
                        context.push(AppRoutes.addProduct);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add 3D', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: modelDishes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _build3DModelCard(modelDishes[i], isDark, products),
            ),
          ),
      ],
    );
  }

  Widget _build3DModelCard(ProductModel p, bool isDark, ProductProvider products) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final isVeg = p.vegStatus == VegStatus.veg || p.vegStatus == VegStatus.vegan;

    return HoverCard(
      borderRadius: 18,
      onTap: () => context.push(AppRoutes.productDetail(p.id)),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _dishImage(p, isDark, width: double.infinity, height: 115),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 6),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_in_ar_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          '3D AR MODEL',
                          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                if (p.soldOutToday)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(6)),
                      child: const Text('86 SOLD OUT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.priceLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.black)),
                      _vegDotWidget(isVeg),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => previewProductInAr(context, productId: p.id, productName: p.name),
                          icon: const Icon(Icons.view_in_ar, size: 12),
                          label: const Text('View 3D', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            side: const BorderSide(color: AppColors.primaryOrange, width: 0.8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _stockToggle(p, products, compact: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 7. Daily Use Items & Stock Availability (86) ────────────────────────
  Widget _buildDailyUseItemsSection(ThemeData theme, bool isDark, ProductProvider products) {
    final allProducts = products.products;
    final bestsellers = allProducts.where((p) => p.isBestseller).toList();
    final soldOut = allProducts.where((p) => p.soldOutToday).toList();
    final modelDishes = allProducts.where((p) => p.photos.length >= 4).toList();

    final displayedList = switch (_dailyItemFilter) {
      '3d' => modelDishes,
      'bestseller' => bestsellers.isNotEmpty ? bestsellers : allProducts,
      'soldout' => soldOut,
      _ => allProducts,
    };

    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.restaurant_menu_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'Daily Menu Items & Stock',
          actionLabel: 'Manage Menu →',
          onAction: () => context.go(AppRoutes.products),
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('all', 'All (${allProducts.length})', isDark),
              const SizedBox(width: 8),
              _filterChip('3d', '3D Models (${modelDishes.length})', isDark),
              const SizedBox(width: 8),
              _filterChip('bestseller', 'Bestsellers (${bestsellers.length})', isDark),
              const SizedBox(width: 8),
              _filterChip('soldout', 'Sold Out / 86 (${soldOut.length})', isDark, isAlert: soldOut.isNotEmpty),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (displayedList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  _dailyItemFilter == 'soldout'
                      ? 'No items are currently sold out. All dishes in stock!'
                      : 'No dishes found in this filter.',
                  style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayedList.take(6).length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildDailyUseItemTile(displayedList[i], isDark, products),
          ),
      ],
    );
  }

  Widget _buildDailyUseItemTile(ProductModel p, bool isDark, ProductProvider products) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final isVeg = p.vegStatus == VegStatus.veg || p.vegStatus == VegStatus.vegan;

    return HoverCard(
      borderRadius: 14,
      onTap: () => context.push(AppRoutes.productDetail(p.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _dishImage(p, isDark, width: 48, height: 48, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _vegDotWidget(isVeg),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.black),
                        ),
                      ),
                      if (p.photos.length >= 4) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('3D', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(p.priceLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primaryOrange)),
                      const SizedBox(width: 8),
                      Text('• ${p.category?.label ?? "Dish"}', style: const TextStyle(fontSize: 11, color: AppColors.mediumGray)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _stockToggle(p, products),
          ],
        ),
      ),
    );
  }

  // ─── Shared UI Helpers (Reusable across dashboard sections) ───────────────
  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? badge,
    Color? badgeColor,
    String? actionLabel,
    VoidCallback? onAction,
    bool isDark = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? iconColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.primaryOrangeLight : AppColors.primaryOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stockToggle(ProductModel p, ProductProvider products, {bool compact = false}) {
    final isSoldOut = p.soldOutToday;
    final color = isSoldOut ? AppColors.error : AppColors.accentGreen;

    return InkWell(
      onTap: () async {
        final newStatus = !isSoldOut;
        await products.toggleSoldOut(p.id, soldOut: newStatus);
        if (mounted) {
          TopToast.show(
            context,
            newStatus ? '${p.name} marked 86 / Sold Out today' : '${p.name} marked In Stock',
            isWarning: newStatus,
          );
        }
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 20),
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(compact ? 8 : 20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSoldOut ? Icons.cancel_outlined : Icons.check_circle_outline,
              size: 13,
              color: color,
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                isSoldOut ? '86 Sold Out' : 'In Stock',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dishImage(ProductModel p, bool isDark, {double? width, double? height, double borderRadius = 0}) {
    final hasUrl = p.photos.isNotEmpty && p.photos.first.photoUrl.isNotEmpty;
    final img = hasUrl
        ? Image.network(
            p.photos.first.photoUrl,
            fit: BoxFit.cover,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _placeholderBox(isDark, width: width, height: height),
          )
        : _placeholderBox(isDark, width: width, height: height);

    if (borderRadius > 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: img);
    }
    return SizedBox(width: width, height: height, child: img);
  }

  Widget _filterChip(String key, String label, bool isDark, {bool isAlert = false}) {
    final isSelected = _dailyItemFilter == key;
    Color activeColor = AppColors.primaryOrange;
    if (isAlert) activeColor = AppColors.error;

    return InkWell(
      onTap: () => setState(() => _dailyItemFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _placeholderBox(bool isDark, {double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF222533) : const Color(0xFFF1F3F7),
      child: Center(
        child: Icon(
          Icons.fastfood_outlined,
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          size: (width != null && width <= 48) ? 20 : 26,
        ),
      ),
    );
  }

  Widget _vegDotWidget(bool isVeg) {
    final c = isVeg ? AppColors.accentGreen : AppColors.error;
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
