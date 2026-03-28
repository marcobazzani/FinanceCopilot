part of 'providers.dart';

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

// ── Dashboard chart providers ──

final dashboardChartServiceProvider = Provider<DashboardChartService>((ref) {
  return DashboardChartService(ref.watch(databaseProvider));
});

// ── CAPEX / Buffer providers ──

final capexServiceProvider = Provider<CapexService>((ref) {
  return CapexService(ref.watch(databaseProvider));
});

final bufferServiceProvider = Provider<BufferService>((ref) {
  return BufferService(ref.watch(databaseProvider));
});

// ── Income adjustment providers ──

final incomeAdjustmentServiceProvider = Provider<IncomeAdjustmentService>((ref) {
  return IncomeAdjustmentService(ref.watch(databaseProvider));
});

// ── Income providers ──

final incomeServiceProvider = Provider<IncomeService>((ref) {
  return IncomeService(ref.watch(databaseProvider));
});
