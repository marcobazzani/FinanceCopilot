part of 'providers.dart';

// ── Reactive stream providers ──

final intermediariesProvider = StreamProvider<List<Intermediary>>((ref) {
  return ref.watch(intermediaryServiceProvider).watchAll();
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountServiceProvider).watchAll();
});

final accountStatsProvider = StreamProvider<Map<int, AccountStats>>((ref) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(accountServiceProvider).watchStatsForAll(through: through);
});

final assetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetServiceProvider).watchAll();
});

final activeAssetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetServiceProvider).watchActive();
});

final pillarsProvider = StreamProvider<List<Pillar>>((ref) {
  return ref.watch(pillarServiceProvider).watchAll();
});

/// Only standard (partition-based) pillars.
final standardPillarsProvider = StreamProvider<List<Pillar>>((ref) {
  return ref
      .watch(pillarServiceProvider)
      .watchAll()
      .map(
        (list) => list.where((p) => p.kind == PillarKind.standard).toList(),
      );
});

/// Only virtual portfolios (overlap-based, no Objective).
final virtualPortfoliosProvider = StreamProvider<List<Pillar>>((ref) {
  return ref
      .watch(pillarServiceProvider)
      .watchAll()
      .map(
        (list) => list.where((p) => p.kind == PillarKind.virtual).toList(),
      );
});

final pillarAssetsProvider = StreamProvider<List<PillarAsset>>((ref) {
  return ref.watch(pillarServiceProvider).watchAllAssignments();
});

final portfolioModelsProvider = StreamProvider<List<PortfolioModel>>((ref) async* {
  final service = ref.watch(portfolioModelServiceProvider);
  await service.seedBuiltInModels();
  yield* service.watchAll();
});

final portfolioModelItemsProvider = StreamProvider.family<List<PortfolioModelItem>, String>((ref, modelId) {
  return ref.watch(portfolioModelServiceProvider).watchItems(modelId);
});

/// For one pillar: assetId → fraction of that asset's total holding.
final pillarFractionProvider = FutureProvider.family<Map<int, double>, String>((ref, pillarId) async {
  ref.watch(pillarAssetsProvider);
  return ref.read(pillarServiceProvider).fractionsForPillar(pillarId);
});

final unassignedFractionProvider = FutureProvider<Map<int, double>>((ref) async {
  ref.watch(pillarAssetsProvider);
  final assets = await ref.watch(activeAssetsProvider.future);
  final svc = ref.read(pillarServiceProvider);
  final out = <int, double>{};
  for (final a in assets) {
    final total = await svc.totalQuantity(a.id);
    if (total > 0) {
      final unassigned = await svc.unassignedQty(a.id);
      out[a.id] = unassigned / total;
    }
  }
  return out;
});

/// Asset composition breakdowns (country / sector / holding weights from
/// the composition provider).
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
  final through = ref.watch(waybackDateProvider);
  return ref.watch(assetServiceProvider).watchStatsForAll(through: through);
});

/// Transactions for a specific account (pass accountId as family parameter).
final accountTransactionsProvider = StreamProvider.family<List<Transaction>, int>((ref, accountId) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(transactionServiceProvider).watchByAccount(accountId, through: through);
});

/// All transactions across every account — feeds the read-only virtual
/// "All accounts" entry.
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(transactionServiceProvider).watchAll(through: through);
});

// ── Transaction categorization ──

/// Active (non-archived) categories in display order.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryServiceProvider).watchAll();
});

/// Every category including archived ones (management screen, label lookup
/// for rows still pointing at an archived category).
final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryServiceProvider).watchAll(includeArchived: true);
});

/// Categories by id — includes archived so existing rows always resolve.
final categoriesByIdProvider = Provider<Map<int, Category>>((ref) {
  final list = ref.watch(allCategoriesProvider).value ?? const <Category>[];
  return {for (final c in list) c.id: c};
});

/// Rules in evaluation order.
final categorizationRulesProvider = StreamProvider<List<AutoCategorizationRule>>((ref) {
  return ref.watch(ruleServiceProvider).watchAll();
});

/// Every category the user has actually used, most recently used first:
/// categories targeted by a rule (newest rule first), then categories set
/// directly on transactions. Unbounded by design — "used at least once" is
/// the whole criterion.
final usedCategoryIdsProvider = StreamProvider<List<int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT category_id AS id, MAX(last_used) AS last_used FROM ('
        '  SELECT category_id, created_at AS last_used FROM auto_categorization_rules'
        '  UNION ALL'
        '  SELECT category_id, 0 AS last_used FROM transactions WHERE category_id IS NOT NULL'
        ') GROUP BY category_id ORDER BY last_used DESC, id',
        readsFrom: {db.autoCategorizationRules, db.transactions},
      )
      .watch()
      .map((rows) => rows.map((r) => r.read<int>('id')).toList());
});

/// Classification progress measured in base-currency money (rows without an
/// FX rate excluded and counted); family key = accountId (null = whole ledger).
final classificationProgressProvider = StreamProvider.family<ClassificationProgress, int?>((ref, accountId) async* {
  final base = await ref.watch(baseCurrencyProvider.future);
  final rates = CachedRateResolver(ref.watch(exchangeRateServiceProvider), base);
  yield* ref.watch(transactionClassifierServiceProvider).watchProgress(accountId: accountId, rate: rates.getRate, baseCurrency: base);
});

/// Uncategorized merchant groups, the ones worth the most money first;
/// family key = accountId.
final uncategorizedGroupsProvider = StreamProvider.family<List<MerchantGroup>, int?>((ref, accountId) async* {
  final base = await ref.watch(baseCurrencyProvider.future);
  final rates = CachedRateResolver(ref.watch(exchangeRateServiceProvider), base);
  yield* ref.watch(transactionClassifierServiceProvider).watchUncategorizedGroups(accountId: accountId, rate: rates.getRate, baseCurrency: base);
});

/// Structural ledger roles (transfer / no-op / adjustment / cancelled) for
/// every explained row. Rows in this map never take part in categorization.
final ledgerRolesProvider = StreamProvider<Map<int, LedgerRole>>((ref) {
  return ref.watch(transactionClassifierServiceProvider).watchLedger().map((l) => l.roles);
});

/// Set when rules changed since the last classifier run — the management
/// screen shows a "reclassify" reminder until the user runs it.
final rulesDirtyProvider = StateProvider<bool>((ref) => false);

/// Asset events for a specific asset (pass assetId as family parameter).
final assetEventsProvider = StreamProvider.family<List<AssetEvent>, int>((ref, assetId) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(assetEventServiceProvider).watchByAsset(assetId, through: through);
});

/// Loads `assets/default_charts.json` and expands the categories against
/// the live accounts / assets / events. Always available — both the
/// editor (debug mode) and the read-only renderer (release mode) use it
/// as their starting point.
final defaultChartsLoadedProvider = FutureProvider<List<DashboardChart>>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  final assets = await ref.watch(activeAssetsProvider.future);
  final events = await ref.watch(extraordinaryEventsProvider.future);
  return const DefaultChartsLoader().load(
    activeAccounts: accounts.where((a) => a.isActive).toList(),
    activeAssets: assets,
    activeEvents: events,
  );
});

/// In-memory editor state — only meaningful when `debugChartsEnabled` is
/// true. Listens to `defaultChartsLoadedProvider`; when the JSON load
/// emits, the notifier resets to a fresh state with that list as both
/// `charts` and `pristine`. User edits go on top until the next reload.
final editableChartsProvider = StateNotifierProvider<EditableChartsNotifier, EditableChartsState>((ref) {
  final loaded = ref.watch(defaultChartsLoadedProvider).value ?? const <DashboardChart>[];
  return EditableChartsNotifier(
    EditableChartsState(
      charts: List.of(loaded),
      pristine: List.of(loaded),
    ),
  );
});

/// Dashboard charts source — debug mode reads the editor notifier, release
/// reads the JSON-loaded list directly. No DB persistence either way.
final dashboardChartsProvider = Provider<List<DashboardChart>>((ref) {
  if (debugChartsEnabled) {
    return ref.watch(editableChartsProvider).charts;
  }
  return ref.watch(defaultChartsLoadedProvider).value ?? const <DashboardChart>[];
});

/// True when the editor's working set differs from the pristine JSON
/// baseline. Drives the dirty dot on the Export FAB.
final chartsDirtyProvider = Provider<bool>((ref) {
  if (!debugChartsEnabled) return false;
  return ref.watch(editableChartsProvider).isDirty;
});

// ── Buffer transactions (reimbursements; shared across events) ──

final bufferTransactionsProvider = StreamProvider.family<List<BufferTransaction>, int>((ref, bufferId) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(bufferServiceProvider).watchByBuffer(bufferId, through: through);
});

// ── Extraordinary events stream providers ──

final extraordinaryEventsProvider = StreamProvider<List<ExtraordinaryEvent>>((ref) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(extraordinaryEventServiceProvider).watchAll(through: through);
});

final extraordinaryEventProvider = StreamProvider.family<ExtraordinaryEvent, int>((ref, id) {
  return ref.watch(extraordinaryEventServiceProvider).watchById(id);
});

final extraordinaryEventEntriesProvider = StreamProvider.family<List<ExtraordinaryEventEntry>, int>((ref, eventId) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(extraordinaryEventServiceProvider).watchEntries(eventId, through: through);
});

final extraordinaryEventStatsProvider = StreamProvider<Map<int, ExtraordinaryEventStats>>((ref) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(extraordinaryEventServiceProvider).watchStatsForAll(through: through);
});

/// Aggregated adjustment inputs for the read-only All-Accounts view:
/// active events + their entries + buffer reimbursements, grouped by event id.
///
/// Driven by [ExtraordinaryEventService.watchAdjustmentRevision] so it rebuilds
/// on writes to the events, entries, AND buffer-transactions tables. It
/// previously keyed off `extraordinaryEventsProvider` alone, which is a select
/// over `extraordinary_events`; adding an entry — exactly what "mark as
/// adjustment" does — never re-emitted, so the ledger badge and the day/month
/// totals exclusion stayed stale until the app was restarted.
///
/// A `StreamProvider` rather than a `FutureProvider`: `AsyncValue` is identical
/// across both, so consumers reading `.value` need no change.
final adjustmentInputsProvider = StreamProvider<AdjustmentInputs>((ref) {
  final through = ref.watch(waybackDateProvider);
  final service = ref.watch(extraordinaryEventServiceProvider);
  return service.watchAdjustmentRevision().asyncMap((_) => service.getAdjustmentInputs(through: through));
});

// ── Income stream providers ──

final incomesProvider = StreamProvider<List<Income>>((ref) {
  final through = ref.watch(waybackDateProvider);
  return ref.watch(incomeServiceProvider).watchAll(through: through);
});
