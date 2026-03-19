import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asset_manager/ui/screens/dashboard_screen.dart';

void main() {
  group('toDayKey', () {
    test('same day different times produce same key', () {
      final morning = DateTime(2024, 3, 15, 8, 30, 0);
      final evening = DateTime(2024, 3, 15, 22, 45, 59);
      final midnight = DateTime(2024, 3, 15, 0, 0, 0);

      expect(toDayKey(morning), toDayKey(evening));
      expect(toDayKey(morning), toDayKey(midnight));
    });

    test('different days produce different keys', () {
      final day1 = DateTime(2024, 3, 15);
      final day2 = DateTime(2024, 3, 16);
      final day3 = DateTime(2024, 1, 1);

      expect(toDayKey(day1), isNot(toDayKey(day2)));
      expect(toDayKey(day1), isNot(toDayKey(day3)));
    });
  });

  group('currencySymbol', () {
    test('EUR returns euro sign', () {
      expect(currencySymbol('EUR'), '€');
    });

    test('USD returns dollar sign', () {
      expect(currencySymbol('USD'), '\$');
    });

    test('GBP returns pound sign', () {
      expect(currencySymbol('GBP'), '£');
    });

    test('JPY returns yen sign', () {
      expect(currencySymbol('JPY'), '¥');
    });

    test('CHF returns CHF', () {
      expect(currencySymbol('CHF'), 'CHF');
    });

    test('unknown currency returns code as-is', () {
      expect(currencySymbol('SEK'), 'SEK');
      expect(currencySymbol('AUD'), 'AUD');
    });
  });

  group('buildTotalSpots', () {
    test('empty input returns empty', () {
      expect(buildTotalSpots([]), isEmpty);
    });

    test('single series returns same spots', () {
      final spots = [FlSpot(1, 10), FlSpot(2, 20), FlSpot(3, 30)];
      final result = buildTotalSpots([spots]);

      expect(result.length, 3);
      expect(result[0].x, 1);
      expect(result[0].y, 10);
      expect(result[1].x, 2);
      expect(result[1].y, 20);
      expect(result[2].x, 3);
      expect(result[2].y, 30);
    });

    test('two series with overlapping X values are summed', () {
      final seriesA = [FlSpot(1, 100), FlSpot(2, 200)];
      final seriesB = [FlSpot(1, 10), FlSpot(2, 20)];

      final result = buildTotalSpots([seriesA, seriesB]);

      expect(result.length, 2);
      expect(result[0].x, 1);
      expect(result[0].y, 110); // 100 + 10
      expect(result[1].x, 2);
      expect(result[1].y, 220); // 200 + 20
    });

    test('carry-forward: series A value carries forward to missing X in series B', () {
      // Series A has values at x=1, x=5
      // Series B has values at x=1, x=3, x=5
      // At x=3, series A should carry forward its value from x=1
      final seriesA = [FlSpot(1, 100), FlSpot(5, 500)];
      final seriesB = [FlSpot(1, 10), FlSpot(3, 30), FlSpot(5, 50)];

      final result = buildTotalSpots([seriesA, seriesB]);

      // All unique x values: 1, 3, 5
      expect(result.length, 3);

      // x=1: A=100, B=10 → 110
      expect(result[0].x, 1);
      expect(result[0].y, 110);

      // x=3: A carries 100 (last known), B=30 → 130
      expect(result[1].x, 3);
      expect(result[1].y, 130);

      // x=5: A=500, B=50 → 550
      expect(result[2].x, 5);
      expect(result[2].y, 550);
    });

    test('carry-forward: series B starts later than series A', () {
      // Series A starts at x=1, series B starts at x=5
      // Before x=5, series B contributes 0 (initial running value)
      final seriesA = [FlSpot(1, 100), FlSpot(3, 300)];
      final seriesB = [FlSpot(5, 50)];

      final result = buildTotalSpots([seriesA, seriesB]);

      // All unique x values: 1, 3, 5
      expect(result.length, 3);

      // x=1: A=100, B=0 (not started yet) → 100
      expect(result[0].x, 1);
      expect(result[0].y, 100);

      // x=3: A=300, B=0 → 300
      expect(result[1].x, 3);
      expect(result[1].y, 300);

      // x=5: A carries 300, B=50 → 350
      expect(result[2].x, 5);
      expect(result[2].y, 350);
    });
  });
}
