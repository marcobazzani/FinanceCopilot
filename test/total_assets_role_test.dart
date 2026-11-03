// The Total Assets chart is a role chart, like Cash and Portfolio: the Health
// tab reads its value as the net worth. When the chart is missing the role
// falls back to the composition the bundled chart has, and the exporter keeps
// the role.
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/charts/default_charts_exporter.dart';
import 'package:finance_copilot/services/charts/default_charts_loader.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartRoles, ChartSeries;

ChartSeries _series(String key, double y) => ChartSeries(key: key, name: key, color: Colors.blue, spots: [FlSpot(0, y)]);

Account _account(int id) => Account(
  id: id,
  name: 'Account $id',
  type: AccountType.bank,
  currency: 'EUR',
  institution: '',
  isActive: true,
  includeInNetWorth: true,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Asset _asset(int id) => Asset(
  id: id,
  intermediaryId: 1,
  name: 'Asset $id',
  assetType: AssetType.stockEtf,
  instrumentType: InstrumentType.etf,
  assetClass: AssetClass.equity,
  assetGroup: '',
  valuationMethod: ValuationMethod.marketPrice,
  currency: 'EUR',
  isActive: true,
  includeInSavings: true,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

ExtraordinaryEvent _event(int id, EventDirection direction, {bool ephemeral = false}) => ExtraordinaryEvent(
  id: id,
  name: 'Event $id',
  direction: direction,
  treatment: EventTreatment.instant,
  totalAmount: 100,
  currency: 'EUR',
  eventDate: DateTime(2024, 6, 1),
  isActive: true,
  isEphemeral: ephemeral,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  // Two accounts, two assets; an outflow adjustment, an inflow adjustment and a credit line.
  final accounts = [_account(1), _account(2)];
  final assets = [_asset(10), _asset(11)];
  final events = [
    _event(2, EventDirection.outflow),
    _event(3, EventDirection.inflow),
    _event(4, EventDirection.inflow, ephemeral: true),
  ];
  final data = AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: [_series('account:1', 1000), _series('account:2', 500)],
    assetInvested: [_series('asset_invested:10', 1800), _series('asset_invested:11', 900)],
    assetMarket: [_series('asset_market:10', 2000), _series('asset_market:11', 1000)],
    assetGain: const [],
    assetNet: [_series('asset_net:10', 1900), _series('asset_net:11', 950)],
    adjustments: [_series('adjustment_value:2', 300), _series('adjustment_events:2', -100)],
    incomeAdjustments: [_series('income_adj_value:3', -250)],
    ephemeralInflows: [_series('ephemeral_inflow_value:4', -400)],
    baseCurrency: 'EUR',
  );

  group('the fallback of the total_assets role', () {
    test('with no Total Assets chart: the market values, the accounts and the outflow adjustments', () {
      final spots = ChartRoles.spotsForRole('total_assets', const [], data, assets);
      // 3,000 invested + 1,500 in accounts + 300 − 100
      expect(spots.last.y, 4700);
    });

    test('it leaves out the inflow adjustments and the credit lines: they are not assets', () {
      final keys = ChartRoles.seriesForRole('total_assets', const [], data, assets).map((s) => s.key).toSet();
      expect(keys.where((k) => k.startsWith('income_adj') || k.startsWith('ephemeral')), isEmpty);
      expect(keys.where((k) => k.startsWith('asset_invested') || k.startsWith('asset_net')), isEmpty, reason: 'value, not cost or after tax');
    });

    test('a Total Assets chart the user edited wins over the fallback', () {
      final chart = DashboardChart(
        id: 1,
        title: 'Total Assets',
        widgetType: 'total_assets',
        sortOrder: 0,
        seriesJson: '[{"type":"account","id":1}]',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(ChartRoles.valueForRole('total_assets', [chart], data, assets), 1000);
    });

    test('a chart that no longer resolves to a series falls back, like the other roles', () {
      final chart = DashboardChart(
        id: 1,
        title: 'Total Assets',
        widgetType: 'total_assets',
        sortOrder: 0,
        seriesJson: '[{"type":"account","id":99}]',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(ChartRoles.valueForRole('total_assets', [chart], data, assets), 4700);
    });

    test('it is the composition the bundled Total Assets chart has', () {
      final charts = const DefaultChartsLoader().parse(
        File('assets/default_charts.json').readAsStringSync(),
        activeAccounts: accounts,
        activeAssets: assets,
        activeEvents: events,
      );
      final bundled = charts.firstWhere((c) => c.title == 'Total Assets');
      final bundledKeys = {
        for (final entry in (jsonDecode(bundled.seriesJson) as List).cast<Map<String, dynamic>>()) '${entry['type']}:${entry['id']}',
      };
      final fallbackKeys = ChartRoles.seriesForRole('total_assets', const [], data, assets).map((s) => s.key).toSet();
      expect(fallbackKeys, bundledKeys);
    });
  });

  group('the bundled Total Assets chart', () {
    List<DashboardChart> bundled() => const DefaultChartsLoader().parse(
      File('assets/default_charts.json').readAsStringSync(),
      activeAccounts: accounts,
      activeAssets: assets,
      activeEvents: events,
    );

    test('is a role chart, so the Health tab can read it', () {
      final totalAssets = bundled().where((c) => c.title == 'Total Assets');
      expect(totalAssets.length, 1);
      expect(totalAssets.single.widgetType, 'total_assets');
    });

    test('still sits among the sources of the Totals chart, which names it by title', () {
      final charts = bundled();
      final totals = charts.firstWhere((c) => c.title == 'Totals');
      expect(jsonDecode(totals.sourceChartIds!), contains('Total Assets'));
      expect(charts.where((c) => c.widgetType == 'net_asset_value' || c.widgetType == 'total_assets').length, 2);
    });

    test('the value the role reads is the chart\'s own', () {
      expect(ChartRoles.valueForRole('total_assets', bundled(), data, assets), 4700);
    });
  });

  group('exporting the role', () {
    test('a total_assets chart comes out as a role, not as a plain chart', () {
      final json = DefaultChartsExporter().export(
        charts: [
          DashboardChart(
            id: 1,
            title: 'Total Assets',
            widgetType: 'total_assets',
            sortOrder: 0,
            seriesJson:
                '[{"type":"asset_market","id":10},{"type":"asset_market","id":11},{"type":"account","id":1},{"type":"account","id":2},'
                '{"type":"adjustment_value","id":2},{"type":"adjustment_events","id":2}]',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
        activeAccounts: accounts,
        activeAssets: assets,
        activeEvents: events,
      );
      final chart = ((jsonDecode(json) as Map<String, dynamic>)['charts'] as List).single as Map<String, dynamic>;
      expect(chart['role'], 'total_assets');
      expect(chart.containsKey('widgetType'), isFalse);
      expect(chart['categories'], unorderedEquals(['all_market', 'all_accounts', 'outflow_value', 'outflow_events']));
    });
  });
}
