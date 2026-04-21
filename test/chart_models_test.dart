import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show ChartSeries, buildTotalSpots, toDayKey;

void main() {
  group('ChartSeries', () {
    test('stores fields correctly', () {
      final series = ChartSeries(
        key: 'asset_market:1',
        name: 'VWCE',
        color: Colors.blue,
        spots: [const FlSpot(0, 100), const FlSpot(10, 120)],
      );
      expect(series.key, 'asset_market:1');
      expect(series.name, 'VWCE');
      expect(series.color, Colors.blue);
      expect(series.spots.length, 2);
      expect(series.isDashed, false);
      expect(series.rightAxis, false);
    });

    test('isDashed and rightAxis flags work', () {
      final series = ChartSeries(
        key: 'cf:vel',
        name: 'Velocity',
        color: Colors.red,
        spots: [],
        isDashed: true,
        rightAxis: true,
      );
      expect(series.isDashed, true);
      expect(series.rightAxis, true);
    });
  });

  group('buildTotalSpots', () {
    test('returns empty for empty input', () {
      expect(buildTotalSpots([]), isEmpty);
    });

    test('single series returns same spots', () {
      final spots = [const FlSpot(0, 10), const FlSpot(5, 20)];
      final total = buildTotalSpots([spots]);
      expect(total.length, 2);
      expect(total[0].y, 10);
      expect(total[1].y, 20);
    });

    test('two series sums values at same x', () {
      final s1 = [const FlSpot(0, 10), const FlSpot(5, 20)];
      final s2 = [const FlSpot(0, 5), const FlSpot(5, 15)];
      final total = buildTotalSpots([s1, s2]);
      expect(total.length, 2);
      expect(total[0].y, 15); // 10 + 5
      expect(total[1].y, 35); // 20 + 15
    });

    test('carry-forward fills gaps', () {
      final s1 = [const FlSpot(0, 10), const FlSpot(5, 20)];
      final s2 = [const FlSpot(0, 5)]; // no value at x=5
      final total = buildTotalSpots([s1, s2]);
      expect(total.length, 2);
      expect(total[0].y, 15); // 10 + 5
      expect(total[1].y, 25); // 20 + 5 (carry-forward)
    });
  });

  group('toDayKey', () {
    test('truncates to midnight epoch seconds', () {
      final dt = DateTime(2024, 6, 15, 14, 30, 45);
      final key = toDayKey(dt);
      final midnight = DateTime(2024, 6, 15).millisecondsSinceEpoch ~/ 1000;
      expect(key, midnight);
    });

    test('same day different times produce same key', () {
      final a = toDayKey(DateTime(2024, 1, 1, 0, 0, 0));
      final b = toDayKey(DateTime(2024, 1, 1, 23, 59, 59));
      expect(a, b);
    });
  });
}
