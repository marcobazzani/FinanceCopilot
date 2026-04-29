part of 'providers.dart';

// ── Service providers ──

Provider<T> _dbService<T>(T Function(AppDatabase) ctor) =>
    Provider<T>((ref) => ctor(ref.watch(databaseProvider)));

final intermediaryServiceProvider = _dbService(IntermediaryService.new);
final accountServiceProvider = _dbService(AccountService.new);
final assetServiceProvider = _dbService(AssetService.new);
final importServiceProvider = _dbService(ImportService.new);
final transactionServiceProvider = _dbService(TransactionService.new);
final assetEventServiceProvider = _dbService(AssetEventService.new);
final importConfigServiceProvider = _dbService(ImportConfigService.new);

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

final bufferServiceProvider = _dbService(BufferService.new);

// ── Extraordinary events (unified CAPEX + IncomeAdj replacement) ──

final extraordinaryEventServiceProvider = _dbService(ExtraordinaryEventService.new);

// ── Income providers ──

final incomeServiceProvider = _dbService(IncomeService.new);
