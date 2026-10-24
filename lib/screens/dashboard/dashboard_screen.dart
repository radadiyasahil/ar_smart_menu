import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/owner_notifications_sync.dart';
import '../../models/product_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/common/hover_card.dart';

/// Owner home dashboard styled after modern dark food discovery apps.
/// Features crisp borders and slim light glowing hover effects on all cards and menus.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final b = context.read<BusinessProvider>();
      if (b.isActive) {
        context.read<ProductProvider>().loadProducts(background: true);
        syncOwnerNotifications(
          productProvider: context.read<ProductProvider>(),
          businessProvider: b,
          notificationProvider: context.read<NotificationProvider>(),
          subscriptionService: SubscriptionService(),
        );
      }
    });
  }

  Future<void> _openWebAr() async {
    final uri = Uri.parse('http://localhost:5174/dish/shish-kebab');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open http://localhost:5174 in your browser')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer3<BusinessProvider, ProductProvider, AnalyticsProvider>(
      builder: (context, business, products, analytics, _) {
        if (!business.isActive && business.hasBusiness) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRoutes.businessStatus);
          });
        }

        final bName = business.business?.businessName ?? 'Zing Burger & Co.';
        final city = business.business?.city ?? 'New York, USA';
        final dishes = _getDishes(products);

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
                  _buildHeader(theme, isDark, bName, city),
                  const SizedBox(height: 14),
                  _buildSearchBar(theme, isDark),
                  const SizedBox(height: 16),
                  _buildHeroBanner(theme, isDark),
                  const SizedBox(height: 20),
                  _buildExploreCategories(theme, isDark),
                  const SizedBox(height: 16),
                  _buildPulseCard(theme, isDark, products, analytics),
                  const SizedBox(height: 20),
                  _buildDishSection(theme, isDark, dishes),
                  const SizedBox(height: 16),
                  _buildQrCard(theme, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 1. Header (Avatar, Location, Notification & AR) ──────────────────────

  Widget _buildHeader(ThemeData theme, bool isDark, String name, String city) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final btnBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.2),
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.primaryOrange, size: 22),
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
                        '$name, $city',
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

  // ─── 3. Hero Banner (Instagram Style: Orange Curve & Dishes) ──────────────

  Widget _buildHeroBanner(ThemeData theme, bool isDark) {
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
                right: -25,
                bottom: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&fit=crop'),
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 140, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Exclusive Offers!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Get Special Offers\nUp to 30%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _openWebAr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('Get Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // ─── 4. Explore Categories (Instagram Style: Horizontal Pill Row) ─────────

  Widget _buildExploreCategories(ThemeData theme, bool isDark) {
    final categories = [
      ('Burger', Icons.lunch_dining, () => context.go(AppRoutes.products)),
      ('Pizza', Icons.local_pizza_outlined, () => context.go(AppRoutes.products)),
      ('3D Live', Icons.view_in_ar, _openWebAr),
      ('Table QRs', Icons.qr_code_2, () => context.go(AppRoutes.qr)),
      ('Analytics', Icons.insights, () => context.go(AppRoutes.analytics)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Explore Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.products),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (label, icon, onTap) = categories[i];
              final isSelected = _selectedCategoryIndex == i;

              return HoverCard(
                borderRadius: 24,
                hoverBorderColor: AppColors.primaryOrange,
                onTap: () {
                  setState(() => _selectedCategoryIndex = i);
                  onTap();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.black),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 5. Real-Time 3D Pulse Stats ──────────────────────────────────────────

  Widget _buildPulseCard(ThemeData theme, bool isDark, ProductProvider prod, AnalyticsProvider a) {
    final scans = a.totalScans > 0 ? a.totalScans : 48;
    final live = prod.liveCount > 0 ? prod.liveCount : 12;

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
                        '3D Pulse • Real-Time Stats',
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
                  _statItem('QR Scans', '$scans', '+14% today', AppColors.primaryOrangeLight),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  _statItem('AR Views', '${(scans * 2.6).round()}', 'Interactions', AppColors.info),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  _statItem('Live 3D', '$live', 'On Tables', AppColors.accentGreen),
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

  // ─── 6. Popular in 3D Dish Section (ItaliaCrisp Style) ─────────────────────

  Widget _buildDishSection(ThemeData theme, bool isDark, List<_DishItem> dishes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Most Popular in 3D',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.products),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dishes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _DishCard(dish: dishes[i]),
          ),
        ),
      ],
    );
  }

  // ─── 7. Table QR Tent Cards Card ──────────────────────────────────────────

  Widget _buildQrCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: HoverCard(
        borderRadius: 18,
        onTap: () => context.go(AppRoutes.qr),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(Icons.qr_code_scanner, color: AppColors.primaryOrange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table QR Tent Cards Ready',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Guests scan on tables to view 3D models.',
                      style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Download Tent Cards (PDF) →',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
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

  List<_DishItem> _getDishes(ProductProvider p) {
    if (p.products.isEmpty) return _DishItem.defaults;
    return p.recentProducts.map((prod) {
      final isVeg = prod.vegStatus == VegStatus.veg || prod.vegStatus == VegStatus.vegan;
      return _DishItem(
        name: prod.name,
        price: prod.priceLabel,
        category: prod.category?.label ?? 'Dish',
        imageUrl: prod.thumbnailUrl ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&fit=crop',
        isVeg: isVeg,
        is3d: prod.isLive,
        onTap: () => context.push(AppRoutes.productDetail(prod.id)),
      );
    }).toList();
  }
}

// ─── Dish Component & Palette ────────────────────────────────────────────────

class _DishItem {
  const _DishItem({
    required this.name,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.isVeg = true,
    this.is3d = true,
    this.onTap,
  });

  final String name, price, category, imageUrl;
  final bool isVeg, is3d;
  final VoidCallback? onTap;

  static const defaults = [
    _DishItem(name: 'ItaliaCrisp Pizza', price: '₹349', category: '10 min • Main Course', imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&fit=crop', isVeg: true),
    _DishItem(name: 'Smashed Double Burger', price: '₹299', category: '12 min • Starters', imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&fit=crop', isVeg: false),
    _DishItem(name: 'Grilled Shish Kebab', price: '₹349', category: '15 min • Starters', imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&fit=crop', isVeg: false),
    _DishItem(name: 'Avocado Gourmet Bowl', price: '₹280', category: '8 min • Healthy Salad', imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&fit=crop', isVeg: true),
  ];
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.dish,
  });

  final _DishItem dish;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return HoverCard(
      borderRadius: 18,
      onTap: dish.onTap,
      child: SizedBox(
        width: 175,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 125,
                  width: double.infinity,
                  child: Image.network(
                    dish.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: isDark ? AppColors.darkSurface : AppColors.lightGray,
                      child: const Icon(Icons.fastfood, color: AppColors.mediumGray),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          '20% OFF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (dish.is3d)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.view_in_ar, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            '3D',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, size: 18, color: AppColors.primaryOrange),
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
                      Text(
                        dish.price,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.black,
                        ),
                      ),
                      _vegDot(dish.isVeg),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 11, color: AppColors.mediumGray),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          dish.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.mediumGray),
                        ),
                      ),
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

  Widget _vegDot(bool isVeg) {
    final c = isVeg ? AppColors.accentGreen : AppColors.error;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
