part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Unified data provider — computes ALL series at once
// ════════════════════════════════════════════════════

final allSeriesDataProvider = FutureProvider<AllSeriesData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final marketPriceService = ref.watch(marketPriceServiceProvider);

  // Watch reactive streams so we rebuild when data changes
  ref.watch(accountsProvider);
  ref.watch(accountStatsProvider);
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(extraordinaryEventsProvider);
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
      'SELECT account_id, value_date, balance_after '
      'FROM transactions '
      'WHERE account_id IN ($placeholders) '
      'AND balance_after IS NOT NULL '
      'ORDER BY value_date ASC, id ASC',
      variables: activeIds.map((id) => Variable.withInt(id)).toList(),
    ).get();

    for (final row in rows) {
      final accountId = row.read<int>('account_id');
      final epochSec = row.read<int>('value_date');
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

  // Add market price dates so sortedDays is dense for FX-adjusted ATH
  if (assetIds.isNotEmpty) {
    final pricePlaceholders = assetIds.map((_) => '?').join(',');
    final priceDateRows = await db.customSelect(
      'SELECT DISTINCT date FROM market_prices WHERE asset_id IN ($pricePlaceholders)',
      variables: assetIds.map((id) => Variable.withInt(id)).toList(),
    ).get();
    for (final row in priceDateRows) {
      allDayKeys.add(row.read<int>('date'));
    }
  }

  // Need actual data beyond just today's placeholder
  if (allDayKeys.length <= 1 && perAccount.isEmpty && perAssetDeltas.isEmpty) return null;

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // ── Build account series ──
  final accountSeries = <ChartSeries>[];
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

    accountSeries.add(ChartSeries(
      key: 'account:${account.id}',
      name: account.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
    ));
    colorIdx++;
  }

  // ── Build asset invested series (cumulative) ──
  final assetInvestedSeries = <ChartSeries>[];
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

    assetInvestedSeries.add(ChartSeries(
      key: 'asset_invested:${asset.id}',
      name: '${asset.ticker ?? asset.name} inv.',
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isDashed: true,
    ));
    colorIdx++;
  }

  // ── Build asset market value series ──
  // Batch-fetch all price histories (with revalue fallback for missing assets)
  final allPriceHistories = await marketPriceService.getPriceHistoryBatch(assetIds.toList());

  // Batch-fetch FX rates via SQL for all asset currencies (direct + inverse)
  final assetCurrencies = activeAssets
      .where((a) => a.currency != baseCurrency && perAssetDeltas.containsKey(a.id))
      .map((a) => a.currency)
      .toSet();
  final fxBatch = <String, List<(int, double)>>{}; // currency -> sorted [(dayKey, rate)]
  if (assetCurrencies.isNotEmpty) {
    final currList = assetCurrencies.toList();
    final currPlaceholders = currList.map((_) => '?').join(',');
    final fxRows = await db.customSelect(
      'SELECT from_currency, to_currency, date, rate FROM exchange_rates '
      'WHERE (from_currency IN ($currPlaceholders) AND to_currency = ?) '
      'OR (from_currency = ? AND to_currency IN ($currPlaceholders)) '
      'ORDER BY date',
      variables: [
        ...currList.map((c) => Variable.withString(c)),
        Variable.withString(baseCurrency),
        Variable.withString(baseCurrency),
        ...currList.map((c) => Variable.withString(c)),
      ],
    ).get();
    // Merge direct + inverse per currency, preferring direct on same date
    final directByDate = <String, Map<int, double>>{};
    final inverseByDate = <String, Map<int, double>>{};
    for (final row in fxRows) {
      final from = row.read<String>('from_currency');
      final to = row.read<String>('to_currency');
      final date = row.read<int>('date');
      final rate = row.read<double>('rate');
      if (to == baseCurrency && assetCurrencies.contains(from)) {
        directByDate.putIfAbsent(from, () => {})[date] = rate;
      } else if (from == baseCurrency && assetCurrencies.contains(to) && rate > 0) {
        inverseByDate.putIfAbsent(to, () => {})[date] = 1.0 / rate;
      }
    }
    for (final curr in assetCurrencies) {
      // Merge: start with inverse, overlay direct (direct wins on same date)
      final merged = <int, double>{
        ...?inverseByDate[curr],
        ...?directByDate[curr],
      };
      if (merged.isNotEmpty) {
        final sorted = merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        fxBatch[curr] = sorted.map((e) => (e.key, e.value)).toList();
      }
    }
  }

  // Sync FX rate lookup: binary search for latest rate <= dayKey.
  // Returns null if no data found (caller must fall back to async resolver).
  double? lookupFx(String currency, int dayKey) {
    if (currency == baseCurrency) return 1.0;
    final list = fxBatch[currency];
    if (list == null || list.isEmpty || list.first.$1 > dayKey) return null;
    var lo = 0, hi = list.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (list[mid].$1 <= dayKey) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return list[lo].$2;
  }

  final assetMarketSeries = <ChartSeries>[];
  for (final asset in activeAssets) {
    if (!perAssetDeltas.containsKey(asset.id)) continue;
    final qtyDeltaMap = perAssetQtyDeltas[asset.id] ?? {};

    final prices = allPriceHistories[asset.id] ?? [];
    final priceMap = <int, double>{};
    for (final p in prices) {
      priceMap[toDayKey(p.key)] = p.value;
    }
    // Today's price is now stored in the DB by background sync,
    // so getPriceHistoryBatch already includes it.

    // Iterate all global dates (like accounts do) so FX rates are applied
    // daily, not just on price-data days. This fixes stale FX in ATH.
    final firstEventKey = perAssetDeltas[asset.id]!.keys.reduce(min);
    final spots = <FlSpot>[];
    var cumQuantity = 0.0;
    double? lastPrice;
    var started = false;

    for (final dayKey in sortedDays) {
      // Skip dates before this asset's first event for performance
      if (!started && dayKey < firstEventKey) continue;
      if (qtyDeltaMap.containsKey(dayKey)) {
        cumQuantity += qtyDeltaMap[dayKey]!;
        started = true;
      }
      if (priceMap.containsKey(dayKey)) {
        lastPrice = priceMap[dayKey]!;
      }
      if (!started) continue;
      if (lastPrice != null && cumQuantity > 0) {
        // Batch lookup; fall back to async resolver for EUR cross-rates
        final fxRate = lookupFx(asset.currency, dayKey) ??
            await rates.getRate(asset.currency, dayKey);
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = dt.difference(firstDate).inDays.toDouble();
        final bondDiv = asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;
        spots.add(FlSpot(x, cumQuantity * lastPrice / bondDiv * fxRate));
      }
    }

    // Use same color as invested counterpart
    final investedIdx = assetInvestedSeries.indexWhere((s) => s.key == 'asset_invested:${asset.id}');
    final color = investedIdx >= 0 ? assetInvestedSeries[investedIdx].color : _chartColors[colorIdx++ % _chartColors.length];

    assetMarketSeries.add(ChartSeries(
      key: 'asset_market:${asset.id}',
      name: asset.ticker ?? asset.name,
      color: color,
      spots: spots,
    ));
  }

  // ── Build asset gain series (market - invested) ──
  final assetGainSeries = <ChartSeries>[];
  for (final asset in activeAssets) {
    final invMatch = assetInvestedSeries.where((s) => s.key == 'asset_invested:${asset.id}');
    final mktMatch = assetMarketSeries.where((s) => s.key == 'asset_market:${asset.id}');
    if (invMatch.isEmpty || mktMatch.isEmpty) continue;
    final invSpots = invMatch.first.spots;
    final mktSpots = mktMatch.first.spots;
    // Build lookup for invested values
    final invLookup = <double, double>{};
    for (final s in invSpots) {
      invLookup[s.x] = s.y;
    }
    // Compute gain at each market data point
    final gainSpots = <FlSpot>[];
    double lastInv = 0;
    for (final mkt in mktSpots) {
      if (invLookup.containsKey(mkt.x)) lastInv = invLookup[mkt.x]!;
      gainSpots.add(FlSpot(mkt.x, mkt.y - lastInv));
    }
    assetGainSeries.add(ChartSeries(
      key: 'asset_gain:${asset.id}',
      name: asset.ticker ?? asset.name,
      color: mktMatch.first.color,
      spots: gainSpots,
    ));
  }

  // ════════════════════════════════════════════════
  // 3. EXTRAORDINARY EVENTS — unified CAPEX + IncomeAdj series
  //
  // Anchor on eventDate: +totalAmount for outflow, -totalAmount for inflow.
  // Entries carry pre-signed deltas and are summed as-is.
  // Reimbursements (spread+buffer) subtract |amount| on their operation date.
  //
  // Series are partitioned into adjustments (outflow) and incomeAdjustments
  // (inflow) so downstream savings/cash composition in cashflow_tab.dart
  // stays compatible without further changes.
  // ════════════════════════════════════════════════
  final activeEvents = await (db.select(db.extraordinaryEvents)
        ..where((e) => e.isActive.equals(true)))
      .get();

  // Batch-fetch entries for all active events.
  final allEventEntries = <int, List<ExtraordinaryEventEntry>>{};
  if (activeEvents.isNotEmpty) {
    final rows = await (db.select(db.extraordinaryEventEntries)
          ..where((e) => e.eventId.isIn(activeEvents.map((e) => e.id).toList()))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();
    for (final entry in rows) {
      allEventEntries.putIfAbsent(entry.eventId, () => []).add(entry);
    }
  }

  // Batch-fetch reimbursements from linked buffers (spread treatment only).
  final allReimbursements = <int, List<BufferTransaction>>{};
  final bufferIds = activeEvents
      .where((e) => e.bufferId != null)
      .map((e) => e.bufferId!)
      .toList();
  if (bufferIds.isNotEmpty) {
    final reimbRows = await (db.select(db.bufferTransactions)
          ..where((t) => t.bufferId.isIn(bufferIds))
          ..where((t) => t.isReimbursement.equals(true)))
        .get();
    for (final txn in reimbRows) {
      allReimbursements.putIfAbsent(txn.bufferId, () => []).add(txn);
    }
  }

  final adjustmentSeries = <ChartSeries>[];
  final incomeAdjSeries = <ChartSeries>[];

  for (final event in activeEvents) {
    final entries = allEventEntries[event.id] ?? const [];
    final deltaMap = <int, double>{};

    // Anchor delta.
    final anchorSign = event.direction == EventDirection.outflow ? 1.0 : -1.0;
    final anchorKey = toDayKey(event.eventDate);
    deltaMap[anchorKey] = (deltaMap[anchorKey] ?? 0) + anchorSign * event.totalAmount;
    allDayKeys.add(anchorKey);

    // Entries are pre-signed per direction — sum as-is.
    for (final entry in entries) {
      final dayKey = toDayKey(entry.date);
      deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) + entry.amount;
      allDayKeys.add(dayKey);
    }

    // Reimbursements reduce saving further (only meaningful on spread outflows).
    if (event.bufferId != null) {
      for (final r in allReimbursements[event.bufferId!] ?? const []) {
        final dayKey = toDayKey(r.operationDate);
        deltaMap[dayKey] = (deltaMap[dayKey] ?? 0) - r.amount.abs();
      }
    }

    if (deltaMap.isEmpty) continue;

    final days = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;

    for (final dayKey in days) {
      final rate = await rates.getRate(event.currency, dayKey);
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

    // Partition by direction to preserve legacy series keys and downstream
    // Saving = accounts + invested + adjustments + incomeAdjustments formula.
    final isOutflow = event.direction == EventDirection.outflow;
    final series = ChartSeries(
      key: isOutflow ? 'adjustment:${event.id}' : 'income_adj:${event.id}',
      name: event.name,
      color: _chartColors[colorIdx % _chartColors.length],
      spots: spots,
      isDashed: true,
    );
    (isOutflow ? adjustmentSeries : incomeAdjSeries).add(series);
    colorIdx++;
  }

  return AllSeriesData(
    firstDate: firstDate,
    accounts: accountSeries,
    assetInvested: assetInvestedSeries,
    assetMarket: assetMarketSeries,
    assetGain: assetGainSeries,
    adjustments: adjustmentSeries,
    incomeAdjustments: incomeAdjSeries,
    baseCurrency: baseCurrency,
  );
});

// ════════════════════════════════════════════════════
// Income/Expense data provider
// ════════════════════════════════════════════════════

final _incomeExpenseDataProvider = FutureProvider<_IncomeExpenseData?>((ref) async {
  final allSeriesData = await ref.watch(allSeriesDataProvider.future);
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

