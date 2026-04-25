/// Plain dashboard-chart model. Used by the History tab loader / editor /
/// exporter. **Not** persisted to a database — chart configuration lives in
/// `assets/default_charts.json` only.
class DashboardChart {
  final int id;
  final String title;
  final String widgetType; // 'price_changes' | 'cash' | 'saving' | 'portfolio' | 'liquid_investments' | 'chart'
  final int sortOrder;
  final String seriesJson; // JSON array of {type, id, sign?}
  final String? sourceChartIds; // '*' | JSON list of int ids | JSON list of titles
  final DateTime createdAt;

  const DashboardChart({
    required this.id,
    required this.title,
    required this.widgetType,
    required this.sortOrder,
    required this.seriesJson,
    this.sourceChartIds,
    required this.createdAt,
  });

  DashboardChart copyWith({
    int? id,
    String? title,
    String? widgetType,
    int? sortOrder,
    String? seriesJson,
    Object? sourceChartIds = _sentinel,
    DateTime? createdAt,
  }) {
    return DashboardChart(
      id: id ?? this.id,
      title: title ?? this.title,
      widgetType: widgetType ?? this.widgetType,
      sortOrder: sortOrder ?? this.sortOrder,
      seriesJson: seriesJson ?? this.seriesJson,
      sourceChartIds: identical(sourceChartIds, _sentinel)
          ? this.sourceChartIds
          : sourceChartIds as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardChart &&
      other.id == id &&
      other.title == title &&
      other.widgetType == widgetType &&
      other.sortOrder == sortOrder &&
      other.seriesJson == seriesJson &&
      other.sourceChartIds == sourceChartIds;

  @override
  int get hashCode =>
      Object.hash(id, title, widgetType, sortOrder, seriesJson, sourceChartIds);
}

const Object _sentinel = Object();
