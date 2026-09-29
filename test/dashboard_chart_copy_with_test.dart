// DashboardChart.copyWith keeps its sentinel API for the one nullable field:
// omitted keeps the value, an explicit null clears it, a string replaces it.
// Anything else is refused with an ArgumentError naming the field instead of
// failing on an `as String?` cast.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/models/dashboard_chart.dart';

void main() {
  final chart = DashboardChart(
    id: -1,
    title: 'Cash',
    widgetType: 'cash',
    sortOrder: 0,
    seriesJson: '[]',
    sourceChartIds: '*',
    createdAt: DateTime(2026, 1, 1),
  );

  test('source charts: omitted keeps, null clears, a string replaces', () {
    expect(chart.copyWith().sourceChartIds, '*');
    expect(chart.copyWith(title: 'Other').sourceChartIds, '*');
    expect(chart.copyWith(sourceChartIds: null).sourceChartIds, isNull);
    expect(chart.copyWith(sourceChartIds: '["Cash"]').sourceChartIds, '["Cash"]');
  });

  test('the other fields: given replaces, omitted keeps', () {
    final moved = chart.copyWith(id: 7, sortOrder: 3);

    expect(moved, isNot(chart));
    expect(
      (moved.id, moved.sortOrder, moved.title, moved.widgetType, moved.seriesJson, moved.createdAt),
      (7, 3, 'Cash', 'cash', '[]', DateTime(2026, 1, 1)),
    );
    expect(chart.copyWith(), chart);
  });

  test('source charts that are not a string are refused, naming the field', () {
    expect(() => chart.copyWith(sourceChartIds: 42), throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'sourceChartIds')));
    expect(() => chart.copyWith(sourceChartIds: ['Cash']), throwsArgumentError);
  });
}
