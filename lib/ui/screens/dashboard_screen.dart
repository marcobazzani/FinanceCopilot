import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Variable;
import 'package:intl/intl.dart';
import '../../utils/formatters.dart' as fmt;

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../services/derived_metrics_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';

final _log = getLogger('DashboardScreen');

// ════════════════════════════════════════════════════
// Data models
// ════════════════════════════════════════════════════

/// Unified series for accounts, assets, and CAPEX.
class _Series {
  final String key; // unique id for toggling: "a:3" (account), "s:7" (asset), "c:1" (capex)
  final String name;
  final Color color;
  final List<FlSpot> spots;
  final bool isDashed;
  const _Series({
    required this.key,
    required this.name,
    required this.color,
    required this.spots,
    this.isDashed = false,
  });
}

/// All chart data: account series, asset series, CAPEX series, market value series, derived metrics.
class _AllSeriesData {
  final DateTime firstDate;
  final List<_Series> accounts;      // key: "account:<id>"
  final List<_Series> assetInvested; // key: "asset_invested:<id>"
  final List<_Series> assetMarket;   // key: "asset_market:<id>"
  final List<_Series> adjustments;      // key: "adjustment:<id>"
  final List<_Series> incomeAdjustments; // key: "income_adj:<id>"
  final List<_Series> derivedSeries; // key: "derived:<name>"
  final String baseCurrency;
  final DerivedMetrics? derivedMetrics;
  final List<YearlyStats> yearlyStats;

  const _AllSeriesData({
    required this.firstDate,
    required this.accounts,
    required this.assetInvested,
    required this.assetMarket,
    required this.adjustments,
    required this.incomeAdjustments,
    this.derivedSeries = const [],
    required this.baseCurrency,
    this.derivedMetrics,
    this.yearlyStats = const [],
  });

  List<_Series> get allSeries => [...accounts, ...assetInvested, ...assetMarket, ...adjustments, ...incomeAdjustments, ...derivedSeries];
}

final _chartColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.red,
  Colors.amber,
  Colors.cyan,
  Colors.indigo,
  Colors.pink,
  Colors.lime,
  Colors.deepOrange,
];

/// Convert a DateTime to a day-key (epoch seconds at midnight).
int toDayKey(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/ 1000;

/// Build a carry-forward total line from multiple spot lists.
List<FlSpot> buildTotalSpots(List<List<FlSpot>> allSpots) {
  if (allSpots.isEmpty) return [];
  final allX = <double>{};
  final lookups = <Map<double, double>>[];
  for (final spots in allSpots) {
    final m = <double, double>{};
    for (final s in spots) {
      m[s.x] = s.y;
      allX.add(s.x);
    }
    lookups.add(m);
  }
  final sorted = allX.toList()..sort();
  final running = List<double>.filled(lookups.length, 0.0);
  return sorted.map((x) {
    var total = 0.0;
    for (var i = 0; i < lookups.length; i++) {
      if (lookups[i].containsKey(x)) running[i] = lookups[i][x]!;
      total += running[i];
    }
    return FlSpot(x, total);
  }).toList();
}

/// Cached exchange rate resolver for chart computations.
class _RateResolver {
  final ExchangeRateService _rateService;
  final String _baseCurrency;
  final _cache = <String, double>{};

  _RateResolver(this._rateService, this._baseCurrency);

  Future<double> getRate(String from, int dayKey) async {
    if (from == _baseCurrency) return 1.0;
    final key = '$from:$dayKey';
    if (_cache.containsKey(key)) return _cache[key]!;
    final date = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
    final rate = await _rateService.getRate(from, _baseCurrency, date);
    _cache[key] = rate ?? 1.0;
    return rate ?? 1.0;
  }
}

/// Convert an amount to base currency using stored rate or live fallback.
Future<double> convertToBase({
  required double amount,
  required String currency,
  required String baseCurrency,
  required double? storedRate,
  required _RateResolver resolver,
  required int dayKey,
}) async {
  if (currency == baseCurrency) return amount.abs();
  if (storedRate != null && storedRate > 0) return amount.abs() / storedRate;
  final rate = await resolver.getRate(currency, dayKey);
  return amount.abs() * rate;
}

/// Currency symbol lookup for display.
String currencySymbol(String code) {
  return switch (code) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    'JPY' => '¥',
    'CHF' => 'CHF',
    _ => code,
  };
}

// ════════════════════════════════════════════════════
// Raw time-series provider — extracts raw day-keyed maps
// ════════════════════════════════════════════════════

final _rawTimeSeriesProvider = FutureProvider<RawTimeSeriesData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final marketPriceService = ref.watch(marketPriceServiceProvider);

  // Watch reactive streams so we rebuild when data changes
  ref.watch(accountsProvider);
  ref.watch(accountStatsProvider);
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(capexSchedulesProvider);
  ref.watch(incomeAdjustmentsProvider);
  ref.watch(priceRefreshCounter);

  final allDayKeys = <int>{};
  final rates = _RateResolver(rateService, baseCurrency);

  // ════════════════════════════════════════════════
  // 1. ACCOUNTS — daily balance from transactions
  // ════════════════════════════════════════════════
  final activeAccounts = await (db.select(db.accounts)
        ..where((a) => a.isActive.equals(true))
        ..where((a) => a.includeInNetWorth.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  final activeIds = activeAccounts.map((a) => a.id).toSet();

  final perAccount = <int, Map<int, double>>{};
  if (activeIds.isNotEmpty) {
    final placeholders = activeIds.map((_) => '?').join(',');
    final rows = await db.customSelect(
      'SELECT account_id, operation_date, balance_after '
      'FROM transactions '
      'WHERE account_id IN ($placeholders) '
      'AND balance_after IS NOT NULL '
      'ORDER BY operation_date ASC, id ASC',
      variables: activeIds.map((id) => Variable.withInt(id)).toList(),
    ).get();

    for (final row in rows) {
      final accountId = row.read<int>('account_id');
      final epochSec = row.read<int>('operation_date');
      final balance = row.read<double>('balance_after');
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);
      perAccount.putIfAbsent(accountId, () => {});
      perAccount[accountId]![dayKey] = balance;
      allDayKeys.add(dayKey);
    }
  }

  // Convert account balances to base currency
  final accountBalancesBase = <int, Map<int, double>>{};
  for (final account in activeAccounts) {
    if (!perAccount.containsKey(account.id)) continue;
    final dayMap = perAccount[account.id]!;
    final baseMap = <int, double>{};
    for (final entry in dayMap.entries) {
      final rate = await rates.getRate(account.currency, entry.key);
      baseMap[entry.key] = entry.value * rate;
    }
    accountBalancesBase[account.id] = baseMap;
  }

  // ════════════════════════════════════════════════
  // 2. ASSETS — cumulative invested value from events
  // ════════════════════════════════════════════════
  final activeAssets = await (db.select(db.assets)
        ..where((a) => a.isActive.equals(true))
        ..where((a) => a.includeInNetWorth.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  final assetIds = activeAssets.map((a) => a.id).toSet();

  final perAssetDeltas = <int, Map<int, double>>{};
  final perAssetQtyDeltas = <int, Map<int, double>>{};

  if (assetIds.isNotEmpty) {
    final assetPlaceholders = assetIds.map((_) => '?').join(',');
    final evRows = await db.customSelect(
      'SELECT asset_id, date, type, amount, quantity, currency, exchange_rate '
      'FROM asset_events '
      'WHERE asset_id IN ($assetPlaceholders) '
      'ORDER BY date ASC',
      variables: assetIds.map((id) => Variable.withInt(id)).toList(),
    ).get();

    for (final row in evRows) {
      final assetId = row.read<int>('asset_id');
      final epochSec = row.read<int>('date');
      final type = row.read<String>('type');
      final amount = row.read<double>('amount');
      final quantity = row.readNullable<double>('quantity') ?? 0;
      final currency = row.read<String>('currency');
      final storedRate = row.readNullable<double>('exchange_rate');

      double sign;
      if (type == 'buy' || type == 'contribute') {
        sign = 1.0;
      } else if (type == 'sell') {
        sign = -1.0;
      } else {
        continue;
      }

      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);

      final baseAmount = await convertToBase(
        amount: amount, currency: currency, baseCurrency: baseCurrency,
        storedRate: storedRate, resolver: rates, dayKey: dayKey,
      );

      perAssetDeltas.putIfAbsent(assetId, () => {});
      perAssetDeltas[assetId]![dayKey] =
          (perAssetDeltas[assetId]![dayKey] ?? 0) + sign * baseAmount;

      perAssetQtyDeltas.putIfAbsent(assetId, () => {});
      perAssetQtyDeltas[assetId]![dayKey] =
          (perAssetQtyDeltas[assetId]![dayKey] ?? 0) + sign * quantity.abs();

      allDayKeys.add(dayKey);
    }
  }

  if (allDayKeys.isEmpty) return null;

  // Build cumulative invested series per asset
  final assetInvestedCum = <int, Map<int, double>>{};
  final sortedDaysInterim = allDayKeys.toList()..sort();
  for (final asset in activeAssets) {
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final deltaMap = perAssetDeltas[asset.id]!;
    final cumMap = <int, double>{};
    var cumulative = 0.0;
    var started = false;
    for (final dayKey in sortedDaysInterim) {
      if (deltaMap.containsKey(dayKey)) {
        cumulative += deltaMap[dayKey]!;
        started = true;
      }
      if (started) cumMap[dayKey] = cumulative;
    }
    assetInvestedCum[asset.id] = cumMap;
  }

  // Build market value series per asset
  final assetMarketVal = <int, Map<int, double>>{};
  for (final asset in activeAssets) {
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final qtyDeltaMap = perAssetQtyDeltas[asset.id] ?? {};
    final prices = await marketPriceService.getPriceHistory(asset.id);
    final priceMap = <int, double>{};
    for (final p in prices) {
      priceMap[toDayKey(p.key)] = p.value;
    }

    final firstEventKey = perAssetDeltas[asset.id]!.keys.reduce(min);
    final assetDays = <int>{
      ...perAssetDeltas[asset.id]!.keys,
      ...priceMap.keys.where((dk) => dk >= firstEventKey),
    }.toList()..sort();

    final mktMap = <int, double>{};
    var cumQuantity = 0.0;
    double? lastPrice;
    var started = false;
    for (final dayKey in assetDays) {
      if (qtyDeltaMap.containsKey(dayKey)) {
        cumQuantity += qtyDeltaMap[dayKey]!;
        started = true;
      }
      if (priceMap.containsKey(dayKey)) lastPrice = priceMap[dayKey]!;
      if (!started) continue;
      if (lastPrice != null && cumQuantity > 0) {
        final fxRate = await rates.getRate(asset.currency, dayKey);
        mktMap[dayKey] = cumQuantity * lastPrice * fxRate;
        allDayKeys.add(dayKey);
      }
    }
    assetMarketVal[asset.id] = mktMap;
  }

  // ════════════════════════════════════════════════
  // 3. CAPEX adjustments
  // ════════════════════════════════════════════════
  final activeSchedules = await (db.select(db.depreciationSchedules)
        ..where((s) => s.isActive.equals(true)))
      .get();

  final adjustmentsCum = <int, Map<int, double>>{};
  for (final schedule in activeSchedules) {
    final entries = await (db.select(db.depreciationEntries)
          ..where((e) => e.scheduleId.equals(schedule.id))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();

    final deltaMap = <int, double>{};
    if (schedule.expenseDate != null) {
      final expDayKey = toDayKey(schedule.expenseDate!);
      deltaMap[expDayKey] = (deltaMap[expDayKey] ?? 0) + schedule.totalAmount;
    }
    for (final entry in entries) {
      final dayKey = toDayKey(entry.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - entry.amount;
    }
    if (schedule.bufferId != null) {
      final reimbursements = await (db.select(db.bufferTransactions)
            ..where((t) => t.bufferId.equals(schedule.bufferId!))
            ..where((t) => t.isReimbursement.equals(true)))
          .get();
      for (final r in reimbursements) {
        final dayKey = toDayKey(r.operationDate);
        deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - r.amount.abs();
      }
    }
    if (deltaMap.isEmpty) continue;

    // Convert to cumulative (in base currency)
    final capexDays = deltaMap.keys.toList()..sort();
    final cumMap = <int, double>{};
    var cumulative = 0.0;
    for (final dayKey in capexDays) {
      final rate = await rates.getRate(schedule.currency, dayKey);
      cumulative += deltaMap[dayKey]! * rate;
      cumMap[dayKey] = cumulative;
      allDayKeys.add(dayKey);
    }
    adjustmentsCum[schedule.id] = cumMap;
  }

  // ════════════════════════════════════════════════
  // 4. INCOME ADJUSTMENTS
  // ════════════════════════════════════════════════
  final activeIncomeAdj = await (db.select(db.incomeAdjustments)
        ..where((a) => a.isActive.equals(true)))
      .get();

  final incomeAdjCum = <int, Map<int, double>>{};
  for (final adj in activeIncomeAdj) {
    final expenses = await (db.select(db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.equals(adj.id))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();

    final deltaMap = <int, double>{};
    final incomeDayKey = toDayKey(adj.incomeDate);
    deltaMap[incomeDayKey] = (deltaMap[incomeDayKey] ?? 0) - adj.totalAmount;
    allDayKeys.add(incomeDayKey);

    for (final exp in expenses) {
      final dayKey = toDayKey(exp.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) + exp.amount;
      allDayKeys.add(dayKey);
    }
    if (deltaMap.isEmpty) continue;

    final adjDays = deltaMap.keys.toList()..sort();
    final cumMap = <int, double>{};
    var cumulative = 0.0;
    for (final dayKey in adjDays) {
      final rate = await rates.getRate(adj.currency, dayKey);
      cumulative += deltaMap[dayKey]! * rate;
      cumMap[dayKey] = cumulative;
    }
    incomeAdjCum[adj.id] = cumMap;
  }

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  return RawTimeSeriesData(
    firstDate: firstDate,
    sortedDayKeys: sortedDays,
    baseCurrency: baseCurrency,
    accountBalances: accountBalancesBase,
    assetInvested: assetInvestedCum,
    assetMarketValue: assetMarketVal,
    adjustments: adjustmentsCum,
    incomeAdjustments: incomeAdjCum,
  );
});

// ════════════════════════════════════════════════════
// Derived metrics provider
// ════════════════════════════════════════════════════

final _derivedMetricsProvider = FutureProvider<DerivedMetrics?>((ref) async {
  final raw = await ref.watch(_rawTimeSeriesProvider.future);
  if (raw == null) return null;
  final events = await ref.watch(registeredEventsProvider.future);
  final configs = await ref.watch(appConfigsMapProvider.future);
  return DerivedMetricsService().compute(
    raw: raw,
    registeredEvents: events,
    configs: configs,
  );
});

final _yearlyStatsProvider = FutureProvider<List<YearlyStats>>((ref) async {
  final raw = await ref.watch(_rawTimeSeriesProvider.future);
  if (raw == null) return [];
  final derived = await ref.watch(_derivedMetricsProvider.future);
  if (derived == null) return [];
  final events = await ref.watch(registeredEventsProvider.future);
  return DerivedMetricsService().computeYearlyStats(
    raw: raw,
    risparTotale: derived.risparTotale,
    registeredEvents: events,
  );
});

// ════════════════════════════════════════════════════
// Unified data provider — converts raw maps to _Series
// ════════════════════════════════════════════════════

final _allSeriesDataProvider = FutureProvider<_AllSeriesData?>((ref) async {
  final raw = await ref.watch(_rawTimeSeriesProvider.future);
  if (raw == null) return null;

  final derived = await ref.watch(_derivedMetricsProvider.future);
  final yearlyStats = await ref.watch(_yearlyStatsProvider.future);
  final db = ref.watch(databaseProvider);

  final firstDate = raw.firstDate;
  final sortedDays = raw.sortedDayKeys;
  var colorIdx = 0;

  // ── Build account series ──
  final activeAccounts = await (db.select(db.accounts)
        ..where((a) => a.isActive.equals(true))
        ..where((a) => a.includeInNetWorth.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();

  final accountSeries = <_Series>[];
  for (final account in activeAccounts) {
    final dayMap = raw.accountBalances[account.id];
    if (dayMap == null) continue;
    final spots = <FlSpot>[];
    double? running;
    for (final dayKey in sortedDays) {
      if (dayMap.containsKey(dayKey)) running = dayMap[dayKey];
      if (running != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running));
      }
    }
    accountSeries.add(_Series(
      key: 'account:${account.id}',
      name: account.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
    ));
    colorIdx++;
  }

  // ── Build asset invested series ──
  final activeAssets = await (db.select(db.assets)
        ..where((a) => a.isActive.equals(true))
        ..where((a) => a.includeInNetWorth.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();

  final assetInvestedSeries = <_Series>[];
  for (final asset in activeAssets) {
    final cumMap = raw.assetInvested[asset.id];
    if (cumMap == null) continue;
    final spots = <FlSpot>[];
    double? running;
    for (final dayKey in sortedDays) {
      if (cumMap.containsKey(dayKey)) running = cumMap[dayKey];
      if (running != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running));
      }
    }
    assetInvestedSeries.add(_Series(
      key: 'asset_invested:${asset.id}',
      name: '${asset.ticker ?? asset.name} inv.',
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isDashed: true,
    ));
    colorIdx++;
  }

  // ── Build asset market value series ──
  final assetMarketSeries = <_Series>[];
  for (final asset in activeAssets) {
    final mktMap = raw.assetMarketValue[asset.id];
    if (mktMap == null) continue;
    final spots = <FlSpot>[];
    double? running;
    for (final dayKey in sortedDays) {
      if (mktMap.containsKey(dayKey)) running = mktMap[dayKey];
      if (running != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running));
      }
    }
    final investedIdx = assetInvestedSeries.indexWhere((s) => s.key == 'asset_invested:${asset.id}');
    final color = investedIdx >= 0 ? assetInvestedSeries[investedIdx].color : _chartColors[colorIdx++ % _chartColors.length];
    assetMarketSeries.add(_Series(
      key: 'asset_market:${asset.id}',
      name: asset.ticker ?? asset.name,
      color: color,
      spots: spots,
    ));
  }

  // ── Build adjustment series ──
  final activeSchedules = await (db.select(db.depreciationSchedules)
        ..where((s) => s.isActive.equals(true)))
      .get();

  final adjustmentSeries = <_Series>[];
  for (final schedule in activeSchedules) {
    final cumMap = raw.adjustments[schedule.id];
    if (cumMap == null) continue;
    final capexDays = cumMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    double? prevY;
    for (final dayKey in capexDays) {
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      if (prevY != null && spots.isNotEmpty && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      final y = cumMap[dayKey]!;
      spots.add(FlSpot(x, y));
      prevY = y;
    }
    adjustmentSeries.add(_Series(
      key: 'adjustment:${schedule.id}',
      name: schedule.assetName,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isDashed: true,
    ));
    colorIdx++;
  }

  // ── Build income adjustment series ──
  final activeIncomeAdj = await (db.select(db.incomeAdjustments)
        ..where((a) => a.isActive.equals(true)))
      .get();

  final incomeAdjSeries = <_Series>[];
  for (final adj in activeIncomeAdj) {
    final cumMap = raw.incomeAdjustments[adj.id];
    if (cumMap == null) continue;
    final adjDays = cumMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    double? prevY;
    for (final dayKey in adjDays) {
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      if (prevY != null && spots.isNotEmpty && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      final y = cumMap[dayKey]!;
      spots.add(FlSpot(x, y));
      prevY = y;
    }
    incomeAdjSeries.add(_Series(
      key: 'income_adj:${adj.id}',
      name: adj.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isDashed: true,
    ));
    colorIdx++;
  }

  // ── Build derived metric series ──
  final derivedSeriesList = <_Series>[];
  if (derived != null) {
    final derivedColors = [
      Colors.deepPurple, Colors.tealAccent.shade700, Colors.pinkAccent,
      Colors.lightBlue, Colors.brown, Colors.deepOrange.shade300,
      Colors.greenAccent.shade700, Colors.indigo.shade300,
      Colors.amber.shade700, Colors.cyan.shade700,
    ];
    var dColorIdx = 0;
    for (final entry in derived.allSeries.entries) {
      if (entry.value.isEmpty) continue;
      final spots = <FlSpot>[];
      for (final dayKey in sortedDays) {
        if (entry.value.containsKey(dayKey)) {
          final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
          final x = dt.difference(firstDate).inDays.toDouble();
          spots.add(FlSpot(x, entry.value[dayKey]!));
        }
      }
      if (spots.isEmpty) continue;
      derivedSeriesList.add(_Series(
        key: 'derived:${entry.key}',
        name: entry.key,
        color: derivedColors[dColorIdx % derivedColors.length],
        spots: spots,
      ));
      dColorIdx++;
    }
  }

  return _AllSeriesData(
    firstDate: firstDate,
    accounts: accountSeries,
    assetInvested: assetInvestedSeries,
    assetMarket: assetMarketSeries,
    adjustments: adjustmentSeries,
    incomeAdjustments: incomeAdjSeries,
    derivedSeries: derivedSeriesList,
    baseCurrency: raw.baseCurrency,
    derivedMetrics: derived,
    yearlyStats: yearlyStats,
  );
});

// ════════════════════════════════════════════════════
// Dashboard screen with dynamic custom charts
// ════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _ChartZoom {
  double? minX, maxX, minY, maxY;
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _hiddenPerChart = <int, Set<String>>{}; // chartId → hidden series keys
  final _chartHeights = <int, double>{}; // chartId → user-set height
  final _chartZooms = <int, _ChartZoom>{}; // chartId → independent zoom
  final _hideComponents = <int, bool>{}; // chartId → hide individual lines
  final _expandedCollapsed = <int>{}; // chart IDs temporarily un-collapsed

  static const _defaultChartHeight = 420.0;
  static const _minChartHeight = 200.0;
  static const _maxChartHeight = 900.0;

  Set<String> _hiddenFor(int chartId) =>
      _hiddenPerChart.putIfAbsent(chartId, () => {});

  double _heightFor(int chartId) =>
      _chartHeights.putIfAbsent(chartId, () => _defaultChartHeight);

  _ChartZoom _zoomFor(int chartId) =>
      _chartZooms.putIfAbsent(chartId, () => _ChartZoom());

  bool _hideComponentsFor(int chartId) =>
      _hideComponents.putIfAbsent(chartId, () => false);

  @override
  Widget build(BuildContext context) {
    final allDataAsync = ref.watch(_allSeriesDataProvider);
    final chartsAsync = ref.watch(dashboardChartsProvider);
    final locale = ref.watch(appLocaleProvider).valueOrNull ?? 'en_US';

    return allDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allData) {
        if (allData == null) {
          return const Center(
            child: Text('No data yet. Import transactions or add assets to get started.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        return chartsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (charts) {
            // Build set of chart IDs that are sources of a combined chart
            final collapsedChartIds = <int>{};
            for (final chart in charts) {
              if (chart.sourceChartIds != null) {
                try {
                  final ids = (jsonDecode(chart.sourceChartIds!) as List).cast<int>();
                  collapsedChartIds.addAll(ids);
                } catch (_) {}
              }
            }

            return Scaffold(
              body: charts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No charts configured.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showChartEditor(context, allData, null),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Chart'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _AssetDailyChangesCard(locale: locale, baseCurrency: allData.baseCurrency),
                        if (allData.derivedMetrics != null) ...[
                          const SizedBox(height: 16),
                          _MetricsSummaryCard(
                            metrics: allData.derivedMetrics!,
                            locale: locale,
                            baseCurrency: allData.baseCurrency,
                          ),
                        ],
                        if (allData.yearlyStats.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _IncomeExpenseCard(
                            yearlyStats: allData.yearlyStats,
                            locale: locale,
                            baseCurrency: allData.baseCurrency,
                          ),
                        ],
                        const SizedBox(height: 24),
                        ...charts.map((chart) {
                          final isCombined = chart.sourceChartIds != null;
                          final isCollapsed = collapsedChartIds.contains(chart.id) && !_expandedCollapsed.contains(chart.id);

                          // For collapsed source charts, show slim row
                          if (isCollapsed) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CollapsedChartRow(
                                chart: chart,
                                onExpand: () => setState(() => _expandedCollapsed.add(chart.id)),
                                onEdit: () => _showChartEditor(context, allData, chart),
                                onDelete: () => _deleteChart(context, chart),
                              ),
                            );
                          }

                          // For combined charts, build series from source chart totals
                          List<_Series> filteredSeries;
                          if (isCombined) {
                            filteredSeries = _buildCombinedSeries(charts, chart, allData);
                          } else {
                            final seriesConfigs = _parseSeriesJson(chart.seriesJson);
                            filteredSeries = _filterSeries(allData, seriesConfigs);
                          }

                          final hidden = _hiddenFor(chart.id);
                          final zoom = _zoomFor(chart.id);
                          final hideComp = _hideComponentsFor(chart.id);

                          // Show collapse button if this chart was auto-collapsed but user expanded it
                          final showCollapseButton = collapsedChartIds.contains(chart.id) && _expandedCollapsed.contains(chart.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _ChartCard(
                              chart: chart,
                              series: filteredSeries,
                              allData: allData,
                              hidden: hidden,
                              hideComponents: hideComp,
                              locale: locale,
                              chartHeight: _heightFor(chart.id),
                              zoomMinX: zoom.minX,
                              zoomMaxX: zoom.maxX,
                              zoomMinY: zoom.minY,
                              zoomMaxY: zoom.maxY,
                              onToggle: (key) => setState(() {
                                hidden.contains(key) ? hidden.remove(key) : hidden.add(key);
                              }),
                              onToggleGroup: (keys) => setState(() {
                                keys.every(hidden.contains) ? hidden.removeAll(keys) : hidden.addAll(keys);
                              }),
                              onToggleHideComponents: () => setState(() {
                                _hideComponents[chart.id] = !hideComp;
                              }),
                              onZoom: (minX, maxX, minY, maxY) => setState(() {
                                zoom.minX = minX;
                                zoom.maxX = maxX;
                                zoom.minY = minY;
                                zoom.maxY = maxY;
                              }),
                              onHeightChanged: (h) => setState(() {
                                _chartHeights[chart.id] = h.clamp(_minChartHeight, _maxChartHeight);
                              }),
                              onEdit: isCombined ? () => _showCombineChartsDialog(context, charts, chart) : () => _showChartEditor(context, allData, chart),
                              onDelete: () => _deleteChart(context, chart),
                              onCollapse: showCollapseButton ? () => setState(() => _expandedCollapsed.remove(chart.id)) : null,
                            ),
                          );
                        }),
                      ],
                    ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (charts.where((c) => c.sourceChartIds == null).length >= 2)
                    FloatingActionButton.small(
                      heroTag: 'combine',
                      onPressed: () => _showCombineChartsDialog(context, charts, null),
                      tooltip: 'Combine Charts',
                      child: const Icon(Icons.merge_type),
                    ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'add',
                    onPressed: () => _showChartEditor(context, allData, null),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build series for a combined chart: each source chart's total becomes a line.
  List<_Series> _buildCombinedSeries(List<DashboardChart> allCharts, DashboardChart combined, _AllSeriesData allData) {
    List<int> sourceIds;
    try {
      sourceIds = (jsonDecode(combined.sourceChartIds!) as List).cast<int>();
    } catch (_) {
      return [];
    }

    final result = <_Series>[];
    var colorIdx = 0;

    for (final srcId in sourceIds) {
      final srcChart = allCharts.where((c) => c.id == srcId).firstOrNull;
      if (srcChart == null) continue;

      final seriesConfigs = _parseSeriesJson(srcChart.seriesJson);
      final srcSeries = _filterSeries(allData, seriesConfigs);
      if (srcSeries.isEmpty) continue;

      // Compute total spots for this source chart using the smart logic
      final totalSpots = _buildSmartTotalSpotsStatic(srcSeries);
      if (totalSpots.isEmpty) continue;

      result.add(_Series(
        key: 'combined_src:$srcId',
        name: srcChart.title,
        color: _chartColors[colorIdx % _chartColors.length],
        spots: totalSpots,
      ));
      colorIdx++;
    }

    return result;
  }

  /// Static version of smart total spots for use outside _ChartCard.
  static List<FlSpot> _buildSmartTotalSpotsStatic(List<_Series> visible) {
    final visibleInvestedIds = <int>{};
    final visibleMarketIds = <int>{};
    for (final s in visible) {
      final parts = s.key.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[1]);
      if (id == null) continue;
      if (parts[0] == 'asset_invested') visibleInvestedIds.add(id);
      if (parts[0] == 'asset_market') visibleMarketIds.add(id);
    }
    final excludeFromTotal = <String>{};
    for (final id in visibleInvestedIds) {
      if (visibleMarketIds.contains(id)) {
        excludeFromTotal.add('asset_invested:$id');
      }
    }
    final spotsForTotal = visible
        .where((s) => !excludeFromTotal.contains(s.key))
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
  }

  Future<void> _showCombineChartsDialog(BuildContext context, List<DashboardChart> charts, DashboardChart? existing) async {
    final result = await showDialog<_CombineChartsResult>(
      context: context,
      builder: (ctx) => _CombineChartsDialog(
        charts: charts.where((c) => c.sourceChartIds == null).toList(),
        existing: existing,
      ),
    );
    if (result == null) return;

    final service = ref.read(dashboardChartServiceProvider);
    final sourceJson = jsonEncode(result.selectedChartIds);

    if (existing != null) {
      await service.update(existing.id, title: result.title, sourceChartIds: sourceJson);
    } else {
      await service.create(title: result.title, seriesJson: '[]', sourceChartIds: sourceJson);
    }
  }

  List<Map<String, dynamic>> _parseSeriesJson(String json) {
    try {
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  List<_Series> _filterSeries(_AllSeriesData allData, List<Map<String, dynamic>> configs) {
    final result = <_Series>[];
    for (final config in configs) {
      final type = config['type'] as String?;
      final id = config['id'];
      if (type == null || id == null) continue;
      final key = '$type:$id';
      final match = allData.allSeries.where((s) => s.key == key);
      if (match.isNotEmpty) result.add(match.first);
    }
    return result;
  }

  Future<void> _showChartEditor(BuildContext context, _AllSeriesData allData, DashboardChart? existing) async {
    final result = await showDialog<_ChartEditorResult>(
      context: context,
      builder: (ctx) => _ChartEditorDialog(
        allData: allData,
        existing: existing,
      ),
    );
    if (result == null) return;

    final service = ref.read(dashboardChartServiceProvider);
    final seriesJson = jsonEncode(result.selectedSeries);

    if (existing != null) {
      await service.update(existing.id, title: result.title, seriesJson: seriesJson);
    } else {
      await service.create(title: result.title, seriesJson: seriesJson);
    }
  }

  Future<void> _deleteChart(BuildContext context, DashboardChart chart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chart'),
        content: Text('Delete "${chart.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(dashboardChartServiceProvider).delete(chart.id);
    }
  }
}

// ════════════════════════════════════════════════════
// Chart editor dialog
// ════════════════════════════════════════════════════

class _ChartEditorResult {
  final String title;
  final List<Map<String, dynamic>> selectedSeries;
  _ChartEditorResult({required this.title, required this.selectedSeries});
}

class _ChartEditorDialog extends StatefulWidget {
  final _AllSeriesData allData;
  final DashboardChart? existing;

  const _ChartEditorDialog({required this.allData, this.existing});

  @override
  State<_ChartEditorDialog> createState() => _ChartEditorDialogState();
}

class _ChartEditorDialogState extends State<_ChartEditorDialog> {
  late final TextEditingController _titleCtrl;
  final _selected = <String>{}; // set of "type:id" keys

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    if (widget.existing != null) {
      try {
        final configs = (jsonDecode(widget.existing!.seriesJson) as List).cast<Map<String, dynamic>>();
        for (final c in configs) {
          final type = c['type'] as String?;
          final id = c['id'];
          if (type != null && id != null) _selected.add('$type:$id');
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.allData;

    // Extract unique asset ids from invested + market series
    final assetIds = <int>{};
    for (final s in [...d.assetInvested, ...d.assetMarket]) {
      final parts = s.key.split(':');
      if (parts.length == 2) assetIds.add(int.parse(parts[1]));
    }

    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Chart' : 'New Chart'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Chart Title'),
              ),
              const SizedBox(height: 16),

              // Accounts
              if (d.accounts.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Accounts',
                  allSelected: d.accounts.every((s) => _selected.contains(s.key)),
                  onToggleAll: () => _toggleGroup(d.accounts.map((s) => s.key).toSet()),
                ),
                for (final s in d.accounts)
                  CheckboxListTile(
                    dense: true,
                    title: Text(s.name, style: const TextStyle(fontSize: 13)),
                    value: _selected.contains(s.key),
                    onChanged: (_) => setState(() {
                      _selected.contains(s.key) ? _selected.remove(s.key) : _selected.add(s.key);
                    }),
                  ),
              ],

              // Assets (each with invested + market checkboxes)
              if (assetIds.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Assets',
                  allSelected: assetIds.every((id) =>
                      _selected.contains('asset_invested:$id') &&
                      _selected.contains('asset_market:$id')),
                  onToggleAll: () {
                    final keys = <String>{};
                    for (final id in assetIds) {
                      keys.add('asset_invested:$id');
                      keys.add('asset_market:$id');
                    }
                    _toggleGroup(keys);
                  },
                ),
                for (final id in assetIds) ...[
                  () {
                    final inv = d.assetInvested.where((s) => s.key == 'asset_invested:$id');
                    final mkt = d.assetMarket.where((s) => s.key == 'asset_market:$id');
                    final name = mkt.isNotEmpty ? mkt.first.name : (inv.isNotEmpty ? inv.first.name : 'Asset $id');
                    return Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              if (inv.isNotEmpty)
                                Expanded(
                                  child: CheckboxListTile(
                                    dense: true,
                                    title: const Text('Invested', style: TextStyle(fontSize: 12)),
                                    value: _selected.contains('asset_invested:$id'),
                                    onChanged: (_) => setState(() {
                                      _selected.contains('asset_invested:$id')
                                          ? _selected.remove('asset_invested:$id')
                                          : _selected.add('asset_invested:$id');
                                    }),
                                  ),
                                ),
                              if (mkt.isNotEmpty)
                                Expanded(
                                  child: CheckboxListTile(
                                    dense: true,
                                    title: const Text('Market', style: TextStyle(fontSize: 12)),
                                    value: _selected.contains('asset_market:$id'),
                                    onChanged: (_) => setState(() {
                                      _selected.contains('asset_market:$id')
                                          ? _selected.remove('asset_market:$id')
                                          : _selected.add('asset_market:$id');
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }(),
                ],
              ],

              // Spread Adjustments
              if (d.adjustments.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Spread Adjustments',
                  allSelected: d.adjustments.every((s) => _selected.contains(s.key)),
                  onToggleAll: () => _toggleGroup(d.adjustments.map((s) => s.key).toSet()),
                ),
                for (final s in d.adjustments)
                  CheckboxListTile(
                    dense: true,
                    title: Text(s.name, style: const TextStyle(fontSize: 13)),
                    value: _selected.contains(s.key),
                    onChanged: (_) => setState(() {
                      _selected.contains(s.key) ? _selected.remove(s.key) : _selected.add(s.key);
                    }),
                  ),
              ],

              // Income Adjustments
              if (d.incomeAdjustments.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Income Adjustments',
                  allSelected: d.incomeAdjustments.every((s) => _selected.contains(s.key)),
                  onToggleAll: () => _toggleGroup(d.incomeAdjustments.map((s) => s.key).toSet()),
                ),
                for (final s in d.incomeAdjustments)
                  CheckboxListTile(
                    dense: true,
                    title: Text(s.name, style: const TextStyle(fontSize: 13)),
                    value: _selected.contains(s.key),
                    onChanged: (_) => setState(() {
                      _selected.contains(s.key) ? _selected.remove(s.key) : _selected.add(s.key);
                    }),
                  ),
              ],

              // Derived Metrics
              if (d.derivedSeries.isNotEmpty) ...[
                for (final groupEntry in DerivedMetrics.seriesGroups.entries) ...[
                  () {
                    final groupSeries = d.derivedSeries.where((s) {
                      final name = s.key.replaceFirst('derived:', '');
                      return groupEntry.value.contains(name);
                    }).toList();
                    if (groupSeries.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          label: groupEntry.key,
                          allSelected: groupSeries.every((s) => _selected.contains(s.key)),
                          onToggleAll: () => _toggleGroup(groupSeries.map((s) => s.key).toSet()),
                        ),
                        for (final s in groupSeries)
                          CheckboxListTile(
                            dense: true,
                            title: Text(s.name, style: const TextStyle(fontSize: 13)),
                            value: _selected.contains(s.key),
                            onChanged: (_) => setState(() {
                              _selected.contains(s.key) ? _selected.remove(s.key) : _selected.add(s.key);
                            }),
                          ),
                      ],
                    );
                  }(),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selected.isEmpty || _titleCtrl.text.trim().isEmpty ? null : () {
            final series = _selected.map((key) {
              final colonIdx = key.indexOf(':');
              final type = key.substring(0, colonIdx);
              final idStr = key.substring(colonIdx + 1);
              final idInt = int.tryParse(idStr);
              if (idInt != null) {
                return {'type': type, 'id': idInt};
              } else {
                // Derived series: store name as string id
                return {'type': type, 'id': idStr};
              }
            }).toList();
            Navigator.pop(context, _ChartEditorResult(
              title: _titleCtrl.text.trim(),
              selectedSeries: series,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _toggleGroup(Set<String> keys) {
    setState(() {
      if (keys.every(_selected.contains)) {
        _selected.removeAll(keys);
      } else {
        _selected.addAll(keys);
      }
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool allSelected;
  final VoidCallback onToggleAll;

  const _SectionHeader({required this.label, required this.allSelected, required this.onToggleAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          TextButton(
            onPressed: onToggleAll,
            child: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Combine Charts dialog
// ════════════════════════════════════════════════════

class _CombineChartsResult {
  final String title;
  final List<int> selectedChartIds;
  _CombineChartsResult({required this.title, required this.selectedChartIds});
}

class _CombineChartsDialog extends StatefulWidget {
  final List<DashboardChart> charts; // non-combined charts only
  final DashboardChart? existing;

  const _CombineChartsDialog({required this.charts, this.existing});

  @override
  State<_CombineChartsDialog> createState() => _CombineChartsDialogState();
}

class _CombineChartsDialogState extends State<_CombineChartsDialog> {
  late final TextEditingController _titleCtrl;
  final _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    if (widget.existing?.sourceChartIds != null) {
      try {
        final ids = (jsonDecode(widget.existing!.sourceChartIds!) as List).cast<int>();
        _selectedIds.addAll(ids);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Combined Chart' : 'Combine Charts'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Combined Chart Title'),
              ),
              const SizedBox(height: 16),
              const Text('Select charts to combine (2+):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              for (final chart in widget.charts)
                CheckboxListTile(
                  dense: true,
                  title: Text(chart.title, style: const TextStyle(fontSize: 13)),
                  value: _selectedIds.contains(chart.id),
                  onChanged: (_) => setState(() {
                    _selectedIds.contains(chart.id) ? _selectedIds.remove(chart.id) : _selectedIds.add(chart.id);
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedIds.length >= 2 && _titleCtrl.text.trim().isNotEmpty
              ? () => Navigator.pop(context, _CombineChartsResult(
                  title: _titleCtrl.text.trim(),
                  selectedChartIds: _selectedIds.toList(),
                ))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Collapsed chart row (auto-collapsed source chart)
// ════════════════════════════════════════════════════

class _CollapsedChartRow extends StatelessWidget {
  final DashboardChart chart;
  final VoidCallback onExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollapsedChartRow({
    required this.chart,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(chart.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ),
          IconButton(icon: const Icon(Icons.expand_more, size: 18), onPressed: onExpand, tooltip: 'Expand', iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: onEdit, tooltip: 'Edit', iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: onDelete, tooltip: 'Delete', iconSize: 16, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Unified chart card widget
// ════════════════════════════════════════════════════

class _ChartCard extends StatelessWidget {
  final DashboardChart chart;
  final List<_Series> series;
  final _AllSeriesData allData;
  final Set<String> hidden;
  final bool hideComponents;
  final String locale;
  final double chartHeight;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;
  final VoidCallback onToggleHideComponents;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;
  final ValueChanged<double> onHeightChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCollapse;

  const _ChartCard({
    required this.chart,
    required this.series,
    required this.allData,
    required this.hidden,
    this.hideComponents = false,
    required this.locale,
    required this.chartHeight,
    this.zoomMinX,
    this.zoomMaxX,
    this.zoomMinY,
    this.zoomMaxY,
    required this.onToggle,
    required this.onToggleGroup,
    required this.onToggleHideComponents,
    required this.onZoom,
    required this.onHeightChanged,
    required this.onEdit,
    required this.onDelete,
    this.onCollapse,
  });

  /// Build total spots with smart asset handling:
  /// If both invested and market are visible for the same asset, only sum market.
  List<FlSpot> _buildSmartTotalSpots(List<_Series> visible) {
    // Find asset IDs that have both invested AND market visible
    final visibleInvestedIds = <int>{};
    final visibleMarketIds = <int>{};
    for (final s in visible) {
      final parts = s.key.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[1]);
      if (id == null) continue;
      if (parts[0] == 'asset_invested') visibleInvestedIds.add(id);
      if (parts[0] == 'asset_market') visibleMarketIds.add(id);
    }
    // Exclude invested series where market is also visible
    final excludeFromTotal = <String>{};
    for (final id in visibleInvestedIds) {
      if (visibleMarketIds.contains(id)) {
        excludeFromTotal.add('asset_invested:$id');
      }
    }
    final spotsForTotal = visible
        .where((s) => !excludeFromTotal.contains(s.key))
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
  }

  @override
  Widget build(BuildContext context) {
    final visible = series.where((s) => !hidden.contains(s.key)).toList();
    final totalSpots = _buildSmartTotalSpots(visible);
    final symbol = currencySymbol(allData.baseCurrency);
    final currentTotal = totalSpots.isNotEmpty ? totalSpots.last.y : 0.0;
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);

    // Series to actually draw (empty if hideComponents, but total is unaffected)
    final drawnSeries = hideComponents ? <_Series>[] : visible;

    // Group series by type for legend
    final accountSeries = series.where((s) => s.key.startsWith('account:')).toList();
    final investedSeries = series.where((s) => s.key.startsWith('asset_invested:')).toList();
    final marketSeries = series.where((s) => s.key.startsWith('asset_market:')).toList();
    final adjustmentSeries = series.where((s) => s.key.startsWith('adjustment:')).toList();
    final incomeAdjSeries = series.where((s) => s.key.startsWith('income_adj:')).toList();
    final derivedSeriesLegend = series.where((s) => s.key.startsWith('derived:')).toList();

    final hasZoom = zoomMinX != null || zoomMinY != null;

    return SizedBox(
      height: chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Row(
            children: [
              Expanded(
                child: Text(chart.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(currFmt.format(currentTotal),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              // Hide components toggle
              IconButton(
                icon: Icon(hideComponents ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: onToggleHideComponents,
                tooltip: hideComponents ? 'Show components' : 'Hide components',
              ),
              if (hasZoom)
                IconButton(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  onPressed: () => onZoom(null, null, null, null),
                  tooltip: 'Reset zoom',
                ),
              if (onCollapse != null)
                IconButton(
                  icon: const Icon(Icons.expand_less, size: 18),
                  onPressed: onCollapse,
                  tooltip: 'Collapse',
                ),
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit, tooltip: 'Edit'),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, tooltip: 'Delete'),
            ],
          ),
          const SizedBox(height: 4),

          // Legend
          if (!hideComponents) ...[
            _ChartLegend(
              accountSeries: accountSeries,
              investedSeries: investedSeries,
              marketSeries: marketSeries,
              adjustmentSeries: adjustmentSeries,
              incomeAdjSeries: incomeAdjSeries,
              derivedSeries: derivedSeriesLegend,
              hidden: hidden,
              onToggle: onToggle,
              onToggleGroup: onToggleGroup,
            ),
            const SizedBox(height: 8),
          ],

          // Chart
          Expanded(
            child: totalSpots.length >= 2
                ? Builder(builder: (context) {
                    // Compute Y range so _DragZoomWrapper can map pixels to chart Y
                    final allY = [
                      ...totalSpots.map((s) => s.y),
                      ...drawnSeries.expand((s) => s.spots.map((p) => p.y)),
                    ];
                    final autoMinY = allY.isEmpty ? 0.0 : allY.reduce(min);
                    final autoMaxY = allY.isEmpty ? 100.0 : allY.reduce(max);
                    final autoRange = autoMaxY - autoMinY;
                    final effectiveMinY = zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
                    final effectiveMaxY = zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);

                    return _DragZoomWrapper(
                      xMin: zoomMinX ?? 0,
                      xMax: zoomMaxX ?? (totalSpots.isNotEmpty ? totalSpots.last.x : 1),
                      yMin: effectiveMinY,
                      yMax: effectiveMaxY,
                      firstDate: allData.firstDate,
                      baseCurrency: allData.baseCurrency,
                      locale: locale,
                      onZoom: onZoom,
                      child: _UnifiedChart(
                        firstDate: allData.firstDate,
                        visible: drawnSeries,
                        totalSpots: totalSpots,
                        showTotal: !hidden.contains('_total'),
                        baseCurrency: allData.baseCurrency,
                        locale: locale,
                        zoomMinX: zoomMinX,
                        zoomMaxX: zoomMaxX,
                        zoomMinY: zoomMinY,
                        zoomMaxY: zoomMaxY,
                      ),
                    );
                  })
                : const Center(child: Text('Not enough data to plot', style: TextStyle(color: Colors.grey))),
          ),

          // Resize handle
          GestureDetector(
            onVerticalDragUpdate: (d) {
              onHeightChanged(chartHeight + d.delta.dy);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: Center(
                child: Container(
                  width: 40,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Chart legend (grouped)
// ════════════════════════════════════════════════════

class _ChartLegend extends StatelessWidget {
  final List<_Series> accountSeries;
  final List<_Series> investedSeries;
  final List<_Series> marketSeries;
  final List<_Series> adjustmentSeries;
  final List<_Series> incomeAdjSeries;
  final List<_Series> derivedSeries;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;

  const _ChartLegend({
    required this.accountSeries,
    required this.investedSeries,
    required this.marketSeries,
    required this.adjustmentSeries,
    required this.incomeAdjSeries,
    this.derivedSeries = const [],
    required this.hidden,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (accountSeries.isNotEmpty)
          ..._buildGroup(context, 'Accounts', accountSeries),
        if (investedSeries.isNotEmpty || marketSeries.isNotEmpty)
          ..._buildAssetGroup(context),
        if (adjustmentSeries.isNotEmpty)
          ..._buildGroup(context, 'Spread Adj.', adjustmentSeries),
        if (incomeAdjSeries.isNotEmpty)
          ..._buildGroup(context, 'Income Adj.', incomeAdjSeries),
        if (derivedSeries.isNotEmpty)
          ..._buildGroup(context, 'Derived', derivedSeries),
        _ToggleLegendItem(
          color: Colors.white,
          label: 'Total',
          bold: true,
          enabled: !hidden.contains('_total'),
          onTap: () => onToggle('_total'),
        ),
      ],
    );
  }

  List<Widget> _buildGroup(BuildContext context, String label, List<_Series> series) {
    final keys = series.map((s) => s.key).toSet();
    final allHidden = keys.every(hidden.contains);

    return [
      GestureDetector(
        onTap: () => onToggleGroup(keys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: !allHidden
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: !allHidden
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              decoration: !allHidden ? null : TextDecoration.lineThrough,
            )),
          ),
        ),
      ),
      for (final s in series)
        _ToggleLegendItem(
          color: s.color,
          label: s.name,
          dashed: s.isDashed,
          enabled: !hidden.contains(s.key),
          onTap: () => onToggle(s.key),
        ),
      const SizedBox(width: 4),
    ];
  }

  List<Widget> _buildAssetGroup(BuildContext context) {
    // Combine invested + market keys for group toggle
    final allKeys = {...investedSeries.map((s) => s.key), ...marketSeries.map((s) => s.key)};
    final allHidden = allKeys.isNotEmpty && allKeys.every(hidden.contains);

    final widgets = <Widget>[
      GestureDetector(
        onTap: () => onToggleGroup(allKeys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: !allHidden
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text('Assets', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: !allHidden
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              decoration: !allHidden ? null : TextDecoration.lineThrough,
            )),
          ),
        ),
      ),
    ];

    // Show each unique asset with one legend item per series type present
    final shownAssets = <int>{};
    for (final s in [...marketSeries, ...investedSeries]) {
      final id = int.tryParse(s.key.split(':').last);
      if (id == null || !shownAssets.add(id)) continue;
      final inv = investedSeries.where((s) => s.key == 'asset_invested:$id');
      final mkt = marketSeries.where((s) => s.key == 'asset_market:$id');

      // Show market value (solid) if present
      if (mkt.isNotEmpty) {
        widgets.add(_ToggleLegendItem(
          color: mkt.first.color,
          label: mkt.first.name,
          enabled: !hidden.contains(mkt.first.key),
          onTap: () => onToggle(mkt.first.key),
        ));
      }
      // Show invested (dashed) if present
      if (inv.isNotEmpty) {
        widgets.add(_ToggleLegendItem(
          color: inv.first.color,
          label: inv.first.name,
          dashed: true,
          enabled: !hidden.contains(inv.first.key),
          onTap: () => onToggle(inv.first.key),
        ));
      }
    }

    widgets.add(const SizedBox(width: 4));
    return widgets;
  }
}

// ════════════════════════════════════════════════════
// Legend item with tap-to-toggle
// ════════════════════════════════════════════════════

class _ToggleLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final bool bold;
  final bool enabled;
  final VoidCallback? onTap;

  const _ToggleLegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
    this.bold = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dashed)
              SizedBox(
                width: 12,
                height: 3,
                child: CustomPaint(painter: _DashedLinePainter(effectiveColor)),
              )
            else
              Container(width: 12, height: 3, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 3.0;
    const gap = 2.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + dashWidth, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════
// Drag-to-zoom wrapper (CloudWatch style)
// ════════════════════════════════════════════════════

class _DragZoomWrapper extends StatefulWidget {
  final Widget child;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double leftReserved;
  final double bottomReserved;
  final DateTime firstDate;
  final String baseCurrency;
  final String locale;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;

  const _DragZoomWrapper({
    required this.child,
    required this.xMin,
    required this.xMax,
    this.yMin = 0,
    this.yMax = 1,
    this.leftReserved = 60,
    this.bottomReserved = 28,
    required this.firstDate,
    required this.baseCurrency,
    required this.locale,
    required this.onZoom,
  });

  @override
  State<_DragZoomWrapper> createState() => _DragZoomWrapperState();
}

class _DragZoomWrapperState extends State<_DragZoomWrapper> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;

  double _pixelToChartX(double px, double chartWidth) {
    final fraction = (px - widget.leftReserved) / chartWidth;
    return widget.xMin + fraction * (widget.xMax - widget.xMin);
  }

  double _pixelToChartY(double py, double chartHeight) {
    // Y is inverted: top of widget = max Y, bottom of chart area = min Y
    final fraction = 1.0 - (py / chartHeight);
    return widget.yMin + fraction * (widget.yMax - widget.yMin);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - widget.leftReserved;
        final chartHeight = constraints.maxHeight - widget.bottomReserved;
        final dateFmt = fmt.fullDateFormat(widget.locale);
        final currFmt = fmt.currencyFormat(widget.locale, currencySymbol(widget.baseCurrency), decimalDigits: 0);

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            setState(() {
              _dragStart = e.localPosition;
              _dragCurrent = e.localPosition;
              _isDragging = false;
            });
          },
          onPointerMove: (e) {
            if (_dragStart == null) return;
            final dist = (e.localPosition - _dragStart!).distance;
            if (dist > 5) _isDragging = true;
            if (_isDragging) {
              setState(() => _dragCurrent = e.localPosition);
            }
          },
          onPointerUp: (e) {
            if (_isDragging && _dragStart != null && _dragCurrent != null) {
              final x1 = _pixelToChartX(_dragStart!.dx, chartWidth);
              final x2 = _pixelToChartX(_dragCurrent!.dx, chartWidth);
              final y1 = _pixelToChartY(_dragStart!.dy, chartHeight);
              final y2 = _pixelToChartY(_dragCurrent!.dy, chartHeight);
              final xLo = min(x1, x2);
              final xHi = max(x1, x2);
              final yLo = min(y1, y2);
              final yHi = max(y1, y2);

              final xSpan = xHi - xLo;
              final ySpan = yHi - yLo;
              final yRange = widget.yMax - widget.yMin;

              double? newMinX, newMaxX, newMinY, newMaxY;
              if (xSpan > 10) {
                newMinX = max(0, xLo);
                newMaxX = min(widget.xMax, xHi);
              }
              if (yRange > 0 && ySpan > yRange * 0.05) {
                newMinY = yLo;
                newMaxY = yHi;
              }
              if (newMinX != null || newMinY != null) {
                widget.onZoom(newMinX ?? widget.xMin, newMaxX ?? widget.xMax, newMinY, newMaxY);
              }
            }
            setState(() {
              _dragStart = null;
              _dragCurrent = null;
              _isDragging = false;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () => widget.onZoom(null, null, null, null),
            child: Stack(
              children: [
                widget.child,
                if (_isDragging && _dragStart != null && _dragCurrent != null)
                  Positioned(
                    left: min(_dragStart!.dx, _dragCurrent!.dx),
                    top: min(_dragStart!.dy, _dragCurrent!.dy),
                    width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                    height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.blue.withValues(alpha: 0.7),
                            child: Text(
                              '${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(min(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt())))} – '
                              '${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(max(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt())))}\n'
                              '${currFmt.format(_pixelToChartY(max(_dragStart!.dy, _dragCurrent!.dy), chartHeight))} – '
                              '${currFmt.format(_pixelToChartY(min(_dragStart!.dy, _dragCurrent!.dy), chartHeight))}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Unified chart widget
// ════════════════════════════════════════════════════

class _UnifiedChart extends StatelessWidget {
  final DateTime firstDate;
  final List<_Series> visible;
  final List<FlSpot> totalSpots;
  final bool showTotal;
  final String baseCurrency;
  final String locale;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;

  const _UnifiedChart({
    required this.firstDate,
    required this.visible,
    required this.totalSpots,
    this.showTotal = true,
    required this.baseCurrency,
    required this.locale,
    this.zoomMinX,
    this.zoomMaxX,
    this.zoomMinY,
    this.zoomMaxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(baseCurrency);

    final totalDays = totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;
    final dateFmt = fmt.monthYearFormat(locale);
    final fullFmt = fmt.fullDateFormat(locale);
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);

    final lineBars = <LineChartBarData>[];

    // Total line
    if (showTotal) {
      lineBars.add(LineChartBarData(
        spots: totalSpots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: isDark ? Colors.white : theme.colorScheme.primary,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.08),
        ),
      ));
    }

    // Visible series lines
    for (final s in visible) {
      lineBars.add(LineChartBarData(
        spots: s.spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: s.isDashed ? 1.5 : 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        dashArray: s.isDashed ? [6, 3] : null,
      ));
    }

    // Compute Y range from visible lines only
    final visibleY = lineBars.expand((b) => b.spots.map((s) => s.y));
    final autoMinY = visibleY.isEmpty ? 0.0 : visibleY.reduce(min);
    final autoMaxY = visibleY.isEmpty ? 100.0 : visibleY.reduce(max);
    final autoRange = autoMaxY - autoMinY;
    final chartMinY = zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
    final chartMaxY = zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);
    final yRange = chartMaxY - chartMinY;

    final xMin = zoomMinX ?? 0;
    final xMax = zoomMaxX ?? totalDays;
    final xRange = xMax - xMin;

    return LineChart(
      LineChartData(
        minX: xMin,
        maxX: xMax,
        minY: chartMinY,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yRange > 0 ? yRange / 4 : 100,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xRange > 0 ? xRange / 5 : 1,
              getTitlesWidget: (value, meta) {
                final date = firstDate.add(Duration(days: value.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(dateFmt.format(date),
                      style: TextStyle(fontSize: 10, color: textColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (value, meta) {
                return Text(currFmt.format(value),
                    style: TextStyle(fontSize: 10, color: textColor));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final barIndex = spot.barIndex;
                final isTotal = showTotal && barIndex == 0;
                final seriesIdx = barIndex - (showTotal ? 1 : 0);
                final date = firstDate.add(Duration(days: spot.x.toInt()));

                if (isTotal) {
                  return LineTooltipItem(
                    '${fullFmt.format(date)}\nTotal: ${currFmt.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }

                if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  return LineTooltipItem(
                    '${s.name}: ${currFmt.format(spot.y)}',
                    TextStyle(color: s.color, fontSize: 11),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Asset Daily Changes Card
// ════════════════════════════════════════════════════

class _AssetDailyChangesCard extends ConsumerStatefulWidget {
  final String locale;
  final String baseCurrency;

  const _AssetDailyChangesCard({
    required this.locale,
    required this.baseCurrency,
  });

  @override
  ConsumerState<_AssetDailyChangesCard> createState() => _AssetDailyChangesCardState();
}

enum _SortCol { name, priceDiff, pct, valueDiff }
enum _SortDir { asc, desc, none }

class _AssetDailyChangesCardState extends ConsumerState<_AssetDailyChangesCard> {
  static const _labels = ['1d', '1w', '1m', '3m', '6m', 'YTD', '1y', '3y', '5y', 'All'];
  int _selectedIdx = 0;
  _SortCol _sortCol = _SortCol.name;
  _SortDir _sortDir = _SortDir.asc;

  void _onHeaderTap(_SortCol col) {
    setState(() {
      if (_sortCol == col) {
        // Cycle: asc → desc → none (back to default name asc)
        _sortDir = switch (_sortDir) {
          _SortDir.asc => _SortDir.desc,
          _SortDir.desc => _SortDir.none,
          _SortDir.none => _SortDir.asc,
        };
        if (_sortDir == _SortDir.none) {
          _sortCol = _SortCol.name;
          _sortDir = _SortDir.asc;
        }
      } else {
        _sortCol = col;
        _sortDir = _SortDir.asc;
      }
    });
  }

  List<AssetDailyChange> _applySorting(List<AssetDailyChange> changes) {
    final sorted = List.of(changes);
    int Function(AssetDailyChange, AssetDailyChange) comparator;
    switch (_sortCol) {
      case _SortCol.name:
        comparator = (a, b) => (a.ticker ?? a.name).compareTo(b.ticker ?? b.name);
      case _SortCol.priceDiff:
        comparator = (a, b) => (a.priceDiff * a.todayFxRate).compareTo(b.priceDiff * b.todayFxRate);
      case _SortCol.pct:
        comparator = (a, b) => a.pricePct.compareTo(b.pricePct);
      case _SortCol.valueDiff:
        comparator = (a, b) => a.valueDiff.compareTo(b.valueDiff);
    }
    sorted.sort((a, b) => _sortDir == _SortDir.desc ? comparator(b, a) : comparator(a, b));
    return sorted;
  }

  DateTime get _referenceDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_selectedIdx) {
      0 => today.subtract(const Duration(days: 1)),
      1 => today.subtract(const Duration(days: 7)),
      2 => DateTime(today.year, today.month - 1, today.day),
      3 => DateTime(today.year, today.month - 3, today.day),
      4 => DateTime(today.year, today.month - 6, today.day),
      5 => DateTime(today.year, 1, 1),
      6 => DateTime(today.year - 1, today.month, today.day),
      7 => DateTime(today.year - 3, today.month, today.day),
      8 => DateTime(today.year - 5, today.month, today.day),
      9 => DateTime(2000, 1, 1),
      _ => today.subtract(const Duration(days: 1)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final changesAsync = ref.watch(assetDailyChangesProvider(_referenceDate));
    final theme = Theme.of(context);
    final amtFmt = fmt.amountFormat(widget.locale);
    final symbol = currencySymbol(widget.baseCurrency);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Price Changes', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                ...List.generate(_labels.length, (i) {
                  final selected = i == _selectedIdx;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text(_labels[i]),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedIdx = i),
                      labelStyle: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            changesAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (changes) {
                if (changes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No price data available', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  );
                }

                final sorted = _applySorting(changes);

                final totalDiff = sorted.fold(0.0, (sum, c) => sum + c.valueDiff);
                final totalPreviousValue = sorted.fold(0.0, (sum, c) => sum + c.previousPrice * c.quantity * c.previousFxRate);
                final totalPct = totalPreviousValue != 0 ? (totalDiff / totalPreviousValue) * 100 : 0.0;

                Widget headerCell(String label, _SortCol col, {int flex = 2, TextAlign align = TextAlign.right}) {
                  final isActive = _sortCol == col;
                  final arrow = isActive ? (_sortDir == _SortDir.asc ? ' \u25B2' : ' \u25BC') : '';
                  return Expanded(
                    flex: flex,
                    child: GestureDetector(
                      onTap: () => _onHeaderTap(col),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          '$label$arrow',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isActive ? theme.colorScheme.primary : Colors.grey,
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: align,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          headerCell('Asset', _SortCol.name, flex: 3, align: TextAlign.left),
                          headerCell('Price \u0394 ($symbol)', _SortCol.priceDiff),
                          headerCell('%', _SortCol.pct),
                          headerCell('Value \u0394 ($symbol)', _SortCol.valueDiff, flex: 3),
                        ],
                      ),
                    ),
                    ...sorted.map((c) => _buildRow(
                      theme: theme,
                      name: c.ticker ?? c.name,
                      priceDiff: c.priceDiff * c.todayFxRate,
                      pricePct: c.pricePct,
                      valueDiff: c.valueDiff,
                      amtFmt: amtFmt,
                    )),
                    const Divider(height: 16),
                    _buildRow(
                      theme: theme,
                      name: 'Total',
                      priceDiff: null,
                      pricePct: totalPct,
                      valueDiff: totalDiff,
                      amtFmt: amtFmt,
                      bold: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required ThemeData theme,
    required String name,
    required double? priceDiff,
    required double pricePct,
    required double valueDiff,
    required NumberFormat amtFmt,
    bool bold = false,
  }) {
    final isPositive = valueDiff >= 0;
    final color = valueDiff == 0 ? Colors.grey : (isPositive ? Colors.green : Colors.red);
    final arrow = valueDiff == 0 ? '' : (isPositive ? '\u25B2 ' : '\u25BC ');
    final weight = bold ? FontWeight.w700 : FontWeight.w400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: weight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (priceDiff != null)
            Expanded(
              flex: 2,
              child: Text(
                '${priceDiff >= 0 ? '+' : ''}${amtFmt.format(priceDiff)}',
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontSize: 11),
                textAlign: TextAlign.right,
              ),
            )
          else
            const Expanded(flex: 2, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text(
              '${pricePct >= 0 ? '+' : ''}${pricePct.toStringAsFixed(2)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '$arrow${amtFmt.format(valueDiff.abs())}',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Metrics Summary Card
// ════════════════════════════════════════════════════

class _MetricsSummaryCard extends StatelessWidget {
  final DerivedMetrics metrics;
  final String locale;
  final String baseCurrency;

  const _MetricsSummaryCard({
    required this.metrics,
    required this.locale,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = currencySymbol(baseCurrency);
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);
    final pctFmt = NumberFormat('0.00%', locale);

    final rows = <_SummaryRow>[
      _SummaryRow('Net Worth', metrics.ytdDeltas['Net Worth'], metrics.athValues['Net Worth'], metrics.drawdowns['Net Worth'], false),
      _SummaryRow('Gross P/L', metrics.ytdDeltas['Gross P/L'], metrics.athValues['Gross P/L'], metrics.drawdowns['Gross P/L'], false),
      _SummaryRow('Net P/L', metrics.ytdDeltas['Net P/L'], metrics.athValues['Net P/L'], metrics.drawdowns['Net P/L'], false),
      if (metrics.plATPercent.isNotEmpty)
        _SummaryRow('P/L AT%', null, null, null, true, currentPct: metrics.plATPercent.values.lastOrNull),
      _SummaryRow('Risparmio', metrics.ytdDeltas['Risparmio'], metrics.athValues['Risparmio'], metrics.drawdowns['Risparmio'], false),
      if (metrics.volatility.isNotEmpty)
        _SummaryRow('Volatility', null, null, null, true, currentPct: metrics.volatility.values.last),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(flex: 3, child: Text('Metric', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10))),
                Expanded(flex: 2, child: Text('Current', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('YTD', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('ATH', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Drawdown', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
              ],
            ),
            const Divider(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(row.label, style: theme.textTheme.bodySmall)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.isPct
                            ? (row.currentPct != null ? pctFmt.format(row.currentPct!) : '—')
                            : (row.ath != null ? currFmt.format((row.ath ?? 0) - (row.drawdown ?? 0)) : '—'),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.ytd != null ? '${row.ytd! >= 0 ? '+' : ''}${currFmt.format(row.ytd!)}' : '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: row.ytd != null ? (row.ytd! >= 0 ? Colors.green : Colors.red) : Colors.grey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.isPct ? '—' : (row.ath != null ? currFmt.format(row.ath!) : '—'),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.isPct ? '—' : (row.drawdown != null && row.drawdown! > 0 ? '-${currFmt.format(row.drawdown!)}' : '—'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: row.drawdown != null && row.drawdown! > 0 ? Colors.red : Colors.grey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow {
  final String label;
  final double? ytd;
  final double? ath;
  final double? drawdown;
  final bool isPct;
  final double? currentPct;
  const _SummaryRow(this.label, this.ytd, this.ath, this.drawdown, this.isPct, {this.currentPct});
}

// ════════════════════════════════════════════════════
// Income vs Expenses Card
// ════════════════════════════════════════════════════

enum _ViewMode { raw, monthly, annualized, daily }
enum _IncExpView { table, barChart, monthlyChart }

class _IncomeExpenseCard extends StatefulWidget {
  final List<YearlyStats> yearlyStats;
  final String locale;
  final String baseCurrency;

  const _IncomeExpenseCard({
    required this.yearlyStats,
    required this.locale,
    required this.baseCurrency,
  });

  @override
  State<_IncomeExpenseCard> createState() => _IncomeExpenseCardState();
}

class _IncomeExpenseCardState extends State<_IncomeExpenseCard> {
  _ViewMode _viewMode = _ViewMode.raw;
  _IncExpView _currentView = _IncExpView.table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = currencySymbol(widget.baseCurrency);
    final currFmt = fmt.currencyFormat(widget.locale, symbol, decimalDigits: 0);
    final pctFmt = NumberFormat('+0.0%;-0.0%', widget.locale);

    // Compute CAGR
    final years = widget.yearlyStats;
    double incomeCagr = 0, expenseCagr = 0;
    if (years.length >= 2) {
      final yoyIncome = years.skip(1).map((y) => 1 + y.yoyIncomeChangePct);
      final yoyExpense = years.skip(1).map((y) => 1 + y.yoyExpenseChangePct);
      if (yoyIncome.every((v) => v > 0)) {
        incomeCagr = yoyIncome.reduce((a, b) => a * b);
        incomeCagr = pow(incomeCagr, 1.0 / (years.length - 1)).toDouble() - 1;
      }
      if (yoyExpense.every((v) => v > 0)) {
        expenseCagr = yoyExpense.reduce((a, b) => a * b);
        expenseCagr = pow(expenseCagr, 1.0 / (years.length - 1)).toDouble() - 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Income vs Expenses', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.table_chart, size: 18),
                  onPressed: () => setState(() => _currentView = _IncExpView.table),
                  color: _currentView == _IncExpView.table ? theme.colorScheme.primary : null,
                  tooltip: 'Table',
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart, size: 18),
                  onPressed: () => setState(() => _currentView = _IncExpView.barChart),
                  color: _currentView == _IncExpView.barChart ? theme.colorScheme.primary : null,
                  tooltip: 'Bar Chart',
                ),
                IconButton(
                  icon: const Icon(Icons.show_chart, size: 18),
                  onPressed: () => setState(() => _currentView = _IncExpView.monthlyChart),
                  color: _currentView == _IncExpView.monthlyChart ? theme.colorScheme.primary : null,
                  tooltip: 'Monthly',
                ),
              ],
            ),
            Row(
              children: [
                for (final mode in _ViewMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                      selected: _viewMode == mode,
                      onSelected: (_) => setState(() => _viewMode = mode),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: TextStyle(fontSize: 11, fontWeight: _viewMode == mode ? FontWeight.w700 : FontWeight.w400),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                const Spacer(),
                if (years.length >= 2) ...[
                  Text('Income CAGR: ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey)),
                  Text(pctFmt.format(incomeCagr), style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10, color: incomeCagr >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(width: 8),
                  Text('Expense CAGR: ', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey)),
                  Text(pctFmt.format(expenseCagr), style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10, color: expenseCagr <= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600,
                  )),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_currentView == _IncExpView.table)
              _buildTable(theme, currFmt, pctFmt)
            else if (_currentView == _IncExpView.barChart)
              _buildBarChart(theme, currFmt)
            else
              _buildMonthlyChart(theme, currFmt),
          ],
        ),
      ),
    );
  }

  double _income(YearlyStats y) => switch (_viewMode) {
    _ViewMode.raw => y.income,
    _ViewMode.monthly => y.monthlyIncome,
    _ViewMode.annualized => y.annualizedIncome,
    _ViewMode.daily => y.dailyIncome,
  };

  double _expense(YearlyStats y) => switch (_viewMode) {
    _ViewMode.raw => y.expenses,
    _ViewMode.monthly => y.monthlyExpenses,
    _ViewMode.annualized => y.annualizedExpenses,
    _ViewMode.daily => y.dailyExpenses,
  };

  double _savings(YearlyStats y) => _income(y) - _expense(y);

  Widget _buildTable(ThemeData theme, NumberFormat currFmt, NumberFormat pctFmt) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 1, child: Text('Year', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10))),
            Expanded(flex: 1, child: Text('Days', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Income', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Expenses', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Savings', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
            Expanded(flex: 1, child: Text('Rate', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('YoY Exp', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10), textAlign: TextAlign.right)),
          ],
        ),
        const Divider(height: 8),
        for (final y in widget.yearlyStats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('${y.year}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('${y.trackedDays}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(currFmt.format(_income(y)), style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.green), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(currFmt.format(_expense(y)), style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.red), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(
                  currFmt.format(_savings(y)),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: _savings(y) >= 0 ? Colors.green : Colors.red),
                  textAlign: TextAlign.right,
                )),
                Expanded(flex: 1, child: Text(
                  '${(y.savingsRate * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: y.savingsRate >= 0 ? Colors.green : Colors.red),
                  textAlign: TextAlign.right,
                )),
                Expanded(flex: 2, child: Text(
                  y.yoyExpenseChangePct != 0 ? pctFmt.format(y.yoyExpenseChangePct) : '—',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: y.yoyExpenseChangePct <= 0 ? Colors.green : Colors.red),
                  textAlign: TextAlign.right,
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBarChart(ThemeData theme, NumberFormat currFmt) {
    final years = widget.yearlyStats;
    if (years.isEmpty) return const SizedBox();

    final maxVal = years.map((y) => _income(y)).reduce(max);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.1,
          barGroups: years.asMap().entries.map((entry) {
            final y = entry.value;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: _income(y),
                  color: Colors.green.withValues(alpha: 0.7),
                  width: 12,
                ),
                BarChartRodData(
                  toY: _expense(y),
                  color: Colors.red.withValues(alpha: 0.7),
                  width: 12,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= years.length) return const SizedBox();
                  return Text('${years[idx].year}', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, _) => Text(
                  currFmt.format(value),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(ThemeData theme, NumberFormat currFmt) {
    final years = widget.yearlyStats;
    if (years.isEmpty) return const SizedBox();

    final monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final yearColors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.pink, Colors.cyan];

    final lines = <LineChartBarData>[];
    final allY = <double>[];

    for (var i = 0; i < years.length; i++) {
      final y = years[i];
      final spots = <FlSpot>[];
      for (var m = 1; m <= 12; m++) {
        final val = y.monthlyExpenseBreakdown[m] ?? 0;
        if (val > 0) {
          spots.add(FlSpot(m.toDouble() - 1, val));
          allY.add(val);
        }
      }
      if (spots.isEmpty) continue;
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: yearColors[i % yearColors.length],
        barWidth: 2,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ));
    }

    if (lines.isEmpty) return const Text('No monthly data', style: TextStyle(color: Colors.grey));

    final maxY = allY.isEmpty ? 100.0 : allY.reduce(max) * 1.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < years.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 3, color: yearColors[i % yearColors.length]),
                  const SizedBox(width: 4),
                  Text('${years[i].year}', style: const TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY: maxY,
              lineBarsData: lines,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= 12) return const SizedBox();
                      return Text(monthLabels[idx], style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, _) => Text(
                      currFmt.format(value),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
      ],
    );
  }
}
