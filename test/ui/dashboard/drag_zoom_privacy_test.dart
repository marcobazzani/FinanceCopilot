// The drag-to-zoom readout names the value range under the selection. On a
// money chart that range is the size of the position, so privacy mode must
// mask it — while the date range, which says nothing about how much is held,
// stays readable. A unit-price chart of a listed instrument shows public
// market data and stays readable in full (covered with the asset screen).
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/fullscreen_chart_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  final firstDate = DateTime(2026, 1, 1);
  const spots = [FlSpot(0, 1000), FlSpot(30, 1500), FlSpot(60, 1200), FlSpot(90, 2000)];
  final series = [ChartSeries(key: 'asset_market:1', name: 'Fund', color: const Color(0xFF2196F3), spots: spots)];

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  // The readout is two lines: "<date> – <date>" and "€<value> – €<value>".
  final dateRange = find.textContaining(RegExp(r'\d{4} – '));
  final valueRange = find.textContaining(RegExp('€[0-9,]+ – €'));

  /// Mouse-drags a selection rectangle across the middle of [area] and leaves
  /// the button down, so the readout stays on screen.
  Future<TestGesture> dragAcross(WidgetTester tester, Finder area) async {
    final center = tester.getCenter(area);
    final gesture = await tester.startGesture(center - const Offset(150, 80), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(center + const Offset(150, 80));
    await tester.pump();
    return gesture;
  }

  Future<void> release(WidgetTester tester, TestGesture gesture) async {
    await gesture.up();
    // Let the double-tap / long-press recognizers' timers run out.
    await tester.pump(const Duration(seconds: 1));
  }

  /// Pumps a dashboard chart card and returns its provider container.
  Future<ProviderContainer> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final card = ChartCard(
      chart: DashboardChart(id: 1, title: 'Portfolio', widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate),
      series: series,
      allData: AllSeriesData(
        firstDate: firstDate,
        accounts: const [],
        assetInvested: const [],
        assetMarket: series,
        assetGain: const [],
        assetNet: const [],
        adjustments: const [],
        incomeAdjustments: const [],
        ephemeralInflows: const [],
        baseCurrency: 'EUR',
      ),
      hidden: const {},
      locale: 'en_US',
      language: 'en_US',
      chartHeight: 420,
      onToggle: (_) {},
      onToggleGroup: (_) {},
      onToggleHideComponents: () {},
      onZoom: (_, _, _, _) {},
      onHeightChanged: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: Scaffold(body: card)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byWidget(card)));
  }

  testWidgets('dashboard chart card: privacy masks the value range of the drag readout, not its dates', (tester) async {
    final container = await pumpCard(tester);

    var gesture = await dragAcross(tester, find.byType(LineChart));
    expect(valueRange, findsOneWidget);
    expect(masked(valueRange), isFalse, reason: 'nothing is masked before privacy is on');
    await release(tester, gesture);

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    gesture = await dragAcross(tester, find.byType(LineChart));
    expect(dateRange, findsOneWidget);
    expect(valueRange, findsOneWidget);
    expect(masked(valueRange), isTrue, reason: 'the value range of a money chart is position size');
    expect(masked(dateRange), isFalse, reason: 'dates carry no magnitude');
    await release(tester, gesture);
  });

  testWidgets('full-screen chart opened from the card: privacy masks the value range of the drag readout, not its dates', (
    tester,
  ) async {
    final container = await pumpCard(tester);
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenChartScreen), findsOneWidget);

    final gesture = await dragAcross(tester, find.byType(LineChart).last);
    expect(dateRange, findsOneWidget);
    expect(valueRange, findsOneWidget);
    expect(masked(valueRange), isTrue, reason: 'the value range of a money chart is position size');
    expect(masked(dateRange), isFalse, reason: 'dates carry no magnitude');
    await release(tester, gesture);
  });
}
