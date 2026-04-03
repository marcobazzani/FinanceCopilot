import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/chart_math.dart';

void main() {
  // ── densifySpots ──────────────────────────────────

  group('densifySpots', () {
    test('returns empty list for empty input', () {
      expect(densifySpots([]), isEmpty);
    });

    test('single spot returns single spot', () {
      final result = densifySpots([FlSpot(5, 10)]);
      expect(result.length, 1);
      expect(result.first.x, 5);
      expect(result.first.y, 10);
    });

    test('fills gaps between sparse spots via forward-fill', () {
      final spots = [FlSpot(0, 1), FlSpot(3, 4)];
      final result = densifySpots(spots);
      // Should produce spots at x = 0, 1, 2, 3
      expect(result.length, 4);
      expect(result[0].y, 1); // original
      expect(result[1].y, 1); // forward-filled
      expect(result[2].y, 1); // forward-filled
      expect(result[3].y, 4); // original
    });

    test('handles unsorted input', () {
      final spots = [FlSpot(2, 20), FlSpot(0, 10)];
      final result = densifySpots(spots);
      expect(result.length, 3);
      expect(result[0].x, 0);
      expect(result[0].y, 10);
      expect(result[2].x, 2);
      expect(result[2].y, 20);
    });
  });

  // ── computeMA ─────────────────────────────────────

  group('computeMA', () {
    test('returns empty for empty input', () {
      expect(computeMA([], 3), isEmpty);
    });

    test('window=1 returns densified values unchanged', () {
      final spots = [FlSpot(0, 2), FlSpot(1, 4), FlSpot(2, 6)];
      final result = computeMA(spots, 1);
      expect(result.length, 3);
      expect(result[0].y, 2);
      expect(result[1].y, 4);
      expect(result[2].y, 6);
    });

    test('3-day window on known data', () {
      // Values: 3, 6, 9, 12
      final spots = [FlSpot(0, 3), FlSpot(1, 6), FlSpot(2, 9), FlSpot(3, 12)];
      final result = computeMA(spots, 3);
      expect(result.length, 4);
      // i=0: sum=3, min(1,3)=1 -> 3/1 = 3
      expect(result[0].y, 3);
      // i=1: sum=9, min(2,3)=2 -> 9/2 = 4.5
      expect(result[1].y, 4.5);
      // i=2: sum=18, min(3,3)=3 -> 18/3 = 6
      expect(result[2].y, 6);
      // i=3: sum=18+12-3=27, 3 -> 27/3 = 9
      expect(result[3].y, 9);
    });
  });

  // ── computeVelocity ───────────────────────────────

  group('computeVelocity', () {
    test('returns empty for empty input', () {
      expect(computeVelocity([]), isEmpty);
    });

    test('returns empty for single spot', () {
      expect(computeVelocity([FlSpot(0, 5)]), isEmpty);
    });

    test('computes positive slope', () {
      final result = computeVelocity([FlSpot(0, 10), FlSpot(1, 15)]);
      expect(result.length, 1);
      expect(result[0].y, 5);
    });

    test('computes negative slope', () {
      final result = computeVelocity([FlSpot(0, 10), FlSpot(1, 7)]);
      expect(result.length, 1);
      expect(result[0].y, -3);
    });

    test('computes zero slope', () {
      final result = computeVelocity([FlSpot(0, 5), FlSpot(1, 5)]);
      expect(result.length, 1);
      expect(result[0].y, 0);
    });

    test('mixed slopes', () {
      final result = computeVelocity([FlSpot(0, 0), FlSpot(1, 10), FlSpot(2, 7)]);
      expect(result.length, 2);
      expect(result[0].y, 10);
      expect(result[1].y, -3);
    });
  });

  // ── buildSpendingFromSaving ───────────────────────

  group('buildSpendingFromSaving', () {
    test('returns empty for fewer than 2 dense spots', () {
      expect(buildSpendingFromSaving([]), isEmpty);
      expect(buildSpendingFromSaving([FlSpot(0, 100)]), isEmpty);
    });

    test('all positive deltas result in flat zero spending', () {
      final spots = [FlSpot(0, 10), FlSpot(1, 20), FlSpot(2, 30)];
      final result = buildSpendingFromSaving(spots);
      for (final s in result) {
        expect(s.y, 0);
      }
    });

    test('only counts negative deltas', () {
      // Day 0->1: +10 (skip), Day 1->2: -5 (cumul = -5), Day 2->3: -3 (cumul = -8)
      final spots = [FlSpot(0, 10), FlSpot(1, 20), FlSpot(2, 15), FlSpot(3, 12)];
      final result = buildSpendingFromSaving(spots);
      expect(result.length, 4);
      expect(result[0].y, 0);
      expect(result[1].y, 0);   // delta=+10, no accumulation
      expect(result[2].y, -5);  // delta=-5
      expect(result[3].y, -8);  // delta=-3
    });
  });

  // ── computeDiff ───────────────────────────────────

  group('computeDiff', () {
    test('returns empty if either input is empty', () {
      expect(computeDiff([], [FlSpot(0, 1)]), isEmpty);
      expect(computeDiff([FlSpot(0, 1)], []), isEmpty);
    });

    test('subtracts matching x values', () {
      final a = [FlSpot(0, 10), FlSpot(1, 20), FlSpot(2, 30)];
      final b = [FlSpot(0, 3), FlSpot(1, 5), FlSpot(2, 7)];
      final result = computeDiff(a, b);
      expect(result.length, 3);
      expect(result[0].y, 7);
      expect(result[1].y, 15);
      expect(result[2].y, 23);
    });

    test('handles different lengths (only overlapping x)', () {
      final a = [FlSpot(0, 10), FlSpot(1, 20), FlSpot(2, 30)];
      final b = [FlSpot(1, 5), FlSpot(2, 10)];
      final result = computeDiff(a, b);
      // a is densified from 0..2, b from 1..2
      // Overlap at x=1 and x=2
      expect(result.length, 2);
      expect(result[0].y, 15); // 20-5
      expect(result[1].y, 20); // 30-10
    });
  });
}
