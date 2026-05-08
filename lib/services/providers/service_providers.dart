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
  return IsinLookupService(priceService as WebMarketDataService);
});

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  final priceService = ref.watch(marketPriceServiceProvider);
  final provider = priceService is WebMarketDataService ? priceService : null;
  return ExchangeRateService(ref.watch(databaseProvider), providerService: provider);
});

final marketPriceServiceProvider = Provider<MarketPriceService>((ref) {
  final db = ref.watch(databaseProvider);
  return WebMarketDataService(db);
});

final compositionServiceProvider = Provider<CompositionService>((ref) {
  final priceService = ref.watch(marketPriceServiceProvider);
  return CompositionService(
    ref.watch(databaseProvider),
    providerService: priceService is WebMarketDataService ? priceService : null,
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

// ── Pillar providers ──

final pillarServiceProvider = _dbService(PillarService.new);

/// Currently selected pillar scope on dashboards (default: All).
final selectedPillarScopeProvider =
    StateProvider<PillarScope>((ref) => const PillarScope.all());
