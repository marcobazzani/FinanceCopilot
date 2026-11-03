// The balance sheet the Health ratios are built from: each figure is a History
// chart or a sum of the series those charts are made of — and none of them
// counts a credit line as wealth.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/pillars/health_balance_sheet.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries;

ChartSeries _series(String key, List<FlSpot> spots) => ChartSeries(key: key, name: key, color: Colors.blue, spots: spots);

Asset _asset(int id, InstrumentType type, {AssetClass assetClass = AssetClass.equity}) => Asset(
  id: id,
  intermediaryId: 1,
  name: 'Asset $id',
  assetType: AssetType.stockEtf,
  instrumentType: type,
  assetClass: assetClass,
  assetGroup: '',
  valuationMethod: ValuationMethod.marketPrice,
  currency: 'EUR',
  isActive: true,
  includeInSavings: true,
  sortOrder: 0,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

DashboardChart _chart(String role, String seriesJson) =>
    DashboardChart(id: 1, title: role, widgetType: role, sortOrder: 0, seriesJson: seriesJson, createdAt: DateTime(2024, 1, 1));

AllSeriesData _data({
  List<ChartSeries> accounts = const [],
  List<ChartSeries> market = const [],
  List<ChartSeries> net = const [],
  List<ChartSeries> adjustments = const [],
  List<ChartSeries> ephemeral = const [],
}) => AllSeriesData(
  firstDate: DateTime(2024, 1, 1),
  accounts: accounts,
  assetInvested: const [],
  assetMarket: market,
  assetGain: const [],
  assetNet: net,
  adjustments: adjustments,
  incomeAdjustments: const [],
  ephemeralInflows: ephemeral,
  baseCurrency: 'EUR',
);

void main() {
  // Day 10 is "today" in every series. The situation, in euro:
  //  * accounts: Fineco −68,000 and Fideuram −62,000 overdrawn, Revolut +700;
  //  * a world ETF 500,000, a money-market ETF 360,000, a pension fund 60,000,
  //    a mortgage −150,000 (a Liability), a house 300,000, a painting 40,000;
  //  * the T-Roc adjustment: a purchase spread over time, 8,000 left of it;
  //  * two credit lines (236,000 and 200,000), whose draws are spent.
  final accounts = [
    _series('account:1', const [FlSpot(0, 5000), FlSpot(10, -68000)]),
    _series('account:2', const [FlSpot(0, 0), FlSpot(10, -62000)]),
    _series('account:3', const [FlSpot(0, 700), FlSpot(10, 700)]),
  ];
  final market = [
    _series('asset_market:10', const [FlSpot(0, 0), FlSpot(10, 500000)]),
    _series('asset_market:11', const [FlSpot(10, 360000)]),
    _series('asset_market:12', const [FlSpot(10, 60000)]),
    _series('asset_market:13', const [FlSpot(10, -150000)]),
    _series('asset_market:14', const [FlSpot(10, 300000)]),
    _series('asset_market:15', const [FlSpot(10, 40000)]),
  ];
  final net = [
    _series('asset_net:10', const [FlSpot(10, 460000)]),
    _series('asset_net:11', const [FlSpot(10, 359000)]),
    _series('asset_net:12', const [FlSpot(10, 59000)]),
    _series('asset_net:13', const [FlSpot(10, -150000)]),
    _series('asset_net:14', const [FlSpot(10, 290000)]),
    _series('asset_net:15', const [FlSpot(10, 38000)]),
  ];
  final adjustments = [
    _series('adjustment_value:2', const [FlSpot(5, 20000)]),
    _series('adjustment_events:2', const [FlSpot(5, -12000)]),
  ];
  final ephemeral = [
    _series('ephemeral_inflow_value:4', const [FlSpot(5, -236000)]),
    _series('ephemeral_inflow_value:5', const [FlSpot(5, -200000)]),
    _series('ephemeral_inflow_events:4', const [FlSpot(5, 147000)]),
  ];
  final assets = [
    _asset(10, InstrumentType.etf),
    _asset(11, InstrumentType.etf, assetClass: AssetClass.moneyMarket),
    _asset(12, InstrumentType.pension, assetClass: AssetClass.multiAsset),
    _asset(13, InstrumentType.liability),
    _asset(14, InstrumentType.realEstate, assetClass: AssetClass.realEstate),
    _asset(15, InstrumentType.alternative, assetClass: AssetClass.alternative),
  ];
  final data = _data(accounts: accounts, market: market, net: net, adjustments: adjustments, ephemeral: ephemeral);

  HealthBalanceSheet sheet({List<DashboardChart> charts = const [], AllSeriesData? from}) =>
      computeHealthBalanceSheet(charts: charts, allData: from ?? data, activeAssets: assets)!;

  group('the accounts', () {
    test('the balances added up, an overdrawn account negative', () {
      expect(sheet().bankBalances, -129300);
    });

    test('the accounts above zero and the accounts below zero, apart', () {
      expect(sheet().positiveBankBalances, 700);
      expect(sheet().overdrawnAccounts, 130000);
    });

    test('the latest balance counts, not the first', () {
      final s = sheet(
        from: _data(
          accounts: [
            _series('account:1', const [FlSpot(0, 9000), FlSpot(4, -100), FlSpot(10, 250)]),
          ],
        ),
      );
      expect(s.bankBalances, 250);
      expect(s.overdrawnAccounts, 0);
    });

    test('an account without a single value (no exchange rate) adds nothing', () {
      final s = sheet(
        from: _data(
          accounts: [
            _series('account:1', const [FlSpot(10, 1000)]),
            _series('account:2', const []),
          ],
        ),
      );
      expect(s.bankBalances, 1000);
    });
  });

  group('cash and the money market', () {
    test('the money market is the market value of the assets of the Money Market class', () {
      expect(sheet().moneyMarket, 360000);
    });

    test('cash is the accounts plus the money market', () {
      expect(sheet().cash, -129300 + 360000);
    });

    test('a money-market fund is no more than its class: an ETF of another class is not cash', () {
      final s = sheet(
        from: _data(
          accounts: accounts,
          market: [
            _series('asset_market:10', const [FlSpot(10, 5000)]),
          ],
        ),
      );
      expect(s.moneyMarket, 0);
    });
  });

  group('credit lines are not wealth', () {
    test('their amounts added up: 236,000 + 200,000', () {
      expect(sheet().creditLines, 436000);
    });

    test('only the amount of a line counts, not what was drawn from it', () {
      // ephemeral_inflow_events:4 (147,000) is the draw, and is in no figure.
      expect(sheet().creditLines, isNot(436000 + 147000));
    });

    test('they are in no total: not cash, not the net worth, not the gross assets', () {
      final s = sheet();
      final without = sheet(
        from: _data(accounts: accounts, market: market, net: net, adjustments: adjustments),
      );
      expect(s.cash, without.cash);
      expect(s.netWorth, without.netWorth);
      expect(s.grossAssets, without.grossAssets);
      expect(s.investableNetWorth, without.investableNetWorth);
    });

    test('with no line of credit the amount is 0', () {
      expect(sheet(from: _data(accounts: accounts)).creditLines, 0);
    });
  });

  group('net worth, owed and gross assets', () {
    test('the net worth is the Total Assets chart: market values + accounts + outflow adjustments', () {
      // 1,110,000 − 129,300 + 8,000
      expect(sheet().netWorth, 988700);
    });

    test('owed is the overdrawn accounts plus the liabilities', () {
      expect(sheet().liabilities, 150000);
      expect(sheet().owed, 280000);
    });

    test('the gross assets are the net worth plus what is owed', () {
      expect(sheet().grossAssets, 988700 + 280000);
    });

    test('investments are the Portfolio chart before its liabilities are taken off', () {
      // The chart adds the mortgage up as −150,000, 1,110,000 in all; the mortgage is a debt, not a negative investment.
      expect(sheet().investments, 1260000);
    });

    test('liquid investments are the Liquid Investments chart: no pension, real estate, alternative or liability', () {
      expect(sheet().liquidInvestments, 860000);
    });

    test('a Portfolio chart the user edited drives the investments, and only the liabilities in it are added back', () {
      final onlyTheEtfs = _chart('portfolio', '[{"type":"asset_market","id":10},{"type":"asset_market","id":11}]');
      expect(sheet(charts: [onlyTheEtfs]).investments, 860000);
      final withTheMortgage = _chart('portfolio', '[{"type":"asset_market","id":10},{"type":"asset_market","id":13}]');
      expect(sheet(charts: [withTheMortgage]).investments, 500000);
    });

    test('a Total Assets chart the user edited drives the net worth', () {
      final onlyAccounts = _chart('total_assets', '[{"type":"account","id":1},{"type":"account","id":2}]');
      final s = sheet(charts: [onlyAccounts]);
      expect(s.netWorth, -130000);
      expect(s.liabilities, 0, reason: 'the mortgage is not in that chart');
    });
  });

  group('the net worth that could pay for a life (investable)', () {
    test('Net Asset Value less the outflow adjustments, the real estate and the alternatives', () {
      final s = sheet();
      // Net Asset Value: after-tax values 1,056,000 − 129,300 + 8,000
      expect(s.netAssetValue, 934700);
      // − 8,000 (T-Roc) − 290,000 (house) − 38,000 (painting)
      expect(s.investableNetWorth, 598700);
    });

    test('pension funds count, debts are subtracted', () {
      final s = sheet();
      // The pension fund (59,000 net) is in; the mortgage (−150,000) and the overdrafts (−130,000) are off it.
      final onlyPensionAndDebts = sheet(
        from: _data(
          accounts: accounts,
          net: [net[2], net[3]],
          market: [market[2], market[3]],
        ),
      );
      expect(onlyPensionAndDebts.investableNetWorth, 59000 - 150000 - 129300);
      expect(s.investableNetWorth, lessThan(s.netAssetValue));
    });

    test('an asset id that is also an account id does not hide the account', () {
      // account:14 is an account; asset 14 is a house. The house leaves, the account stays.
      final s = sheet(
        from: _data(
          accounts: [
            _series('account:14', const [FlSpot(10, 1000)]),
          ],
          net: [net[4]],
          market: [market[4]],
        ),
      );
      expect(s.investableNetWorth, 1000);
    });

    test('with nothing to count it is 0', () {
      final s = sheet(
        from: _data(
          accounts: [
            _series('account:1', const [FlSpot(10, 0)]),
          ],
        ),
      );
      expect(s.investableNetWorth, 0);
    });
  });

  group('no net worth to speak of', () {
    test('no series at all: no balance sheet', () {
      expect(computeHealthBalanceSheet(charts: const [], allData: _data(), activeAssets: const []), isNull);
    });

    test('every balance left out for want of an exchange rate: no balance sheet, not a net worth of 0', () {
      final onlyUnrated = _data(accounts: [_series('account:1', const [])]);
      expect(computeHealthBalanceSheet(charts: const [], allData: onlyUnrated, activeAssets: assets), isNull);
    });

    test('an account at exactly 0 is a net worth of 0, a known one', () {
      final s = sheet(
        from: _data(
          accounts: [
            _series('account:1', const [FlSpot(10, 0)]),
          ],
        ),
      );
      expect(s.netWorth, 0);
    });
  });
}
