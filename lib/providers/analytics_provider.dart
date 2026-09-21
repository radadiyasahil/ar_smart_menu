import 'package:flutter/foundation.dart';

import '../core/services/analytics_service.dart';
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

  Future<void> load({AnalyticsRange? range, bool force = false}) async {
    if (_isLoading) return;
    if (!force && _isLoaded && range == null) return;

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

      _overview = results[0] as AnalyticsOverviewModel;
      _chartPoints = results[1] as List<AnalyticsChartPointModel>;
      _topProducts = results[2] as List<TopProductAnalyticsModel>;
      _isLoaded = true;
    } catch (e) {
      _error = formatApiError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);
}
