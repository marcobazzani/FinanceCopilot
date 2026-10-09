// A chart card's header reads the chart's total. What that total leaves out
// for want of a price or an exchange rate — an asset without a value, an
// account without a rate to base, an asset whose gain cannot be drawn against
// an incomplete cost basis — is counted under the header, from the same
// exclusions as the Totals table ([totalExclusions]), each contributor once.
// A hidden series is not in the total, so it is not counted; a combined chart
// shows no header total, so it counts nothing. The count is shape, not
// magnitude: it stays readable in privacy mode, the total beside it is masked.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  const s = AppStrings.en;
  setUpAll(() async => initializeDateFormatting('en'));

  final firstDate = DateTime(2026, 1, 1);
  ChartSeries series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: const Color(0xFF2196F3), spots: spots);

  // Account 1 is in the base currency; account 2 in one without any rate to
  // it: no spots.
  final euros = series('account:1', const [FlSpot(0, 1000), FlSpot(1, 1200)]);
  final dollars = series('account:2', const []);
  // Asset 5 is valued, but a buy of it has no rate to base: no gain drawn.
  final market5 = series('asset_market:5', const [FlSpot(0, 500), FlSpot(1, 550)]);
  final gain5 = series('asset_gain:5', const []);
  // Asset 6 is valued, with a complete cost basis.
  final market6 = series('asset_market:6', const [FlSpot(0, 100), FlSpot(1, 130)]);
  final gain6 = series('asset_gain:6', const [FlSpot(0, 0), FlSpot(1, 30)]);
  // Asset 7 is held without any price.
  final market7 = series('asset_market:7', const []);

  final data = AllSeriesData(
    firstDate: firstDate,
    accounts: [euros, dollars],
    assetInvested: const [],
    assetMarket: [market5, market6, market7],
    assetGain: [gain5, gain6],
    assetNet: const [],
    adjustments: const [],
    incomeAdjustments: const [],
    ephemeralInflows: const [],
    baseCurrency: 'EUR',
    excludedAccountIds: const {2},
  );

  Widget card(String title, List<ChartSeries> shown, {Set<String> hidden = const {}, String? sourceChartIds}) => SizedBox(
    height: 420,
    child: ChartCard(
      chart: DashboardChart(
        id: title.hashCode,
        title: title,
        widgetType: 'chart',
        sortOrder: 0,
        seriesJson: '[]',
        sourceChartIds: sourceChartIds,
        createdAt: firstDate,
      ),
      series: shown,
      allData: data,
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

  Future<ProviderContainer> pump(WidgetTester tester, Widget body) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byWidget(body)));
  }

  Finder note(int n) => find.text(s.unpricedExcludedFromTotal(n));
  Finder anyNote() => find.textContaining('excluded from the total');
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('an account without a rate is counted under the total it is left out of', (tester) async {
    await pump(tester, card('Cash', [euros, dollars]));
    expect(find.text('€1,200'), findsOneWidget, reason: 'the euro account alone, the other never added 1:1');
    expect(note(1), findsOneWidget);
  });

  testWidgets('a Gain chart counts the asset whose gain it cannot draw', (tester) async {
    await pump(tester, card('Gain', [gain5, gain6]));
    expect(find.text('€30'), findsOneWidget);
    expect(note(1), findsOneWidget);
  });

  testWidgets('each contributor is counted once, whatever the reason', (tester) async {
    await pump(tester, card('Everything', [euros, dollars, market5, market6, market7, gain5]));
    expect(note(3), findsOneWidget, reason: 'the dollar account, the unpriced asset 7 and asset 5 without a gain');
  });

  testWidgets('a hidden series is not in the total, so it is not counted', (tester) async {
    await pump(tester, card('Cash', [euros, dollars], hidden: const {'account:2'}));
    expect(find.text('€1,200'), findsOneWidget);
    expect(anyNote(), findsNothing);
  });

  testWidgets('nothing left out: no note', (tester) async {
    await pump(tester, card('Portfolio', [market5, market6]));
    expect(find.text('€680'), findsOneWidget);
    expect(anyNote(), findsNothing);
  });

  testWidgets('a combined chart has no header total, so no note', (tester) async {
    await pump(tester, card('Totals', [euros, dollars], sourceChartIds: '*'));
    expect(anyNote(), findsNothing);
  });

  testWidgets('privacy: the total is masked, the count under it stays readable', (tester) async {
    final container = await pump(tester, card('Cash', [euros, dollars]));
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump(const Duration(milliseconds: 300));
    expect(masked(find.text('€1,200')), isTrue, reason: 'a balance is position size');
    expect(note(1), findsOneWidget);
    expect(masked(note(1)), isFalse, reason: 'a count of contributors: shape, not magnitude');
  });
}
