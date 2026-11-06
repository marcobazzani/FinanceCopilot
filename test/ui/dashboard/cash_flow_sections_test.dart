// The Cash Flow sections under the overview: Year by year (a chart of totals
// or of monthly averages, or a table), Month by month (each year a line or a
// bar per month, a year's name hiding it) and Trends (the moving averages,
// their window typed in). Tooltips name the year, the month and the figures.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show ChartCard;

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester);
    await tester.tap(f);
    await h.settle(tester);
  }

  group('Year by year', () {
    testWidgets('totals or monthly averages, and a bar\'s tooltip names the year and its three figures', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final tile = await h.cashFlowSection(tester, 'cfYearByYearTile');
        final chart = tester.widget<BarChart>(find.descendant(of: tile, matching: find.byType(BarChart)).first).data;
        final y2025 = chart.barGroups[1];
        final tip = chart.barTouchData.touchTooltipData.getTooltipItem(y2025, 1, y2025.barRods.first, 0)!.text;
        expect(tip, startsWith('2025\n'));
        for (final figure in [s.legendIncome, s.legendExpenses, s.legendSavings]) {
          expect(tip, contains('$figure: '));
        }
        expect(
          chart.barTouchData.touchTooltipData.getTooltipItem(chart.barGroups[2], 2, chart.barGroups[2].barRods.first, 0)!.text,
          startsWith('2026*\n'),
          reason: 'the year so far',
        );

        await h.cashFlowSection(tester, 'cfYearByYearTile', pick: [s.cfMonthlyAverage]);
        expect(find.descendant(of: tile, matching: find.text(s.legendAvgMonthlyIncome)), findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text(s.legendIncome)), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('Month by month', () {
    testWidgets('as bars: a group per month, a bar per year; a year\'s name hides it, all hidden says so', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final tile = await h.cashFlowSection(tester, 'cfMonthByMonthTile', pick: [s.cfChartBars]);
        BarChartData bars() => tester.widget<BarChart>(find.descendant(of: tile, matching: find.byType(BarChart))).data;
        expect(bars().barGroups.length, 12);
        expect(bars().barGroups.map((g) => g.barRods.length).toSet(), {3}, reason: '2024, 2025 and 2026');
        final february = bars().barGroups[1];
        expect(february.barRods[1].toY, 3000, reason: 'the 2025 salary');
        final tip = bars().barTouchData.touchTooltipData.getTooltipItem(february, 1, february.barRods[1], 1)!.text;
        expect(tip, startsWith('2025 Feb\n'));

        await tap(tester, find.descendant(of: tile, matching: find.text('2025')));
        expect(bars().barGroups.map((g) => g.barRods.length).toSet(), {2});
        await tap(tester, find.descendant(of: tile, matching: find.text('2024')));
        await tap(tester, find.descendant(of: tile, matching: find.text('2026')));
        expect(find.descendant(of: tile, matching: find.text(s.allSeriesHidden)), findsOneWidget);
        expect(find.descendant(of: tile, matching: find.byType(BarChart)), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('as lines: a line per year, its tooltip the year, the month and the amount', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final tile = await h.cashFlowSection(tester, 'cfMonthByMonthTile');
        final lines = tester.widget<LineChart>(find.descendant(of: tile, matching: find.byType(LineChart))).data;
        final y2025 = lines.lineBarsData.firstWhere((b) => b.spots.length == 12 && b.spots.every((p) => p.y == 3000));
        final june = y2025.spots[5];
        final tip = lines.lineTouchData.touchTooltipData
            .getTooltipItems([LineBarSpot(y2025, lines.lineBarsData.indexOf(y2025), june)])
            .single!
            .text;
        expect(tip, startsWith('2025 Jun\n'));
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('Trends', () {
    testWidgets('closed until opened; a moving-average window typed in redraws its chart', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        expect(find.byType(ChartCard), findsNothing, reason: 'closed by default');
        final tile = await h.cashFlowSection(tester, 'cfTrendsTile');
        expect(find.descendant(of: tile, matching: find.byType(ChartCard)), findsNWidgets(3));
        List<FlSpot> movingAverage() =>
            tester.widgetList<ChartCard>(find.byType(ChartCard)).expand((c) => c.series).singleWhere((x) => x.key == 'cf:saving_ma').spots;
        final before = movingAverage();
        final window = find.descendant(of: find.byType(ChartCard).first, matching: find.byType(TextField));
        await tester.ensureVisible(window);
        await h.settle(tester);
        await tester.enterText(window, '7');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await h.settle(tester);
        expect(movingAverage(), isNot(equals(before)), reason: 'a 7-day window, not the default one');
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
