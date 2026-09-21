import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/subscription_service.dart';
import '../../core/utils/owner_notifications_sync.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../widgets/common/gradient_card.dart';

/// Main dashboard with greeting, metrics, quick actions, and product preview.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>();
      if (business.isActive) {
        context.read<ProductProvider>().loadProducts(background: true);
        _syncNotifications();
      }
    });
  }

  Future<void> _syncNotifications() async {
    if (!mounted) return;
    await syncOwnerNotifications(
      productProvider: context.read<ProductProvider>(),
      businessProvider: context.read<BusinessProvider>(),
      notificationProvider: context.read<NotificationProvider>(),
      subscriptionService: SubscriptionService(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BusinessProvider, ProductProvider, AnalyticsProvider>(
      builder: (context, businessProvider, productProvider, analyticsProvider, _) {
        if (!businessProvider.isActive && businessProvider.hasBusiness) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(AppRoutes.businessStatus);
          });
        }

        final businessName =
            businessProvider.business?.businessName ?? 'Your business';
        final ownerName = businessProvider.user?.fullName ?? 'Owner';

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(context, ownerName, businessName),
                        const SizedBox(height: AppSpacing.lg),
                        _buildSubscriptionCard(context, businessProvider),
                        const SizedBox(height: AppSpacing.lg),
                        _buildMetricsRow(context, productProvider, analyticsProvider),
                        const SizedBox(height: AppSpacing.lg),
                        _buildQuickActions(context),
                        const SizedBox(height: AppSpacing.lg),
                        _buildRecentProductsHeader(context),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: productProvider.recentProducts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Text(
                            businessProvider.isActive
                                ? 'No products yet — tap Add product to get started.'
                                : 'Products appear after business approval.',
                            style: const TextStyle(color: AppColors.mediumGray),
                          ),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            itemCount: productProvider.recentProducts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.md),
                            itemBuilder: (context, index) {
                              return _ProductPreviewCard(
                                product: productProvider.recentProducts[index],
                              );
                            },
                          ),
                        ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGreeting(
    BuildContext context,
    String ownerName,
    String businessName,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'dashboard_greeting'.tr()}, $ownerName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                businessName,
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'dashboard_subtitle'.tr(),
                style: const TextStyle(color: AppColors.mediumGray),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.15),
          child: const Icon(
            Icons.store,
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Consumer<NotificationProvider>(
          builder: (context, notifications, _) {
            return IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push(AppRoutes.notifications),
              icon: Badge(
                isLabelVisible: notifications.unreadCount > 0,
                label: Text('${notifications.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    BusinessProvider businessProvider,
  ) {
    final status = businessProvider.business?.status.label ?? 'Not registered';

    return GradientCard(
      gradient: AppColors.primaryGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business status',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  businessProvider.isActive
                      ? 'Add products and generate QR codes'
                      : 'Complete KYC in Account tab',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.account),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.white),
            ),
            child: const Text('Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    ProductProvider productProvider,
    AnalyticsProvider analyticsProvider,
  ) {
    final total = productProvider.totalCount;
    final live = productProvider.liveCount;
    final livePct = total > 0 ? '${((live / total) * 100).round()}%' : '0%';
    final scans = analyticsProvider.totalScans;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.qr_code_scanner,
            label: 'qr_scans'.tr(),
            value: '$scans',
            trend: scans > 0 ? '7d' : '—',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricCard(
            icon: Icons.inventory_2_outlined,
            label: 'total_products'.tr(),
            value: '$total',
            trend: total > 0 ? '+$total' : '—',
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricCard(
            icon: Icons.check_circle_outline,
            label: 'live_products'.tr(),
            value: '$live',
            trend: livePct,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'quick_actions'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_box_outlined,
                label: 'add_product'.tr(),
                onTap: () => context.push(AppRoutes.addProduct),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.qr_code,
                label: 'generate_qr'.tr(),
                onTap: () => context.go(AppRoutes.qr),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.insights_outlined,
                label: 'view_analytics'.tr(),
                onTap: () => context.go(AppRoutes.analytics),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentProductsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'recent_products'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.products),
          child: Text('view_all'.tr()),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mediumGray,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryOrange, size: 28),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({required this.product});

  final ProductModel product;

  Color _statusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.live:
        return AppColors.success;
      case ProductStatus.review:
      case ProductStatus.submitted:
      case ProductStatus.processing:
        return AppColors.warning;
      default:
        return AppColors.mediumGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              color: AppColors.lightGray,
              child: product.thumbnailUrl != null
                  ? Image.network(product.thumbnailUrl!, fit: BoxFit.cover)
                  : const Icon(
                      Icons.image_outlined,
                      color: AppColors.mediumGray,
                      size: 36,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    product.category?.label ?? 'Uncategorized',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.priceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(product.status)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          product.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(product.status),
                          ),
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
}
