// The full-screen chart follows privacy mode while it is open. It used to take
// the flag once, when the chart card pushed it: privacy switched on from
// anywhere else (a global shortcut) left the open chart's amounts readable,
// and switched off left them masked.
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

  final fullscreen = find.byType(FullscreenChartScreen);
  Finder inFullscreen(Finder f) => find.descendant(of: fullscreen, matching: f);
  // The drag readout's second line: "€<value> – €<value>".
  final valueRange = inFullscreen(find.textContaining(RegExp('€[0-9,]+ – €')));

  /// Pumps a dashboard chart card and opens its full-screen chart; returns
  /// the provider container.
  Future<ProviderContainer> openFullscreen(WidgetTester tester, {required bool privateAtOpen}) async {
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
          privacyModeProvider.overrideWith((ref) => privateAtOpen),
        ],
        child: MaterialApp(home: Scaffold(body: card)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(tester.element(find.byWidget(card)));
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(fullscreen, findsOneWidget);
    return container;
  }

  bool chartIsPrivate(WidgetTester tester) => tester.widget<UnifiedChart>(inFullscreen(find.byType(UnifiedChart))).isPrivate;

  /// The value-axis labels of the full-screen chart.
  Finder valueAxis() => inFullscreen(find.descendant(of: find.byType(LineChart), matching: find.textContaining('€')));

  Future<TestGesture> dragAcross(WidgetTester tester) async {
    final center = tester.getCenter(inFullscreen(find.byType(LineChart)));
    final gesture = await tester.startGesture(center - const Offset(150, 80), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(center + const Offset(150, 80));
    await tester.pump();
    return gesture;
  }

  Future<void> release(WidgetTester tester, TestGesture gesture) async {
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('privacy switched on while the chart is open masks it at once', (tester) async {
    final container = await openFullscreen(tester, privateAtOpen: false);
    expect(chartIsPrivate(tester), isFalse);
    expect(valueAxis(), findsWidgets);
    expect(masked(valueAxis().first), isFalse);

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    expect(chartIsPrivate(tester), isTrue, reason: 'the open chart follows privacy mode');
    for (final label in valueAxis().evaluate()) {
      expect(masked(find.byElementPredicate((e) => e == label)), isTrue, reason: 'the value axis is position size');
    }
    final gesture = await dragAcross(tester);
    expect(valueRange, findsOneWidget);
    expect(masked(valueRange), isTrue, reason: 'the drag readout follows privacy mode too');
    await release(tester, gesture);
  });

  testWidgets('privacy switched off while the chart is open unmasks it', (tester) async {
    final container = await openFullscreen(tester, privateAtOpen: true);
    expect(chartIsPrivate(tester), isTrue);

    container.read(privacyModeProvider.notifier).state = false;
    await tester.pump();
    expect(chartIsPrivate(tester), isFalse);
    expect(valueAxis(), findsWidgets);
    for (final label in valueAxis().evaluate()) {
      expect(masked(find.byElementPredicate((e) => e == label)), isFalse);
    }
    final gesture = await dragAcross(tester);
    expect(masked(valueRange), isFalse);
    await release(tester, gesture);
  });
}
