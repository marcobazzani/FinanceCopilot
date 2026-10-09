part of 'dashboard_screen.dart';

final _allSeriesLog = getLogger('AllSeriesData');

// ════════════════════════════════════════════════════
// Unified data provider — computes ALL series at once
// ════════════════════════════════════════════════════

final allSeriesDataProvider = FutureProvider<AllSeriesData?>((ref) async {
  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final defaultTaxRate = await ref.watch(defaultTaxRateProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final marketPriceService = ref.watch(marketPriceServiceProvider);

  // Watch reactive streams so we rebuild when data changes
  ref.watch(accountsProvider);
  ref.watch(accountStatsProvider);
  ref.watch(assetsProvider);
  ref.watch(assetStatsProvider);
  ref.watch(extraordinaryEventsProvider);
  ref.watch(priceRefreshCounter);
  final currentDate = ref.watch(currentDateProvider);
  final waybackDate = ref.watch(waybackDateProvider);
  final cutoffDayKey = waybackDate == null ? null : toDayKey(currentDate);
  final cutoffEndDate = waybackDate == null ? null : startOfNextDay(currentDate);
  final cutoffEndExclusive = waybackDate == null ? null : cutoffEndDate!.millisecondsSinceEpoch ~/ 1000;
  bool includeDayKey(int dayKey) => cutoffDayKey == null || dayKey <= cutoffDayKey;

  final allDayKeys = <int>{};
  // Include the visual current date so charts extend to the selected "today".
  allDayKeys.add(toDayKey(currentDate));
  final rates = _RateResolver(rateService, baseCurrency);
  var colorIdx = 0;

  // ════════════════════════════════════════════════
  // 1. ACCOUNTS — daily balance from transactions
  // ════════════════════════════════════════════════
  final activeAccounts =
      await (db.select(db.accounts)
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .get();
  final activeIds = activeAccounts.map((a) => a.id).toSet();

  final perAccount = <int, Map<int, double>>{};
  if (activeIds.isNotEmpty) {
    final placeholders = activeIds.map((_) => '?').join(',');
    final rows = await db
        .customSelect(
          'SELECT account_id, value_date, balance_after '
          'FROM transactions '
          'WHERE account_id IN ($placeholders) '
          'AND balance_after IS NOT NULL '
          'ORDER BY value_date ASC, id ASC',
          variables: activeIds.map((id) => Variable.withInt(id)).toList(),
        )
        .get();

    for (final row in rows) {
      final accountId = row.read<int>('account_id');
      final epochSec = row.read<int>('value_date');
      final balance = row.read<double>('balance_after');
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final dayKey = toDayKey(dt);
      if (!includeDayKey(dayKey)) continue;

      perAccount.putIfAbsent(accountId, () => {});
      perAccount[accountId]![dayKey] = balance;
      allDayKeys.add(dayKey);
    }
  }

  // ════════════════════════════════════════════════
  // 2. ASSETS — cumulative invested value from events
  // ════════════════════════════════════════════════
  final activeAssets =
      await (db.select(db.assets)
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .get();
  final assetIds = activeAssets.map((a) => a.id).toSet();

  final perAssetDeltas = <int, Map<int, double>>{};
  final perAssetQtyDeltas = <int, Map<int, double>>{};
  // Assets with a buy or sell amount left out of the invested series: their
  // cost basis is incomplete, so no gain or net value is drawn against it.
  final costBasisIncomplete = <int>{};

  if (assetIds.isNotEmpty) {
    final assetPlaceholders = assetIds.map((_) => '?').join(',');
    final events = await db
        .customSelect(
          'SELECT * FROM asset_events '
          'WHERE asset_id IN ($assetPlaceholders) '
          "${cutoffEndExclusive != null ? 'AND value_date < ? ' : ''}"
          'ORDER BY value_date ASC',
          variables: [
            ...assetIds.map((id) => Variable.withInt(id)),
            if (cutoffEndExclusive != null) Variable.withInt(cutoffEndExclusive),
          ],
        )
        .map((row) => db.assetEvents.map(row.data))
        .get();

    for (final ev in events) {
      final assetId = ev.assetId;
      double sign;
      if (ev.type == EventType.buy) {
        sign = 1.0;
      } else if (ev.type == EventType.sell) {
        sign = -1.0;
      } else {
        continue;
      }

      final dayKey = toDayKey(ev.valueDate);
      if (!includeDayKey(dayKey)) continue;

      // Units bought or sold move the held quantity whether or not the
      // amount converts to base, so the market value always sees them.
      perAssetQtyDeltas.putIfAbsent(assetId, () => {});
      perAssetQtyDeltas[assetId]![dayKey] = (perAssetQtyDeltas[assetId]![dayKey] ?? 0) + sign * (ev.quantity ?? 0).abs();
      allDayKeys.add(dayKey);

      final netAmount = ev.amount - (ev.commission ?? 0);
      final baseAmount = await convertToBase(
        amount: netAmount,
        currency: ev.currency,
        baseCurrency: baseCurrency,
        // A rate stamped with a previous base is preserved data, not a
        // conversion into this one: resolve it from rate history instead.
        storedRate: AssetEventService.isExchangeRateUsableFor(ev, baseCurrency) ? ev.exchangeRate : null,
        resolver: rates,
        dayKey: dayKey,
      );
      // No rate available -> leave the amount out of the invested series
      // rather than feed a wrong number into cumulative totals.
      if (baseAmount == null) {
        _allSeriesLog.warning(
          'asset $assetId ${ev.type.name} on ${fmt.formatYmd(ev.valueDate)}: no ${ev.currency}/$baseCurrency rate - '
          'amount left out of the invested series, quantity kept, no gain or net value drawn',
        );
        costBasisIncomplete.add(assetId);
        continue;
      }

      perAssetDeltas.putIfAbsent(assetId, () => {});
      perAssetDeltas[assetId]![dayKey] = (perAssetDeltas[assetId]![dayKey] ?? 0) + sign * baseAmount;
    }
  }

  // ════════════════════════════════════════════════
  // 3. EXTRAORDINARY EVENTS — preload and contribute their dates to the
  // global chart domain before series are built.
  // ════════════════════════════════════════════════
  final activeEventsQuery = db.select(db.extraordinaryEvents)..where((e) => e.isActive.equals(true));
  final activeEvents = (await activeEventsQuery.get())
      .where(
        (event) => cutoffEndDate == null || event.eventDate.isBefore(cutoffEndDate),
      )
      .toList();

  final allEventEntries = <int, List<ExtraordinaryEventEntry>>{};
  if (activeEvents.isNotEmpty) {
    final entriesQuery = db.select(db.extraordinaryEventEntries)..where((e) => e.eventId.isIn(activeEvents.map((e) => e.id).toList()));
    entriesQuery.orderBy([(e) => OrderingTerm.asc(e.date)]);
    final rows = (await entriesQuery.get())
        .where(
          (entry) => cutoffEndDate == null || entry.date.isBefore(cutoffEndDate),
        )
        .toList();
    for (final entry in rows) {
      allEventEntries.putIfAbsent(entry.eventId, () => []).add(entry);
      final dayKey = toDayKey(entry.date);
      if (includeDayKey(dayKey)) allDayKeys.add(dayKey);
    }
  }

  final allReimbursements = <int, List<BufferTransaction>>{};
  final bufferIds = activeEvents.where((e) => e.bufferId != null).map((e) => e.bufferId!).toList();
  if (bufferIds.isNotEmpty) {
    final reimbQuery = db.select(db.bufferTransactions)
      ..where((t) => t.bufferId.isIn(bufferIds))
      ..where((t) => t.isReimbursement.equals(true));
    final reimbRows = (await reimbQuery.get())
        .where(
          (txn) => cutoffEndDate == null || txn.valueDate.isBefore(cutoffEndDate),
        )
        .toList();
    for (final txn in reimbRows) {
      allReimbursements.putIfAbsent(txn.bufferId, () => []).add(txn);
      final dayKey = toDayKey(txn.valueDate);
      if (includeDayKey(dayKey)) allDayKeys.add(dayKey);
    }
  }

  for (final event in activeEvents) {
    final dayKey = toDayKey(event.eventDate);
    if (includeDayKey(dayKey)) allDayKeys.add(dayKey);
  }

  // Add market price dates so sortedDays is dense for FX-adjusted ATH
  if (assetIds.isNotEmpty) {
    final pricePlaceholders = assetIds.map((_) => '?').join(',');
    final priceDateRows = await db
        .customSelect(
          'SELECT DISTINCT date FROM market_prices WHERE asset_id IN ($pricePlaceholders)',
          variables: assetIds.map((id) => Variable.withInt(id)).toList(),
        )
        .get();
    for (final row in priceDateRows) {
      // A price stored with a clock time (a revalue at 15:42) belongs to its
      // calendar day: every series is keyed by local midnight.
      final dayKey = toDayKey(DateTime.fromMillisecondsSinceEpoch(row.read<int>('date') * 1000));
      if (includeDayKey(dayKey)) allDayKeys.add(dayKey);
    }
  }

  // Need actual data beyond just today's placeholder
  if (allDayKeys.length <= 1 && perAccount.isEmpty && perAssetQtyDeltas.isEmpty && activeEvents.isEmpty) {
    return null;
  }

  final sortedDays = allDayKeys.toList()..sort();
  final firstDate = DateTime.fromMillisecondsSinceEpoch(sortedDays.first * 1000);

  // ── Build account series ──
  final accountSeries = <ChartSeries>[];
  // Accounts with a balance but no rate to base on any day: their series has
  // no spots — every total leaves them out, and counts them.
  final excludedAccountIds = <int>{};
  for (final account in activeAccounts) {
    if (!perAccount.containsKey(account.id)) continue;
    final dayMap = perAccount[account.id]!;
    final spots = <FlSpot>[];
    double? running;

    for (final dayKey in sortedDays) {
      if (dayMap.containsKey(dayKey)) running = dayMap[dayKey];
      if (running != null) {
        final rate = await rates.getRate(account.currency, dayKey);
        if (rate == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
        final x = chart_math.calendarDaysBetween(firstDate, dt).toDouble();
        spots.add(FlSpot(x, running * rate));
      }
    }
    if (spots.isEmpty) {
      _allSeriesLog.warning('account ${account.id}: no ${account.currency}/$baseCurrency rate - left out of every total');
      excludedAccountIds.add(account.id);
    }

    accountSeries.add(
      ChartSeries(
        key: 'account:${account.id}',
        name: account.name,
        color: _chartColors[colorIdx % _chartColors.length],
        spots: spots,
      ),
    );
    colorIdx++;
  }

  // ── Build asset invested series (cumulative) ──
  final assetInvestedSeries = <ChartSeries>[];
  for (final asset in activeAssets) {
    // None of its amounts converts to base: the series is kept without spots,
    // like its gain and net series, so a total built from it leaves the asset
    // out and counts it (see [totalExclusions]).
    final deltaMap = perAssetDeltas[asset.id] ?? (costBasisIncomplete.contains(asset.id) ? const <int, double>{} : null);
    if (deltaMap == null) continue;
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
        final x = chart_math.calendarDaysBetween(firstDate, dt).toDouble();
        spots.add(FlSpot(x, cumulative));
      }
    }

    assetInvestedSeries.add(
      ChartSeries(
        key: 'asset_invested:${asset.id}',
        name: '${asset.ticker ?? asset.name} inv.',
        color: _chartColors[colorIdx % _chartColors.length],
        spots: spots,
        isDashed: true,
      ),
    );
    colorIdx++;
  }

  // ── Build asset market value series ──
  // Batch-fetch all price histories (with revalue fallback for missing assets)
  final allPriceHistories = await marketPriceService.getPriceHistoryBatch(assetIds.toList());

  // Batch-fetch FX rates via SQL for all asset currencies (direct + inverse)
  final assetCurrencies = activeAssets
      .where((a) => a.currency != baseCurrency && perAssetQtyDeltas.containsKey(a.id))
      .map((a) => a.currency)
      .toSet();
  final fxBatch = <String, List<(int, double)>>{}; // currency -> sorted [(dayKey, rate)]
  if (assetCurrencies.isNotEmpty) {
    final currList = assetCurrencies.toList();
    final currPlaceholders = currList.map((_) => '?').join(',');
    final fxRows = await db
        .customSelect(
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
        )
        .get();
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
    // Keyed on the quantity deltas, not the invested ones: a held position
    // has a market value even when its cost cannot be converted to base.
    if (!perAssetQtyDeltas.containsKey(asset.id)) continue;
    final qtyDeltaMap = perAssetQtyDeltas[asset.id]!;

    final prices = allPriceHistories[asset.id] ?? [];
    final priceMap = <int, double>{};
    for (final p in prices) {
      priceMap[toDayKey(p.key)] = p.value;
    }
    // Today's price is now stored in the DB by background sync,
    // so getPriceHistoryBatch already includes it.

    // Iterate all global dates (like accounts do) so FX rates are applied
    // daily, not just on price-data days. This fixes stale FX in ATH.
    final firstEventKey = qtyDeltaMap.keys.reduce(min);
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
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = chart_math.calendarDaysBetween(firstDate, dt).toDouble();
      if (cumQuantity <= 0) {
        // Position fully closed (bought then fully sold). This is an exact,
        // known-zero value — independent of price/FX availability — so it
        // must still be emitted. Without it, buildTotalSpots' carry-forward
        // would keep plotting the last pre-sale market value forever.
        spots.add(FlSpot(x, 0.0));
        continue;
      }
      if (lastPrice == null) continue;
      // Batch lookup; fall back to async resolver for EUR cross-rates.
      // If neither yields a rate, skip the spot rather than plot a value
      // computed with an implicit 1.0 FX rate.
      final value = computeAssetBaseValue(
        quantity: cumQuantity,
        price: lastPrice,
        bondDivisor: bondPriceDivisor(asset.instrumentType),
        fxRate: lookupFx(asset.currency, dayKey) ?? await rates.getRate(asset.currency, dayKey),
      );
      if (value == null) continue;
      spots.add(FlSpot(x, value));
    }

    // Use same color as invested counterpart
    final investedIdx = assetInvestedSeries.indexWhere((s) => s.key == 'asset_invested:${asset.id}');
    final color = investedIdx >= 0 ? assetInvestedSeries[investedIdx].color : _chartColors[colorIdx++ % _chartColors.length];

    assetMarketSeries.add(
      ChartSeries(
        key: 'asset_market:${asset.id}',
        name: asset.ticker ?? asset.name,
        color: color,
        spots: spots,
      ),
    );
  }

  // ── Build asset gain series (market - invested) ──
  // An asset whose cost basis is incomplete keeps its series, without spots
  // (see [costBasisIncompleteAssetIds]): against part of what it cost, a buy
  // left out would read as profit and a sell left out as a loss.
  final assetGainSeries = <ChartSeries>[];
  for (final asset in activeAssets) {
    final invMatch = assetInvestedSeries.where((s) => s.key == 'asset_invested:${asset.id}');
    final mktMatch = assetMarketSeries.where((s) => s.key == 'asset_market:${asset.id}');
    if (mktMatch.isEmpty) continue;
    if (costBasisIncomplete.contains(asset.id)) {
      assetGainSeries.add(
        ChartSeries(key: 'asset_gain:${asset.id}', name: asset.ticker ?? asset.name, color: mktMatch.first.color, spots: const []),
      );
      continue;
    }
    if (invMatch.isEmpty) continue;
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
    assetGainSeries.add(
      ChartSeries(
        key: 'asset_gain:${asset.id}',
        name: asset.ticker ?? asset.name,
        color: mktMatch.first.color,
        spots: gainSpots,
      ),
    );
  }

  // ── Build asset net series (invested + max(0,gain) * (1 - τ)) ──
  // τ = per-asset taxRate if set, otherwise the global default. Used for
  // the optional "Net" chart series toggled in the chart editor, and for the
  // Net Asset Value. Without spots for an incomplete cost basis, like the gain:
  // a total built from it leaves the asset out and counts it.
  final assetNetSeries = <ChartSeries>[];
  for (final asset in activeAssets) {
    final invMatch = assetInvestedSeries.where((s) => s.key == 'asset_invested:${asset.id}');
    final mktMatch = assetMarketSeries.where((s) => s.key == 'asset_market:${asset.id}');
    if (mktMatch.isEmpty) continue;
    if (costBasisIncomplete.contains(asset.id)) {
      assetNetSeries.add(
        ChartSeries(key: 'asset_net:${asset.id}', name: asset.ticker ?? asset.name, color: mktMatch.first.color, spots: const []),
      );
      continue;
    }
    if (invMatch.isEmpty) continue;
    final invSpots = invMatch.first.spots;
    final mktSpots = mktMatch.first.spots;
    final invLookup = <double, double>{};
    for (final s in invSpots) {
      invLookup[s.x] = s.y;
    }
    final tau = asset.taxRate ?? defaultTaxRate;
    final netSpots = <FlSpot>[];
    double lastInv = 0;
    for (final mkt in mktSpots) {
      if (invLookup.containsKey(mkt.x)) lastInv = invLookup[mkt.x]!;
      netSpots.add(
        FlSpot(
          mkt.x,
          computeAssetNetValue(invested: lastInv, market: mkt.y, taxRate: tau),
        ),
      );
    }
    assetNetSeries.add(
      ChartSeries(
        key: 'asset_net:${asset.id}',
        name: asset.ticker ?? asset.name,
        color: mktMatch.first.color,
        spots: netSpots,
      ),
    );
  }

  // ════════════════════════════════════════════════
  // 3. EXTRAORDINARY EVENTS — unified CAPEX + IncomeAdj series
  //
  // Anchor on eventDate: +totalAmount for outflow, -totalAmount for inflow.
  // Entries carry pre-signed deltas and are summed as-is.
  // Reimbursements (spread+buffer) subtract |amount| on their value date.
  //
  // Series are partitioned into adjustments (outflow) and incomeAdjustments
  // (inflow) so downstream savings/cash composition in cashflow_tab.dart
  // stays compatible without further changes.
  // ════════════════════════════════════════════════
  final adjustmentSeries = <ChartSeries>[];
  final incomeAdjSeries = <ChartSeries>[];
  final ephemeralInflowSeries = <ChartSeries>[];
  // Adjustments with amounts but no rate to base on any of their days.
  final excludedAdjustmentIds = <int>{};

  // Compute carry-forward spots from a day→delta map, using the event's FX
  // rate on each day. Pure helper — returns empty when the map is empty.
  Future<List<FlSpot>> buildSpots(Map<int, double> deltaMap, String currency) async {
    if (deltaMap.isEmpty) return const [];
    final days = deltaMap.keys.toList()..sort();
    final spots = <FlSpot>[];
    var cumulative = 0.0;
    double? prevY;
    for (final dayKey in days) {
      final rate = await rates.getRate(currency, dayKey);
      // We must still accumulate the delta to keep the series consistent on
      // later days — but if no FX rate is available, skip plotting this spot
      // rather than emit a value computed against base 1:1.
      cumulative += deltaMap[dayKey]!;
      if (rate == null) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(dayKey * 1000);
      final x = chart_math.calendarDaysBetween(firstDate, dt).toDouble();
      if (prevY != null && spots.isNotEmpty && x > (spots.last.x + 1)) {
        spots.add(FlSpot(x - 0.5, prevY));
      }
      final y = cumulative * rate;
      spots.add(FlSpot(x, y));
      prevY = y;
    }
    return spots;
  }

  for (final event in activeEvents) {
    final entries = allEventEntries[event.id] ?? const <ExtraordinaryEventEntry>[];
    final isOutflow = event.direction == EventDirection.outflow;
    final anchorSign = isOutflow ? 1.0 : -1.0;

    // Split each event into two independently-toggleable series so the
    // chart editor can offer "Value" (the anchor at eventDate) and
    // "Events" (entries + reimbursements over time) as separate picks.
    final eventDayKey = toDayKey(event.eventDate);
    final valueMap = <int, double>{
      if (includeDayKey(eventDayKey)) eventDayKey: anchorSign * event.totalAmount,
    };
    if (includeDayKey(eventDayKey)) allDayKeys.add(eventDayKey);

    final eventsMap = <int, double>{};
    for (final entry in entries) {
      final dayKey = toDayKey(entry.date);
      if (!includeDayKey(dayKey)) continue;
      eventsMap[dayKey] = (eventsMap[dayKey] ?? 0) + entry.amount;
      allDayKeys.add(dayKey);
    }
    if (event.bufferId != null) {
      for (final r in allReimbursements[event.bufferId!] ?? const <BufferTransaction>[]) {
        // valueDate per AGENTS.md — chart day-keys use the canonical
        // "money moved" date, never operation_date.
        final dayKey = toDayKey(r.valueDate);
        if (!includeDayKey(dayKey)) continue;
        eventsMap[dayKey] = (eventsMap[dayKey] ?? 0) - r.amount.abs();
        allDayKeys.add(dayKey);
      }
    }

    final chartEndDayKey = sortedDays.last;
    final valueSpots = extendSingleSpotCarryForward(
      await buildSpots(valueMap, event.currency),
      firstDate: firstDate,
      endDayKey: chartEndDayKey,
    );
    final eventSpots = extendSingleSpotCarryForward(
      await buildSpots(eventsMap, event.currency),
      firstDate: firstDate,
      endDayKey: chartEndDayKey,
    );

    // Ephemeral inflows live in their own bucket; non-ephemeral inflows
    // stay in incomeAdjSeries; outflows always in adjustmentSeries.
    final isEphemeral = !isOutflow && event.isEphemeral;
    final String valuePrefix;
    final String eventsPrefix;
    final List<ChartSeries> bucket;
    if (isOutflow) {
      valuePrefix = 'adjustment_value';
      eventsPrefix = 'adjustment_events';
      bucket = adjustmentSeries;
    } else if (isEphemeral) {
      valuePrefix = 'ephemeral_inflow_value';
      eventsPrefix = 'ephemeral_inflow_events';
      bucket = ephemeralInflowSeries;
    } else {
      valuePrefix = 'income_adj_value';
      eventsPrefix = 'income_adj_events';
      bucket = incomeAdjSeries;
    }

    // Amounts without a rate to base on any of their days have no spots. The
    // series is kept all the same — like an asset's without a price — so a
    // total built from it leaves the adjustment out and counts it.
    if ((valueMap.isNotEmpty && valueSpots.isEmpty) || (eventsMap.isNotEmpty && eventSpots.isEmpty)) {
      _allSeriesLog.warning('adjustment ${event.id}: no ${event.currency}/$baseCurrency rate - left out of every total');
      excludedAdjustmentIds.add(event.id);
    }
    if (valueMap.isNotEmpty) {
      bucket.add(
        ChartSeries(
          key: '$valuePrefix:${event.id}',
          name: event.name,
          color: _chartColors[colorIdx % _chartColors.length],
          spots: valueSpots,
          isDashed: true,
        ),
      );
      colorIdx++;
    }
    if (eventsMap.isNotEmpty) {
      bucket.add(
        ChartSeries(
          key: '$eventsPrefix:${event.id}',
          name: event.name,
          color: _chartColors[colorIdx % _chartColors.length],
          spots: eventSpots,
          isDashed: true,
        ),
      );
      colorIdx++;
    }
  }

  return AllSeriesData(
    firstDate: firstDate,
    accounts: accountSeries,
    assetInvested: assetInvestedSeries,
    assetMarket: assetMarketSeries,
    assetGain: assetGainSeries,
    assetNet: assetNetSeries,
    adjustments: adjustmentSeries,
    incomeAdjustments: incomeAdjSeries,
    ephemeralInflows: ephemeralInflowSeries,
    baseCurrency: baseCurrency,
    excludedAccountIds: excludedAccountIds,
    excludedAdjustmentIds: excludedAdjustmentIds,
  );
});

/// Assets of [data] whose cost basis is incomplete: a buy or sell whose
/// amount has no rate to base is left out of their invested series (kept
/// without spots when no amount converts) while its units still count in
/// their market value, so [allSeriesDataProvider] keeps their gain and net
/// series without spots rather than compute them against part of what they
/// cost. A total built from those series leaves them out; its footnote counts
/// them ([totalExclusions]). An asset without any market value is not one of
/// them: it is unpriced (see [TotalExclusions.unpricedAssetIds]).
Set<int> costBasisIncompleteAssetIds(AllSeriesData data) {
  final ids = <int>{};
  for (final gain in data.assetGain) {
    final id = parseSeriesKey(gain.key)?.id;
    if (id == null || gain.spots.isNotEmpty) continue;
    final market = data.assetMarket.where((s) => s.key == 'asset_market:$id').firstOrNull;
    if (market != null && market.spots.isNotEmpty) ids.add(id);
  }
  return ids;
}

// ════════════════════════════════════════════════════
// Income/Expense data provider
// ════════════════════════════════════════════════════

/// The yearly Income / Expense / Savings figures, with the number of income
/// records they leave out for want of a rate
/// ([_IncomeExpenseData.rowsWithoutRate]).
final _incomeExpenseDataProvider = FutureProvider<_IncomeExpenseData?>((ref) async {
  final allSeriesData = await ref.watch(allSeriesDataProvider.future);
  if (allSeriesData == null) return null;

  final db = ref.watch(databaseProvider);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  ref.watch(incomesProvider); // reactive
  final currentDate = ref.watch(currentDateProvider);
  final cutoffDayKey = ref.watch(waybackDateProvider) == null ? null : toDayKey(currentDate);
  bool includeDayKey(int dayKey) => cutoffDayKey == null || dayKey <= cutoffDayKey;

  final rates = _RateResolver(rateService, baseCurrency);

  // The income records [sql] selects (`date` = value date, `amount`,
  // `currency`, optionally `asset_id` for [keep]), up to the as-of cutoff and
  // in query order, as (value date, amount in base at that day's rate). A
  // record whose currency has no rate that day is left out rather than
  // mis-summed — and counted.
  var rowsWithoutRate = 0;
  Future<List<(DateTime, double)>> incomeInBase(String sql, {bool Function(int? assetId)? keep}) async {
    final converted = <(DateTime, double)>[];
    for (final row in await db.customSelect(sql).get()) {
      if (keep != null && !keep(row.readNullable<int>('asset_id'))) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(row.read<int>('date') * 1000);
      if (!includeDayKey(toDayKey(dt))) continue;
      final rate = await rates.getRate(row.read<String>('currency'), toDayKey(dt));
      if (rate == null) {
        rowsWithoutRate++;
        continue;
      }
      converted.add((dt, row.read<double>('amount') * rate));
    }
    return converted;
  }

  // 1. Load incomes (excluding refunds and pension contributions),
  // convert to base currency. Both refund and pensionContribution are
  // money received but not "personal income" — the user reports them in
  // the ledger but doesn't want them inflating salary totals.
  // Ordered by value_date per AGENTS.md convention — operation_date is
  // only for import dedup, never for display/aggregation.
  final incomeByMonth = <(int, int), double>{};
  final monthsWithIncomeData = <(int, int)>{};
  for (final (dt, amount) in await incomeInBase(
    "SELECT value_date AS date, amount, currency FROM incomes "
    "WHERE type NOT IN ('refund', 'pensionContribution') "
    "ORDER BY value_date ASC",
  )) {
    final key = (dt.year, dt.month);
    incomeByMonth[key] = (incomeByMonth[key] ?? 0) + amount;
    monthsWithIncomeData.add(key);
  }

  // 1b. Refund Income records: money received that is not personal income
  // but lands in the bank, so it is inside the savings change and lowers
  // the derived expenses. Kept per year so the cash-flow Sankey can show it.
  final refundByYear = <int, double>{};
  for (final (dt, amount) in await incomeInBase(
    "SELECT value_date AS date, amount, currency FROM incomes WHERE type = 'refund' ORDER BY value_date ASC",
  )) {
    refundByYear[dt.year] = (refundByYear[dt.year] ?? 0) + amount;
  }

  // 2. Build total saving series — resolved from the user's configured
  // Saving chart when present (option B), else hard-coded composition.
  final userCharts = ref.watch(dashboardChartsProvider);
  final activeAssets = await ref.watch(activeAssetsProvider.future);
  final savingSpots = _DashboardScreenState.spotsForRole(
    'saving',
    userCharts,
    allSeriesData,
    activeAssets,
  );
  final savingAssetIds = _DashboardScreenState.assetIdsForRoleTotal(
    'saving',
    userCharts,
    allSeriesData,
    activeAssets,
  );

  // Pension contributions are external money (employer/state/severance
  // redirect) — they inflate the pension fund's NAV without ever
  // landing in the user's bank account. Refunds, by contrast, DO land
  // in the bank, so their NAV impact is real personal savings — only
  // their income classification is excluded above. Pension is the rare
  // case where both the income side AND the savings side need to
  // subtract, otherwise saving/expense velocity reads as if the user
  // saved €X each month they didn't actually save.
  //
  // Only subtract contribution rows whose asset is actually included in
  // the resolved Saving total. If a pension fund is excluded from Saving,
  // subtracting its mirrored income rows here would double-exclude it.
  final pensionRows = await incomeInBase(
    "SELECT value_date AS date, amount, currency, asset_id FROM incomes "
    "WHERE type = 'pensionContribution' ORDER BY value_date ASC",
    keep: (assetId) => assetId != null && savingAssetIds.contains(assetId),
  );
  final pensionContribByMonth = <(int, int), double>{};
  for (final (dt, amount) in pensionRows) {
    final key = (dt.year, dt.month);
    pensionContribByMonth[key] = (pensionContribByMonth[key] ?? 0) + amount;
  }

  // Before its first data point the saving total is not 0 — it is not known
  // yet. The first observed value is where the tracked history opens, so the
  // first period's savings are measured from there: balances that already
  // existed when tracking began are not a period of savings (which would
  // also read as negative expenses).
  final openingNav = savingSpots.isEmpty ? 0.0 : savingSpots.first.y;
  double lookupNAV(DateTime date) {
    final x = chart_math.calendarDaysBetween(allSeriesData.firstDate, date).toDouble();
    double nav = openingNav;
    for (final s in savingSpots) {
      if (s.x <= x) {
        nav = s.y;
      } else {
        break;
      }
    }
    return nav;
  }

  // 3. Build monthly + yearly buckets
  final now = currentDate;
  final years = <_YearBucket>[];

  for (int y = allSeriesData.firstDate.year; y <= now.year; y++) {
    // Use Dec 31 of previous year as start reference so that Jan 1
    // transactions are included in the year's NAV change.
    final yStartRef = DateTime(y - 1, 12, 31);
    final yStart = DateTime(y, 1, 1);
    final isCurrentYear = y == now.year;
    final effectiveEnd = isCurrentYear ? now : DateTime(y, 12, 31);
    // Calendar days, both ends included: elapsed hours fall an hour short of
    // whole days while summer time is on.
    final days = chart_math.calendarDaysBetween(yStart, effectiveEnd) + 1;

    double yearIncome = 0;
    double yearPensionContrib = 0;
    final months = <_MonthBucket>[];

    for (int m = 1; m <= 12; m++) {
      if (isCurrentYear && m > now.month) break;
      // Use last day of previous month (day 0) so 1st-of-month txns are
      // captured. Calendar days, not the 1st minus 24 hours: when DST starts
      // on 31 March that lands on 30 March and books 31 March in April.
      final mStartRef = DateTime(y, m, 0);
      final mEnd = (isCurrentYear && m == now.month) ? now : DateTime(y, m + 1, 0);
      final mIncome = incomeByMonth[(y, m)] ?? 0;
      final mPensionContrib = pensionContribByMonth[(y, m)] ?? 0;
      yearIncome += mIncome;
      yearPensionContrib += mPensionContrib;
      months.add(
        _MonthBucket(
          year: y,
          month: m,
          income: mIncome,
          navChange: lookupNAV(mEnd) - lookupNAV(mStartRef),
          pensionContrib: mPensionContrib,
          hasIncomeData: monthsWithIncomeData.contains((y, m)),
        ),
      );
    }

    years.add(
      _YearBucket(
        year: y,
        days: days,
        income: yearIncome,
        navChange: lookupNAV(effectiveEnd) - lookupNAV(yStartRef),
        pensionContrib: yearPensionContrib,
        refunds: refundByYear[y] ?? 0,
        months: months,
      ),
    );
  }

  // Cumulative pension contributions as a day-offset spot series,
  // aligned to allSeriesData.firstDate so cashflow_tab can subtract it
  // from savingSpots without re-running a query. Each spot's x is the
  // day offset of that contribution; y is the running total in base
  // currency. Used to build a "personal saving" series for velocity.
  final pensionContribSpots = <FlSpot>[];
  double cumulative = 0;
  for (final (dt, amount) in pensionRows) {
    cumulative += amount;
    final x = chart_math.calendarDaysBetween(allSeriesData.firstDate, dt).toDouble();
    pensionContribSpots.add(FlSpot(x, cumulative));
  }

  if (rowsWithoutRate > 0) {
    _allSeriesLog.warning(
      'income: $rowsWithoutRate record(s) without a rate to $baseCurrency on their value date - left out of the yearly figures',
    );
  }
  return _IncomeExpenseData(
    years: years,
    baseCurrency: baseCurrency,
    firstDate: allSeriesData.firstDate,
    pensionContribCumulativeSpots: pensionContribSpots,
    rowsWithoutRate: rowsWithoutRate,
  );
});

/// Income records (salaries, refunds, pension contributions) whose currency
/// had no rate to base on their value date: left out of the yearly Income /
/// Expense / Savings figures rather than converted 1:1. The Cash Flow and
/// Health tabs footnote this count next to those figures. None without any
/// figures.
final incomeRowsWithoutRateProvider = FutureProvider<int>(
  (ref) async => (await ref.watch(_incomeExpenseDataProvider.future))?.rowsWithoutRate ?? 0,
);

// ════════════════════════════════════════════════════
// Spending by category (splits the yearly expenses in the Sankey)
// ════════════════════════════════════════════════════

final _spendingByCategoryProvider = FutureProvider<SpendingByCategoryData>((ref) async {
  final txs = await ref.watch(allTransactionsProvider.future);
  final cats = await ref.watch(allCategoriesProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rates = _RateResolver(ref.watch(exchangeRateServiceProvider), baseCurrency);
  final now = ref.watch(currentDateProvider);
  final roles = await ref.watch(ledgerRolesProvider.future);
  // Same cutoff as the yearly Income/Expense/Savings figures.
  final wayback = ref.watch(waybackDateProvider) != null;
  return aggregateSpendingByCategory(
    transactions: txs,
    categories: {for (final c in cats) c.id: c},
    rate: rates.getRate,
    baseCurrency: baseCurrency,
    now: now,
    through: wayback ? now : null,
    excludedIds: roles.keys.toSet(),
  );
});
