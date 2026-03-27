import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/database.dart';
import '../database/providers.dart';
import '../l10n/app_strings.dart';
import 'account_service.dart';
import 'asset_event_service.dart';
import 'asset_service.dart';
import 'buffer_service.dart';
import 'capex_service.dart';
import 'dashboard_chart_service.dart';
import 'income_adjustment_service.dart';
import 'income_service.dart';
import 'exchange_rate_service.dart';
import 'import_config_service.dart';
import 'composition_service.dart';
import 'investing_com_service.dart';
import 'network_monitor.dart';
import 'import_service.dart';
import 'isin_lookup_service.dart';
import 'market_price_service.dart';
import 'transaction_service.dart';
import '../utils/logger.dart';

final _log = getLogger('Providers');

// ── Network ──

final networkMonitorProvider = Provider<NetworkMonitor>((ref) => NetworkMonitor());

/// Whether network is currently available. Polled reactively.
final networkOnlineProvider = StateProvider<bool>((ref) => true);

// ── Service providers ──

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref.watch(databaseProvider));
});

final assetServiceProvider = Provider<AssetService>((ref) {
  return AssetService(ref.watch(databaseProvider));
});

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.watch(databaseProvider));
});

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref.watch(databaseProvider));
});

final assetEventServiceProvider = Provider<AssetEventService>((ref) {
  return AssetEventService(ref.watch(databaseProvider));
});

final importConfigServiceProvider = Provider<ImportConfigService>((ref) {
  return ImportConfigService(ref.watch(databaseProvider));
});

final isinLookupServiceProvider = Provider<IsinLookupService>((ref) {
  final priceService = ref.watch(marketPriceServiceProvider);
  return IsinLookupService(priceService as InvestingComService);
});

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final priceService = ref.watch(marketPriceServiceProvider);
  final investing = priceService is InvestingComService ? priceService : null;
  return ExchangeRateService(ref.watch(databaseProvider), investingService: investing);
});

final marketPriceServiceProvider = Provider<MarketPriceService>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestingComService(db);
});

final compositionServiceProvider = Provider<CompositionService>((ref) {
  return CompositionService(ref.watch(databaseProvider));
});

/// Bumped after market price sync to trigger chart rebuilds.
final priceRefreshCounter = StateProvider<int>((ref) => 0);

/// Privacy mode: blur all monetary amounts for screenshot sharing.
final privacyModeProvider = StateProvider<bool>((ref) => false);

// ── Reactive stream providers ──

/// UI language from AppConfigs, reactive. 'en' (default) or 'it'.
final appLanguageProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('LANGUAGE')))
      .watchSingleOrNull()
      .map((row) => row?.value ?? 'en');
});

/// Provides the current [AppStrings] instance derived from [appLanguageProvider].
final appStringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(appLanguageProvider).value ?? 'en';
  return AppStrings.of(lang);
});

/// Display locale from AppConfigs, reactive. Empty string = system default.
final appLocaleProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('LOCALE')))
      .watchSingleOrNull()
      .map((row) {
    final value = row?.value ?? '';
    return value.isEmpty ? Platform.localeName : value;
  });
});

/// Base currency from AppConfigs, reactive. Defaults to EUR.
final baseCurrencyProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('BASE_CURRENCY')))
      .watchSingleOrNull()
      .map((row) => row?.value ?? 'EUR');
});


final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountServiceProvider).watchAll();
});

final accountStatsProvider = StreamProvider<Map<int, AccountStats>>((ref) {
  return ref.watch(accountServiceProvider).watchStatsForAll();
});

final assetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetServiceProvider).watchAll();
});

/// Asset composition breakdowns (country/sector/holding weights from justETF).
final assetCompositionsProvider = StreamProvider<Map<int, List<AssetComposition>>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.assetCompositions)).watch().map((rows) {
    final map = <int, List<AssetComposition>>{};
    for (final row in rows) {
      map.putIfAbsent(row.assetId, () => []).add(row);
    }
    return map;
  });
});

final assetStatsProvider = StreamProvider<Map<int, AssetStats>>((ref) {
  return ref.watch(assetServiceProvider).watchStatsForAll();
});

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
        total += await rateService.convertLive(ev.amount, ev.currency, baseCurrency);
      }
    }
    result[asset.id] = total;
  }
  return result;
});

/// Market value per asset: qty * lastPrice * fxRate → base currency.
final assetMarketValuesProvider = FutureProvider<Map<int, double>>((ref) async {
  final assets = await ref.watch(assetsProvider.future);
  final stats = await ref.watch(assetStatsProvider.future);
  final baseCurrency = await ref.watch(baseCurrencyProvider.future);
  final priceService = ref.watch(marketPriceServiceProvider);
  final rateService = ref.watch(exchangeRateServiceProvider);

  final result = <int, double>{};
  final now = DateTime.now();
  _log.info('assetMarketValues: ${assets.length} assets, ${stats.length} stats, base=$baseCurrency');
  for (final asset in assets) {
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) {
      _log.fine('assetMarketValues: ${asset.ticker ?? asset.name} — no stat or qty=0');
      continue;
    }
    // Use live price for current market values
    double? price;
    if (priceService is InvestingComService) {
      price = await priceService.getLivePrice(asset.id);
    }
    price ??= await priceService.getPrice(asset.id, now);
    if (price == null) {
      _log.warning('assetMarketValues: ${asset.ticker ?? asset.name} — no price');
      continue;
    }
    double fxRate = 1.0;
    if (asset.currency != baseCurrency) {
      fxRate = await rateService.getLiveRate(asset.currency, baseCurrency) ?? 1.0;
    }
    final value = stat.totalQuantity * price * fxRate;
    _log.fine('assetMarketValues: ${asset.ticker ?? asset.name} — qty=${stat.totalQuantity} price=$price fx=$fxRate → $value');
    result[asset.id] = value;
  }
  _log.info('assetMarketValues: ${result.length} assets with values, total=${result.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}');
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
  final double todayFxRate;    // asset currency → base currency (today)
  final double previousFxRate; // asset currency → base currency (reference date)
  final String baseCurrency;
  final String? investingUrl;   // Investing.com page URL

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
  });

  double get priceDiff => todayPrice - previousPrice;
  double get pricePct => previousPrice != 0 ? (priceDiff / previousPrice) * 100 : 0;
  /// Value change in base currency, captures both price AND FX movements.
  double get valueDiff =>
      (todayPrice * quantity * todayFxRate) - (previousPrice * quantity * previousFxRate);
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
      _log.fine('dailyChanges: ${asset.ticker ?? asset.name} — livePrice=$latestPrice');
    }
    latestPrice ??= await priceService.getPrice(asset.id, today);
    if (latestPrice == null) {
      _log.warning('dailyChanges: ${asset.ticker ?? asset.name} — no price at all');
      continue;
    }

    double todayFx = 1.0;
    double prevFx = 1.0;
    if (asset.currency != baseCurrency) {
      todayFx = await rateService.getLiveRate(asset.currency, baseCurrency) ?? 1.0;
      prevFx = await rateService.getRate(asset.currency, baseCurrency, referenceDate) ?? todayFx;
    }

    // If reference date is before first buy, use weighted average buy price
    double? previousPrice;
    final beforeFirstBuy = stat.firstDate != null && referenceDate.isBefore(stat.firstDate!);
    if (beforeFirstBuy) {
      final avgRow = await priceService.db.customSelect(
        "SELECT SUM(ABS(COALESCE(quantity,0)) * COALESCE(price,0)) AS total_cost, "
        "SUM(ABS(COALESCE(quantity,0))) AS total_qty "
        "FROM asset_events WHERE asset_id = ? AND type IN ('buy','contribute') AND quantity IS NOT NULL AND price IS NOT NULL",
        variables: [Variable.withInt(asset.id)],
      ).getSingleOrNull();
      final totalCost = avgRow?.readNullable<double>('total_cost') ?? 0;
      final totalQty = avgRow?.readNullable<double>('total_qty') ?? 0;
      if (totalQty > 0) {
        previousPrice = totalCost / totalQty;
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

  final result = <int, double>{};
  for (final ev in events) {
    if (ev.currency == baseCurrency) {
      result[ev.id] = ev.amount;
    } else if (ev.exchangeRate != null && ev.exchangeRate! > 0) {
      // Stored rate is BASE/ASSET, so divide to get base currency amount
      result[ev.id] = ev.amount / ev.exchangeRate!;
    } else {
      result[ev.id] = await rateService.convertLive(ev.amount, ev.currency, baseCurrency);
    }
  }
  return result;
});

/// Transactions for a specific account (pass accountId as family parameter).
final accountTransactionsProvider = StreamProvider.family<List<Transaction>, int>((ref, accountId) {
  return ref.watch(transactionServiceProvider).watchByAccount(accountId);
});

/// Asset events for a specific asset (pass assetId as family parameter).
final assetEventsProvider = StreamProvider.family<List<AssetEvent>, int>((ref, assetId) {
  return ref.watch(assetEventServiceProvider).watchByAsset(assetId);
});

// ── CAPEX / Buffer providers ──

// ── Dashboard chart providers ──

final dashboardChartServiceProvider = Provider<DashboardChartService>((ref) {
  return DashboardChartService(ref.watch(databaseProvider));
});

final dashboardChartsProvider = StreamProvider<List<DashboardChart>>((ref) {
  return ref.watch(dashboardChartServiceProvider).watchAll();
});

// ── CAPEX / Buffer providers ──

final capexServiceProvider = Provider<CapexService>((ref) {
  return CapexService(ref.watch(databaseProvider));
});

final bufferServiceProvider = Provider<BufferService>((ref) {
  return BufferService(ref.watch(databaseProvider));
});

final capexSchedulesProvider = StreamProvider<List<DepreciationSchedule>>((ref) {
  return ref.watch(capexServiceProvider).watchAll();
});

final capexStatsProvider = StreamProvider<Map<int, CapexStats>>((ref) {
  return ref.watch(capexServiceProvider).watchStatsForAll();
});

final capexScheduleProvider = StreamProvider.family<DepreciationSchedule, int>((ref, scheduleId) {
  return ref.watch(capexServiceProvider).watchById(scheduleId);
});

final capexEntriesProvider = StreamProvider.family<List<DepreciationEntry>, int>((ref, scheduleId) {
  return ref.watch(capexServiceProvider).watchEntries(scheduleId);
});

final bufferTransactionsProvider = StreamProvider.family<List<BufferTransaction>, int>((ref, bufferId) {
  return ref.watch(bufferServiceProvider).watchByBuffer(bufferId);
});

// ── Income adjustment providers ──

final incomeAdjustmentServiceProvider = Provider<IncomeAdjustmentService>((ref) {
  return IncomeAdjustmentService(ref.watch(databaseProvider));
});

final incomeAdjustmentsProvider = StreamProvider<List<IncomeAdjustment>>((ref) {
  return ref.watch(incomeAdjustmentServiceProvider).watchAll();
});

final incomeAdjustmentProvider = StreamProvider.family<IncomeAdjustment, int>((ref, id) {
  return ref.watch(incomeAdjustmentServiceProvider).watchById(id);
});

final incomeAdjustmentExpensesProvider = StreamProvider.family<List<IncomeAdjustmentExpense>, int>((ref, adjustmentId) {
  return ref.watch(incomeAdjustmentServiceProvider).watchExpenses(adjustmentId);
});

// ── Income providers ──

final incomeServiceProvider = Provider<IncomeService>((ref) {
  return IncomeService(ref.watch(databaseProvider));
});

final incomesProvider = StreamProvider<List<Income>>((ref) {
  return ref.watch(incomeServiceProvider).watchAll();
});
