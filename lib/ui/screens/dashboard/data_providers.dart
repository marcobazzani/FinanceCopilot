part of 'dashboard_screen.dart';

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
  // Include today so charts extend to the current day with live data
  allDayKeys.add(toDayKey(DateTime.now()));
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
  // assetId → { currency → { dayKey → delta } } for FX-aware invested series
  final perAssetInvestedDeltas = <int, Map<String, Map<int, double>>>{};

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

      // Store delta in original currency for FX-aware invested series
      perAssetInvestedDeltas.putIfAbsent(assetId, () => {});
      perAssetInvestedDeltas[assetId]!.putIfAbsent(currency, () => {});
      perAssetInvestedDeltas[assetId]![currency]![dayKey] =
          (perAssetInvestedDeltas[assetId]![currency]![dayKey] ?? 0) + sign * netAmount.abs();

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

  // Need actual data beyond just today's placeholder
  if (allDayKeys.length <= 1 && perAccount.isEmpty && perAssetDeltas.isEmpty) return null;

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

  // ── Build asset invested series (cumulative, FX-aware) ──
  final assetInvestedSeries = <_Series>[];
  for (final asset in activeAssets) {
    if (!perAssetInvestedDeltas.containsKey(asset.id)) continue;
    final currencyDeltas = perAssetInvestedDeltas[asset.id]!;
    final spots = <FlSpot>[];
    // Track cumulative invested per original currency
    final cumByCurrency = <String, double>{};
    var started = false;

    for (final dayKey in sortedDays) {
      for (final entry in currencyDeltas.entries) {
        final delta = entry.value[dayKey];
        if (delta != null) {
          cumByCurrency[entry.key] = (cumByCurrency[entry.key] ?? 0) + delta;
          started = true;
        }
      }
      if (started) {
        // Convert each currency's cumulative to base at this day's rate
        var total = 0.0;
        for (final entry in cumByCurrency.entries) {
          final rate = await rates.getRate(entry.key, dayKey);
          total += entry.value * rate;
        }
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, total));
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

    // Load market prices (DB = confirmed closes only)
    final prices = await marketPriceService.getPriceHistory(asset.id);
    final priceMap = <int, double>{};
    for (final p in prices) {
      priceMap[toDayKey(p.key)] = p.value;
    }
    // Add today's live price (not in DB) so the chart extends to today
    if (marketPriceService is InvestingComService) {
      final livePrice = await marketPriceService.getLivePrice(asset.id);
      if (livePrice != null) {
        final todayKey = toDayKey(DateTime.now());
        priceMap[todayKey] = livePrice;
      }
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

    final spots = <FlSpot>[];
    var cumulative = 0.0;
    var started = false;

    for (final dayKey in sortedDays) {
      if (deltaMap.containsKey(dayKey)) {
        cumulative += deltaMap[dayKey]!;
        started = true;
      }
      if (started) {
        final rate = await rates.getRate(schedule.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, cumulative * rate));
      }
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

    final spots = <FlSpot>[];
    var cumulative = 0.0;
    var started = false;

    for (final dayKey in sortedDays) {
      if (deltaMap.containsKey(dayKey)) {
        cumulative += deltaMap[dayKey]!;
        started = true;
      }
      if (started) {
        final rate = await rates.getRate(adj.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, cumulative * rate));
      }
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

  // 1. Load incomes (excluding refunds), convert to base currency
  final rows = await db.customSelect(
    "SELECT date, amount, currency FROM incomes WHERE type != 'refund' ORDER BY date ASC",
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
    // Use Dec 31 of previous year as start reference so that Jan 1
    // transactions are included in the year's NAV change.
    final yStartRef = DateTime(y - 1, 12, 31);
    final yStart = DateTime(y, 1, 1);
    final isCurrentYear = y == now.year;
    final effectiveEnd = isCurrentYear ? now : DateTime(y, 12, 31);
    final days = effectiveEnd.difference(yStart).inDays + 1;

    double yearIncome = 0;
    final months = <_MonthBucket>[];

    for (int m = 1; m <= 12; m++) {
      if (isCurrentYear && m > now.month) break;
      // Use last day of previous month so 1st-of-month txns are captured.
      final mStartRef = DateTime(y, m, 1).subtract(const Duration(days: 1));
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
        navChange: lookupNAV(mEnd) - lookupNAV(mStartRef),
      ));
    }

    years.add(_YearBucket(
      year: y, days: days,
      income: yearIncome,
      navChange: lookupNAV(effectiveEnd) - lookupNAV(yStartRef),
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
