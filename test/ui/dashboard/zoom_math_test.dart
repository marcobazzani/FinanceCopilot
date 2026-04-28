import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  group('computeZoomedXRange', () {
    test('zooming 2x at centered focal halves the range and stays centered', () {
      final r = computeZoomedXRange(
        currentMinX: 0,
        currentMaxX: 100,
        focalPx: 460, // leftReserved=60 + 0.5 * chartWidth=800 → 50% across
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 2,
        panPx: 0,
        totalDays: 100,
      );
      expect(r.minX, closeTo(25, 1e-9));
      expect(r.maxX, closeTo(75, 1e-9));
    });

    test('zooming at a left-biased focal pulls the window toward that focal', () {
      // Focal at 25% of chart width: 60 + 0.25 * 800 = 260.
      final r = computeZoomedXRange(
        currentMinX: 0,
        currentMaxX: 100,
        focalPx: 260,
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 2,
        panPx: 0,
        totalDays: 100,
      );
      // focalChartX = 25; new range = 50; minX = 25 - 0.25*50 = 12.5
      expect(r.minX, closeTo(12.5, 1e-9));
      expect(r.maxX, closeTo(62.5, 1e-9));
    });

    test('panPx shifts both bounds by the same amount (no scale change)', () {
      // No zoom factor, but currentRange is below totalDays so panPx applies.
      final r = computeZoomedXRange(
        currentMinX: 25,
        currentMaxX: 75,
        focalPx: 460,
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 1,
        panPx: 20,
        totalDays: 100,
      );
      // dxUnits = 20 * 50/800 = 1.25; both bounds shift down by 1.25.
      expect(r.minX, closeTo(23.75, 1e-9));
      expect(r.maxX, closeTo(73.75, 1e-9));
      expect(r.maxX - r.minX, closeTo(50, 1e-9));
    });

    test('panning past the left edge clamps to 0 and preserves the span', () {
      final r = computeZoomedXRange(
        currentMinX: 25,
        currentMaxX: 75,
        focalPx: 460,
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 1,
        panPx: 50000,
        totalDays: 100,
      );
      expect(r.minX, 0);
      expect(r.maxX, closeTo(50, 1e-9));
    });

    test('panning past the right edge clamps to totalDays and preserves the span', () {
      final r = computeZoomedXRange(
        currentMinX: 25,
        currentMaxX: 75,
        focalPx: 460,
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 1,
        panPx: -50000,
        totalDays: 100,
      );
      expect(r.maxX, 100);
      expect(r.minX, closeTo(50, 1e-9));
    });

    test('zooming further out than totalDays returns the full range', () {
      final r = computeZoomedXRange(
        currentMinX: 25,
        currentMaxX: 75,
        focalPx: 460,
        leftReserved: 60,
        chartWidth: 800,
        scaleFactor: 0.1,
        panPx: 0,
        totalDays: 100,
      );
      expect(r.minX, 0);
      expect(r.maxX, 100);
    });
  });

  group('computeZoomedYRange', () {
    test('zooming 2x at centered focal halves the range and stays centered', () {
      final r = computeZoomedYRange(
        currentMinY: 0,
        currentMaxY: 100,
        focalPy: 300, // chartHeight=600 → fraction-from-bottom 0.5
        chartHeight: 600,
        scaleFactor: 2,
        panPy: 0,
      );
      expect(r.minY, closeTo(25, 1e-9));
      expect(r.maxY, closeTo(75, 1e-9));
    });

    test('positive panPy (mouse down) shifts the window up in chart units', () {
      final r = computeZoomedYRange(
        currentMinY: 25,
        currentMaxY: 75,
        focalPy: 300,
        chartHeight: 600,
        scaleFactor: 1,
        panPy: 12,
      );
      // dyUnits = 12 * 50/600 = 1.0
      expect(r.minY, closeTo(26, 1e-9));
      expect(r.maxY, closeTo(76, 1e-9));
    });

    test('Y has no clamping', () {
      final r = computeZoomedYRange(
        currentMinY: 0,
        currentMaxY: 100,
        focalPy: 300,
        chartHeight: 600,
        scaleFactor: 1,
        panPy: 100000,
      );
      // Far-pan moves the window up freely; no upper clamp.
      expect(r.minY, greaterThan(1000));
    });
  });
}
