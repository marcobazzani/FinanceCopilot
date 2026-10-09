part of 'providers.dart';

// ── Derived / computed data providers ──

class PillarAllocationData {
  final List<Asset> assets;
  final Map<int, double> marketValues;
  final String baseCurrency;

  /// Held assets of the pillar left out of [assets] and [marketValues]
  /// because they have no market value (no price, or no exchange rate to
  /// [baseCurrency]) — never counted as worth 0.
  final int unvaluedAssetCount;

  const PillarAllocationData({
    required this.assets,
    required this.marketValues,
    required this.baseCurrency,
    this.unvaluedAssetCount = 0,
  });
}

/// Account stats with balances converted to base currency using live rates.
final convertedAccountStatsProvider = FutureProvider<Map<int, double?>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final stats = await ref.watch(accountStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final waybackDate = ref.watch(waybackDateProvider);
  final currentDate = ref.watch(currentDateProvider);

  final result = <int, double?>{};
  for (final account in accounts) {
    final stat = stats[account.id];
    if (stat == null || stat.balance == null) continue;
    if (account.currency == baseCurrency) {
      result[account.id] = stat.balance;
    } else {
      // Null when no rate is available — surface as null in the map rather
      // than fabricate a wrong value.
      result[account.id] = waybackDate == null
          ? await rateService.convertLive(
              stat.balance!,
              account.currency,
              baseCurrency,
            )
          : await rateService.convertAmount(
              stat.balance!,
              account.currency,
              baseCurrency,
              currentDate,
            );
    }
  }
  return result;
});

/// Asset stats with totalInvested converted to base currency.
///
/// Same semantic as [AssetStats.totalInvested] — moving-average cost basis
/// of currently-held shares — but computed in the user's base currency. Each
/// buy is converted from the currency it was recorded in at its own
/// historical FX rate (so a position bought when EUR/USD was very different
/// from today keeps the contemporaneous cost), then run through the same
/// moving-average-cost pool as [AssetService._computeAssetStats]
/// ([CostBasisPool]): a sell removes quantity at the pool's current average,
/// and a full liquidation resets the pool so a later re-buy starts fresh
/// instead of blending in a disposed lot's price. Null when a buy cannot be
/// converted: the cost basis — and any gain against it — is unknown.
final convertedAssetStatsProvider = FutureProvider<Map<int, double?>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final eventService = ref.watch(assetEventServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);
  final waybackDate = ref.watch(waybackDateProvider);

  final result = <int, double?>{};

  // Every asset goes through the per-buy conversion, a base-currency one too:
  // its stats add up each buy's amount as recorded, and a buy recorded in
  // another currency is not in the base one. Inactive assets are excluded —
  // same convention as assetDailyChangesProvider and the dashboard chart
  // provider.
  final assetIds = <int>[];
  for (final asset in assets) {
    if (!asset.isActive) continue;
    final stat = stats[asset.id];
    if (stat == null || stat.totalInvested == 0) continue;
    assetIds.add(asset.id);
  }

  // Convert each buy at its own FX rate, then walk the events in
  // chronological order through a moving-average-cost pool.
  if (assetIds.isNotEmpty) {
    final allEvents = await eventService.getByAssets(assetIds, through: waybackDate);
    for (final asset in assets) {
      final events = allEvents[asset.id];
      if (events == null || events.isEmpty) continue;

      // getByAssets orders DESC by valueDate for display purposes; the
      // moving-average pool below requires ascending chronological order
      // (oldest first), with id as a same-day tiebreak.
      final ordered = events.toList()
        ..sort((a, b) {
          final byDate = a.valueDate.compareTo(b.valueDate);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });

      // Convert one event amount from event.currency → baseCurrency: the
      // rate stored on the event, else the latest rate on or before its
      // value date. Returns null when neither exists — the asset's total
      // cannot be trusted, mark unresolved. Never today's rate: a past cost
      // converted at the live rate is a wrong figure.
      Future<double?> convertToBase(double amount, AssetEvent ev) async {
        if (ev.currency == baseCurrency) return amount;
        // Only reuse a stored rate that was quoted against the CURRENT base
        // (see AssetEventService.isExchangeRateUsableFor) — a rate belonging
        // to a previous base is preserved data, not a usable conversion.
        if (AssetEventService.isExchangeRateUsableFor(ev, baseCurrency)) {
          return amount / ev.exchangeRate!;
        }
        final rate = await rateService.getRate(baseCurrency, ev.currency, ev.valueDate);
        if (rate != null && rate > 0) {
          // Only FILL a missing rate — never overwrite one that is already
          // stored. A stored rate is user- or broker-supplied data (and after
          // a base change, data quoted against the previous base); clobbering
          // it with a derived value would destroy it just as surely as
          // deleting it. Re-resolving is cheap: getRate is a local lookup in
          // the exchange_rates table, no network.
          if (waybackDate == null && ev.exchangeRate == null) {
            await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id))).write(
              AssetEventsCompanion(exchangeRate: Value(rate), exchangeRateBase: Value(baseCurrency)),
            );
          }
          return amount / rate;
        }
        _log.warning(
          'convertedAssetStats: asset ${ev.assetId} event ${ev.id} - no ${ev.currency}/$baseCurrency rate on or before its value date, '
          'cost basis unknown',
        );
        return null;
      }

      final pool = CostBasisPool();
      var unresolved = false;

      for (final ev in ordered) {
        if (ev.type != EventType.buy && ev.type != EventType.sell) continue;
        final qty = (ev.quantity ?? 0.0).abs();
        if (ev.type == EventType.buy) {
          final amtBase = await convertToBase(ev.amount.abs(), ev);
          if (amtBase == null) {
            unresolved = true;
            break;
          }
          pool.buy(amtBase, qty);
        } else {
          pool.sell(qty);
        }
      }

      if (unresolved) {
        result[asset.id] = null;
        continue;
      }

      // Same composition as AssetService._computeAssetStats: the per-share
      // pool (zeroed once every share is sold) plus cash-only contributions,
      // which share sales don't affect.
      result[asset.id] = pool.costBasis(heldQuantity: stats[asset.id]?.totalQuantity ?? 0.0);
    }
  }
  return result;
});

/// Market value per asset: qty * lastPrice * fxRate -> base currency.
final assetMarketValuesProvider = FutureProvider<Map<int, double>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final priceService = ref.watch(marketPriceServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  ref.watch(priceRefreshCounter); // rebuild after price sync
  final waybackDate = ref.watch(waybackDateProvider);
  final today = ref.watch(currentDateProvider);

  final result = <int, double>{};
  _log.info('assetMarketValues: ${assets.length} assets, ${stats.length} stats, base=$baseCurrency');
  for (final asset in assets) {
    // Inactive assets are excluded — same convention as
    // assetDailyChangesProvider and the dashboard chart provider.
    if (!asset.isActive) continue;
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) continue;
    // Use stored DB price (background sync keeps it fresh)
    final price = await priceService.getPrice(asset.id, today);
    if (price == null) {
      _log.warning('assetMarketValues: ${asset.ticker ?? asset.name} - no price');
      continue;
    }
    final double? fxRate;
    if (asset.currency == baseCurrency) {
      fxRate = 1.0;
    } else {
      fxRate = waybackDate == null
          ? await rateService.getLiveRate(asset.currency, baseCurrency)
          : await rateService.getRate(asset.currency, baseCurrency, today);
      if (fxRate == null) {
        _log.warning('assetMarketValues: ${asset.ticker ?? asset.name} - no ${asset.currency}/$baseCurrency rate, skipping');
        continue;
      }
    }
    final value = computeAssetBaseValue(
      quantity: stat.totalQuantity,
      price: price,
      bondDivisor: bondPriceDivisor(asset.instrumentType),
      fxRate: fxRate,
    );
    if (value != null) result[asset.id] = value;
  }
  _log.info('assetMarketValues: ${result.length} assets with values');
  return result;
});

final pillarAllocationDataProvider = FutureProvider.family<PillarAllocationData, String>((ref, pillarId) async {
  final assets = await ref.watch(activeAssetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final marketValues = await ref.watch(assetMarketValuesProvider.future);
  final fractions = await ref.watch(pillarFractionProvider(pillarId).future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);

  final scopedAssets = <Asset>[];
  final scopedMarketValues = <int, double>{};
  final inPillar = [
    for (final asset in assets)
      if ((fractions[asset.id] ?? 0) > 0) asset,
  ];

  for (final asset in inPillar) {
    final fullValue = marketValues[asset.id];
    if (fullValue == null) continue;
    scopedAssets.add(asset);
    scopedMarketValues[asset.id] = fullValue * fractions[asset.id]!;
  }

  return PillarAllocationData(
    assets: scopedAssets,
    marketValues: scopedMarketValues,
    baseCurrency: baseCurrency,
    // Held but without a market value (no price, or no rate to base): left
    // out and counted, never shown as worth 0. An asset not held on the
    // viewed date has no value to miss.
    unvaluedAssetCount: unvaluedAssetCount(
      inPillar,
      marketValues,
      heldIds: {
        for (final e in stats.entries)
          if (e.value.totalQuantity != 0) e.key,
      },
    ),
  );
});

final pillarPerformanceSnapshotsProvider = FutureProvider<Map<String, PillarPerformanceSnapshot>>((ref) async {
  ref.watch(pillarAssetsProvider);
  final currentDate = ref.watch(currentDateProvider);
  final allData = await ref.watch(allSeriesDataProvider.future);
  final pillars = await ref.watch(pillarsProvider.future);
  if (allData == null || pillars.isEmpty) return const {};

  final pillarService = ref.read(pillarServiceProvider);
  final pairs = await Future.wait(
    pillars.map((pillar) async {
      final fractions = await pillarService.fractionsForPillar(pillar.id);
      return MapEntry(
        pillar.id,
        computePillarPerformanceSnapshot(
          asOfDate: currentDate,
          allData: allData,
          fractions: fractions,
        ),
      );
    }),
  );
  return {for (final pair in pairs) pair.key: pair.value};
});

final pillarPerformanceProvider = FutureProvider.family<PillarPerformanceSnapshot, String>((ref, pillarId) async {
  final currentDate = ref.watch(currentDateProvider);
  final snapshots = await ref.watch(pillarPerformanceSnapshotsProvider.future);
  return snapshots[pillarId] ?? PillarPerformanceSnapshot.empty(currentDate);
});

/// IDs of active, marketPrice-valued assets that have no rows in
/// `market_prices`. The asset's displayed value falls back to the buy or
/// revalue price; the UI uses this set to flag the value as not market-sourced.
final assetsWithoutMarketPriceProvider = FutureProvider<Set<int>>((ref) async {
  final db = ref.watch(databaseProvider);
  ref.watch(priceRefreshCounter); // refresh after each sync attempt
  final rows = await db
      .customSelect(
        "SELECT a.id FROM assets a "
        "WHERE a.is_active = 1 "
        "AND a.valuation_method = 'marketPrice' "
        "AND NOT EXISTS (SELECT 1 FROM market_prices mp WHERE mp.asset_id = a.id)",
      )
      .get();
  return rows.map((r) => r.read<int>('id')).toSet();
});

/// Price change per asset over a lookback period.
class AssetDailyChange {
  final String name;
  final String? ticker;
  final String currency;
  final double todayPrice;
  final double previousPrice;
  final double quantity;
  final double todayFxRate; // asset currency -> base currency (today)
  // asset currency -> base currency (reference date); for a reference before
  // the first buy, the rate the position was bought at (cost-weighted).
  final double previousFxRate;
  final String baseCurrency;
  final String? providerUrl; // the market data provider page URL
  final double priceDivisor; // 100 for bonds (quoted per 100 nominal), 1 otherwise
  final bool marketOpen; // true if today's date has a stored price

  /// How the asset is valued. A manually valued asset has no market price:
  /// its "price" is the user's own revaluation per unit held.
  final ValuationMethod valuationMethod;

  const AssetDailyChange({
    required this.name,
    this.ticker,
    required this.currency,
    required this.todayPrice,
    required this.previousPrice,
    required this.quantity,
    required this.todayFxRate,
    required this.previousFxRate,
    required this.baseCurrency,
    this.providerUrl,
    this.priceDivisor = 1.0,
    this.marketOpen = false,
    this.valuationMethod = ValuationMethod.marketPrice,
  });

  double get priceDiff => todayPrice - previousPrice;
  double get pricePct => previousPrice != 0 ? (priceDiff / previousPrice) * 100 : 0;

  /// Value change in base currency, captures both price AND FX movements.
  double get valueDiff => (todayPrice * quantity / priceDivisor * todayFxRate) - (previousPrice * quantity / priceDivisor * previousFxRate);
}

/// Compare latest price vs price on or before [referenceDate].
/// For "1d", pass yesterday; for "1y", pass one year ago, etc.
/// If the reference date falls on a non-trading day, the closest prior
/// trading day's price is used automatically (via getPrice).
final assetDailyChangesProvider = FutureProvider.family<List<AssetDailyChange>, DateTime>((ref, referenceDate) async {
  ref.watch(priceRefreshCounter); // rebuild after price sync
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final priceService = ref.watch(marketPriceServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final waybackDate = ref.watch(waybackDateProvider);
  // What each position cost in base currency, every buy at its own rate: the
  // reference of a foreign asset bought after [referenceDate]. Late: watched
  // only once such an asset needs it, so no other figure waits for — or fails
  // with — that walk over every asset's events.
  late final costInBase = ref.watch(convertedAssetStatsProvider.future);

  final today = ref.watch(currentDateProvider);

  final result = <AssetDailyChange>[];
  for (final asset in assets) {
    if (!asset.isActive) continue;
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) continue;

    // Use stored DB price (background sync keeps it fresh)
    final latestPrice = await priceService.getPrice(asset.id, today);
    if (latestPrice == null) {
      _log.warning('dailyChanges: ${asset.ticker ?? asset.name} - no price at all');
      continue;
    }

    double todayFx = 1.0;
    double prevFx = 1.0;
    final isForeign = asset.currency != baseCurrency;
    double? referenceFx; // previous-day rate; null until resolved
    if (isForeign) {
      final currentFx = waybackDate == null
          ? await rateService.getLiveRate(asset.currency, baseCurrency)
          : await rateService.getRate(asset.currency, baseCurrency, today);
      if (currentFx == null) {
        // No live FX -> we cannot value this asset in base currency. Drop it
        // from the change list rather than silently report a 1:1 conversion,
        // which would inflate the visible price-change for foreign assets.
        _log.warning('dailyChanges: ${asset.ticker ?? asset.name} - no ${asset.currency}/$baseCurrency rate, skipping');
        continue;
      }
      todayFx = currentFx;
      referenceFx = await rateService.getRateNearest(asset.currency, baseCurrency, referenceDate);
    }

    // If reference date is before first buy, use weighted average buy price
    double? previousPrice;
    final beforeFirstBuy = stat.firstDate != null && referenceDate.isBefore(stat.firstDate!);
    if (beforeFirstBuy) {
      final avgPrice = await ref.read(assetEventServiceProvider).getAverageBuyPrice(asset.id, through: waybackDate);
      if (avgPrice != null) {
        previousPrice = avgPrice;
        if (isForeign) {
          // At the rates the buys were made at, weighted by what each cost —
          // the cost in base over the cost in the asset's currency — so the
          // change carries the currency gain or loss since purchase, like the
          // gain on the Assets screen. Today's rate on both sides dropped it.
          final cost = (await costInBase)[asset.id];
          if (cost == null || stat.totalInvested <= 0) {
            _log.warning('dailyChanges: ${asset.ticker ?? asset.name} - a buy has no ${asset.currency}/$baseCurrency rate, skipping');
            continue;
          }
          prevFx = cost / stat.totalInvested;
        }
      }
    } else {
      previousPrice = await priceService.getPrice(asset.id, referenceDate);
      if (isForeign) {
        if (referenceFx == null) {
          // No FX rate at all for this pair (not even after the reference date)
          // -> we cannot value the asset honestly. Skip rather than fabricate.
          _log.warning(
            'dailyChanges: ${asset.ticker ?? asset.name} - no ${asset.currency}/$baseCurrency rate available, skipping',
          );
          continue;
        }
        // referenceFx is the closest real rate on or before the reference date,
        // or the nearest one after it when the reference predates all history.
        prevFx = referenceFx;
      }
    }
    if (previousPrice == null) continue;

    final providerUrl = priceService is WebMarketDataService ? await priceService.providerPageUrl(asset) : null;

    // Market is open if live price was fetched within the last 15 minutes
    final isMarketOpen = waybackDate == null && priceService is WebMarketDataService && priceService.isMarketOpen(asset.id);

    result.add(
      AssetDailyChange(
        name: asset.name,
        ticker: asset.ticker,
        currency: asset.currency,
        todayPrice: latestPrice,
        previousPrice: previousPrice,
        quantity: stat.totalQuantity,
        todayFxRate: todayFx,
        previousFxRate: prevFx,
        baseCurrency: baseCurrency,
        providerUrl: providerUrl,
        priceDivisor: bondPriceDivisor(asset.instrumentType),
        marketOpen: isMarketOpen,
        valuationMethod: asset.valuationMethod,
      ),
    );
  }
  return result;
});

/// Converted event amounts for an asset, in base currency at the event's own
/// rate: the stored exchangeRate (BASE/ASSET format) if usable, otherwise the
/// latest rate on or before the event's value date. An event with neither is
/// left out (never converted at today's rate) — the UI gates on containsKey,
/// so its converted line is simply hidden. Released with the screen showing
/// the asset, and with it the asset's event stream.
final convertedEventAmountsProvider = FutureProvider.autoDispose.family<Map<int, double>, int>((ref, assetId) async {
  final events = await ref.watch(assetEventsProvider(assetId).future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);
  final waybackDate = ref.watch(waybackDateProvider);

  final result = <int, double>{};
  for (final ev in events) {
    if (ev.currency == baseCurrency) {
      result[ev.id] = ev.amount;
    } else if (AssetEventService.isExchangeRateUsableFor(ev, baseCurrency)) {
      // Stored rate is BASE/ASSET, so divide to get base currency amount.
      // Only a rate quoted against the current base is usable — one stamped
      // with a previous base is preserved data, not a conversion factor.
      result[ev.id] = ev.amount / ev.exchangeRate!;
    } else {
      final rate = await rateService.getRate(baseCurrency, ev.currency, ev.valueDate);
      if (rate != null && rate > 0) {
        result[ev.id] = ev.amount / rate;
        // Fill only — never overwrite a stored (user/broker-supplied, or
        // previous-base) rate with a derived one. See convertToBase above.
        if (waybackDate == null && ev.exchangeRate == null) {
          await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id))).write(
            AssetEventsCompanion(exchangeRate: Value(rate), exchangeRateBase: Value(baseCurrency)),
          );
        }
      } else {
        _log.warning(
          'convertedEventAmounts: asset $assetId event ${ev.id} - no ${ev.currency}/$baseCurrency rate on or before its value date, '
          'no converted amount',
        );
      }
    }
  }
  return result;
});
