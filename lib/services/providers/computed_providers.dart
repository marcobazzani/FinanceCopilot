part of 'providers.dart';

// ── Derived / computed data providers ──

/// Account stats with balances converted to base currency using live rates.
final convertedAccountStatsProvider = FutureProvider<Map<int, double?>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final stats = await ref.watch(accountStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final rateService = ref.watch(exchangeRateServiceProvider);

  final result = <int, double?>{};
  for (final account in accounts) {
    final stat = stats[account.id];
    if (stat == null || stat.balance == null) continue;
    if (account.currency == baseCurrency) {
      result[account.id] = stat.balance;
    } else {
      result[account.id] = await rateService.convertLive(
        stat.balance!, account.currency, baseCurrency,
      );
    }
  }
  return result;
});

/// Asset stats with totalInvested converted to base currency.
/// Sums per-event conversions using each event's stored rate for accuracy.
final convertedAssetStatsProvider = FutureProvider<Map<int, double?>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final eventService = ref.watch(assetEventServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);
  final db = ref.watch(databaseProvider);

  final result = <int, double?>{};
  for (final asset in assets) {
    final stat = stats[asset.id];
    if (stat == null || stat.totalInvested == 0) continue;
    if (asset.currency == baseCurrency) {
      result[asset.id] = stat.totalInvested;
      continue;
    }
    // Sum each event's base-currency equivalent using its own stored rate
    final events = await eventService.getByAsset(asset.id);
    var total = 0.0;
    for (final ev in events) {
      if (ev.currency == baseCurrency) {
        total += ev.amount;
      } else if (ev.exchangeRate != null && ev.exchangeRate! > 0) {
        total += ev.amount / ev.exchangeRate!;
      } else {
        final rate = await rateService.getRate(baseCurrency, ev.currency, ev.date);
        if (rate != null && rate > 0) {
          total += ev.amount / rate;
          // Persist so we don't re-fetch next time
          await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id)))
              .write(AssetEventsCompanion(exchangeRate: Value(rate)));
        } else {
          total += await rateService.convertLive(ev.amount, ev.currency, baseCurrency);
        }
      }
    }
    result[asset.id] = total;
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

  final result = <int, double>{};
  final now = DateTime.now();
  _log.info('assetMarketValues: ${assets.length} assets, ${stats.length} stats, base=$baseCurrency');
  for (final asset in assets) {
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) {
      _log.fine('assetMarketValues: ${asset.ticker ?? asset.name} - no stat or qty=0');
      continue;
    }
    // Use live price for current market values
    double? price;
    if (priceService is InvestingComService) {
      price = await priceService.getLivePrice(asset.id);
    }
    price ??= await priceService.getPrice(asset.id, now);
    if (price == null) {
      _log.warning('assetMarketValues: ${asset.ticker ?? asset.name} - no price');
      continue;
    }
    double fxRate = 1.0;
    if (asset.currency != baseCurrency) {
      final rate = await rateService.getLiveRate(asset.currency, baseCurrency);
      if (rate != null) {
        fxRate = rate;
      } else {
        _log.warning('assetMarketValues: ${asset.ticker ?? asset.name} - no ${asset.currency}/$baseCurrency rate, using 1.0 (INACCURATE)');
      }
    }
    final bondDiv = asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;
    final value = stat.totalQuantity * price / bondDiv * fxRate;
    _log.fine('assetMarketValues: ${asset.ticker ?? asset.name} - price=$price fx=$fxRate bondDiv=$bondDiv');
    result[asset.id] = value;
  }
  _log.info('assetMarketValues: ${result.length} assets with values');
  return result;
});

/// Price change per asset over a lookback period.
class AssetDailyChange {
  final String name;
  final String? ticker;
  final String currency;
  final double todayPrice;
  final double previousPrice;
  final double quantity;
  final double todayFxRate;    // asset currency -> base currency (today)
  final double previousFxRate; // asset currency -> base currency (reference date)
  final String baseCurrency;
  final String? investingUrl;   // Investing.com page URL
  final double priceDivisor;   // 100 for bonds (quoted per 100 nominal), 1 otherwise

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
    this.investingUrl,
    this.priceDivisor = 1.0,
  });

  double get priceDiff => todayPrice - previousPrice;
  double get pricePct => previousPrice != 0 ? (priceDiff / previousPrice) * 100 : 0;
  /// Value change in base currency, captures both price AND FX movements.
  double get valueDiff =>
      (todayPrice * quantity / priceDivisor * todayFxRate) - (previousPrice * quantity / priceDivisor * previousFxRate);
}

/// Compare latest price vs price on or before [referenceDate].
/// For "1d", pass yesterday; for "1y", pass one year ago, etc.
/// If the reference date falls on a non-trading day, the closest prior
/// trading day's price is used automatically (via getPrice).
final assetDailyChangesProvider = FutureProvider.family<List<AssetDailyChange>, DateTime>((ref, referenceDate) async {
  ref.watch(priceRefreshCounter); // rebuild after price sync
  ref.watch(assetsProvider);     // explicit reactive dependency (Riverpod 3.x)
  ref.watch(assetStatsProvider); // explicit reactive dependency (Riverpod 3.x)
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final priceService = ref.watch(marketPriceServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final result = <AssetDailyChange>[];
  for (final asset in assets) {
    if (!asset.isActive) continue;
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) continue;

    // Use live price (not stored in DB) for today's value
    double? latestPrice;
    if (priceService is InvestingComService) {
      latestPrice = await priceService.getLivePrice(asset.id);
      _log.fine('dailyChanges: ${asset.ticker ?? asset.name} - livePrice=$latestPrice');
    }
    latestPrice ??= await priceService.getPrice(asset.id, today);
    if (latestPrice == null) {
      _log.warning('dailyChanges: ${asset.ticker ?? asset.name} - no price at all');
      continue;
    }

    double todayFx = 1.0;
    double prevFx = 1.0;
    if (asset.currency != baseCurrency) {
      final liveFx = await rateService.getLiveRate(asset.currency, baseCurrency);
      if (liveFx != null) {
        todayFx = liveFx;
      } else {
        _log.warning('dailyChanges: ${asset.ticker ?? asset.name} - no live ${asset.currency}/$baseCurrency rate, using 1.0 (INACCURATE)');
      }
      prevFx = await rateService.getRate(asset.currency, baseCurrency, referenceDate) ?? todayFx;
    }

    // If reference date is before first buy, use weighted average buy price
    double? previousPrice;
    final beforeFirstBuy = stat.firstDate != null && referenceDate.isBefore(stat.firstDate!);
    if (beforeFirstBuy) {
      final avgPrice = await ref.read(assetEventServiceProvider).getAverageBuyPrice(asset.id);
      if (avgPrice != null) {
        previousPrice = avgPrice;
        // For cost-basis, use today's FX for both sides (we're comparing price, not FX)
        prevFx = todayFx;
      }
    } else {
      previousPrice = await priceService.getPrice(asset.id, referenceDate);
    }
    if (previousPrice == null) continue;

    // Look up cached Investing.com URL for the link (same key logic as _searchCid)
    String? investingUrl;
    final searchTerm = (asset.ticker?.isNotEmpty == true) ? asset.ticker! : asset.isin;
    if (searchTerm != null && searchTerm.isNotEmpty) {
      final urlKey = 'INVESTING_URL_${searchTerm}_${asset.exchange ?? 'MIL'}';
      final urlRow = await priceService.db.customSelect(
        'SELECT value FROM app_configs WHERE key = ?',
        variables: [Variable.withString(urlKey)],
      ).getSingleOrNull();
      if (urlRow != null) {
        final path = urlRow.read<String>('value');
        investingUrl = path.startsWith('http') ? path : 'https://www.investing.com$path';
      }
    }

    result.add(AssetDailyChange(
      name: asset.name,
      ticker: asset.ticker,
      currency: asset.currency,
      todayPrice: latestPrice,
      previousPrice: previousPrice,
      quantity: stat.totalQuantity,
      todayFxRate: todayFx,
      previousFxRate: prevFx,
      baseCurrency: baseCurrency,
      investingUrl: investingUrl,
      priceDivisor: asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0,
    ));
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

  final result = <int, double>{};
  for (final ev in events) {
    if (ev.currency == baseCurrency) {
      result[ev.id] = ev.amount;
    } else if (ev.exchangeRate != null && ev.exchangeRate! > 0) {
      // Stored rate is BASE/ASSET, so divide to get base currency amount
      result[ev.id] = ev.amount / ev.exchangeRate!;
    } else {
      final rate = await rateService.getRate(baseCurrency, ev.currency, ev.date);
      if (rate != null && rate > 0) {
        result[ev.id] = ev.amount / rate;
        await (db.update(db.assetEvents)..where((e) => e.id.equals(ev.id)))
            .write(AssetEventsCompanion(exchangeRate: Value(rate)));
      } else {
        result[ev.id] = await rateService.convertLive(ev.amount, ev.currency, baseCurrency);
      }
    }
  }
  return result;
});
