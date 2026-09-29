// The "smart" total of a chart follows one rule set wherever it is read: an
// asset's net series supersedes its invested and market series, a visible
// market series supersedes invested, and a right-axis series never counts.
// ChartCard (its header and plotted Total line) and the role resolvers behind
// Health, Cash Flow and the Totals table must agree on the same overlapping
// fixture.
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
  ChartSeries series(String key, List<FlSpot> spots, {bool rightAxis = false}) =>
      ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots, rightAxis: rightAxis);

  // Asset 5: invested, market and net all visible → only net counts.
  // Asset 6: invested and market → only market counts.
  // Asset 7: invested only → invested counts.
  // Asset 8: on the right axis → never counts, whatever its value.
  final account = series('account:1', const [FlSpot(0, 100), FlSpot(10, 200)]);
  final invested5 = series('asset_invested:5', const [FlSpot(0, 1000), FlSpot(10, 1000)]);
  final market5 = series('asset_market:5', const [FlSpot(0, 1100), FlSpot(10, 1300)]);
  final net5 = series('asset_net:5', const [FlSpot(0, 1050), FlSpot(10, 1200)]);
  final invested6 = series('asset_invested:6', const [FlSpot(0, 500), FlSpot(10, 500)]);
  final market6 = series('asset_market:6', const [FlSpot(0, 600), FlSpot(10, 700)]);
  final invested7 = series('asset_invested:7', const [FlSpot(0, 300)]);
  final market8RightAxis = series('asset_market:8', const [FlSpot(0, 99999), FlSpot(10, 99999)], rightAxis: true);
  final overlapping = [account, invested5, market5, net5, invested6, market6, invested7, market8RightAxis];

  // x=0:  100 + 1050 (net 5) + 600 (market 6) + 300 (invested 7)
  // x=10: 200 + 1200 (net 5) + 700 (market 6) + 300 (invested 7, carried forward)
  const expected = [FlSpot(0, 2050), FlSpot(10, 2400)];

  final allData = AllSeriesData(
    firstDate: firstDate,
    accounts: [account],
    assetInvested: [invested5, invested6, invested7],
    assetMarket: [market5, market6, market8RightAxis],
    assetGain: const [],
    assetNet: [net5],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
  );

  final roleChart = DashboardChart(
    id: 1,
    title: 'Portfolio',
    widgetType: 'portfolio',
    sortOrder: 0,
    seriesJson:
        '[{"type":"account","id":1},'
        '{"type":"asset_invested","id":5},{"type":"asset_market","id":5},{"type":"asset_net","id":5},'
        '{"type":"asset_invested","id":6},{"type":"asset_market","id":6},'
        '{"type":"asset_invested","id":7},{"type":"asset_market","id":8}]',
    createdAt: firstDate,
  );

  group('role resolvers', () {
    test('the role total follows the smart rules', () {
      expect(ChartRoles.spotsForRole('portfolio', [roleChart], allData, const []), expected);
      expect(ChartRoles.valueForRole('portfolio', [roleChart], allData, const []), 2400);
    });

    test('the assets reported for the role total are the ones that count toward it', () {
      expect(ChartRoles.assetIdsForRoleTotal('portfolio', [roleChart], allData, const []), {5, 6, 7});
    });
  });

  group('the shared rule', () {
    test('keeps net over market over invested, drops the right axis', () {
      expect(smartTotalSeries(overlapping).map((s) => s.key), ['account:1', 'asset_net:5', 'asset_market:6', 'asset_invested:7']);
      expect(buildSmartTotalSpots(overlapping), expected);
    });

    test('hiding the net series brings market back, hiding market brings invested back', () {
      expect(smartTotalSeries([invested5, market5]).map((s) => s.key), ['asset_market:5']);
      expect(smartTotalSeries([invested5]).map((s) => s.key), ['asset_invested:5']);
      expect(buildSmartTotalSpots(const []), isEmpty);
    });
  });

  testWidgets('ChartCard: the header readout and the plotted Total line follow the same rules', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chart = DashboardChart(id: 2, title: 'Mixed', widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChartCard(
              chart: chart,
              series: overlapping,
              allData: allData,
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

    expect(find.text('€2,400'), findsOneWidget);
    expect(tester.widget<UnifiedChart>(find.byType(UnifiedChart)).totalSpots, expected);
  });
}
