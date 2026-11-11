import 'package:flutter/foundation.dart';

import '../core/services/analytics_service.dart';
import '../core/services/billing_service.dart';
import '../core/utils/api_error_utils.dart';
import '../models/analytics_model.dart';

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider({AnalyticsService? analyticsService})
      : _analyticsService = analyticsService ?? AnalyticsService();

  final AnalyticsService _analyticsService;

  AnalyticsRange _range = AnalyticsRange.week;
  AnalyticsOverviewModel? _overview;
  List<AnalyticsChartPointModel> _chartPoints = [];
  List<TopProductAnalyticsModel> _topProducts = [];
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;
  String? _currentBusinessId;
  bool _isBusinessActive = false;

  AnalyticsRange get range => _range;
  AnalyticsOverviewModel? get overview => _overview;
  List<AnalyticsChartPointModel> get chartPoints =>
      List.unmodifiable(_chartPoints);
  List<TopProductAnalyticsModel> get topProducts =>
      List.unmodifiable(_topProducts);
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  int get totalScans => _overview?.totalScans ?? 0;
  int get totalOrders => _overview?.totalOrders ?? 0;
  int get totalRevenue => _overview?.totalRevenue ?? 0;
  double get averageOrderValue => _overview?.averageOrderValue ?? 0;

  void clear() {
    _overview = null;
    _chartPoints = [];
    _topProducts = [];
    _isLoading = false;
    _isLoaded = false;
    _error = null;
    _currentBusinessId = null;
    _isBusinessActive = false;
    notifyListeners();
  }

  Future<void> load({
    AnalyticsRange? range,
    bool force = false,
    String? businessId,
    bool isBusinessActive = true,
  }) async {
    // If not approved or business is not active, never fetch or leak analytics
    if (!isBusinessActive || businessId == null || businessId.isEmpty) {
      clear();
      return;
    }

    if (_isLoading) return;
    if (!force && _isLoaded && range == null && _currentBusinessId == businessId) return;

    _currentBusinessId = businessId;
    _isBusinessActive = isBusinessActive;

    if (range != null) {
      _range = range;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final apiRange = _range.apiValue;
      final results = await Future.wait([
        _analyticsService.getOverview(range: apiRange),
        _analyticsService.getChart(range: apiRange),
        _analyticsService.getTopProducts(range: apiRange),
      ]);

      var ov = results[0] as AnalyticsOverviewModel;
      var cp = List<AnalyticsChartPointModel>.from(
          results[1] as List<AnalyticsChartPointModel>);
      var tp = List<TopProductAnalyticsModel>.from(
          results[2] as List<TopProductAnalyticsModel>);

      // Merge with completed local bills only for THIS specific business
      try {
        final localBills = await BillingService().getCompletedHistory(businessId);
        if (localBills.isNotEmpty) {
          final now = DateTime.now();
          DateTime cutoff;
          switch (_range) {
            case AnalyticsRange.today:
              cutoff = DateTime(now.year, now.month, now.day);
              break;
            case AnalyticsRange.week:
              cutoff = DateTime(now.year, now.month, now.day)
                  .subtract(const Duration(days: 6));
              break;
            case AnalyticsRange.month:
              cutoff = DateTime(now.year, now.month, now.day)
                  .subtract(const Duration(days: 29));
              break;
            case AnalyticsRange.year:
              cutoff = DateTime(now.year, now.month, now.day)
                  .subtract(const Duration(days: 364));
              break;
          }

          final filteredBills = localBills.where((b) {
            final dt = b.paidAt ?? b.createdAt;
            return dt.isAfter(cutoff) || dt.isAtSameMomentAs(cutoff);
          }).toList();

          if (filteredBills.isNotEmpty) {
            final localOrdersCount = filteredBills.length;
            final localRevenueSum =
                filteredBills.fold<int>(0, (sum, b) => sum + b.grandTotal);

            // Use the maximum of backend vs local so all sales are represented
            final bestOrders = ov.totalOrders > localOrdersCount
                ? ov.totalOrders
                : localOrdersCount;
            final bestRevenue = ov.totalRevenue > localRevenueSum
                ? ov.totalRevenue
                : localRevenueSum;
            final bestAov = bestOrders > 0 ? (bestRevenue / bestOrders) : 0.0;

            ov = AnalyticsOverviewModel(
              totalScans: ov.totalScans,
              totalViews: ov.totalViews,
              uniqueVisitors: ov.uniqueVisitors,
              conversionRate: ov.conversionRate,
              totalOrders: bestOrders,
              totalRevenue: bestRevenue,
              averageOrderValue: bestAov,
            );

            // If backend returned no top dishes with order count, aggregate from local bills
            if (tp.every((p) => p.orderCount == 0)) {
              final dishMap = <String, Map<String, dynamic>>{};
              for (final bill in filteredBills) {
                for (final item in bill.items) {
                  final k = item.name.trim().toLowerCase();
                  if (dishMap.containsKey(k)) {
                    dishMap[k]!['count'] = (dishMap[k]!['count'] as int) + item.quantity;
                    dishMap[k]!['revenue'] = (dishMap[k]!['revenue'] as int) + item.total;
                  } else {
                    dishMap[k] = {
                      'name': item.name,
                      'count': item.quantity,
                      'revenue': item.total,
                    };
                  }
                }
              }

              if (dishMap.isNotEmpty) {
                final localTop = dishMap.values.map((d) {
                  return TopProductAnalyticsModel(
                    productId: '',
                    productName: d['name'] as String,
                    scans: 0,
                    views: 0,
                    conversionRate: 0,
                    orderCount: d['count'] as int,
                    totalRevenue: d['revenue'] as int,
                  );
                }).toList();

                localTop.sort((a, b) => b.orderCount.compareTo(a.orderCount));
                tp = localTop.take(15).toList();
              }
            }
          }
        }
      } catch (err) {
        debugPrint('Could not merge local history analytics: $err');
      }

      _overview = ov;
      _chartPoints = cp;
      _topProducts = tp;
      _isLoaded = true;
    } catch (e) {
      _error = formatApiError(e);
      _overview = null;
      _chartPoints = [];
      _topProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(
        force: true,
        businessId: _currentBusinessId,
        isBusinessActive: _isBusinessActive,
      );
}
