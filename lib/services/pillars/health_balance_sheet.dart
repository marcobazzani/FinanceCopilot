import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartRoles, ChartSeries, buildTotalSpots, isOutflowAdjustmentSeriesKey, parseSeriesKey, smartTotalSeries;

/// The figures every Health ratio is built from, in base currency, as of the
/// last day of the History charts.
///
/// Each one is a History chart (Portfolio, Liquid Investments, Total Assets,
/// Net Asset Value) or a sum of series those charts are made of (Accounts,
/// Money Market, Credit Lines), so it can be checked against what the app
/// shows elsewhere. Credit lines are money that can be borrowed, not wealth:
/// none of them is in [cash], [netWorth] or [grossAssets].
class HealthBalanceSheet {
  /// The Accounts balances added up; an overdrawn account counts as negative.
  final double bankBalances;

  /// The Accounts above zero, added up.
  final double positiveBankBalances;

  /// The Accounts below zero, added up as a positive amount.
  final double overdrawnAccounts;

  /// Market value of the assets of the Money Market asset class.
  final double moneyMarket;

  /// The Total Assets chart: what is owned minus what is owed.
  final double netWorth;

  /// The Portfolio chart before its Liability assets are taken off: the market
  /// value of everything invested.
  final double investments;

  /// The Liquid Investments chart.
  final double liquidInvestments;

  /// Market value of the Liability assets in Total Assets, as a positive amount.
  final double liabilities;

  /// The amounts of the line-of-credit adjustments, added up.
  final double creditLines;

  /// The Net Asset Value chart.
  final double netAssetValue;

  /// [netAssetValue] without what cannot pay for the expenses of a life:
  /// outflow adjustments (a purchase spread over time keeps a residual value)
  /// and real estate and alternative assets. Pension funds count, debts are
  /// subtracted.
  final double investableNetWorth;

  const HealthBalanceSheet({
    this.bankBalances = 0,
    this.positiveBankBalances = 0,
    this.overdrawnAccounts = 0,
    this.moneyMarket = 0,
    required this.netWorth,
    this.investments = 0,
    this.liquidInvestments = 0,
    this.liabilities = 0,
    this.creditLines = 0,
    this.netAssetValue = 0,
    this.investableNetWorth = 0,
  });

  /// Accounts plus Money Market.
  double get cash => bankBalances + moneyMarket;

  /// What is owed: overdrawn Accounts plus Liability assets.
  double get owed => overdrawnAccounts + liabilities;

  /// What is owned, before debts: Net Worth plus what is owed.
  double get grossAssets => netWorth + owed;
}

double _lastValue(ChartSeries series) => series.spots.isEmpty ? 0.0 : series.spots.last.y;

/// Instruments whose value cannot pay for the expenses of a life.
const _notInvestable = {InstrumentType.realEstate, InstrumentType.alternative};

/// The [HealthBalanceSheet] of [allData], or null when there is no net worth to
/// speak of: no account balance and no holding has a value (none, or all of
/// them left out for want of an exchange rate).
HealthBalanceSheet? computeHealthBalanceSheet({
  required List<DashboardChart> charts,
  required AllSeriesData allData,
  required List<Asset> activeAssets,
}) {
  final totalAssets = ChartRoles.spotsForRole('total_assets', charts, allData, activeAssets);
  if (totalAssets.isEmpty) return null;

  var bank = 0.0, above = 0.0, below = 0.0;
  for (final account in allData.accounts) {
    final balance = _lastValue(account);
    bank += balance;
    if (balance > 0) above += balance;
    if (balance < 0) below -= balance;
  }

  final moneyMarketIds = {
    for (final asset in activeAssets)
      if (asset.assetClass == AssetClass.moneyMarket) asset.id,
  };
  final moneyMarket = allData.assetMarket
      .where((series) => moneyMarketIds.contains(parseSeriesKey(series.key)?.id))
      .fold(0.0, (sum, series) => sum + _lastValue(series));

  // The ephemeral series carry the amount negated: a line of credit is an
  // inflow, and the chart editor draws inflows below zero.
  final creditLines = allData.ephemeralInflows
      .where((series) => series.key.startsWith('ephemeral_inflow_value:'))
      .fold(0.0, (sum, series) => sum - _lastValue(series));

  /// The Liability assets (negative market value) behind a role's total.
  double liabilitiesIn(String role) {
    final ids = ChartRoles.assetIdsForRoleTotal(role, charts, allData, activeAssets);
    var owed = 0.0;
    for (final series in allData.assetMarket) {
      final id = parseSeriesKey(series.key)?.id;
      final value = _lastValue(series);
      if (id != null && ids.contains(id) && value < 0) owed -= value;
    }
    return owed;
  }

  final notInvestableIds = {
    for (final asset in activeAssets)
      if (_notInvestable.contains(asset.instrumentType)) asset.id,
  };
  bool paysForExpenses(ChartSeries series) {
    if (isOutflowAdjustmentSeriesKey(series.key)) return false;
    final key = parseSeriesKey(series.key);
    return key == null || !key.type.startsWith('asset_') || !notInvestableIds.contains(key.id);
  }

  final netAssetValueSeries = smartTotalSeries(ChartRoles.seriesForRole('net_asset_value', charts, allData, activeAssets));
  final investable = buildTotalSpots([
    for (final series in netAssetValueSeries)
      if (paysForExpenses(series)) series.spots,
  ]);

  return HealthBalanceSheet(
    bankBalances: bank,
    positiveBankBalances: above,
    overdrawnAccounts: below,
    moneyMarket: moneyMarket,
    netWorth: totalAssets.last.y,
    investments: ChartRoles.valueForRole('portfolio', charts, allData, activeAssets) + liabilitiesIn('portfolio'),
    liquidInvestments: ChartRoles.valueForRole('liquid_investments', charts, allData, activeAssets),
    liabilities: liabilitiesIn('total_assets'),
    creditLines: creditLines,
    netAssetValue: ChartRoles.valueForRole('net_asset_value', charts, allData, activeAssets),
    investableNetWorth: investable.isEmpty ? 0.0 : investable.last.y,
  );
}
