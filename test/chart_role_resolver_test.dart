import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartRoles, ChartSeries, buildTotalSpots;

/// Fixture: accounts + invested + market + gain + adjustment split across
/// two assets, one of which is marked illiquid in the asset list below.
AllSeriesData _allData() {
  return AllSeriesData(
    firstDate: DateTime(2024, 1, 1),
    accounts: [
      ChartSeries(
        key: 'account:1',
        name: 'Checking',
        color: Colors.blue,
        spots: const [FlSpot(0, 1000), FlSpot(10, 1200)],
      ),
      ChartSeries(
        key: 'account:2',
        name: 'Savings',
        color: Colors.green,
        spots: const [FlSpot(0, 500), FlSpot(10, 650)],
      ),
    ],
    assetInvested: [
      ChartSeries(
        key: 'asset_invested:10',
        name: 'Stock ETF cost',
        color: Colors.orange,
        spots: const [FlSpot(3, 2000), FlSpot(10, 3000)],
      ),
      ChartSeries(
        key: 'asset_invested:11',
        name: 'Pension cost',
        color: Colors.purple,
        spots: const [FlSpot(3, 5000), FlSpot(10, 6000)],
      ),
    ],
    assetMarket: [
      ChartSeries(
        key: 'asset_market:10',
        name: 'Stock ETF value',
        color: Colors.orange,
        spots: const [FlSpot(3, 2200), FlSpot(10, 3500)],
      ),
      ChartSeries(
        key: 'asset_market:11',
        name: 'Pension value',
        color: Colors.purple,
        spots: const [FlSpot(3, 5100), FlSpot(10, 6500)],
      ),
    ],
    assetGain: const [],
    adjustments: [
      ChartSeries(
        key: 'adjustment_value:1',
        name: 'Tax provision',
        color: Colors.red,
        spots: const [FlSpot(2, -200)],
      ),
    ],
    incomeAdjustments: const [],
    baseCurrency: 'EUR',
  );
}

List<Asset> _assets() => [
      _asset(id: 10, name: 'Stock ETF', type: InstrumentType.etf),
      _asset(id: 11, name: 'Pension', type: InstrumentType.pension),
    ];

Asset _asset({
  required int id,
  required String name,
  required InstrumentType type,
}) =>
    Asset(
      id: id,
      intermediaryId: 1,
      name: name,
      assetType: AssetType.stockEtf,
      instrumentType: type,
      assetClass: AssetClass.equity,
      assetGroup: '',
      valuationMethod: ValuationMethod.marketPrice,
      currency: 'EUR',
      isActive: true,
      includeInNetWorth: true,
      sortOrder: 0,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

DashboardChart _chart({
  required int id,
  required String title,
  required String widgetType,
  required String seriesJson,
  int sortOrder = 0,
}) =>
    DashboardChart(
      id: id,
      title: title,
      widgetType: widgetType,
      sortOrder: sortOrder,
      seriesJson: seriesJson,
      createdAt: DateTime(2024, 1, 1),
    );

void main() {
  group('ChartRoles.spotsForRole — fallback when role chart absent', () {
    test('cash: no role chart → returns allData.cashSpots', () {
      final d = _allData();
      final got = ChartRoles.spotsForRole('cash', const [], d, _assets());
      expect(got, d.cashSpots);
    });

    test('saving: no role chart → returns allData.savingSpots', () {
      final d = _allData();
      final got = ChartRoles.spotsForRole('saving', const [], d, _assets());
      expect(got, d.savingSpots);
    });

    test('portfolio: no role chart → returns total of all assetMarket', () {
      final d = _allData();
      final got = ChartRoles.spotsForRole('portfolio', const [], d, _assets());
      final expected = buildTotalSpots(d.assetMarket.map((s) => s.spots).toList());
      expect(got, expected);
    });

    test('liquid_investments: no role chart → excludes illiquid (pension)', () {
      final d = _allData();
      final got = ChartRoles.spotsForRole('liquid_investments', const [], d, _assets());
      // Only asset 10 (etf) is liquid; asset 11 is pension.
      final expected = buildTotalSpots([
        d.assetMarket.firstWhere((s) => s.key == 'asset_market:10').spots,
      ]);
      expect(got, expected);
    });

    test('unknown role → empty', () {
      final d = _allData();
      final got = ChartRoles.spotsForRole('nope', const [], d, _assets());
      expect(got, isEmpty);
    });
  });

  group('ChartRoles.spotsForRole — stored role chart wins', () {
    test('cash role chart with custom series drives the result', () {
      final d = _allData();
      // User's Cash chart only includes account:1 (not account:2).
      final custom = _chart(
        id: 1,
        title: 'Cash',
        widgetType: 'cash',
        seriesJson: '[{"type":"account","id":1}]',
      );
      final got = ChartRoles.spotsForRole('cash', [custom], d, _assets());
      final expected = buildTotalSpots([
        d.accounts.firstWhere((s) => s.key == 'account:1').spots,
      ]);
      expect(got, expected);
      // And must NOT equal the hard-coded cashSpots, proving the role
      // chart is actually driving the result.
      expect(got, isNot(d.cashSpots));
    });

    test('portfolio role chart with custom subset wins over default sum', () {
      final d = _allData();
      // User's Portfolio = only the liquid ETF, not the pension.
      final custom = _chart(
        id: 2,
        title: 'Portfolio',
        widgetType: 'portfolio',
        seriesJson: '[{"type":"asset_market","id":10}]',
      );
      final got = ChartRoles.spotsForRole('portfolio', [custom], d, _assets());
      final expected = buildTotalSpots([
        d.assetMarket.firstWhere((s) => s.key == 'asset_market:10').spots,
      ]);
      expect(got, expected);
    });

    test('liquid_investments role chart including illiquid is honoured', () {
      final d = _allData();
      // User explicitly includes the pension (normally illiquid).
      final custom = _chart(
        id: 3,
        title: 'Liquid Investments',
        widgetType: 'liquid_investments',
        seriesJson: '[{"type":"asset_market","id":10},{"type":"asset_market","id":11}]',
      );
      final got = ChartRoles.spotsForRole('liquid_investments', [custom], d, _assets());
      final expected = buildTotalSpots(d.assetMarket.map((s) => s.spots).toList());
      expect(got, expected);
    });
  });

  group('ChartRoles.spotsForRole — resolvable-series check', () {
    test('role chart with only nonexistent IDs → falls back to hard-coded', () {
      final d = _allData();
      final stale = _chart(
        id: 9,
        title: 'Cash',
        widgetType: 'cash',
        seriesJson: '[{"type":"account","id":999}]',
      );
      final got = ChartRoles.spotsForRole('cash', [stale], d, _assets());
      // Series couldn't resolve any real key → fallback to cashSpots.
      expect(got, d.cashSpots);
    });
  });

  group('ChartRoles.valueForRole', () {
    test('returns last y of spotsForRole', () {
      final d = _allData();
      final got = ChartRoles.valueForRole('cash', const [], d, _assets());
      expect(got, d.cashSpots.last.y);
    });

    test('returns 0 when no spots', () {
      final d = _allData();
      final got = ChartRoles.valueForRole('nope', const [], d, _assets());
      expect(got, 0.0);
    });
  });
}

