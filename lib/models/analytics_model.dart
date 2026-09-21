class AnalyticsOverviewModel {
  const AnalyticsOverviewModel({
    required this.totalScans,
    required this.totalViews,
    required this.uniqueVisitors,
    required this.conversionRate,
  });

  final int totalScans;
  final int totalViews;
  final int uniqueVisitors;
  final double conversionRate;

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverviewModel(
      totalScans: json['totalScans'] as int? ?? 0,
      totalViews: json['totalViews'] as int? ?? 0,
      uniqueVisitors: json['uniqueVisitors'] as int? ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AnalyticsChartPointModel {
  const AnalyticsChartPointModel({
    required this.date,
    required this.scans,
    required this.views,
  });

  final DateTime date;
  final int scans;
  final int views;

  factory AnalyticsChartPointModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] as String? ?? '';
    return AnalyticsChartPointModel(
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
      scans: json['scans'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
    );
  }
}

class TopProductAnalyticsModel {
  const TopProductAnalyticsModel({
    required this.productId,
    required this.productName,
    required this.scans,
    required this.views,
    required this.conversionRate,
  });

  final String productId;
  final String productName;
  final int scans;
  final int views;
  final double conversionRate;

  factory TopProductAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return TopProductAnalyticsModel(
      productId: json['productId']?.toString() ?? '',
      productName: json['productName'] as String? ?? 'Unknown',
      scans: json['scans'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum AnalyticsRange {
  today('today', 'Today'),
  week('7d', '7 days'),
  month('30d', '30 days');

  const AnalyticsRange(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
