import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/providers.dart';
import 'account_service.dart';
import 'asset_event_service.dart';
import 'asset_service.dart';
import 'buffer_service.dart';
import 'capex_service.dart';
import 'dashboard_chart_service.dart';
import 'income_adjustment_service.dart';
import 'exchange_rate_service.dart';
import 'import_config_service.dart';
import 'investing_com_service.dart';
import 'import_service.dart';
import 'isin_lookup_service.dart';
import 'market_price_service.dart';
import 'transaction_service.dart';

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
  return IsinLookupService();
});

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService(ref.watch(databaseProvider));
});

final marketPriceServiceProvider = Provider<MarketPriceService>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestingComService(db);
});

/// Bumped after market price sync to trigger chart rebuilds.
final priceRefreshCounter = StateProvider<int>((ref) => 0);

// ── Reactive stream providers ──

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
  for (final asset in assets) {
    final stat = stats[asset.id];
    if (stat == null || stat.totalQuantity == 0) continue;
    final price = await priceService.getPrice(asset.id, now);
    if (price == null) continue;
    double fxRate = 1.0;
    if (asset.currency != baseCurrency) {
      fxRate = await rateService.getRate(asset.currency, baseCurrency, now) ?? 1.0;
    }
    result[asset.id] = stat.totalQuantity * price * fxRate;
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
