import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, Variable;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/formatters.dart' as fmt;

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../services/exchange_rate_service.dart';
import '../../l10n/app_strings.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';
import '../widgets/privacy_text.dart';
import 'allocation_tab.dart';

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
  final bool rightAxis; // true → scale into left pixel space, show on right Y-axis
  const _Series({
    required this.key,
    required this.name,
    required this.color,
    required this.spots,
    this.isDashed = false,
    this.rightAxis = false,
  });
}

/// All chart data: account series, asset series, CAPEX series, market value series.
class _AllSeriesData {
  final DateTime firstDate;
  final List<_Series> accounts;      // key: "account:<id>"
  final List<_Series> assetInvested; // key: "asset_invested:<id>"
  final List<_Series> assetMarket;   // key: "asset_market:<id>"
  final List<_Series> adjustments;      // key: "adjustment:<id>"
  final List<_Series> incomeAdjustments; // key: "income_adj:<id>"
  final String baseCurrency;

  const _AllSeriesData({
    required this.firstDate,
    required this.accounts,
    required this.assetInvested,
    required this.assetMarket,
    required this.adjustments,
    required this.incomeAdjustments,
    required this.baseCurrency,
  });

  List<_Series> get allSeries => [...accounts, ...assetInvested, ...assetMarket, ...adjustments, ...incomeAdjustments];
}

// ════════════════════════════════════════════════════
// Income/Expense data models
// ════════════════════════════════════════════════════

class _MonthBucket {
  final int year, month;
  final double income, navChange;
  double get expenses    => income - navChange;
  double get savings     => navChange;
  double get savingsRate => income > 0 ? navChange / income : 0;
  const _MonthBucket({required this.year, required this.month,
                      required this.income, required this.navChange});
}

class _YearBucket {
  final int year, days;
  final double income, navChange;
  final List<_MonthBucket> months;

  double get expenses        => income - navChange;
  double get savings         => navChange;
  double get savingsRate     => income > 0 ? navChange / income : 0;
  double get dailyIncome     => days > 0 ? income / days : 0;
  double get dailyExpenses   => days > 0 ? expenses / days : 0;
  double get monthlyIncome   => months.isNotEmpty ? income / months.length : 0;
  double get monthlyExpenses => months.isNotEmpty ? expenses / months.length : 0;

  const _YearBucket({required this.year, required this.days,
                     required this.income, required this.navChange,
                     required this.months});
}

class _IncomeExpenseData {
  final List<_YearBucket> years;
  final String baseCurrency;
  final DateTime firstDate;
  const _IncomeExpenseData({required this.years, required this.baseCurrency,
                            required this.firstDate});
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
// Unified data provider — computes ALL series at once
// ════════════════════════════════════════════════════

final _allSeriesDataProvider = FutureProvider<_AllSeriesData?>((ref) async {
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
  var colorIdx = 0;

  // ════════════════════════════════════════════════
  // 1. ACCOUNTS — daily balance from transactions
  // ════════════════════════════════════════════════
  final activeAccounts = await (db.select(db.accounts)
        ..where((a) => a.isActive.equals(true))
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

  // ════════════════════════════════════════════════
  // 2. ASSETS — cumulative invested value from events
  // ════════════════════════════════════════════════
  final activeAssets = await (db.select(db.assets)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
  final assetIds = activeAssets.map((a) => a.id).toSet();

  final perAssetDeltas = <int, Map<int, double>>{};
  final perAssetQtyDeltas = <int, Map<int, double>>{};

  if (assetIds.isNotEmpty) {
    final assetPlaceholders = assetIds.map((_) => '?').join(',');
    final evRows = await db.customSelect(
      'SELECT asset_id, date, type, amount, quantity, currency, exchange_rate, commission '
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
      final commission = row.readNullable<double>('commission') ?? 0;
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

      final netAmount = amount - commission;
      final baseAmount = await convertToBase(
        amount: netAmount, currency: currency, baseCurrency: baseCurrency,
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

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // ── Build account series ──
  final accountSeries = <_Series>[];
  for (final account in activeAccounts) {
    if (!perAccount.containsKey(account.id)) continue;
    final dayMap = perAccount[account.id]!;
    final spots = <FlSpot>[];
    double? running;

    for (final dayKey in sortedDays) {
      if (dayMap.containsKey(dayKey)) running = dayMap[dayKey];
      if (running != null) {
        final rate = await rates.getRate(account.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, running * rate));
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

  // ── Build asset invested series (cumulative) ──
  final assetInvestedSeries = <_Series>[];
  for (final asset in activeAssets) {
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final deltaMap = perAssetDeltas[asset.id]!;
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    var started = false;

    for (final dayKey in sortedDays) {
      if (deltaMap.containsKey(dayKey)) {
        cumulative += deltaMap[dayKey]!;
        started = true;
      }
      if (started) {
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, cumulative));
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
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final qtyDeltaMap = perAssetQtyDeltas[asset.id] ?? {};

    // Load market prices
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

    final spots = <FlSpot>[];
    var cumQuantity = 0.0;
    double? lastPrice;
    var started = false;

    for (final dayKey in assetDays) {
      if (qtyDeltaMap.containsKey(dayKey)) {
        cumQuantity += qtyDeltaMap[dayKey]!;
        started = true;
      }
      if (priceMap.containsKey(dayKey)) {
        lastPrice = priceMap[dayKey]!;
      }
      if (!started) continue;
      if (lastPrice != null && cumQuantity > 0) {
        final fxRate = await rates.getRate(asset.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, cumQuantity * lastPrice * fxRate));
      }
    }

    // Use same color as invested counterpart
    final investedIdx = assetInvestedSeries.indexWhere((s) => s.key == 'asset_invested:${asset.id}');
    final color = investedIdx >= 0 ? assetInvestedSeries[investedIdx].color : _chartColors[colorIdx++ % _chartColors.length];

    assetMarketSeries.add(_Series(
      key: 'asset_market:${asset.id}',
      name: asset.ticker ?? asset.name,
      color: color,
      spots: spots,
    ));
  }

  // ════════════════════════════════════════════════
  // 3. CAPEX — re-add at expense date, remove during spread steps
  // ════════════════════════════════════════════════
  final activeSchedules = await (db.select(db.depreciationSchedules)
        ..where((s) => s.isActive.equals(true)))
      .get();

  final adjustmentSeries = <_Series>[];

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

    final capexDays = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;

    for (final dayKey in capexDays) {
      final rate = await rates.getRate(schedule.currency, dayKey);
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      if (prevY != null && spots.isNotEmpty && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      cumulative += deltaMap[dayKey]!;
      final y = cumulative * rate;
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

  // ════════════════════════════════════════════════
  // 4. INCOME ADJUSTMENTS — subtract at income date, add back at expenses
  // ════════════════════════════════════════════════
  final activeIncomeAdj = await (db.select(db.incomeAdjustments)
        ..where((a) => a.isActive.equals(true)))
      .get();

  final incomeAdjSeries = <_Series>[];

  for (final adj in activeIncomeAdj) {
    final expenses = await (db.select(db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.equals(adj.id))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();

    final deltaMap = <int, double>{};

    // At income date: subtract the full amount
    final incomeDayKey = toDayKey(adj.incomeDate);
    deltaMap[incomeDayKey] = (deltaMap[incomeDayKey] ?? 0) - adj.totalAmount;
    allDayKeys.add(incomeDayKey);

    // At each expense date: add back the expense amount
    for (final exp in expenses) {
      final dayKey = toDayKey(exp.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) + exp.amount;
      allDayKeys.add(dayKey);
    }

    if (deltaMap.isEmpty) continue;

    final adjDays = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;

    for (final dayKey in adjDays) {
      final rate = await rates.getRate(adj.currency, dayKey);
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      if (prevY != null && spots.isNotEmpty && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      cumulative += deltaMap[dayKey]!;
      final y = cumulative * rate;
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

  return _AllSeriesData(
    firstDate: firstDate,
    accounts: accountSeries,
    assetInvested: assetInvestedSeries,
    assetMarket: assetMarketSeries,
    adjustments: adjustmentSeries,
    incomeAdjustments: incomeAdjSeries,
    baseCurrency: baseCurrency,
  );
});

// ════════════════════════════════════════════════════
// Income/Expense data provider
// ════════════════════════════════════════════════════

final _incomeExpenseDataProvider = FutureProvider<_IncomeExpenseData?>((ref) async {
  final allSeriesData = await ref.watch(_allSeriesDataProvider.future);
  if (allSeriesData == null) return null;

  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  ref.watch(incomesProvider); // reactive

  final rates = _RateResolver(rateService, baseCurrency);

  // 1. Load all incomes, convert to base currency
  final rows = await db.customSelect(
    'SELECT date, amount, currency FROM incomes ORDER BY date ASC',
  ).get();

  final incomeByMonth = <(int, int), double>{};
  for (final row in rows) {
    final dt = DateTime.fromMillisecondsSinceEpoch(row.read<int>('date') * 1000);
    final amount = row.read<double>('amount');
    final currency = row.read<String>('currency');
    final rate = await rates.getRate(currency, toDayKey(dt));
    final key = (dt.year, dt.month);
    incomeByMonth[key] = (incomeByMonth[key] ?? 0) + amount * rate;
  }

  // 2. Build total saving series (same composition as Cash Flow tab)
  final savingSpots = buildTotalSpots([
    ...allSeriesData.accounts.map((s) => s.spots),
    ...allSeriesData.assetInvested.map((s) => s.spots),
    ...allSeriesData.adjustments.map((s) => s.spots),
    ...allSeriesData.incomeAdjustments.map((s) => s.spots),
  ]);

  double lookupNAV(DateTime date) {
    final x = date.difference(allSeriesData.firstDate).inDays.toDouble();
    double nav = 0;
    for (final s in savingSpots) {
      if (s.x <= x) { nav = s.y; } else { break; }
    }
    return nav;
  }

  // 3. Build monthly + yearly buckets
  final now = DateTime.now();
  final years = <_YearBucket>[];

  for (int y = allSeriesData.firstDate.year; y <= now.year; y++) {
    final yStart = DateTime(y, 1, 1);
    final isCurrentYear = y == now.year;
    final effectiveEnd = isCurrentYear ? now : DateTime(y, 12, 31);
    final days = effectiveEnd.difference(yStart).inDays + 1;

    double yearIncome = 0;
    final months = <_MonthBucket>[];

    for (int m = 1; m <= 12; m++) {
      if (isCurrentYear && m > now.month) break;
      final mStart = DateTime(y, m, 1);
      final mEnd = (isCurrentYear && m == now.month)
          ? now
          : (m < 12
              ? DateTime(y, m + 1, 1).subtract(const Duration(days: 1))
              : DateTime(y, 12, 31));
      final mIncome = incomeByMonth[(y, m)] ?? 0;
      yearIncome += mIncome;
      months.add(_MonthBucket(
        year: y, month: m,
        income: mIncome,
        navChange: lookupNAV(mEnd) - lookupNAV(mStart),
      ));
    }

    years.add(_YearBucket(
      year: y, days: days,
      income: yearIncome,
      navChange: lookupNAV(effectiveEnd) - lookupNAV(yStart),
      months: months,
    ));
  }

  return _IncomeExpenseData(
    years: years,
    baseCurrency: baseCurrency,
    firstDate: allSeriesData.firstDate,
  );
});

/// EOY prediction: extrapolate current year total based on prior-year pattern.
/// Returns null if insufficient data.
double? _eoyPrediction(_YearBucket current, _YearBucket prev, {bool expenses = false}) {
  if (current.months.isEmpty) return null;
  final n = current.months.length;
  final prevSame = prev.months
      .where((m) => m.month <= n)
      .fold(0.0, (s, m) => s + (expenses ? m.expenses : m.income));
  if (prevSame == 0) return null;
  final currentTotal = expenses ? current.expenses : current.income;
  final prevTotal    = expenses ? prev.expenses    : prev.income;
  return prevTotal * currentTotal / prevSame;
}


// ════════════════════════════════════════════════════
// Cash Flow math utilities
// ════════════════════════════════════════════════════

/// Forward-fill spots to one point per integer day (gap-free).
List<FlSpot> _densifySpots(List<FlSpot> spots) {
  if (spots.isEmpty) return [];
  final sorted = List<FlSpot>.from(spots)..sort((a, b) => a.x.compareTo(b.x));
  final result = <FlSpot>[];
  int ix = sorted.first.x.round();
  final ixMax = sorted.last.x.ceil();
  double lastY = sorted.first.y;
  int si = 0;
  while (ix <= ixMax) {
    while (si < sorted.length && sorted[si].x <= ix + 0.5) {
      lastY = sorted[si].y;
      si++;
    }
    result.add(FlSpot(ix.toDouble(), lastY));
    ix++;
  }
  return result;
}

/// Trailing SMA of [windowDays] on spots — O(n) sliding window.
List<FlSpot> _computeMA(List<FlSpot> spots, int windowDays) {
  final dense = _densifySpots(spots);
  if (dense.isEmpty) return [];
  final result = <FlSpot>[];
  double sum = 0;
  for (int i = 0; i < dense.length; i++) {
    sum += dense[i].y;
    if (i >= windowDays) sum -= dense[i - windowDays].y;
    result.add(FlSpot(dense[i].x, sum / min(i + 1, windowDays)));
  }
  return result;
}

/// Day-over-day first difference (velocity = derivative of MA).
List<FlSpot> _computeVelocity(List<FlSpot> dense) {
  final result = <FlSpot>[];
  for (int i = 1; i < dense.length; i++) {
    result.add(FlSpot(dense[i].x, dense[i].y - dense[i - 1].y));
  }
  return result;
}

/// Build spending spots: cumulative sum of negative daily deltas of the saving
/// series (mirrors Excel's "Uscite cumulate" = cumsum of MIN(0, daily_P&L)).
/// Output spots share the same X axis (days from firstDate) as saving spots.
List<FlSpot> _buildSpendingFromSaving(List<FlSpot> savingSpots) {
  final dense = _densifySpots(savingSpots);
  if (dense.length < 2) return [];
  final result = <FlSpot>[];
  double cumul = 0;
  result.add(FlSpot(dense.first.x, 0));
  for (int i = 1; i < dense.length; i++) {
    final delta = dense[i].y - dense[i - 1].y;
    if (delta < 0) cumul += delta; // accumulate only negative (outflow) days
    result.add(FlSpot(dense[i].x, cumul));
  }
  return result;
}

/// Element-wise difference of two spot lists (a − b), aligned by densified X.
List<FlSpot> _computeDiff(List<FlSpot> a, List<FlSpot> b) {
  if (a.isEmpty || b.isEmpty) return [];
  final da = _densifySpots(a);
  final db = _densifySpots(b);
  final bMap = <double, double>{for (final s in db) s.x: s.y};
  return [for (final sa in da) if (bMap.containsKey(sa.x)) FlSpot(sa.x, sa.y - bMap[sa.x]!)];
}

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

  bool _hideComponentsFor(int chartId, {bool defaultValue = true}) =>
      _hideComponents.putIfAbsent(chartId, () => defaultValue);

  @override
  Widget build(BuildContext context) {
    final allDataAsync = ref.watch(_allSeriesDataProvider);
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final s = ref.watch(appStringsProvider);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: s.dashTabCharts),
              Tab(text: s.dashTabCashFlow),
              Tab(text: s.dashTabAllocation),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildChartsTab(allDataAsync, locale, context, s),
                _buildCashFlowTab(allDataAsync, locale, context, s),
                const AllocationTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab(
    AsyncValue<_AllSeriesData?> allDataAsync,
    String locale,
    BuildContext context,
    AppStrings s,
  ) {
    return allDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (allData) {
        if (allData == null) {
          return Center(
            child: Text(s.dashNoData,
                style: const TextStyle(color: Colors.grey)),
          );
        }

        final charts = _buildStaticCharts(allData);

        // Build set of chart IDs that are sources of a combined chart
        final collapsedChartIds = <int>{};
        for (final chart in charts) {
          if (chart.widgetType == 'chart' && chart.sourceChartIds != null) {
            try {
              final ids = (jsonDecode(chart.sourceChartIds!) as List).cast<int>();
              collapsedChartIds.addAll(ids);
            } catch (_) {}
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: charts.length,
          itemBuilder: (context, index) {
            final chart = charts[index];

            // Price changes widget
            if (chart.widgetType == 'price_changes') {
              return Padding(
                key: ValueKey(chart.id),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(chart.title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    _AssetDailyChangesCard(locale: locale, baseCurrency: allData.baseCurrency),
                  ],
                ),
              );
            }

            // Chart widgets
            final isCombined = chart.sourceChartIds != null;
            final isCollapsed = collapsedChartIds.contains(chart.id) && !_expandedCollapsed.contains(chart.id);

            // Source charts auto-collapse under the combined chart
            if (isCollapsed) {
              return Padding(
                key: ValueKey(chart.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollapsedChartRow(
                  chart: chart,
                  onExpand: () => setState(() => _expandedCollapsed.add(chart.id)),
                ),
              );
            }

            List<_Series> filteredSeries;
            if (isCombined) {
              filteredSeries = _buildCombinedSeries(charts, chart, allData);
            } else {
              final seriesConfigs = _parseSeriesJson(chart.seriesJson);
              filteredSeries = _filterSeries(allData, seriesConfigs);
            }

            final hidden = _hiddenFor(chart.id);
            final zoom = _zoomFor(chart.id);
            final hideComp = isCombined ? false : _hideComponentsFor(chart.id);

            return Padding(
              key: ValueKey(chart.id),
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
                onCollapse: (collapsedChartIds.contains(chart.id) && _expandedCollapsed.contains(chart.id))
                    ? () => setState(() => _expandedCollapsed.remove(chart.id))
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCashFlowTab(
    AsyncValue<_AllSeriesData?> allDataAsync,
    String locale,
    BuildContext context,
    AppStrings s,
  ) {
    return allDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (allData) {
        if (allData == null) {
          return Center(
            child: Text(s.dashNoData,
                style: const TextStyle(color: Colors.grey)),
          );
        }
        return _CashFlowTab(allData: allData, locale: locale);
      },
    );
  }

  /// Build the fixed set of dashboard widgets from live series data.
  /// Widget definitions are static; series are resolved dynamically from all
  /// active accounts, assets, and adjustments — no IDs are hardcoded.
  List<DashboardChart> _buildStaticCharts(_AllSeriesData allData) {
    final now = DateTime.now();

    List<Map<String, dynamic>> toConfigs(List<_Series> series) => series.map((s) {
          final parts = s.key.split(':');
          return {'type': parts[0], 'id': int.parse(parts[1])};
        }).toList();

    // Total Assets: all accounts + all market values + spread adjustments
    final totalAssetsJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.assetMarket),
      ...toConfigs(allData.adjustments),
    ]);

    // Cash: all accounts + spread adjustments only (no income adj)
    final cashJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.adjustments),
    ]);

    // Saving: all accounts + all invested assets + all adjustments (spread + income)
    final savingJson = jsonEncode([
      ...toConfigs(allData.accounts),
      ...toConfigs(allData.assetInvested),
      ...toConfigs(allData.adjustments),
      ...toConfigs(allData.incomeAdjustments),
    ]);

    // Invested: all invested assets
    final investedJson = jsonEncode(toConfigs(allData.assetInvested));

    // Stable negative IDs avoid clashing with any real DB rows
    const idPriceChanges = -1;
    const idTotals = -2;
    const idTotalAssets = -3;
    const idCash = -4;
    const idSaving = -5;
    const idInvested = -6;

    return [
      DashboardChart(id: idPriceChanges, title: 'Price Changes', widgetType: 'price_changes',
          sortOrder: 0, seriesJson: '[]', createdAt: now),
      DashboardChart(id: idTotals, title: 'Totals', widgetType: 'chart',
          sortOrder: 1, seriesJson: '[]',
          sourceChartIds: jsonEncode([idTotalAssets, idCash, idSaving, idInvested]),
          createdAt: now),
      DashboardChart(id: idTotalAssets, title: 'Total Assets', widgetType: 'chart',
          sortOrder: 2, seriesJson: totalAssetsJson, createdAt: now),
      DashboardChart(id: idCash, title: 'Cash', widgetType: 'chart',
          sortOrder: 3, seriesJson: cashJson, createdAt: now),
      DashboardChart(id: idSaving, title: 'Saving', widgetType: 'chart',
          sortOrder: 4, seriesJson: savingJson, createdAt: now),
      DashboardChart(id: idInvested, title: 'Invested', widgetType: 'chart',
          sortOrder: 5, seriesJson: investedJson, createdAt: now),
    ];
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
        .where((s) => !excludeFromTotal.contains(s.key) && !s.rightAxis)
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
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
      final id = config['id'] as int?;
      if (type == null || id == null) continue;
      final key = '$type:$id';
      final match = allData.allSeries.where((s) => s.key == key);
      if (match.isNotEmpty) result.add(match.first);
    }
    return result;
  }

}


// ════════════════════════════════════════════════════
// Collapsed chart row (auto-collapsed source chart)
// ════════════════════════════════════════════════════

class _CollapsedChartRow extends StatelessWidget {
  final DashboardChart chart;
  final VoidCallback onExpand;

  const _CollapsedChartRow({required this.chart, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.expand_more, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(chart.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Unified chart card widget
// ════════════════════════════════════════════════════

class _ChartCard extends ConsumerWidget {
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
  final VoidCallback? onCollapse;
  final Widget? headerExtra; // optional trailing widget in title bar (e.g. MA window input)

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
    this.onCollapse,
    this.headerExtra,
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
        .where((s) => !excludeFromTotal.contains(s.key) && !s.rightAxis)
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate = ref.watch(privacyModeProvider);
    final s = ref.watch(appStringsProvider);
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
    final cfSeries = series.where((s) => s.key.startsWith('cf:')).toList();

    final hasZoom = zoomMinX != null || zoomMinY != null;

    return SizedBox(
      height: chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Row(
            children: [
              if (onCollapse != null)
                GestureDetector(
                  onTap: onCollapse,
                  child: const Icon(Icons.expand_less, size: 18, color: Colors.grey),
                ),
              if (onCollapse != null) const SizedBox(width: 4),
              Expanded(
                child: Text(chart.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (chart.sourceChartIds == null)
                isPrivate
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Text(currFmt.format(currentTotal),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      )
                    : Text(currFmt.format(currentTotal),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              // Hide components toggle (not for combined charts — they only show contributors)
              if (chart.sourceChartIds == null)
                IconButton(
                  icon: Icon(hideComponents ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: onToggleHideComponents,
                  tooltip: hideComponents ? s.dashShowComponents : s.dashHideComponents,
                ),
              if (hasZoom)
                IconButton(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  onPressed: () => onZoom(null, null, null, null),
                  tooltip: s.dashResetZoom,
                ),
              if (headerExtra != null) headerExtra!,
            ],
          ),
          const SizedBox(height: 4),

          // Legend
          if (!hideComponents) ...[
            _ChartLegend(
              accountSeries: cfSeries.isEmpty ? accountSeries : [],
              investedSeries: cfSeries.isEmpty ? investedSeries : [],
              marketSeries: cfSeries.isEmpty ? marketSeries : [],
              adjustmentSeries: cfSeries.isEmpty ? adjustmentSeries : [],
              incomeAdjSeries: cfSeries.isEmpty ? incomeAdjSeries : [],
              otherSeries: cfSeries,
              showTotalItem: cfSeries.isEmpty,
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
                    // Must match _UnifiedChart's Y range: include total only when shown
                    final showTotal = chart.sourceChartIds == null && !hidden.contains('_total');
                    final allY = [
                      if (showTotal) ...totalSpots.map((s) => s.y),
                      ...drawnSeries.where((s) => !s.rightAxis).expand((s) => s.spots.map((p) => p.y)),
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
                        showTotal: chart.sourceChartIds == null && !hidden.contains('_total'),
                        baseCurrency: allData.baseCurrency,
                        locale: locale,
                        zoomMinX: zoomMinX,
                        zoomMaxX: zoomMaxX,
                        zoomMinY: zoomMinY,
                        zoomMaxY: zoomMaxY,
                        isPrivate: isPrivate,
                      ),
                    );
                  })
                : Center(child: Text(s.dashNotEnoughData, style: const TextStyle(color: Colors.grey))),
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
  final List<_Series> otherSeries; // e.g. cash-flow series with cf: prefix
  final bool showTotalItem;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;

  const _ChartLegend({
    required this.accountSeries,
    required this.investedSeries,
    required this.marketSeries,
    required this.adjustmentSeries,
    required this.incomeAdjSeries,
    this.otherSeries = const [],
    this.showTotalItem = true,
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
        for (final s in otherSeries)
          _ToggleLegendItem(
            color: s.color,
            label: s.rightAxis ? '${s.name} (→)' : s.name,
            dashed: s.isDashed,
            enabled: !hidden.contains(s.key),
            onTap: () => onToggle(s.key),
          ),
        if (showTotalItem)
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
  final bool isPrivate;

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
    this.isPrivate = false,
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

    // ── Dual Y-axis setup ──
    final leftVisible  = visible.where((s) => !s.rightAxis).toList();
    final rightVisible = visible.where((s) =>  s.rightAxis).toList();
    final hasDualAxis  = rightVisible.isNotEmpty;

    // Left Y range (left series + total)
    final leftY = [
      if (showTotal) ...totalSpots.map((s) => s.y),
      ...leftVisible.expand((s) => s.spots.map((p) => p.y)),
    ];
    final leftAutoMin = leftY.isEmpty ? 0.0  : leftY.reduce(min);
    final leftAutoMax = leftY.isEmpty ? 100.0 : leftY.reduce(max);
    final leftAutoRange = leftAutoMax - leftAutoMin;
    final chartMinY = zoomMinY ?? (leftAutoRange > 0 ? leftAutoMin - leftAutoRange * 0.05 : leftAutoMin - 100);
    final chartMaxY = zoomMaxY ?? (leftAutoRange > 0 ? leftAutoMax + leftAutoRange * 0.05 : leftAutoMax + 100);
    final chartRange = chartMaxY - chartMinY;
    final yRange = chartRange;

    // Right Y range (natural scale, not zoomed — always shows full range)
    double rightNatMin = 0, rightNatMax = 1;
    if (hasDualAxis) {
      final rightY = rightVisible.expand((s) => s.spots.map((p) => p.y)).toList();
      if (rightY.isNotEmpty) {
        rightNatMin = rightY.reduce(min);
        rightNatMax = rightY.reduce(max);
      }
    }
    final rightNatRange = (rightNatMax - rightNatMin).abs().clamp(1e-9, double.infinity);

    // Scale right-axis value → left pixel space
    double scaleRight(double y) =>
        chartRange <= 0 ? chartMinY : (y - rightNatMin) / rightNatRange * chartRange + chartMinY;

    // Reverse-scale left-pixel value → actual right-axis value (for tooltip/labels)
    double unscaleRight(double scaledY) =>
        chartRange <= 0 ? rightNatMin : (scaledY - chartMinY) / chartRange * rightNatRange + rightNatMin;

    final lineBars = <LineChartBarData>[];

    // Total line (always left axis)
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

    // Visible series lines (right-axis series are scaled into left pixel space)
    for (final s in visible) {
      final spots = s.rightAxis
          ? s.spots.map((pt) => FlSpot(pt.x, scaleRight(pt.y))).toList()
          : s.spots;
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: s.rightAxis ? 1.5 : (s.isDashed ? 1.5 : 2),
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        dashArray: s.isDashed ? [6, 3] : null,
      ));
    }

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
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: hasDualAxis,
              reservedSize: hasDualAxis ? 68 : 0,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (scaledY, meta) {
                final actualY = unscaleRight(scaledY);
                final label = isPrivate ? '••••' : currFmt.format(actualY);
                return Text(label, style: TextStyle(fontSize: 9, color: textColor));
              },
            ),
          ),
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
                final label = this.isPrivate ? '••••' : currFmt.format(value);
                return Text(label,
                    style: TextStyle(fontSize: 10, color: textColor));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              final items = <LineTooltipItem?>[];
              for (int spotIdx = 0; spotIdx < spots.length; spotIdx++) {
                final spot = spots[spotIdx];
                final barIndex = spot.barIndex;
                final isTotal = showTotal && barIndex == 0;
                final seriesIdx = barIndex - (showTotal ? 1 : 0);
                final date = firstDate.add(Duration(days: spot.x.toInt()));
                final datePrefix = spotIdx == 0 ? '${fullFmt.format(date)}\n' : '';

                if (isTotal) {
                  items.add(LineTooltipItem(
                    '${fullFmt.format(date)}\nTotal: ${currFmt.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ));
                } else if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  final displayY = s.rightAxis ? unscaleRight(spot.y) : spot.y;
                  items.add(LineTooltipItem(
                    '$datePrefix${s.name}: ${currFmt.format(displayY)}${s.rightAxis ? ' (→)' : ''}',
                    TextStyle(color: s.color, fontSize: 11),
                  ));
                } else {
                  items.add(null);
                }
              }
              return items;
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
    final isPrivate = ref.watch(privacyModeProvider);
    final sl = ref.watch(appStringsProvider);
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
                Text(sl.dashPriceChanges, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
              error: (e, _) => Text(sl.error(e), style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (changes) {
                if (changes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(sl.dashNoPriceData, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                      url: c.investingUrl,
                      isPrivate: isPrivate,
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
                      isPrivate: isPrivate,
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
    String? url,
    required bool isPrivate,
  }) {
    final isPositive = valueDiff >= 0;
    final color = valueDiff == 0 ? Colors.grey : (isPositive ? Colors.green : Colors.red);
    final arrow = valueDiff == 0 ? '' : (isPositive ? '\u25B2 ' : '\u25BC ');
    final weight = bold ? FontWeight.w700 : FontWeight.w400;

    Widget maybeBlur(Widget child) => isPrivate
        ? ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: child)
        : child;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: url != null
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => launchUrl(Uri.parse(url)),
                      child: Text(
                        name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: weight,
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                : Text(
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
            child: maybeBlur(Text(
              '$arrow${amtFmt.format(valueDiff.abs())}',
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: weight),
              textAlign: TextAlign.right,
            )),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Cash Flow tab
// ════════════════════════════════════════════════════

class _CashFlowTab extends ConsumerStatefulWidget {
  final _AllSeriesData allData;
  final String locale;
  const _CashFlowTab({required this.allData, required this.locale});

  @override
  ConsumerState<_CashFlowTab> createState() => _CashFlowTabState();
}

class _CashFlowTabState extends ConsumerState<_CashFlowTab> {
  static const _idSaving   = -10;
  static const _idSpending = -11;
  static const _idVelocity = -12;

  int _savingWindow   = 365;
  int _spendingWindow = 365;
  int _velocityWindow = 365;

  late final TextEditingController _savingWinCtl;
  late final TextEditingController _spendingWinCtl;
  late final TextEditingController _velocityWinCtl;

  final _hidden  = <int, Set<String>>{};
  final _heights = <int, double>{};
  final _zooms   = <int, _ChartZoom>{};

  @override
  void initState() {
    super.initState();
    _savingWinCtl   = TextEditingController(text: '$_savingWindow');
    _spendingWinCtl = TextEditingController(text: '$_spendingWindow');
    _velocityWinCtl = TextEditingController(text: '$_velocityWindow');

    // Default zoom: last 365 days
    final totalDays = DateTime.now().difference(widget.allData.firstDate).inDays.toDouble();
    final xMax = totalDays.clamp(0.0, double.infinity);
    final xMin365 = (xMax - 365).clamp(0.0, double.infinity);
    for (final id in [_idSaving, _idSpending, _idVelocity]) {
      _zooms[id] = _ChartZoom()
        ..minX = xMin365
        ..maxX = xMax;
    }
  }

  @override
  void dispose() {
    _savingWinCtl.dispose();
    _spendingWinCtl.dispose();
    _velocityWinCtl.dispose();
    super.dispose();
  }

  Set<String> _hiddenFor(int id) => _hidden.putIfAbsent(id, () => {});
  double _heightFor(int id) => _heights.putIfAbsent(id, () => 420.0);
  _ChartZoom _zoomFor(int id) => _zooms.putIfAbsent(id, () => _ChartZoom());

  Widget _maField(TextEditingController ctl, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('MA:', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          height: 32,
          child: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final w = int.tryParse(v);
              if (w != null) onChanged(w.clamp(1, 3000));
            },
          ),
        ),
      ],
    );
  }

  DashboardChart _fakeChart(int id, String title) => DashboardChart(
    id: id,
    title: title,
    widgetType: 'chart',
    sortOrder: 0,
    seriesJson: '[]',
    sourceChartIds: 'cf', // non-null → showTotal=false, no hide-components button
    createdAt: DateTime.now(),
  );

  void _onToggle(int chartId, String key) => setState(() {
    final h = _hiddenFor(chartId);
    if (h.contains(key)) { h.remove(key); } else { h.add(key); }
  });

  void _onToggleGroup(int chartId, Set<String> keys) => setState(() {
    final h = _hiddenFor(chartId);
    final allHidden = keys.every(h.contains);
    if (allHidden) { h.removeAll(keys); } else { h.addAll(keys); }
  });

  void _onZoom(int chartId, double? minX, double? maxX, double? minY, double? maxY) =>
      setState(() {
        final z = _zoomFor(chartId);
        z.minX = minX; z.maxX = maxX; z.minY = minY; z.maxY = maxY;
      });

  @override
  Widget build(BuildContext context) {
    final allData = widget.allData;
    final locale  = widget.locale;
    final s       = ref.watch(appStringsProvider);
    final ieAsync = ref.watch(_incomeExpenseDataProvider);
    final ieData  = ieAsync.value;

    // Saving = accounts + invested + adjustments (spread + income)
    final savingSpots = buildTotalSpots([
      ...allData.accounts.map((s) => s.spots),
      ...allData.assetInvested.map((s) => s.spots),
      ...allData.adjustments.map((s) => s.spots),
      ...allData.incomeAdjustments.map((s) => s.spots),
    ]);

    // Cash = accounts + spread adjustments only
    final cashSpots = buildTotalSpots([
      ...allData.accounts.map((s) => s.spots),
      ...allData.adjustments.map((s) => s.spots),
    ]);

    // Spending = cumulative sum of negative daily deltas of saving
    final spendingSpots = _buildSpendingFromSaving(savingSpots);

    final savingMA   = _computeMA(savingSpots,   _savingWindow);
    final spendingMA = _computeMA(spendingSpots, _spendingWindow);
    final savingDiff = _computeDiff(savingSpots, savingMA);

    final savingVel      = _computeVelocity(_computeMA(savingSpots,   _velocityWindow));
    final spendingVelRaw = _computeVelocity(_computeMA(spendingSpots, _velocityWindow));
    final spendingVel    = spendingVelRaw.map((s) => FlSpot(s.x, -s.y)).toList();

    final chartDefs = [
      (
        id: _idSaving,
        chart: _fakeChart(_idSaving, 'Saving vs MA'),
        series: <_Series>[
          _Series(key: 'cf:saving',    name: 'Saving', color: Colors.blue,          spots: savingSpots),
          _Series(key: 'cf:saving_ma', name: 'MA',     color: Colors.blue.shade200,  spots: savingMA,   isDashed: true),
          _Series(key: 'cf:diff',      name: 'Diff',   color: Colors.orange,         spots: savingDiff, rightAxis: true),
        ],
        ctl: _savingWinCtl,
        onWin: (int w) => setState(() => _savingWindow = w),
      ),
      (
        id: _idSpending,
        chart: _fakeChart(_idSpending, 'Spending vs MA & Cash'),
        series: <_Series>[
          _Series(key: 'cf:spending',    name: 'Spending', color: Colors.red,           spots: spendingSpots),
          _Series(key: 'cf:spending_ma', name: 'MA',       color: Colors.red.shade200,   spots: spendingMA,  isDashed: true),
          _Series(key: 'cf:cash',        name: 'Cash',     color: Colors.green,          spots: cashSpots,   rightAxis: true),
        ],
        ctl: _spendingWinCtl,
        onWin: (int w) => setState(() => _spendingWindow = w),
      ),
      (
        id: _idVelocity,
        chart: _fakeChart(_idVelocity, 'Velocity (MA derivative)'),
        series: <_Series>[
          _Series(key: 'cf:saving_vel',   name: 'Saving vel.',   color: Colors.blue, spots: savingVel),
          _Series(key: 'cf:spending_vel', name: 'Spending vel.', color: Colors.red,  spots: spendingVel),
        ],
        ctl: _velocityWinCtl,
        onWin: (int w) => setState(() => _velocityWindow = w),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < chartDefs.length; i++) ...[
          Builder(builder: (_) {
            final c = chartDefs[i];
            final z = _zoomFor(c.id);
            return _ChartCard(
              chart: c.chart,
              series: c.series,
              allData: allData,
              hidden: _hiddenFor(c.id),
              locale: locale,
              chartHeight: _heightFor(c.id),
              zoomMinX: z.minX,
              zoomMaxX: z.maxX,
              zoomMinY: z.minY,
              zoomMaxY: z.maxY,
              onToggle: (key) => _onToggle(c.id, key),
              onToggleGroup: (keys) => _onToggleGroup(c.id, keys),
              onToggleHideComponents: () {},
              onZoom: (minX, maxX, minY, maxY) => _onZoom(c.id, minX, maxX, minY, maxY),
              onHeightChanged: (h) => setState(() => _heights[c.id] = h.clamp(200.0, 900.0)),
              headerExtra: _maField(c.ctl, c.onWin),
            );
          }),
          const SizedBox(height: 24),
        ],
        // Income/expense analytics sections
        if (ieAsync.isLoading) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
        ] else if (ieData != null) ...[
          // Chart 4 equivalent: yearly totals bar chart (Expenses + Savings per year)
          ExpansionTile(
            title: Text(s.chartYearlyBarTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            initiallyExpanded: true,
            children: [_YearlyBarChart(data: ieData, locale: locale)],
          ),
          ExpansionTile(
            title: Text(s.chartMonthlyAvgTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_MonthlyAvgBarChart(data: ieData, locale: locale)],
          ),
          ExpansionTile(
            title: Text(s.chartMonthlyIncomeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_MonthlyByYearLineChart(data: ieData, locale: locale, field: 'income')],
          ),
          ExpansionTile(
            title: Text(s.chartMonthlyExpensesTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_MonthlyByYearLineChart(data: ieData, locale: locale, field: 'expenses', maxYears: 5)],
          ),
          ExpansionTile(
            title: Text(s.chartYearlySummaryTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_YearlySummaryTable(data: ieData, locale: locale)],
          ),
          ExpansionTile(
            title: Text(s.chartMonthlyIncTableTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_MonthlyGrid(data: ieData, locale: locale, field: 'income')],
          ),
          ExpansionTile(
            title: Text(s.chartMonthlyExpTableTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_MonthlyGrid(data: ieData, locale: locale, field: 'expenses', maxYears: 5)],
          ),
          ExpansionTile(
            title: Text(s.chartYoYTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            children: [_YoYDiffTable(data: ieData, locale: locale)],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Income/Expense table widgets
// ════════════════════════════════════════════════════

class _YearlySummaryTable extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _YearlySummaryTable({required this.data, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sl = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final pctFmt = NumberFormat('0.0%');
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = DateTime.now();

    final years = data.years.reversed.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 52,
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(sl.colYear,       style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(sl.colIncome,     style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colExpenses,   style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colSavings,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colRate,        style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colAvgMonthInc, style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colAvgMonthExp, style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colDailyInc,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text(sl.colDailyExp,    style: const TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        ],
        rows: [
          for (int i = 0; i < years.length; i++) ...[
            _yearRow(years[i], i == 0 && years[i].year == now.year,
                     amtFmt, pctFmt, sym, theme),
            // EOY prediction row for current (partial) year
            if (i == 0 && years[i].year == now.year && years.length > 1)
              _eoyRow(years[i], years[i + 1], amtFmt, pctFmt, sym, theme, sl),
          ],
        ],
      ),
    );
  }

  DataRow _yearRow(_YearBucket y, bool isCurrent,
      NumberFormat amtFmt, NumberFormat pctFmt, String sym, ThemeData theme) {
    TextStyle? style = isCurrent
        ? TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))
        : null;

    Color savingsColor = y.savings >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return DataRow(cells: [
      DataCell(Text(isCurrent ? '${y.year}*' : '${y.year}', style: style?.copyWith(fontWeight: FontWeight.w600))),
      DataCell(PrivacyText('${amtFmt.format(y.income)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.expenses)} $sym', style: style)),
      DataCell(PrivacyText(
        '${amtFmt.format(y.savings)} $sym',
        style: (style ?? const TextStyle()).copyWith(color: savingsColor, fontWeight: FontWeight.w600),
      )),
      DataCell(Text(pctFmt.format(y.savingsRate), style: style?.copyWith(color: savingsColor))),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.monthlyExpenses)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyIncome)} $sym', style: style)),
      DataCell(PrivacyText('${amtFmt.format(y.dailyExpenses)} $sym', style: style)),
    ]);
  }

  DataRow _eoyRow(_YearBucket current, _YearBucket prev,
      NumberFormat amtFmt, NumberFormat pctFmt, String sym, ThemeData theme, AppStrings sl) {
    final eoyInc = _eoyPrediction(current, prev);
    final eoyExp = _eoyPrediction(current, prev, expenses: true);
    final eoySav = (eoyInc != null && eoyExp != null) ? eoyInc - eoyExp : null;
    final eoyRate = (eoyInc != null && eoyInc > 0 && eoySav != null) ? eoySav / eoyInc : null;

    final style = TextStyle(
      fontStyle: FontStyle.italic,
      fontSize: 11,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    );

    String fmt_(double? v) => v != null ? '~${amtFmt.format(v)} $sym' : '—';

    return DataRow(cells: [
      DataCell(Text(sl.eoyLabel, style: style)),
      DataCell(PrivacyText(fmt_(eoyInc), style: style)),
      DataCell(PrivacyText(fmt_(eoyExp), style: style)),
      DataCell(PrivacyText(fmt_(eoySav), style: style)),
      DataCell(Text(eoyRate != null ? '~${pctFmt.format(eoyRate)}' : '—', style: style)),
      DataCell(const Text('')),
      DataCell(const Text('')),
      DataCell(const Text('')),
      DataCell(const Text('')),
    ]);
  }
}

class _MonthlyGrid extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String field; // 'income' or 'expenses'
  final int? maxYears;
  const _MonthlyGrid({required this.data, required this.locale,
                      required this.field, this.maxYears});

  static const _monthNames = ['Jan','Feb','Mar','Apr','May','Jun',
                               'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sl = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = DateTime.now();

    var years = data.years;
    if (maxYears != null && years.length > maxYears!) {
      years = years.sublist(years.length - maxYears!);
    }
    final yearLabels = years.map((y) => y.year).toList();

    // avg column: average per year for each month
    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final headerBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    double _value(_YearBucket y, int m) {
      final mb = y.months.where((b) => b.month == m).firstOrNull;
      return mb == null ? double.nan : (field == 'income' ? mb.income : mb.expenses);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Table(
        border: headerBorder,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              _th(sl.colMonth),
              for (final y in yearLabels)
                _th('$y${y == now.year ? "*" : ""}'),
              _th('Avg'),
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++) ...[
            TableRow(children: [
              _td(_monthNames[m - 1], bold: true),
              for (final y in years) ...[
                Builder(builder: (ctx) {
                  final v = _value(y, m);
                  final isFuture = v.isNaN;
                  final isCurrent = y.year == now.year;
                  return _tdPrivacy(
                    isFuture ? '—' : '${amtFmt.format(v)} $sym',
                    dimmed: isCurrent || isFuture,
                  );
                }),
              ],
              Builder(builder: (ctx) {
                final vals = years.map((y) => _value(y, m)).where((v) => !v.isNaN).toList();
                final avg = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
                return _tdPrivacy(avg == null ? '—' : '${amtFmt.format(avg)} $sym');
              }),
            ]),
          ],
          // Total row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              _td('Total', bold: true),
              for (final y in years) ...[
                Builder(builder: (ctx) {
                  final v = field == 'income' ? y.income : y.expenses;
                  return _tdPrivacy('${amtFmt.format(v)} $sym',
                    dimmed: y.year == now.year, bold: true);
                }),
              ],
              Builder(builder: (ctx) {
                final vals = years.map((y) => field == 'income' ? y.income : y.expenses).toList();
                final avg = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
                return _tdPrivacy(avg == null ? '—' : '${amtFmt.format(avg)} $sym', bold: true);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _th(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.right),
  );

  Widget _td(String text, {bool bold = false, bool dimmed = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Text(text,
      style: TextStyle(fontWeight: bold ? FontWeight.w600 : null,
                       fontSize: 12, color: dimmed ? Colors.grey : null),
      textAlign: TextAlign.right),
  );

  Widget _tdPrivacy(String text, {bool bold = false, bool dimmed = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: PrivacyText(text,
        style: TextStyle(fontWeight: bold ? FontWeight.w600 : null,
                         fontSize: 12, color: dimmed ? Colors.grey : null),
        textAlign: TextAlign.right,
      ),
    );
}

class _YoYDiffTable extends ConsumerWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _YoYDiffTable({required this.data, required this.locale});

  static const _monthNames = ['Jan','Feb','Mar','Apr','May','Jun',
                               'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sl = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(locale);
    final theme  = Theme.of(context);
    final sym    = currencySymbol(data.baseCurrency);
    final now    = DateTime.now();
    final years  = data.years;

    if (years.length < 2) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(sl.needMoreYears, style: const TextStyle(color: Colors.grey)),
      );
    }

    // Pairs: (prevYear, curYear)
    final pairs = <(_YearBucket, _YearBucket)>[];
    for (int i = 1; i < years.length; i++) {
      pairs.add((years[i - 1], years[i]));
    }

    double? _diff(_YearBucket prev, _YearBucket cur, int month) {
      final p = prev.months.where((m) => m.month == month).firstOrNull;
      final c = cur.months.where((m) => m.month == month).firstOrNull;
      if (p == null || c == null) return null;
      return c.income - p.income;
    }

    final borderSide = BorderSide(color: theme.dividerColor, width: 0.5);
    final tableBorder = TableBorder(
      horizontalInside: borderSide,
      verticalInside: borderSide,
      bottom: borderSide,
    );

    Widget _diffCell(double? v) {
      if (v == null) return const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Text('—', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey)));
      final color = v >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      final text  = '${v >= 0 ? '+' : ''}${amtFmt.format(v)} $sym';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: PrivacyText(text,
          style: TextStyle(fontSize: 12, color: color),
          textAlign: TextAlign.right,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Table(
        border: tableBorder,
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(sl.colMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final p in pairs)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text('${p.$2.year}→${p.$1.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.right)),
            ],
          ),
          // Month rows
          for (int m = 1; m <= 12; m++)
            TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(_monthNames[m - 1],
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
              for (final p in pairs)
                _diffCell(_diff(p.$1, p.$2, m)),
            ]),
          // YTD row (sum of months 1..now.month for current pair, else full year)
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Text(sl.colYTD, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final p in pairs) ...[
                Builder(builder: (ctx) {
                  final maxM = p.$2.year == now.year ? now.month : 12;
                  double sum = 0;
                  bool valid = false;
                  for (int m = 1; m <= maxM; m++) {
                    final d = _diff(p.$1, p.$2, m);
                    if (d != null) { sum += d; valid = true; }
                  }
                  return _diffCell(valid ? sum : null);
                }),
              ],
            ],
          ),
          // Full year row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Text(sl.colYear, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              for (final p in pairs) ...[
                Builder(builder: (ctx) {
                  if (p.$2.months.length < 12) return _diffCell(null);
                  return _diffCell(p.$2.income - p.$1.income);
                }),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Income/Expense chart widgets (bar + line)
// ════════════════════════════════════════════════════

/// Bar chart: x=years, bars=Income+Expenses+Savings (Chart 4 equivalent).
class _YearlyBarChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _YearlyBarChart({required this.data, required this.locale});

  @override
  ConsumerState<_YearlyBarChart> createState() => _YearlyBarChartState();
}

class _YearlyBarChartState extends ConsumerState<_YearlyBarChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _keys = ['income', 'expenses', 'savings'];

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(privacyModeProvider);
    final sl = ref.watch(appStringsProvider);
    final labels = [sl.legendIncome, sl.legendExpenses, sl.legendSavings];
    final amtFmt   = fmt.amountFormat(widget.locale);
    final sym      = currencySymbol(widget.data.baseCurrency);
    final years    = widget.data.years;
    final now      = DateTime.now();
    if (years.isEmpty) return const SizedBox.shrink();

    final colors = [Colors.green.shade400, Colors.red.shade400, Colors.blue.shade400];
    const barW = 10.0;
    const gap  = 4.0;

    // Build rod list per group respecting hidden state.
    // Track which original index each rod maps to for tooltip.
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < years.length; i++) {
      final y = years[i];
      final vals = [y.income, y.expenses, y.savings];
      final rods = <BarChartRodData>[];
      for (int k = 0; k < 3; k++) {
        if (!_hidden.contains(_keys[k])) {
          rods.add(BarChartRodData(toY: vals[k], color: colors[k], width: barW));
        }
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: gap));
    }

    // Visible indices for tooltip mapping
    final visibleIndices = [0, 1, 2].where((k) => !_hidden.contains(_keys[k])).toList();

    final allVals = years.expand((y) => [y.income, y.expenses, y.savings.abs()]);
    final maxY = allVals.fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(spacing: 16, children: [
            for (int k = 0; k < 3; k++)
              _ToggleLegendItem(
                color: colors[k],
                label: labels[k],
                enabled: !_hidden.contains(_keys[k]),
                onTap: () => _toggle(_keys[k]),
              ),
          ]),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(BarChartData(
              barGroups: groups,
              maxY: maxY * 1.1,
              minY: years.any((y) => y.savings < 0) ? years.map((y) => y.savings).reduce(min) * 1.1 : 0,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final y = years[group.x];
                    if (rodIndex >= visibleIndices.length) return null;
                    final origIdx = visibleIndices[rodIndex];
                    final vals = [y.income, y.expenses, y.savings];
                    return BarTooltipItem(
                      '${y.year}${y.year == now.year ? "*" : ""}\n${labels[origIdx]}\n${amtFmt.format(vals[origIdx])} $sym',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= years.length) return const SizedBox.shrink();
                      final y = years[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${y.year}${y.year == now.year ? "*" : ""}', style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
        )),
      ],
    );
  }
}

/// Bar chart: x=years, bars=Monthly-avg Expenses + Monthly-avg Savings (Chart 2 equivalent).
class _MonthlyAvgBarChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  const _MonthlyAvgBarChart({required this.data, required this.locale});

  @override
  ConsumerState<_MonthlyAvgBarChart> createState() => _MonthlyAvgBarChartState();
}

class _MonthlyAvgBarChartState extends ConsumerState<_MonthlyAvgBarChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _keys = ['income', 'expenses', 'savings'];

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(privacyModeProvider);
    final sl = ref.watch(appStringsProvider);
    final labels = [sl.legendAvgMonthlyIncome, sl.legendAvgMonthlyExpenses, sl.legendAvgMonthlySavings];
    final tipLabels = [sl.tipAvgMonthIncome, sl.tipAvgMonthExpenses, sl.tipAvgMonthSavings];
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym    = currencySymbol(widget.data.baseCurrency);
    final years  = widget.data.years;
    final now    = DateTime.now();
    if (years.isEmpty) return const SizedBox.shrink();

    final colors = [Colors.green.shade400, Colors.red.shade400, Colors.blue.shade400];
    const barW = 12.0;
    const gap  = 4.0;

    final visibleIndices = [0, 1, 2].where((k) => !_hidden.contains(_keys[k])).toList();

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < years.length; i++) {
      final y = years[i];
      final vals = [y.monthlyIncome, y.monthlyExpenses, y.savings / max(1, y.months.length)];
      final rods = <BarChartRodData>[];
      for (final k in visibleIndices) {
        rods.add(BarChartRodData(toY: vals[k], color: colors[k], width: barW));
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: gap));
    }

    final maxY = years.map((y) => [y.monthlyIncome, y.monthlyExpenses]).expand((l) => l).fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(spacing: 16, children: [
            for (int k = 0; k < 3; k++)
              _ToggleLegendItem(
                color: colors[k],
                label: labels[k],
                enabled: !_hidden.contains(_keys[k]),
                onTap: () => _toggle(_keys[k]),
              ),
          ]),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(BarChartData(
              barGroups: groups,
              maxY: maxY * 1.1,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final y = years[group.x];
                    if (rodIndex >= visibleIndices.length) return null;
                    final origIdx = visibleIndices[rodIndex];
                    final vals = [y.monthlyIncome, y.monthlyExpenses, y.savings / max(1, y.months.length)];
                    return BarTooltipItem(
                      '${y.year}${y.year == now.year ? "*" : ""}\n${tipLabels[origIdx]}\n${amtFmt.format(vals[origIdx])} $sym',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 55,
                    getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= years.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${years[i].year}${years[i].year == now.year ? "*" : ""}',
                                    style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            )),
          ),
        )),
      ],
    );
  }
}

/// Line chart: x=months(1–12), one line per year. Shows income or expenses.
/// Chart 3 equivalent (income) and Chart 5 equivalent (expenses).
class _MonthlyByYearLineChart extends ConsumerStatefulWidget {
  final _IncomeExpenseData data;
  final String locale;
  final String field;    // 'income' or 'expenses'
  final int? maxYears;   // limit to most recent N years
  const _MonthlyByYearLineChart({required this.data, required this.locale,
                                  required this.field, this.maxYears});

  @override
  ConsumerState<_MonthlyByYearLineChart> createState() => _MonthlyByYearLineChartState();
}

class _MonthlyByYearLineChartState extends ConsumerState<_MonthlyByYearLineChart> {
  final _hidden = <String>{};
  void _toggle(String key) => setState(() {
    _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
  });

  static const _monthAbbr = ['','Jan','Feb','Mar','Apr','May','Jun',
                                 'Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _palette = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    Colors.cyan, Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(privacyModeProvider);
    final sl = ref.watch(appStringsProvider);
    final amtFmt = fmt.amountFormat(widget.locale);
    final sym    = currencySymbol(widget.data.baseCurrency);
    var   years  = widget.data.years;
    if (widget.maxYears != null && years.length > widget.maxYears!) {
      years = years.sublist(years.length - widget.maxYears!);
    }
    if (years.isEmpty) return const SizedBox.shrink();

    // Build visible line bars only
    final lineBars = <LineChartBarData>[];
    final yearIndexMap = <int, int>{};   // lineBars index → years index
    for (int i = 0; i < years.length; i++) {
      final key = '${years[i].year}';
      if (_hidden.contains(key)) continue;
      final color = _palette[i % _palette.length];
      final spots = <FlSpot>[];
      for (final mb in years[i].months) {
        final val = widget.field == 'income' ? mb.income : mb.expenses;
        spots.add(FlSpot(mb.month.toDouble(), val));
      }
      if (spots.isEmpty) continue;
      yearIndexMap[lineBars.length] = i;
      lineBars.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2,
        isCurved: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    final allVals = years.expand((y) => y.months).map((m) => widget.field == 'income' ? m.income : m.expenses);
    final maxY    = allVals.isEmpty ? 0.0 : allVals.fold(0.0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (int i = 0; i < years.length; i++)
                _ToggleLegendItem(
                  color: _palette[i % _palette.length],
                  label: '${years[i].year}',
                  enabled: !_hidden.contains('${years[i].year}'),
                  onTap: () => _toggle('${years[i].year}'),
                ),
            ],
          ),
        ),
        _maybeBlur(isPrivate, SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: lineBars.isEmpty
                ? Center(child: Text(sl.allSeriesHidden))
                : LineChart(LineChartData(
                    lineBarsData: lineBars,
                    minX: 1,
                    maxX: 12,
                    minY: 0,
                    maxY: maxY * 1.1,
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((s) {
                          final barIdx = lineBars.indexOf(s.bar);
                          final yearIdx = yearIndexMap[barIdx] ?? -1;
                          final yearLabel = yearIdx >= 0 ? '${years[yearIdx].year}' : '';
                          return LineTooltipItem(
                            '$yearLabel ${_monthAbbr[s.x.round()]}\n${amtFmt.format(s.y)} $sym',
                            TextStyle(color: s.bar.color ?? Colors.white, fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, _) {
                            final m = v.round();
                            if (m < 1 || m > 12) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_monthAbbr[m], style: const TextStyle(fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          getTitlesWidget: (v, _) => Text(_shortAmount(v, sym), style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  )),
          ),
        )),
      ],
    );
  }
}

// Shared helpers
Widget _maybeBlur(bool isPrivate, Widget child) => isPrivate
    ? ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: child)
    : child;

Widget _legendDot(Color color, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ],
);

String _shortAmount(double v, String sym) {
  if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M $sym';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(0)}k $sym';
  return '${v.toStringAsFixed(0)} $sym';
}

// (Cash flow rendering is handled by _ChartCard + _UnifiedChart above)
// ════ end of file ════
