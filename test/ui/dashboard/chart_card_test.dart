// ChartCard branches that depended on the machine running the integration
// walkthrough: whether some chart happened to have fewer than two points
// (live data), and which theme the OS was in (the host's dark/light mode).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  final firstDate = DateTime(2026, 1, 1);
  final chart = DashboardChart(id: 1, title: 'Portfolio', widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate);

  AllSeriesData allData(List<ChartSeries> market) => AllSeriesData(
    firstDate: firstDate,
    accounts: const [],
    assetInvested: const [],
    assetMarket: market,
    assetGain: const [],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );

  Future<void> pumpCard(WidgetTester tester, List<FlSpot> spots, {ThemeData? theme}) async {
    final series = [ChartSeries(key: 'asset_market:1', name: 'Fund', color: const Color(0xFF2196F3), spots: spots)];
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ChartCard(
              chart: chart,
              series: series,
              allData: allData(series),
              hidden: const {},
              locale: 'en_US',
              language: 'en_US',
              chartHeight: 420,
              onToggle: (_) {},
              onToggleGroup: (_) {},
              onToggleHideComponents: () {},
              onZoom: (_, _, _, _) {},
              onHeightChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a single point is not plotted: the card says there is not enough data', (tester) async {
    await pumpCard(tester, const [FlSpot(0, 1000)]);
    expect(find.text('Not enough data to plot'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  group('Total line stays visible on either theme', () {
    const spots = [FlSpot(0, 1000), FlSpot(1, 1100)];

    Color totalLineColor(WidgetTester tester) => tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first.color!;

    testWidgets('light theme: primary colour', (tester) async {
      final light = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal));
      await pumpCard(tester, spots, theme: light);
      expect(find.text('Not enough data to plot'), findsNothing);
      expect(totalLineColor(tester), light.colorScheme.primary);
    });

    testWidgets('dark theme: white', (tester) async {
      await pumpCard(tester, spots, theme: ThemeData(brightness: Brightness.dark));
      expect(totalLineColor(tester), Colors.white);
    });
  });
}
