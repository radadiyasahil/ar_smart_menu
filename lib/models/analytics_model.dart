class AnalyticsOverviewModel {
  const AnalyticsOverviewModel({
    required this.totalScans,
    required this.totalViews,
    required this.uniqueVisitors,
    required this.conversionRate,
    this.totalOrders = 0,
    this.totalRevenue = 0,
    this.averageOrderValue = 0,
  });

  final int totalScans;
  final int totalViews;
  final int uniqueVisitors;
  final double conversionRate;
  final int totalOrders;
  final int totalRevenue;
  final double averageOrderValue;

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverviewModel(
      totalScans: json['totalScans'] as int? ?? 0,
      totalViews: json['totalViews'] as int? ?? 0,
      uniqueVisitors: json['uniqueVisitors'] as int? ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      totalRevenue: json['totalRevenue'] as int? ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalScans': totalScans,
        'totalViews': totalViews,
        'uniqueVisitors': uniqueVisitors,
        'conversionRate': conversionRate,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'averageOrderValue': averageOrderValue,
      };
}

class AnalyticsChartPointModel {
  const AnalyticsChartPointModel({
    required this.date,
    required this.scans,
    required this.views,
    this.orders = 0,
    this.revenue = 0,
  });

  final DateTime date;
  final int scans;
  final int views;
  final int orders;
  final int revenue;

  factory AnalyticsChartPointModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    return AnalyticsChartPointModel(
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      scans: json['scans'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      orders: json['orders'] as int? ?? 0,
      revenue: json['revenue'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'scans': scans,
        'views': views,
        'orders': orders,
        'revenue': revenue,
      };
}

class TopProductAnalyticsModel {
  const TopProductAnalyticsModel({
    required this.productId,
    required this.productName,
    required this.scans,
    required this.views,
    required this.conversionRate,
    this.orderCount = 0,
    this.totalRevenue = 0,
  });

  final String productId;
  final String productName;
  final int scans;
  final int views;
  final double conversionRate;
  final int orderCount;
  final int totalRevenue;

  factory TopProductAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return TopProductAnalyticsModel(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName'] as String? ?? 'Unknown',
      scans: json['scans'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
      orderCount: json['orderCount'] as int? ?? 0,
      totalRevenue: json['totalRevenue'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'scans': scans,
        'views': views,
        'conversionRate': conversionRate,
        'orderCount': orderCount,
        'totalRevenue': totalRevenue,
      };
}

class AnalyticsDashboardModel {
  const AnalyticsDashboardModel({
    required this.overview,
    required this.chart,
    required this.topProducts,
  });

  final AnalyticsOverviewModel overview;
  final List<AnalyticsChartPointModel> chart;
  final List<TopProductAnalyticsModel> topProducts;

  factory AnalyticsDashboardModel.fromJson(Map<String, dynamic> json) {
    final chartRaw = json['chart'] as List<dynamic>? ?? const [];
    final topRaw = json['topProducts'] as List<dynamic>? ?? const [];
    return AnalyticsDashboardModel(
      overview: AnalyticsOverviewModel.fromJson(
        json['overview'] as Map<String, dynamic>? ?? const {},
      ),
      chart: chartRaw
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsChartPointModel.fromJson)
          .toList(growable: false),
      topProducts: topRaw
          .whereType<Map<String, dynamic>>()
          .map(TopProductAnalyticsModel.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'overview': overview.toJson(),
        'chart': chart.map((c) => c.toJson()).toList(growable: false),
        'topProducts': topProducts.map((t) => t.toJson()).toList(growable: false),
      };
}

enum AnalyticsRange {
  today('today', 'Today'),
  week('7d', 'This Week'),
  month('30d', 'This Month'),
  year('365d', 'This Year');

  const AnalyticsRange(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
