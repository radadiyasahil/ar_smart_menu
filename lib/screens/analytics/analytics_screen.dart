import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/analytics_model.dart';
import '../../providers/analytics_provider.dart';
import '../../widgets/common/gradient_card.dart';

/// Menu analytics — QR scans, AR views, and top dishes from `/api/analytics/*`.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      onRetry: () => analytics.load(force: true),
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
    final conversion = analytics.overview?.conversionRate ?? 0;
    final scans = analytics.overview?.totalScans ?? 0;

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
                      'Menu Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'QR scans, 3D views & dish performance',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                  ],
                ),
              ),
              if (analytics.isLoading && analytics.isLoaded)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GradientCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan → view conversion',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${conversion.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$scans QR scans in selected period',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Row(
          children: AnalyticsRange.values.map((option) {
            final selected = analytics.range == option;
            return Expanded(
              child: GestureDetector(
                onTap: () => analytics.load(range: option, force: true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
        AppSpacing.md,
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
            icon: Icons.qr_code_scanner_rounded,
            label: 'QR Scans',
            value: '${data.totalScans}',
            color: AppColors.info,
          ),
          _KpiTile(
            icon: Icons.view_in_ar_rounded,
            label: '3D / AR Views',
            value: '${data.totalViews}',
            color: AppColors.primaryOrange,
          ),
          _KpiTile(
            icon: Icons.people_outline_rounded,
            label: 'Unique visitors',
            value: '${data.uniqueVisitors}',
            color: AppColors.success,
          ),
          _KpiTile(
            icon: Icons.percent_rounded,
            label: 'Conversion',
            value: '${data.conversionRate.toStringAsFixed(1)}%',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(AnalyticsProvider analytics) {
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
              const Text(
                'Activity over time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Daily QR scans vs 3D menu views',
                style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _LegendDot(color: AppColors.info, label: 'Scans'),
                  const SizedBox(width: AppSpacing.md),
                  _LegendDot(color: AppColors.primaryOrange, label: 'Views'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 220,
                child: analytics.chartPoints.isEmpty
                    ? const Center(
                        child: Text(
                          'No activity yet — share your QR codes to get data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      )
                    : _AnalyticsLineChart(points: analytics.chartPoints),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopProducts(List<TopProductAnalyticsModel> products) {
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
              const Text(
                'Top dishes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Ranked by QR scans in this period',
                style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'No dish data yet. Publish products and share QR codes.',
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
                    maxScans: products.first.scans,
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
      ],
    );
  }
}

class _AnalyticsLineChart extends StatelessWidget {
  const _AnalyticsLineChart({required this.points});

  final List<AnalyticsChartPointModel> points;

  @override
  Widget build(BuildContext context) {
    final maxY = points
        .map((p) => p.scans > p.views ? p.scans : p.views)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final yMax = maxY == 0 ? 5.0 : (maxY * 1.2).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
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
              reservedSize: 28,
              interval: yMax / 4,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.mediumGray,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: points.length > 14 ? 5 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final date = points[index].date;
                final label = points.length <= 7
                    ? DateFormat('EEE').format(date)
                    : DateFormat('d MMM').format(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: TextStyle(
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
        lineBarsData: [
          _line(
            color: AppColors.info,
            values: points.map((p) => p.scans.toDouble()).toList(),
          ),
          _line(
            color: AppColors.primaryOrange,
            values: points.map((p) => p.views.toDouble()).toList(),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                final date = points[index].date;
                final label = DateFormat('MMM d').format(date);
                final kind = spot.barIndex == 0 ? 'Scans' : 'Views';
                return LineTooltipItem(
                  '$label\n$kind: ${spot.y.toInt()}',
                  const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
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
        color: color.withValues(alpha: 0.12),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.rank,
    required this.product,
    required this.maxScans,
  });

  final int rank;
  final TopProductAnalyticsModel product;
  final int maxScans;

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

  @override
  Widget build(BuildContext context) {
    final progress = maxScans == 0 ? 0.0 : product.scans / maxScans;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
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
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
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
                  children: [
                    Expanded(
                      child: Text(
                        product.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${product.scans} scans',
                      style: TextStyle(
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
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.views} views · ${product.conversionRate.toStringAsFixed(0)}% conversion',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            style: TextStyle(color: AppColors.mediumGray),
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
