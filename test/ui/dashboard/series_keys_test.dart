// Series are keyed '<type>:<id>' (e.g. 'asset_market:5'). The role resolvers,
// the chart legend and the chart editor all read the asset or event id out of
// that key; these tests pin what each of them makes of well-formed keys and of
// keys that do not have that shape.
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/build_flags.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

import 'dashboard_harness.dart';

ChartSeries _series(String key, String name, List<FlSpot> spots) =>
    ChartSeries(key: key, name: name, color: const Color(0xFF2196F3), spots: spots);

Asset _asset(int id, InstrumentType type, {bool includeInSavings = true}) => Asset(
  id: id,
  intermediaryId: 1,
  name: 'Asset $id',
  assetType: AssetType.stockEtf,
  instrumentType: type,
  assetClass: AssetClass.equity,
  assetGroup: '',
  valuationMethod: ValuationMethod.marketPrice,
  currency: 'EUR',
  isActive: true,
  includeInSavings: includeInSavings,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

AllSeriesData _data({
  List<ChartSeries> accounts = const [],
  List<ChartSeries> invested = const [],
  List<ChartSeries> market = const [],
  List<ChartSeries> adjustments = const [],
}) => AllSeriesData(
  firstDate: DateTime(2024, 1, 1),
  accounts: accounts,
  assetInvested: invested,
  assetMarket: market,
  assetGain: const [],
  assetNet: const [],
  adjustments: adjustments,
  incomeAdjustments: const [],
  ephemeralInflows: const [],
  baseCurrency: 'EUR',
);

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('parseSeriesKey', () {
    test('splits "<type>:<id>" into its type and numeric id', () {
      expect(parseSeriesKey('asset_market:5'), (type: 'asset_market', id: 5));
      expect(parseSeriesKey('adjustment_value:12'), (type: 'adjustment_value', id: 12));
    });

    test('any other shape is not a series key', () {
      for (final key in ['_total', 'cf:saving', 'asset_market', 'asset_market:', 'asset_market:5:1', 'combined_src:x']) {
        expect(parseSeriesKey(key), isNull, reason: key);
      }
    });
  });

  test('an asset or event without a series name is named by its number in the display language', () {
    expect(AppStrings.en.chartAssetNumbered(7), 'Asset 7');
    expect(AppStrings.it.chartAssetNumbered(7), 'Attività 7');
    expect(AppStrings.en.chartEventNumbered(3), 'Event 3');
    expect(AppStrings.it.chartEventNumbered(3), 'Evento 3');
  });

  group('role fallbacks read the asset id out of the key', () {
    // One liquid fund (10), one pension (11), and keys without a numeric id.
    final market = [
      _series('asset_market:10', 'Fund', const [FlSpot(0, 100)]),
      _series('asset_market:11', 'Pension', const [FlSpot(0, 1000)]),
      _series('asset_market:x', 'No id', const [FlSpot(0, 10000)]),
      _series('asset_market', 'No colon', const [FlSpot(0, 100000)]),
      _series('asset_market:10:1', 'Three parts', const [FlSpot(0, 1000000)]),
    ];
    final invested = [
      _series('asset_invested:10', 'Fund', const [FlSpot(0, 90)]),
      _series('asset_invested:11', 'Pension', const [FlSpot(0, 900)]),
      _series('asset_invested:x', 'No id', const [FlSpot(0, 9000)]),
      _series('asset_invested:10:1', 'Three parts', const [FlSpot(0, 90000)]),
    ];
    final assets = [_asset(10, InstrumentType.etf), _asset(11, InstrumentType.pension, includeInSavings: false)];

    test('liquid investments: only the liquid asset, never a key without an id', () {
      expect(ChartRoles.spotsForRole('liquid_investments', const [], _data(market: market), assets), const [FlSpot(0, 100)]);
    });

    test('saving: only the invested series of assets kept in savings', () {
      expect(ChartRoles.spotsForRole('saving', const [], _data(invested: invested), assets), const [FlSpot(0, 90)]);
    });

    test('the assets behind a role total: asset keys with an id only', () {
      final data = _data(
        accounts: [
          _series('account:1', 'Main', const [FlSpot(0, 5)]),
        ],
        market: market,
      );
      expect(ChartRoles.assetIdsForRoleTotal('portfolio', const [], data, assets), {10, 11});
      final chart = DashboardChart(
        id: 1,
        title: 'Net',
        widgetType: 'net_asset_value',
        sortOrder: 0,
        seriesJson: '[{"type":"account","id":1},{"type":"asset_market","id":10}]',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(ChartRoles.assetIdsForRoleTotal('net_asset_value', [chart], data, assets), {10}, reason: 'an account is not an asset');
    });
  });

  testWidgets('chart legend: one entry per asset, its market value then its invested line', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const spots = [FlSpot(0, 1), FlSpot(1, 2)];
    final series = [
      _series('asset_market:5', 'A value', spots),
      _series('asset_invested:5', 'A cost', spots),
      _series('asset_invested:6', 'B cost', spots),
      _series('asset_market:6', 'B value', spots),
      _series('asset_invested:7', 'C cost', spots),
      _series('asset_market:x', 'Broken', spots),
    ];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChartCard(
              chart: DashboardChart(
                id: 1,
                title: 'Assets',
                widgetType: 'chart',
                sortOrder: 0,
                seriesJson: '[]',
                createdAt: DateTime(2024, 1, 1),
              ),
              series: series,
              allData: _data(invested: series.where((s) => s.key.startsWith('asset_invested:')).toList(), market: series),
              hidden: const {},
              hideComponents: false,
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

    const names = {'A value', 'A cost', 'B value', 'B cost', 'C cost', 'Broken'};
    final legend = [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (names.contains(t.data)) t.data,
    ];
    expect(legend, ['A value', 'A cost', 'B value', 'B cost', 'C cost'], reason: 'a key without an id names no asset');
  });

  group('chart editor', () {
    final h = DashboardHarness();
    setUp(h.open);
    tearDown(h.close);

    const spots = [FlSpot(0, 1), FlSpot(1, 2)];
    final fixture = AllSeriesData(
      firstDate: DateTime(2025, 1, 1),
      accounts: [_series('account:1', 'Main', spots)],
      assetInvested: [_series('asset_invested:5', 'A cost', spots), _series('asset_invested:7', 'C cost', spots)],
      assetMarket: [_series('asset_market:5', 'A value', spots), _series('asset_market:6', 'B value', spots)],
      assetGain: const [],
      assetNet: const [],
      adjustments: [_series('adjustment_value:3', 'Tax', spots), _series('adjustment_events:3', 'Tax', spots)],
      incomeAdjustments: const [],
      ephemeralInflows: const [],
      baseCurrency: 'EUR',
    );

    testWidgets('lists each asset and event once by name and saves the ticked series as type/id pairs', skip: !debugChartsEnabled, (
      tester,
    ) async {
      await h.pump(tester, overrides: [allSeriesDataProvider.overrideWith((ref) async => fixture)]);
      try {
        await h.openTab(tester, 'History');
        await tester.tap(find.byTooltip('New Chart'));
        await h.settle(tester);
        await tester.tap(find.text('Custom chart…'));
        await h.settle(tester);
        final dialog = find.byType(AlertDialog);
        Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);

        // Asset rows are named after the asset's market series, else its
        // invested one; one row per event, however many series it has.
        for (final name in ['A value', 'B value', 'C cost', 'Tax']) {
          expect(inDialog(find.text(name)), findsOneWidget, reason: name);
        }
        expect(inDialog(find.text('A cost')), findsNothing);

        await tester.enterText(inDialog(find.byType(TextField)).first, 'Mine');
        await tester.tap(inDialog(find.text('Main')));
        Finder rowOf(String name) => find.ancestor(of: inDialog(find.text(name)), matching: find.byType(Row)).first;
        // Row 'A value': [Invested, Market] checkboxes.
        await tester.tap(find.descendant(of: rowOf('A value'), matching: find.byType(Checkbox)).first);
        // Event 'Tax': the Value cell cycles off → + → −.
        final taxValue = find.descendant(of: rowOf('Tax'), matching: find.byType(IconButton)).first;
        await tester.tap(taxValue);
        await h.settle(tester);
        await tester.tap(taxValue);
        await h.settle(tester);
        await tester.tap(inDialog(find.text('Save')));
        await h.settle(tester);

        final saved = h.container.read(editableChartsProvider).charts.singleWhere((c) => c.title == 'Mine');
        expect(jsonDecode(saved.seriesJson), [
          {'type': 'account', 'id': 1},
          {'type': 'asset_invested', 'id': 5},
          {'type': 'adjustment_value', 'id': 3, 'sign': -1},
        ]);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
