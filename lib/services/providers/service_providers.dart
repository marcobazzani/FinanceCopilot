part of 'providers.dart';

// ── Service providers ──

final intermediaryServiceProvider = Provider<IntermediaryService>((ref) {
  return IntermediaryService(ref.watch(databaseProvider));
});

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
  final investing = ref.watch(marketPriceServiceProvider);
  return CompositionService(
    ref.watch(databaseProvider),
    investingService: investing is InvestingComService ? investing : null,
  );
});

// Dashboard chart configuration is no longer DB-backed; see
// `lib/services/editable_charts_notifier.dart` and
// `lib/services/default_charts_loader.dart`.

// ── Buffer provider (shared with ExtraordinaryEvents for reimbursements) ──

final bufferServiceProvider = Provider<BufferService>((ref) {
  return BufferService(ref.watch(databaseProvider));
});

// ── Extraordinary events (unified CAPEX + IncomeAdj replacement) ──

final extraordinaryEventServiceProvider = Provider<ExtraordinaryEventService>((ref) {
  return ExtraordinaryEventService(ref.watch(databaseProvider));
});

// ── Income providers ──

final incomeServiceProvider = Provider<IncomeService>((ref) {
  return IncomeService(ref.watch(databaseProvider));
});
