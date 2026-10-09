// The chart card header reads the latest value of the chart's Total. With no
// Total to read — every series hidden, or no data behind them — it used to
// show "€0": a figure nobody holds. The value is unknown, so the header says
// "—"; privacy mode still masks a real total and has nothing to hide in the
// dash.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  final firstDate = DateTime(2026, 1, 1);
  ChartSeries fund(List<FlSpot> spots) => ChartSeries(key: 'asset_market:1', name: 'Fund', color: const Color(0xFF2196F3), spots: spots);

  Widget card(String title, List<ChartSeries> series, {Set<String> hidden = const {}}) => SizedBox(
    height: 420,
    child: ChartCard(
      chart: DashboardChart(id: title.hashCode, title: title, widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate),
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
      hidden: hidden,
      locale: 'en_US',
      language: 'en_US',
      chartHeight: 420,
      onToggle: (_) {},
      onToggleGroup: (_) {},
      onToggleHideComponents: () {},
      onZoom: (_, _, _, _) {},
      onHeightChanged: (_) {},
    ),
  );

  Future<ProviderContainer> pump(WidgetTester tester, List<Widget> cards) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final body = Column(children: cards);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byWidget(body)));
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('a chart with no data behind its series shows "—" as its total, not €0', (tester) async {
    await pump(tester, [
      card('Empty', [fund(const [])]),
    ]);
    expect(find.text('\u2014'), findsOneWidget);
    expect(find.text('€0'), findsNothing);
  });

  testWidgets('with every series hidden the total is unknown, not zero', (tester) async {
    await pump(tester, [
      card(
        'Hidden',
        [
          fund(const [FlSpot(0, 1000), FlSpot(1, 1100)]),
        ],
        hidden: const {'asset_market:1'},
      ),
    ]);
    expect(find.text('\u2014'), findsOneWidget);
    expect(find.text('€0'), findsNothing);
  });

  testWidgets('privacy mode masks a real total and leaves the dash readable', (tester) async {
    final container = await pump(tester, [
      card('Portfolio', [
        fund(const [FlSpot(0, 1000), FlSpot(1, 1234)]),
      ]),
      card('Empty', [fund(const [])]),
    ]);
    expect(find.text('€1,234'), findsOneWidget);
    expect(masked(find.text('€1,234')), isFalse, reason: 'privacy mode is off');

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(masked(find.text('€1,234')), isTrue, reason: 'a total is position size');
    expect(find.text('\u2014'), findsOneWidget);
    expect(masked(find.text('\u2014')), isFalse, reason: 'an unknown total carries no magnitude');
  });
}
