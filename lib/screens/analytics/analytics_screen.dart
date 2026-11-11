import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/analytics_model.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/business_provider.dart';
import '../../core/services/analytics_export_service.dart';
import '../../core/services/billing_service.dart';
import '../../widgets/common/gradient_card.dart';

enum ChartMetric { revenue, orders, scans }

/// Comprehensive restaurant sales, orders & menu analytics screen.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  ChartMetric _selectedChartMetric = ChartMetric.revenue;
  bool _isExporting = false;

  Future<void> _exportReport(AnalyticsProvider analytics, [AnalyticsRange? specificRange]) async {
    setState(() => _isExporting = true);
    try {
      final businessProvider = context.read<BusinessProvider>();
      final business = businessProvider.business;
      final targetRange = specificRange ?? analytics.range;

      if (specificRange != null && specificRange != analytics.range) {
        await analytics.load(
          range: specificRange,
          businessId: business?.id,
          isBusinessActive: businessProvider.isActive,
        );
      }

      final historyBills = await BillingService().getCompletedHistory(business?.id);

      await AnalyticsExportService.instance.exportFinancialReport(
        business: business,
        overview: analytics.overview,
        chartPoints: analytics.chartPoints,
        topProducts: analytics.topProducts,
        bills: historyBills,
        range: targetRange,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Financial audit report downloaded in Excel (.csv) format.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to generate report: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportOptions(AnalyticsProvider analytics) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.table_view_outlined, color: AppColors.primaryOrange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Export Financial & Audit Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Download restaurant sales, GST, orders, and dish analytics formatted for Microsoft Excel & financial auditing.',
                style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.primaryOrange, size: 20),
                ),
                title: Text('Current Period (${analytics.range.label})'),
                subtitle: const Text('Export real-time figures currently shown on screen'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _exportReport(analytics);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_outlined, color: Colors.green, size: 20),
                ),
                title: const Text('Full Financial Year Report (1 Year Audit)'),
                subtitle: const Text('Complete 12-month breakdown for taxation & accounting audit'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _exportReport(analytics, AnalyticsRange.year);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>();
      if (business.isActive && business.business != null) {
        context.read<AnalyticsProvider>().load(
          businessId: business.business!.id,
          isBusinessActive: business.isActive,
        );
      } else {
        context.read<AnalyticsProvider>().clear();
      }
    });
  }

  String _formatCurrency(num value) {
    try {
      final fmt = NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 0,
        locale: 'en_IN',
      );
      return fmt.format(value);
    } catch (_) {
      return '₹$value';
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final isApproved = businessProvider.isActive;

    if (!isApproved) {
      final isRejected = businessProvider.isRejected;
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                  size: 64,
                  color: isRejected ? AppColors.error : AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isRejected
                      ? 'Business Registration Rejected'
                      : 'Pending Admin Approval',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isRejected
                      ? 'Your business has been rejected by the administrator. Menu and sales analytics are not accessible.'
                      : 'Your business is awaiting review by our team. Sales and order analytics will become available once approved.',
                  style: const TextStyle(color: AppColors.mediumGray, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go(AppRoutes.businessStatus),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View Business Status', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AnalyticsProvider>(
      builder: (context, analytics, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: analytics.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context, analytics)),
                if (analytics.isLoading && !analytics.isLoaded)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (analytics.error != null && !analytics.isLoaded)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: analytics.error!,
                      onRetry: () {
                      final b = context.read<BusinessProvider>();
                      analytics.load(
                        force: true,
                        businessId: b.business?.id,
                        isBusinessActive: b.isActive,
                      );
                    },
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _buildRangeSelector(context, analytics),
                  ),
                  SliverToBoxAdapter(
                    child: _buildKpiGrid(analytics.overview),
                  ),
                  SliverToBoxAdapter(
                    child: _buildChartCard(analytics),
                  ),
                  SliverToBoxAdapter(
                    child: _buildTopProducts(analytics.topProducts),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AnalyticsProvider analytics) {
    final revenue = analytics.overview?.totalRevenue ?? 0;
    final orders = analytics.overview?.totalOrders ?? 0;
    final aov = analytics.overview?.averageOrderValue ?? 0;
    final visitors = analytics.overview?.uniqueVisitors ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales & Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Revenue, orders, popular dishes & dining activity',
                      style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isExporting ? null : () => _showExportOptions(analytics),
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_outlined, size: 18),
                label: const Text(
                  'Download Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (analytics.isLoading && analytics.isLoaded) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Hero Revenue Summary Card
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.currency_rupee,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Revenue (${analytics.range.label})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        analytics.range.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formatCurrency(revenue),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _heroStatItem(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Orders',
                        value: '$orders',
                      ),
                      Container(
                        height: 20,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _heroStatItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Avg / Order',
                        value: _formatCurrency(aov.round()),
                      ),
                      Container(
                        height: 20,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _heroStatItem(
                        icon: Icons.people_outline,
                        label: 'Guests',
                        value: '$visitors',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeSelector(BuildContext context, AnalyticsProvider analytics) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: AnalyticsRange.values.map((option) {
            final selected = analytics.range == option;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final b = context.read<BusinessProvider>();
                  analytics.load(
                    range: option,
                    force: true,
                    businessId: b.business?.id,
                    isBusinessActive: b.isActive,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryOrange
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryOrange
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.white : AppColors.mediumGray,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(AnalyticsOverviewModel? overview) {
    final data = overview ??
        const AnalyticsOverviewModel(
          totalScans: 0,
          totalViews: 0,
          uniqueVisitors: 0,
          conversionRate: 0,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.45,
        children: [
          _KpiTile(
            icon: Icons.currency_rupee_rounded,
            label: 'Total Revenue',
            value: _formatCurrency(data.totalRevenue),
            color: const Color(0xFF10B981),
            subtitle: 'Gross sales',
          ),
          _KpiTile(
            icon: Icons.receipt_long_rounded,
            label: 'Total Orders',
            value: '${data.totalOrders}',
            color: AppColors.primaryOrange,
            subtitle: 'Dine-in orders',
          ),
          _KpiTile(
            icon: Icons.qr_code_scanner_rounded,
            label: 'QR Scans',
            value: '${data.totalScans}',
            color: AppColors.info,
            subtitle: 'Table visits',
          ),
          _KpiTile(
            icon: Icons.view_in_ar_rounded,
            label: '3D / AR Views',
            value: '${data.totalViews}',
            color: const Color(0xFF8B5CF6),
            subtitle: 'Dish views',
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(AnalyticsProvider analytics) {
    final points = analytics.chartPoints;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderGray),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Activity Over Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    analytics.range.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Track trends across days, weeks, months, or year',
                style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
              ),
              const SizedBox(height: AppSpacing.md),

              // Metric Selector Tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _chartTab(
                      metric: ChartMetric.revenue,
                      label: '💰 Revenue (₹)',
                      color: const Color(0xFF10B981),
                    ),
                    _chartTab(
                      metric: ChartMetric.orders,
                      label: '🛍️ Orders',
                      color: AppColors.primaryOrange,
                    ),
                    _chartTab(
                      metric: ChartMetric.scans,
                      label: '📲 Scans & Views',
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 220,
                child: points.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity yet for this period.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      )
                    : _AnalyticsLineChart(
                        points: points,
                        metric: _selectedChartMetric,
                        range: analytics.range,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chartTab({
    required ChartMetric metric,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedChartMetric == metric;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedChartMetric = metric;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? color : AppColors.mediumGray,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProducts(List<TopProductAnalyticsModel> products) {
    final maxOrders = products.fold<int>(0, (m, p) => p.orderCount > m ? p.orderCount : m);
    final maxScans = products.fold<int>(0, (m, p) => p.scans > m ? p.scans : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.borderGray),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Dishes Ordered',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🔥 Most Popular',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Ranked by total dishes ordered and sales revenue',
                style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'No dish sales data yet for this period.\nOrders placed from tables will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  ),
                )
              else
                ...products.asMap().entries.map((entry) {
                  return _TopProductRow(
                    rank: entry.key + 1,
                    product: entry.value,
                    maxMetric: maxOrders > 0 ? maxOrders : (maxScans > 0 ? maxScans : 1),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.mediumGray.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLineChart extends StatelessWidget {
  const _AnalyticsLineChart({
    required this.points,
    required this.metric,
    required this.range,
  });

  final List<AnalyticsChartPointModel> points;
  final ChartMetric metric;
  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    if (metric == ChartMetric.revenue) {
      maxY = points.fold<int>(0, (a, b) => b.revenue > a ? b.revenue : a).toDouble();
    } else if (metric == ChartMetric.orders) {
      maxY = points.fold<int>(0, (a, b) => b.orders > a ? b.orders : a).toDouble();
    } else {
      final maxVal = points
          .map((p) => p.scans > p.views ? p.scans : p.views)
          .fold<int>(0, (a, b) => a > b ? a : b);
      maxY = maxVal.toDouble();
    }

    final yMax = maxY <= 0 ? 5.0 : (maxY * 1.25);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4 > 0 ? yMax / 4 : 1,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.borderGray,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: metric == ChartMetric.revenue ? 40 : 28,
              interval: yMax / 4 > 0 ? yMax / 4 : 1,
              getTitlesWidget: (value, _) {
                String label;
                if (metric == ChartMetric.revenue) {
                  if (value >= 1000) {
                    label = '₹${(value / 1000).toStringAsFixed(1)}k';
                  } else {
                    label = '₹${value.toInt()}';
                  }
                } else {
                  label = value.toInt().toString();
                }
                return Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: range == AnalyticsRange.year
                  ? 2
                  : (points.length > 14 ? 5 : 1),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final date = points[index].date;
                String label;
                if (range == AnalyticsRange.year) {
                  label = DateFormat('MMM').format(date);
                } else if (range == AnalyticsRange.today) {
                  label = DateFormat('ha').format(date);
                } else if (points.length <= 7) {
                  label = DateFormat('EEE').format(date);
                } else {
                  label = DateFormat('d MMM').format(date);
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.mediumGray,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: _buildLineBars(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= points.length) return null;
                final date = points[index].date;
                final dateLabel = range == AnalyticsRange.year
                    ? DateFormat('MMMM yyyy').format(date)
                    : DateFormat('MMM d, yyyy').format(date);

                if (metric == ChartMetric.revenue) {
                  return LineTooltipItem(
                    '$dateLabel\nRevenue: ₹${spot.y.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                } else if (metric == ChartMetric.orders) {
                  return LineTooltipItem(
                    '$dateLabel\nOrders: ${spot.y.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                } else {
                  final kind = spot.barIndex == 0 ? 'Scans' : 'Views';
                  return LineTooltipItem(
                    '$dateLabel\n$kind: ${spot.y.toInt()}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineBars() {
    if (metric == ChartMetric.revenue) {
      return [
        _line(
          color: const Color(0xFF10B981),
          values: points.map((p) => p.revenue.toDouble()).toList(),
        ),
      ];
    } else if (metric == ChartMetric.orders) {
      return [
        _line(
          color: AppColors.primaryOrange,
          values: points.map((p) => p.orders.toDouble()).toList(),
        ),
      ];
    } else {
      return [
        _line(
          color: AppColors.info,
          values: points.map((p) => p.scans.toDouble()).toList(),
        ),
        _line(
          color: AppColors.primaryOrange,
          values: points.map((p) => p.views.toDouble()).toList(),
        ),
      ];
    }
  }

  LineChartBarData _line({
    required Color color,
    required List<double> values,
  }) {
    return LineChartBarData(
      spots: List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.15),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.product,
    required this.maxMetric,
  });

  final int rank;
  final TopProductAnalyticsModel product;
  final int maxMetric;

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB800);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.mediumGray;
    }
  }

  String get _rankBadge {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final comparisonMetric = product.orderCount > 0 ? product.orderCount : product.scans;
    final progress = maxMetric == 0 ? 0.0 : (comparisonMetric / maxMetric).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: rank <= 3 ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              _rankBadge,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: rank <= 3 ? 15 : 12,
                color: rank <= 3 ? _rankColor : AppColors.mediumGray,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (product.orderCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.orderCount} ordered',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${product.scans} scans',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGray,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    color: product.orderCount > 0
                        ? const Color(0xFF10B981)
                        : AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (product.totalRevenue > 0)
                      Text(
                        'Sales: ₹${product.totalRevenue.toLocaleString()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      )
                    else
                      Text(
                        '${product.views} views · ${product.conversionRate.toStringAsFixed(0)}% conversion',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    if (product.scans > 0 && product.orderCount > 0)
                      Text(
                        '${product.scans} scans · ${product.views} views',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mediumGray,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on int {
  String toLocaleString() {
    try {
      final f = NumberFormat('#,##,###');
      return f.format(this);
    } catch (_) {
      return toString();
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mediumGray),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
