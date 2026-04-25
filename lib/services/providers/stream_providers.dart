part of 'providers.dart';

// ── Reactive stream providers ──

final intermediariesProvider = StreamProvider<List<Intermediary>>((ref) {
  return ref.watch(intermediaryServiceProvider).watchAll();
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

final activeAssetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetServiceProvider).watchActive();
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

/// Transactions for a specific account (pass accountId as family parameter).
final accountTransactionsProvider = StreamProvider.family<List<Transaction>, int>((ref, accountId) {
  return ref.watch(transactionServiceProvider).watchByAccount(accountId);
});

/// Asset events for a specific asset (pass assetId as family parameter).
final assetEventsProvider = StreamProvider.family<List<AssetEvent>, int>((ref, assetId) {
  return ref.watch(assetEventServiceProvider).watchByAsset(assetId);
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
final editableChartsProvider =
    StateNotifierProvider<EditableChartsNotifier, EditableChartsState>((ref) {
  final loaded = ref.watch(defaultChartsLoadedProvider).value ??
      const <DashboardChart>[];
  return EditableChartsNotifier(EditableChartsState(
    charts: List.of(loaded),
    pristine: List.of(loaded),
  ));
});

/// Dashboard charts source — debug mode reads the editor notifier, release
/// reads the JSON-loaded list directly. No DB persistence either way.
final dashboardChartsProvider = Provider<List<DashboardChart>>((ref) {
  if (debugChartsEnabled) {
    return ref.watch(editableChartsProvider).charts;
  }
  return ref.watch(defaultChartsLoadedProvider).value ??
      const <DashboardChart>[];
});

/// True when the editor's working set differs from the pristine JSON
/// baseline. Drives the dirty dot on the Export FAB.
final chartsDirtyProvider = Provider<bool>((ref) {
  if (!debugChartsEnabled) return false;
  return ref.watch(editableChartsProvider).isDirty;
});

// ── Buffer transactions (reimbursements; shared across events) ──

final bufferTransactionsProvider = StreamProvider.family<List<BufferTransaction>, int>((ref, bufferId) {
  return ref.watch(bufferServiceProvider).watchByBuffer(bufferId);
});

// ── Extraordinary events stream providers ──

final extraordinaryEventsProvider = StreamProvider<List<ExtraordinaryEvent>>((ref) {
  return ref.watch(extraordinaryEventServiceProvider).watchAll();
});

final extraordinaryEventProvider = StreamProvider.family<ExtraordinaryEvent, int>((ref, id) {
  return ref.watch(extraordinaryEventServiceProvider).watchById(id);
});

final extraordinaryEventEntriesProvider = StreamProvider.family<List<ExtraordinaryEventEntry>, int>((ref, eventId) {
  return ref.watch(extraordinaryEventServiceProvider).watchEntries(eventId);
});

final extraordinaryEventStatsProvider = StreamProvider<Map<int, ExtraordinaryEventStats>>((ref) {
  return ref.watch(extraordinaryEventServiceProvider).watchStatsForAll();
});

// ── Income stream providers ──

final incomesProvider = StreamProvider<List<Income>>((ref) {
  return ref.watch(incomeServiceProvider).watchAll();
});
