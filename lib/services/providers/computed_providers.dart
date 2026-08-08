part of 'providers.dart';

// ── Derived / computed data providers ──

class PillarAllocationData {
  final List<Asset> assets;
  final Map<int, double> marketValues;
  final String baseCurrency;

  const PillarAllocationData({
    required this.assets,
    required this.marketValues,
    required this.baseCurrency,
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
/// Same semantic as [AssetStats.totalInvested] — weighted-average cost basis
/// of currently-held shares — but computed in the user's base currency. For
/// foreign-currency assets each buy is converted at its own historical FX
/// rate (so a position bought when EUR/USD was very different from today
/// keeps the contemporaneous cost), then the weighted-avg base-currency
/// cost is multiplied by the remaining quantity.
final convertedAssetStatsProvider = FutureProvider<Map<int, double?>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final eventService = ref.watch(assetEventServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);
  final waybackDate = ref.watch(waybackDateProvider);

  final result = <int, double?>{};

  // Same-currency assets: use pre-aggregated stats directly.
  // Inactive assets are excluded — same convention as
  // assetDailyChangesProvider and the dashboard chart provider.
  final foreignAssetIds = <int>[];
  for (final asset in assets) {
    if (!asset.isActive) continue;
    final stat = stats[asset.id];
    if (stat == null || stat.totalInvested == 0) continue;
    if (asset.currency == baseCurrency) {
      result[asset.id] = stat.totalInvested;
    } else {
      foreignAssetIds.add(asset.id);
    }
  }

  // Foreign-currency assets: convert each buy at its own FX rate, then
  // apply the weighted-avg × remaining-qty formula in base currency.
  if (foreignAssetIds.isNotEmpty) {
    final allEvents = await eventService.getByAssets(foreignAssetIds, through: waybackDate);
    for (final asset in assets) {
      final events = allEvents[asset.id];
      if (events == null || events.isEmpty) continue;

      var buyAmountBase = 0.0;
      var buyQty = 0.0;
      var unresolved = false;

      // Convert one event amount from event.currency → baseCurrency, using
      // the same fallback ladder as before (stored rate → historical rate →
      // live rate). Returns null when no rate is available — the asset's
      // total cannot be trusted, mark unresolved.
      Future<double?> convertToBase(double amount, AssetEvent ev) async {
        if (ev.currency == baseCurrency) return amount;
        if (ev.exchangeRate != null && ev.exchangeRate! > 0) {
          return amount / ev.exchangeRate!;
        }
        final rate = await rateService.getRate(baseCurrency, ev.currency, ev.valueDate);
        if (rate != null && rate > 0) {
          if (waybackDate == null) {
            await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id))).write(AssetEventsCompanion(exchangeRate: Value(rate)));
          }
          return amount / rate;
        }
        if (waybackDate != null) return null;
        return rateService.convertLive(amount, ev.currency, baseCurrency);
      }

      for (final ev in events) {
        if (ev.type != EventType.buy) continue;
        final amtBase = await convertToBase(ev.amount.abs(), ev);
        if (amtBase == null) {
          unresolved = true;
          break;
        }
        buyAmountBase += amtBase;
        buyQty += (ev.quantity ?? 0).abs();
      }

      if (unresolved) {
        result[asset.id] = null;
        continue;
      }

      final remainingQty = stats[asset.id]?.totalQuantity ?? 0;
      double invested;
      if (buyQty <= 0) {
        // Cash-only events (no per-share qty) — gross fallback in base.
        invested = buyAmountBase;
      } else if (remainingQty <= 0) {
        invested = 0;
      } else {
        invested = (buyAmountBase / buyQty) * remainingQty;
      }
      result[asset.id] = invested;
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
    final bondDiv = asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;
    final value = computeAssetBaseValue(
      quantity: stat.totalQuantity,
      price: price,
      bondDivisor: bondDiv,
      fxRate: fxRate,
    );
    if (value != null) result[asset.id] = value;
  }
  _log.info('assetMarketValues: ${result.length} assets with values');
  return result;
});

final pillarAllocationDataProvider = FutureProvider.family<PillarAllocationData, String>((ref, pillarId) async {
  final assets = await ref.watch(activeAssetsProvider.future);
  final marketValues = await ref.watch(assetMarketValuesProvider.future);
  final fractions = await ref.watch(pillarFractionProvider(pillarId).future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);

  final scopedAssets = <Asset>[];
  final scopedMarketValues = <int, double>{};

  for (final asset in assets) {
    final fraction = fractions[asset.id];
    if (fraction == null || fraction <= 0) continue;
    final fullValue = marketValues[asset.id] ?? 0.0;
    scopedAssets.add(asset);
    scopedMarketValues[asset.id] = fullValue * fraction;
  }

  return PillarAllocationData(
    assets: scopedAssets,
    marketValues: scopedMarketValues,
    baseCurrency: baseCurrency,
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
  final double previousFxRate; // asset currency -> base currency (reference date)
  final String baseCurrency;
  final String? providerUrl; // the market data provider page URL
  final double priceDivisor; // 100 for bonds (quoted per 100 nominal), 1 otherwise
  final bool marketOpen; // true if today's date has a stored price

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
        // For cost-basis, use today's FX for both sides (we're comparing price, not FX)
        prevFx = todayFx;
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

    // Look up cached the market data provider URL for the link (same key logic as _searchCid)
    String? providerUrl;
    final searchTerm = (asset.isin?.isNotEmpty == true) ? asset.isin! : asset.ticker;
    if (searchTerm != null && searchTerm.isNotEmpty) {
      final urlKey = 'PROVIDER_URL_${searchTerm}_${asset.exchange ?? 'Milan'}';
      final urlRow = await priceService.db
          .customSelect(
            'SELECT value FROM app_configs WHERE key = ?',
            variables: [Variable.withString(urlKey)],
          )
          .getSingleOrNull();
      if (urlRow != null) {
        final path = urlRow.read<String>('value');
        providerUrl = path.startsWith('http') ? path : '$kProviderBase$path';
      }
    }

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
        priceDivisor: asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0,
        marketOpen: isMarketOpen,
      ),
    );
  }
  return result;
});

/// Converted event amounts for an asset (live rate for current value display).
/// Uses stored exchangeRate (BASE/ASSET format) if available, otherwise live rate.
final convertedEventAmountsProvider = FutureProvider.family<Map<int, double>, int>((ref, assetId) async {
  final events = await ref.watch(assetEventsProvider(assetId).future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);
  final waybackDate = ref.watch(waybackDateProvider);

  final result = <int, double>{};
  for (final ev in events) {
    if (ev.currency == baseCurrency) {
      result[ev.id] = ev.amount;
    } else if (ev.exchangeRate != null && ev.exchangeRate! > 0) {
      // Stored rate is BASE/ASSET, so divide to get base currency amount
      result[ev.id] = ev.amount / ev.exchangeRate!;
    } else {
      final rate = await rateService.getRate(baseCurrency, ev.currency, ev.valueDate);
      if (rate != null && rate > 0) {
        result[ev.id] = ev.amount / rate;
        if (waybackDate == null) {
          await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id))).write(AssetEventsCompanion(exchangeRate: Value(rate)));
        }
      } else {
        // Live fallback. Skip the event if no rate is available — the UI
        // gates on containsKey, so the converted line is simply hidden.
        if (waybackDate == null) {
          final live = await rateService.convertLive(ev.amount, ev.currency, baseCurrency);
          if (live != null) result[ev.id] = live;
        }
      }
    }
  }
  return result;
});
