// Chart legend group chips ("Accounts", "Assets", adjustments…): tapping one
// toggles every series of its group at once, and it is struck through while
// the whole group is hidden. Pinned before the two copies of the chip were
// folded into one builder: same look, same keys, same toggles.
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
  final chart = DashboardChart(id: 1, title: 'Wealth', widgetType: 'chart', sortOrder: 0, seriesJson: '[]', createdAt: firstDate);
  ChartSeries series(String key, String name) =>
      ChartSeries(key: key, name: name, color: const Color(0xFF2196F3), spots: const [FlSpot(0, 100), FlSpot(1, 110)]);
  final all = [
    series('account:1', 'Main'),
    series('account:2', 'Savings'),
    series('asset_invested:5', 'Fund invested'),
    series('asset_market:5', 'Fund'),
    series('adjustment_value:7', 'Car'),
  ];

  Future<List<Set<String>>> pumpCard(WidgetTester tester, {Set<String> hidden = const {}}) async {
    final toggled = <Set<String>>[];
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChartCard(
              chart: chart,
              series: all,
              allData: AllSeriesData(
                firstDate: firstDate,
                accounts: const [],
                assetInvested: const [],
                assetMarket: const [],
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
              onToggleGroup: toggled.add,
              onToggleHideComponents: () {},
              onZoom: (_, _, _, _) {},
              onHeightChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return toggled;
  }

  TextStyle chipStyle(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style!;
  Color chipColor(WidgetTester tester, String label) =>
      (tester.widget<Container>(find.ancestor(of: find.text(label), matching: find.byType(Container)).first).decoration! as BoxDecoration)
          .color!;

  testWidgets('each group chip toggles exactly its own series', (tester) async {
    final toggled = await pumpCard(tester);
    await tester.tap(find.text('Accounts'));
    await tester.tap(find.text('Assets'));
    await tester.tap(find.text('Spread Adj.'));
    expect(toggled, [
      {'account:1', 'account:2'},
      {'asset_invested:5', 'asset_market:5'},
      {'adjustment_value:7'},
    ]);
  });

  testWidgets('visible groups: bold, not struck through; the Assets chip is the smaller one', (tester) async {
    await pumpCard(tester);
    final theme = Theme.of(tester.element(find.text('Accounts')));
    for (final (label, size) in [('Accounts', 13.0), ('Spread Adj.', 13.0), ('Assets', 11.0)]) {
      final style = chipStyle(tester, label);
      expect(style.fontSize, size, reason: label);
      expect(style.fontWeight, FontWeight.w600, reason: label);
      expect(style.decoration, isNull, reason: label);
      expect(style.color, theme.colorScheme.onSurface, reason: label);
      expect(chipColor(tester, label), theme.colorScheme.surfaceContainerHighest, reason: label);
    }
  });

  testWidgets('a group hidden entirely is struck through and faded; a partly hidden one is not', (tester) async {
    await pumpCard(tester, hidden: {'account:1', 'account:2', 'asset_market:5'});
    final theme = Theme.of(tester.element(find.text('Accounts')));
    final accounts = chipStyle(tester, 'Accounts');
    expect(accounts.decoration, TextDecoration.lineThrough);
    expect(accounts.color, theme.colorScheme.onSurface.withValues(alpha: 0.4));
    expect(chipColor(tester, 'Accounts'), theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3));
    final assets = chipStyle(tester, 'Assets');
    expect(assets.decoration, isNull, reason: 'the invested series is still shown');
    expect(assets.fontSize, 11);
  });

  testWidgets('the Assets chip is struck through once both of its series are hidden', (tester) async {
    await pumpCard(tester, hidden: {'asset_invested:5', 'asset_market:5'});
    expect(chipStyle(tester, 'Assets').decoration, TextDecoration.lineThrough);
    expect(chipStyle(tester, 'Accounts').decoration, isNull);
  });
}
