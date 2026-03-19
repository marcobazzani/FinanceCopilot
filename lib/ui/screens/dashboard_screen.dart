import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:drift/drift.dart' show OrderingTerm, Variable;

import '../../database/database.dart';
import '../../database/providers.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';

final _log = getLogger('DashboardScreen');

/// Unified series for accounts, assets, and CAPEX.
class _Series {
  final String key; // unique id for toggling: "a:3" (account), "s:7" (asset), "c:1" (capex)
  final String name;
  final Color color;
  final List<FlSpot> spots;
  final bool isAsset;
  final bool isCapex;
  const _Series({
    required this.key,
    required this.name,
    required this.color,
    required this.spots,
    this.isAsset = false,
    this.isCapex = false,
  });
}

/// All chart data: account series, asset series, CAPEX series.
class _ChartData {
  final DateTime firstDate;
  final List<_Series> accounts;
  final List<_Series> assets;
  final List<_Series> capex;
  final String baseCurrency;

  const _ChartData({
    required this.firstDate,
    required this.accounts,
    required this.assets,
    required this.capex,
    required this.baseCurrency,
  });

  List<_Series> get allSeries => [...accounts, ...assets, ...capex];
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

/// Provider that fetches daily balance per active account + cumulative asset
/// invested value, all converted to base currency.
final _chartDataProvider = FutureProvider<_ChartData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);

  // Watch reactive streams so we rebuild when data changes
  ref.watch(accountsProvider);
  ref.watch(accountStatsProvider);
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(capexSchedulesProvider);
  ref.watch(priceRefreshCounter);

  // ── Shared helpers ──
  final allDayKeys = <int>{};
  final rates = _RateResolver(rateService, baseCurrency);

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

  if (assetIds.isNotEmpty) {
    final assetPlaceholders = assetIds.map((_) => '?').join(',');
    final evRows = await db.customSelect(
      'SELECT asset_id, date, type, amount, currency, exchange_rate '
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
      allDayKeys.add(dayKey);
    }
  }

  if (allDayKeys.isEmpty) return null;

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // ── Build account series ──
  final accountSeries = <_Series>[];
  var colorIdx = 0;

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
      key: 'a:${account.id}',
      name: account.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
    ));
    colorIdx++;
  }

  // ── Build asset series (cumulative) ──
  final assetSeries = <_Series>[];

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

    assetSeries.add(_Series(
      key: 's:${asset.id}',
      name: asset.ticker ?? asset.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isAsset: true,
    ));
    colorIdx++;
  }

  // ════════════════════════════════════════════════
  // 3. CAPEX — re-add at expense date, remove during spread steps
  //    At expenseDate: +totalAmount (neutralizes the bank dip)
  //    At each entry date: −stepAmount (gradually spread)
  //    At each reimbursement: −reimbursement (someone else paid back)
  // ════════════════════════════════════════════════
  final activeSchedules = await (db.select(db.depreciationSchedules)
        ..where((s) => s.isActive.equals(true)))
      .get();

  final capexSeries = <_Series>[];

  for (final schedule in activeSchedules) {
    final entries = await (db.select(db.depreciationEntries)
          ..where((e) => e.scheduleId.equals(schedule.id))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();

    // Build delta map: dayKey → amount change
    final deltaMap = <int, double>{};

    // 1. At expense date: re-add the full amount
    if (schedule.expenseDate != null) {
      final expDayKey = toDayKey(schedule.expenseDate!);
      deltaMap[expDayKey] = (deltaMap[expDayKey] ?? 0) + schedule.totalAmount;
      allDayKeys.add(expDayKey);
    }

    // 2. At each spread step: remove the step amount
    for (final entry in entries) {
      final dayKey = toDayKey(entry.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - entry.amount;
      allDayKeys.add(dayKey);
    }

    // 3. Reimbursements: reduce the CAPEX adjustment
    if (schedule.bufferId != null) {
      final reimbursements = await (db.select(db.bufferTransactions)
            ..where((t) => t.bufferId.equals(schedule.bufferId!))
            ..where((t) => t.isReimbursement.equals(true)))
          .get();
      for (final r in reimbursements) {
        final dayKey = toDayKey(r.operationDate);
        deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - r.amount.abs();
        allDayKeys.add(dayKey);
      }
    }

    if (deltaMap.isEmpty) continue;

    // Walk sorted days, accumulate, build spots.
    // Insert "hold" points before jumps so the line stays flat
    // (step-like) instead of drawing diagonals across gaps.
    final capexDays = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;

    for (final dayKey in capexDays) {
      final rate = await rates.getRate(schedule.currency, dayKey);
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = dt.difference(firstDate).inDays.toDouble();
      // Hold previous value just before this point to avoid diagonal
      if (prevY != null && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      cumulative += deltaMap[dayKey]!;
      final y = cumulative * rate;
      spots.add(FlSpot(x, y));
      prevY = y;
    }

    capexSeries.add(_Series(
      key: 'c:${schedule.id}',
      name: schedule.assetName,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isCapex: true,
    ));
    colorIdx++;
  }

  return _ChartData(
    firstDate: firstDate,
    accounts: accountSeries,
    assets: assetSeries,
    capex: capexSeries,
    baseCurrency: baseCurrency,
  );
});

// ════════════════════════════════════════════════════
// Investment chart: Invested vs Market Value per asset
// ════════════════════════════════════════════════════

/// One asset's invested + market value series.
class _InvestmentPair {
  final String assetName;
  final Color color;
  final List<FlSpot> investedSpots;
  final List<FlSpot> marketSpots;
  final String key; // "i:20" for asset id 20

  const _InvestmentPair({
    required this.assetName,
    required this.color,
    required this.investedSpots,
    required this.marketSpots,
    required this.key,
  });
}

class _InvestmentChartData {
  final DateTime firstDate;
  final List<_InvestmentPair> pairs;
  final List<FlSpot> totalInvestedSpots;
  final List<FlSpot> totalMarketSpots;
  final String baseCurrency;

  const _InvestmentChartData({
    required this.firstDate,
    required this.pairs,
    required this.totalInvestedSpots,
    required this.totalMarketSpots,
    required this.baseCurrency,
  });
}

final _investmentChartDataProvider = FutureProvider<_InvestmentChartData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final marketPriceService = ref.watch(marketPriceServiceProvider);

  // Watch reactive streams
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(priceRefreshCounter);

  final rates = _RateResolver(rateService, baseCurrency);

  final activeAssets = await (db.select(db.assets)
        ..where((a) => a.isActive.equals(true))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();

  if (activeAssets.isEmpty) return null;

  final pairs = <_InvestmentPair>[];
  var colorIdx = 0;
  final eventDayKeys = <int>{}; // only event dates — determines chart start

  // Collect all data per asset
  for (final asset in activeAssets) {
    // Load events
    final events = await db.customSelect(
      'SELECT date, type, amount, quantity, currency, exchange_rate '
      'FROM asset_events WHERE asset_id = ? ORDER BY date ASC',
      variables: [Variable.withInt(asset.id)],
    ).get();
    if (events.isEmpty) continue;

    // Load market prices
    final prices = await marketPriceService.getPriceHistory(asset.id);
    final priceMap = <int, double>{}; // dayKey → close price
    for (final p in prices) {
      priceMap[toDayKey(p.key)] = p.value;
    }

    // Build invested delta map and quantity delta map
    final investedDelta = <int, double>{};
    final quantityDelta = <int, double>{};

    for (final ev in events) {
      final epochSec = ev.read<int>('date');
      final type = ev.read<String>('type');
      final amount = ev.read<double>('amount');
      final quantity = ev.readNullable<double>('quantity') ?? 0;
      final currency = ev.read<String>('currency');
      final storedRate = ev.readNullable<double>('exchange_rate');
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);

      double sign;
      if (type == 'buy' || type == 'contribute') {
        sign = 1.0;
      } else if (type == 'sell') {
        sign = -1.0;
      } else {
        continue;
      }

      final baseAmount = await convertToBase(
        amount: amount, currency: currency, baseCurrency: baseCurrency,
        storedRate: storedRate, resolver: rates, dayKey: dayKey,
      );

      investedDelta[dayKey] = (investedDelta[dayKey] ?? 0) + sign * baseAmount;
      quantityDelta[dayKey] = (quantityDelta[dayKey] ?? 0) + sign * quantity.abs();
      eventDayKeys.add(dayKey);
    }

    // Find first event date for this asset — only plot from here
    final firstEventKey = investedDelta.keys.reduce(min);

    // Merge event + price day keys, but only prices AFTER first event
    final assetDays = <int>{
      ...investedDelta.keys,
      ...priceMap.keys.where((dk) => dk >= firstEventKey),
    }.toList()..sort();

    final investedSpots = <FlSpot>[];
    final marketSpots = <FlSpot>[];
    var cumInvested = 0.0;
    var cumQuantity = 0.0;
    double? lastPrice;
    var started = false;

    for (final dayKey in assetDays) {
      if (investedDelta.containsKey(dayKey)) {
        cumInvested += investedDelta[dayKey]!;
        cumQuantity += quantityDelta[dayKey] ?? 0;
        started = true;
      }
      if (priceMap.containsKey(dayKey)) {
        lastPrice = priceMap[dayKey]!;
      }
      if (!started) continue;

      // x will be recomputed after we know global firstDate
      investedSpots.add(FlSpot(dayKey.toDouble(), cumInvested));
      if (lastPrice != null && cumQuantity > 0) {
        final fxRate = await rates.getRate(asset.currency, dayKey);
        final marketValue = cumQuantity * lastPrice * fxRate;
        marketSpots.add(FlSpot(dayKey.toDouble(), marketValue));
      }
    }

    if (investedSpots.isEmpty) continue;

    pairs.add(_InvestmentPair(
      assetName: asset.ticker ?? asset.name,
      color: _chartColors[colorIdx % _chartColors.length],
      investedSpots: investedSpots,
      marketSpots: marketSpots,
      key: 'i:${asset.id}',
    ));
    colorIdx++;
  }

  if (pairs.isEmpty || eventDayKeys.isEmpty) return null;

  // Now rebase x values to days since firstDate (first buy event)
  final sortedAll = eventDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedAll.first * 1000);

  double toX(double dayKeyD) {
    final dt = DateTime.fromMillisecondsSinceEpoch(dayKeyD.toInt() * 1000);
    return dt.difference(firstDate).inDays.toDouble();
  }

  for (final pair in pairs) {
    for (var i = 0; i < pair.investedSpots.length; i++) {
      final s = pair.investedSpots[i];
      pair.investedSpots[i] = FlSpot(toX(s.x), s.y);
    }
    for (var i = 0; i < pair.marketSpots.length; i++) {
      final s = pair.marketSpots[i];
      pair.marketSpots[i] = FlSpot(toX(s.x), s.y);
    }
  }

  final totalInvested = buildTotalSpots(pairs.map((p) => p.investedSpots).toList());
  final totalMarket = buildTotalSpots(pairs.where((p) => p.marketSpots.isNotEmpty).map((p) => p.marketSpots).toList());

  return _InvestmentChartData(
    firstDate: firstDate,
    pairs: pairs,
    totalInvestedSpots: totalInvested,
    totalMarketSpots: totalMarket,
    baseCurrency: baseCurrency,
  );
});

// ════════════════════════════════════════════════════
// Dashboard screen with toggleable legend
// ════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _hidden = <String>{}; // keys of hidden series (net worth chart)
  final _hiddenInv = <String>{}; // keys of hidden series (investment chart)
  bool _hideInvested = false; // hide all invested/dashed lines
  double? _zoomMinX; // null = no zoom (show all)
  double? _zoomMaxX;

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(_chartDataProvider);
    final invChartAsync = ref.watch(_investmentChartDataProvider);

    return chartAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (data) {
        if (data == null) {
          return const Center(
            child: Text('No data yet. Import transactions or add assets to get started.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        final invData = invChartAsync.valueOrNull;

        // Compute shared firstDate for aligned X axes
        final sharedFirstDate = (invData != null && invData.firstDate.isBefore(data.firstDate))
            ? invData.firstDate
            : data.firstDate;

        // Offset net worth spots if shared first date is earlier
        final nwOffset = data.firstDate.difference(sharedFirstDate).inDays.toDouble();
        List<FlSpot> offsetSpots(List<FlSpot> spots) =>
            nwOffset == 0 ? spots : spots.map((s) => FlSpot(s.x + nwOffset, s.y)).toList();

        final allSeries = data.allSeries;
        final visible = allSeries.where((s) => !_hidden.contains(s.key)).toList();
        final offsetAll = allSeries.map((s) => offsetSpots(s.spots)).toList();
        final totalSpots = buildTotalSpots(offsetAll);
        final currentTotal = totalSpots.isNotEmpty ? totalSpots.last.y : 0.0;
        final symbol = currencySymbol(data.baseCurrency);

        // Offset visible series
        final offsetVisible = visible.map((s) => _Series(
          key: s.key, name: s.name, color: s.color,
          spots: offsetSpots(s.spots), isAsset: s.isAsset, isCapex: s.isCapex,
        )).toList();

        // Investment chart offset
        final invOffset = invData != null
            ? invData.firstDate.difference(sharedFirstDate).inDays.toDouble()
            : 0.0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Net Worth Chart ──
              Text('Total Net Worth',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                NumberFormat.currency(locale: 'it_IT', symbol: symbol)
                    .format(currentTotal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _GroupedLegend(
                accounts: data.accounts,
                assets: data.assets,
                adjustments: data.capex,
                hidden: _hidden,
                onToggle: (key) => setState(() {
                  _hidden.contains(key) ? _hidden.remove(key) : _hidden.add(key);
                }),
                onToggleGroup: (keys) => setState(() {
                  keys.every(_hidden.contains) ? _hidden.removeAll(keys) : _hidden.addAll(keys);
                }),
              ),
              const SizedBox(height: 8),
              // Zoom controls
              _ZoomControls(
                totalDays: totalSpots.isNotEmpty ? totalSpots.last.x : 0,
                zoomMinX: _zoomMinX,
                onZoom: (minX, maxX) => setState(() {
                  _zoomMinX = minX;
                  _zoomMaxX = maxX;
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: totalSpots.length >= 2
                    ? _DragZoomWrapper(
                        xMin: _zoomMinX ?? 0,
                        xMax: _zoomMaxX ?? (totalSpots.isNotEmpty ? totalSpots.last.x : 1),
                        firstDate: sharedFirstDate,
                        onZoom: (minX, maxX) => setState(() {
                          _zoomMinX = minX;
                          _zoomMaxX = maxX;
                        }),
                        child: _BalanceChart(
                          data: _ChartData(
                            firstDate: sharedFirstDate,
                            accounts: data.accounts,
                            assets: data.assets,
                            capex: data.capex,
                            baseCurrency: data.baseCurrency,
                          ),
                          visible: offsetVisible,
                          totalSpots: totalSpots,
                          showTotal: !_hidden.contains('_total'),
                          zoomMinX: _zoomMinX,
                          zoomMaxX: _zoomMaxX,
                        ),
                      )
                    : const Center(child: Text('Not enough data to plot', style: TextStyle(color: Colors.grey))),
              ),

              // ── Investment Chart ──
              const Divider(height: 24),
              Expanded(
                child: invChartAsync.when(
                  loading: () => const Center(child: Text('Loading investment data...', style: TextStyle(color: Colors.grey))),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (invData) {
                    if (invData == null || invData.pairs.isEmpty) {
                      return const Center(child: Text('No market price data yet. Prices sync on startup.',
                          style: TextStyle(color: Colors.grey)));
                    }
                    // Apply offset for aligned X axis
                    final alignedData = invOffset == 0 ? invData : _InvestmentChartData(
                      firstDate: sharedFirstDate,
                      pairs: invData.pairs.map((p) => _InvestmentPair(
                        assetName: p.assetName,
                        color: p.color,
                        investedSpots: p.investedSpots.map((s) => FlSpot(s.x + invOffset, s.y)).toList(),
                        marketSpots: p.marketSpots.map((s) => FlSpot(s.x + invOffset, s.y)).toList(),
                        key: p.key,
                      )).toList(),
                      totalInvestedSpots: invData.totalInvestedSpots.map((s) => FlSpot(s.x + invOffset, s.y)).toList(),
                      totalMarketSpots: invData.totalMarketSpots.map((s) => FlSpot(s.x + invOffset, s.y)).toList(),
                      baseCurrency: invData.baseCurrency,
                    );
                    return _InvestmentChartSection(
                      data: alignedData,
                      hidden: _hiddenInv,
                      hideInvested: _hideInvested,
                      zoomMinX: _zoomMinX,
                      zoomMaxX: _zoomMaxX,
                      onToggle: (key) => setState(() {
                        _hiddenInv.contains(key) ? _hiddenInv.remove(key) : _hiddenInv.add(key);
                      }),
                      onToggleGroup: (keys) => setState(() {
                        keys.every(_hiddenInv.contains)
                            ? _hiddenInv.removeAll(keys)
                            : _hiddenInv.addAll(keys);
                      }),
                      onToggleInvested: () => setState(() => _hideInvested = !_hideInvested),
                      onZoom: (minX, maxX) => setState(() {
                        _zoomMinX = minX;
                        _zoomMaxX = maxX;
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Grouped legend: Accounts | Assets | Adjustments | Total
// ════════════════════════════════════════════════════

class _GroupedLegend extends StatelessWidget {
  final List<_Series> accounts;
  final List<_Series> assets;
  final List<_Series> adjustments;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;

  const _GroupedLegend({
    required this.accounts,
    required this.assets,
    required this.adjustments,
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
        if (accounts.isNotEmpty)
          ..._buildGroup(context, 'Accounts', accounts, false),
        if (assets.isNotEmpty)
          ..._buildGroup(context, 'Assets', assets, true),
        if (adjustments.isNotEmpty)
          ..._buildGroup(context, 'Adjustments', adjustments, true),
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

  List<Widget> _buildGroup(BuildContext context, String label, List<_Series> series, bool dashed) {
    final keys = series.map((s) => s.key).toSet();
    final allHidden = keys.every(hidden.contains);
    final groupEnabled = !allHidden;

    return [
      // Group header — tapping toggles all in the group
      GestureDetector(
        onTap: () => onToggleGroup(keys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: groupEnabled
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: groupEnabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                decoration: groupEnabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ),
      ),
      // Individual items
      for (final s in series)
        _ToggleLegendItem(
          color: s.color,
          label: s.name,
          dashed: dashed,
          enabled: !hidden.contains(s.key),
          onTap: () => onToggle(s.key),
        ),
      // Separator
      const SizedBox(width: 4),
    ];
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
// Zoom controls (time range selector)
// ════════════════════════════════════════════════════

class _ZoomControls extends StatelessWidget {
  final double totalDays;
  final double? zoomMinX;
  final void Function(double? minX, double? maxX) onZoom;

  const _ZoomControls({
    required this.totalDays,
    required this.zoomMinX,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = [
      ('6M', 182),
      ('1Y', 365),
      ('2Y', 730),
      ('5Y', 1825),
      ('All', -1),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, days) in ranges)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _ZoomChip(
              label: label,
              selected: days == -1
                  ? zoomMinX == null
                  : zoomMinX != null && (totalDays - zoomMinX!).round() == days,
              onTap: () {
                if (days == -1) {
                  onZoom(null, null);
                } else if (totalDays > days) {
                  onZoom(totalDays - days, totalDays);
                }
              },
            ),
          ),
      ],
    );
  }
}

class _ZoomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ZoomChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Drag-to-zoom wrapper (CloudWatch style)
// ════════════════════════════════════════════════════

class _DragZoomWrapper extends StatefulWidget {
  final Widget child;
  final double xMin;
  final double xMax;
  final double leftReserved; // left axis label width
  final DateTime firstDate;
  final void Function(double? minX, double? maxX) onZoom;

  const _DragZoomWrapper({
    required this.child,
    required this.xMin,
    required this.xMax,
    this.leftReserved = 60,
    required this.firstDate,
    required this.onZoom,
  });

  @override
  State<_DragZoomWrapper> createState() => _DragZoomWrapperState();
}

class _DragZoomWrapperState extends State<_DragZoomWrapper> {
  double? _dragStartX;
  double? _dragCurrentX;

  double _pixelToChartX(double px, double chartWidth) {
    final fraction = (px - widget.leftReserved) / chartWidth;
    return widget.xMin + fraction * (widget.xMax - widget.xMin);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - widget.leftReserved;
        final dateFmt = DateFormat('dd MMM yyyy');

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: () => widget.onZoom(null, null),
          onHorizontalDragStart: (d) {
            setState(() {
              _dragStartX = d.localPosition.dx;
              _dragCurrentX = d.localPosition.dx;
            });
          },
          onHorizontalDragUpdate: (d) {
            setState(() => _dragCurrentX = d.localPosition.dx);
          },
          onHorizontalDragEnd: (d) {
            if (_dragStartX != null && _dragCurrentX != null) {
              final x1 = _pixelToChartX(_dragStartX!, chartWidth);
              final x2 = _pixelToChartX(_dragCurrentX!, chartWidth);
              final lo = min(x1, x2);
              final hi = max(x1, x2);
              // Only zoom if dragged at least 10 days
              if ((hi - lo) > 10) {
                widget.onZoom(
                  max(0, lo),
                  min(widget.xMax, hi),
                );
              }
            }
            setState(() {
              _dragStartX = null;
              _dragCurrentX = null;
            });
          },
          child: Stack(
            children: [
              widget.child,
              // Selection overlay
              if (_dragStartX != null && _dragCurrentX != null)
                Positioned(
                  left: min(_dragStartX!, _dragCurrentX!),
                  width: (_dragCurrentX! - _dragStartX!).abs(),
                  top: 0,
                  bottom: 28, // above x-axis labels
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.blue.withValues(alpha: 0.15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.blue.withValues(alpha: 0.7),
                            child: Text(
                              '${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(min(_dragStartX!, _dragCurrentX!), chartWidth).toInt())))} – ${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(max(_dragStartX!, _dragCurrentX!), chartWidth).toInt())))}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Chart widget
// ════════════════════════════════════════════════════

class _BalanceChart extends StatelessWidget {
  final _ChartData data;
  final List<_Series> visible;
  final List<FlSpot> totalSpots;
  final bool showTotal;
  final double? zoomMinX;
  final double? zoomMaxX;

  const _BalanceChart({
    required this.data,
    required this.visible,
    required this.totalSpots,
    this.showTotal = true,
    this.zoomMinX,
    this.zoomMaxX,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(data.baseCurrency);

    final totalDays = totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;
    final dateFmt = DateFormat('MMM yyyy');
    final fullFmt = DateFormat('dd MMM yyyy');
    final currFmt = NumberFormat.currency(locale: 'it_IT', symbol: symbol, decimalDigits: 0);

    // Build line bars: total FIRST (background), then visible series on top
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
          color: (isDark ? Colors.white : theme.colorScheme.primary)
              .withValues(alpha: 0.08),
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
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        dashArray: s.isCapex ? [3, 4] : s.isAsset ? [6, 3] : null,
      ));
    }

    // Compute Y range from visible lines only
    final visibleY = lineBars.expand((b) => b.spots.map((s) => s.y));
    final minY = visibleY.isEmpty ? 0.0 : visibleY.reduce(min);
    final maxY = visibleY.isEmpty ? 100.0 : visibleY.reduce(max);
    final yRange = maxY - minY;
    final chartMinY = yRange > 0 ? minY - yRange * 0.05 : minY - 100;
    final chartMaxY = yRange > 0 ? maxY + yRange * 0.05 : maxY + 100;

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
                final date = data.firstDate.add(Duration(days: value.toInt()));
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
                final date = data.firstDate.add(Duration(days: spot.x.toInt()));

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
// Investment chart section (Invested vs Market Value)
// ════════════════════════════════════════════════════

class _InvestmentChartSection extends StatelessWidget {
  final _InvestmentChartData data;
  final Set<String> hidden;
  final bool hideInvested;
  final double? zoomMinX;
  final double? zoomMaxX;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;
  final VoidCallback onToggleInvested;
  final void Function(double? minX, double? maxX) onZoom;

  const _InvestmentChartSection({
    required this.data,
    required this.hidden,
    required this.hideInvested,
    this.zoomMinX,
    this.zoomMaxX,
    required this.onToggle,
    required this.onToggleGroup,
    required this.onToggleInvested,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(data.baseCurrency);
    final currFmt = NumberFormat.currency(locale: 'it_IT', symbol: symbol, decimalDigits: 0);
    final currentInvested = data.totalInvestedSpots.isNotEmpty ? data.totalInvestedSpots.last.y : 0.0;
    final currentMarket = data.totalMarketSpots.isNotEmpty ? data.totalMarketSpots.last.y : 0.0;
    final gain = currentMarket - currentInvested;
    final gainPct = currentInvested > 0 ? (gain / currentInvested * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Invested vs Market Value',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            GestureDetector(
              onTap: onToggleInvested,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hideInvested ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hideInvested ? 'Show Invested' : 'Hide Invested',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (!hideInvested) ...[
              Text(
                'Invested: ${currFmt.format(currentInvested)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(width: 16),
            ],
            Text(
              'Market: ${currFmt.format(currentMarket)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${gain >= 0 ? '+' : ''}${currFmt.format(gain)} (${gainPct.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: gain >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Legend
        _InvestmentLegend(
          pairs: data.pairs,
          hidden: hidden,
          onToggle: onToggle,
          onToggleGroup: onToggleGroup,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _DragZoomWrapper(
            xMin: zoomMinX ?? 0,
            xMax: zoomMaxX ?? ([...data.totalInvestedSpots, ...data.totalMarketSpots].map((s) => s.x).fold(1.0, max)),
            firstDate: data.firstDate,
            onZoom: onZoom,
            child: _InvestmentChart(data: data, hidden: hidden, hideInvested: hideInvested, zoomMinX: zoomMinX, zoomMaxX: zoomMaxX),
          ),
        ),
      ],
    );
  }
}

class _InvestmentLegend extends StatelessWidget {
  final List<_InvestmentPair> pairs;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;

  const _InvestmentLegend({
    required this.pairs,
    required this.hidden,
    required this.onToggle,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final keys = pairs.map((p) => p.key).toSet();
    final allHidden = keys.isNotEmpty && keys.every(hidden.contains);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Group header
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
              child: Text(
                'Assets',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: !allHidden
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        // Per-asset items: solid = market, dashed = invested
        for (final pair in pairs)
          GestureDetector(
            onTap: () => onToggle(pair.key),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Solid line (market)
                  Container(
                    width: 8, height: 3,
                    color: hidden.contains(pair.key)
                        ? pair.color.withValues(alpha: 0.3)
                        : pair.color,
                  ),
                  // Dashed line (invested)
                  SizedBox(
                    width: 8, height: 3,
                    child: CustomPaint(
                      painter: _DashedLinePainter(
                        hidden.contains(pair.key)
                            ? pair.color.withValues(alpha: 0.3)
                            : pair.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pair.assetName,
                    style: TextStyle(
                      fontSize: 11,
                      color: hidden.contains(pair.key)
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                          : null,
                      decoration: hidden.contains(pair.key) ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Total labels
        _ToggleLegendItem(color: Colors.white, label: 'Total Invested', dashed: true, bold: true, enabled: !hidden.contains('_totalInvested'), onTap: () => onToggle('_totalInvested')),
        _ToggleLegendItem(color: Colors.white, label: 'Total Market', bold: true, enabled: !hidden.contains('_totalMarket'), onTap: () => onToggle('_totalMarket')),
      ],
    );
  }
}

class _InvestmentChart extends StatelessWidget {
  final _InvestmentChartData data;
  final Set<String> hidden;
  final bool hideInvested;
  final double? zoomMinX;
  final double? zoomMaxX;

  const _InvestmentChart({required this.data, required this.hidden, this.hideInvested = false, this.zoomMinX, this.zoomMaxX});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(data.baseCurrency);

    // Use all spots for X range / fallback check
    final allSpots = [...data.totalInvestedSpots, ...data.totalMarketSpots];
    if (allSpots.length < 2) {
      return const Center(child: Text('Not enough data', style: TextStyle(color: Colors.grey)));
    }

    final totalDays = allSpots.map((s) => s.x).reduce(max);
    final dateFmt = DateFormat('MMM yyyy');
    final fullFmt = DateFormat('dd MMM yyyy');
    final currFmt = NumberFormat.currency(locale: 'it_IT', symbol: symbol, decimalDigits: 0);

    final lineBars = <LineChartBarData>[];

    final showTotalInvested = !hidden.contains('_totalInvested') && !hideInvested;
    final showTotalMarket = !hidden.contains('_totalMarket');

    // Total invested (dashed white)
    if (showTotalInvested && data.totalInvestedSpots.length >= 2) {
      lineBars.add(LineChartBarData(
        spots: data.totalInvestedSpots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.6),
        barWidth: 2,
        dotData: const FlDotData(show: false),
        dashArray: [6, 3],
        belowBarData: BarAreaData(show: false),
      ));
    }

    // Total market (solid white)
    if (showTotalMarket && data.totalMarketSpots.length >= 2) {
      lineBars.add(LineChartBarData(
        spots: data.totalMarketSpots,
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

    // Per-asset lines
    for (final pair in data.pairs) {
      if (hidden.contains(pair.key)) continue;
      // Invested (dashed) — skip when hideInvested
      if (!hideInvested && pair.investedSpots.length >= 2) {
        lineBars.add(LineChartBarData(
          spots: pair.investedSpots,
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.15,
          color: pair.color.withValues(alpha: 0.6),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: [6, 3],
          belowBarData: BarAreaData(show: false),
        ));
      }
      // Market (solid)
      if (pair.marketSpots.length >= 2) {
        lineBars.add(LineChartBarData(
          spots: pair.marketSpots,
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.15,
          color: pair.color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ));
      }
    }

    final xMin = zoomMinX ?? 0;
    final xMax = zoomMaxX ?? totalDays;
    final xRange = xMax - xMin;

    // Compute Y range from visible lines only
    final visibleY = lineBars.expand((b) => b.spots.map((s) => s.y));
    final minY = visibleY.isEmpty ? 0.0 : visibleY.reduce(min);
    final maxY = visibleY.isEmpty ? 100.0 : visibleY.reduce(max);
    final yRange = maxY - minY;
    final chartMinY = yRange > 0 ? minY - yRange * 0.05 : minY - 100;
    final chartMaxY = yRange > 0 ? maxY + yRange * 0.05 : maxY + 100;

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
                final date = data.firstDate.add(Duration(days: value.toInt()));
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
              // Build a map of barIndex → label/color
              final labels = <int, (String, Color)>{};
              var idx = 0;
              if (showTotalInvested && data.totalInvestedSpots.length >= 2) {
                labels[idx++] = ('Total Invested', Colors.white70);
              }
              if (showTotalMarket && data.totalMarketSpots.length >= 2) {
                labels[idx++] = ('Total Market', Colors.white);
              }
              for (final pair in data.pairs) {
                if (hidden.contains(pair.key)) continue;
                if (pair.investedSpots.length >= 2) {
                  labels[idx++] = ('${pair.assetName} inv.', pair.color.withValues(alpha: 0.7));
                }
                if (pair.marketSpots.length >= 2) {
                  labels[idx++] = (pair.assetName, pair.color);
                }
              }

              var dateShown = false;
              return spots.map((spot) {
                final date = data.firstDate.add(Duration(days: spot.x.toInt()));
                final entry = labels[spot.barIndex];
                final prefix = !dateShown ? '${fullFmt.format(date)}\n' : '';
                dateShown = true;
                if (entry != null) {
                  return LineTooltipItem(
                    '$prefix${entry.$1}: ${currFmt.format(spot.y)}',
                    TextStyle(color: entry.$2, fontSize: 11),
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
