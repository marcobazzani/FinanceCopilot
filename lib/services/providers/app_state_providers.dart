part of 'providers.dart';

// ── Network ──

final networkMonitorProvider = Provider<NetworkMonitor>((ref) => NetworkMonitor());

/// Whether network is currently available. Polled reactively.
final networkOnlineProvider = StateProvider<bool>((ref) => true);

/// Bumped after market price sync to trigger chart rebuilds.
final priceRefreshCounter = StateProvider<int>((ref) => 0);

/// Privacy mode: blur all monetary amounts for screenshot sharing.
final privacyModeProvider = StateProvider<bool>((ref) => false);

/// Visualization-only date override. When non-null, read-only views behave as
/// if this were the current date. Real wall-clock concerns such as logs, cache
/// TTLs, OAuth, sync timing, and audit timestamps must still use DateTime.now().
final waybackDateProvider = StateProvider<DateTime?>((ref) => null);

/// Current date for user-facing read/display logic.
///
/// Recomputes automatically just after the next local midnight (via a
/// self-scheduled timer) so day-boundary-sensitive views — today's change,
/// YTD, chart cutoffs — roll over without an app restart. Previously this
/// captured [DateTime.now] once at first read and went stale across midnight,
/// leaving "today's change" showing yesterday's movement until relaunch.
/// When a wayback override is set the date is pinned and no timer is armed.
final currentDateProvider = Provider<DateTime>((ref) {
  final override = ref.watch(waybackDateProvider);
  if (override != null) return dateOnly(override);
  final now = ref.watch(nowProvider)();
  final timer = Timer(durationUntilNextDay(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return dateOnly(now);
});

/// Wall-clock source. Overridable in tests so the day-rollover behaviour can be
/// exercised deterministically; production always uses [DateTime.now].
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Labels (chart titles) that have already triggered the ATH celebration
/// overlay during this app session. Used to prevent the dashboard rebuild
/// from re-firing the celebration every time a new frame is laid out for
/// the History tab. Resets on app restart.
final athFiredThisSessionProvider = StateProvider<Set<String>>((_) => <String>{});

/// True once the user has opened the Dashboard's History tab in this app
/// session. The ATH auto-fire is gated on this flag so the celebration
/// doesn't surprise the user at startup if their portfolio happens to be
/// at a new high. The 6-tap easter-egg path ignores this gate — it always
/// fires on demand.
final historyTabSeenThisSessionProvider = StateProvider<bool>((_) => false);

/// Whether the user-triggered price/rate/composition sync is currently
/// running. Drives the spinner on the global Refresh icon from any screen.
final isManualSyncingProvider = StateProvider<bool>((ref) => false);

/// Whether a Drive backup/restore is currently in flight. Independent
/// from [isManualSyncingProvider] so both spinners can co-exist.
final isDriveSyncingProvider = StateProvider<bool>((ref) => false);

/// Portable language setting (from ~/.config/FinanceCopilot/settings.json).
/// Used before a DB is opened. Initialized on app start.
final portableLanguageProvider = StateProvider<String>((ref) => 'en');

/// UI language from AppConfigs, reactive. 'en' (default) or 'it'.
final appLanguageProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('LANGUAGE'))).watchSingleOrNull().map((row) => row?.value ?? 'en');
});

/// Provides the current [AppStrings] instance from portable language setting.
final appStringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(portableLanguageProvider);
  return AppStrings.of(lang);
});

/// Display locale from AppConfigs, reactive. Empty string = system default.
final appLocaleProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('LOCALE'))).watchSingleOrNull().map((row) {
    final value = row?.value ?? '';
    return value.isEmpty ? Platform.localeName : value;
  });
});

/// Base currency from AppConfigs, reactive. Defaults to EUR.
final baseCurrencyProvider = StreamProvider<String>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('BASE_CURRENCY'))).watchSingleOrNull().map((row) => row?.value ?? 'EUR');
});

/// Default capital-gains tax rate (fraction, 0.26 = 26%). Reactive from
/// AppConfigs; defaults to [kDefaultTaxRate] when unset or invalid.
/// Per-asset `taxRate` overrides this on a position-by-position basis.
final defaultTaxRateProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('TAX_RATE'))).watchSingleOrNull().map((row) {
    final v = double.tryParse(row?.value ?? '');
    if (v == null) return kDefaultTaxRate;
    return v.clamp(0.0, 1.0);
  });
});

/// Safe Withdrawal Rate (%) for the FIRE indicator. Reactive from AppConfigs;
/// defaults to [kDefaultFireSwrPct] when unset or invalid.
final fireSwrProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.appConfigs,
  )..where((c) => c.key.equals('FIRE_SWR'))).watchSingleOrNull().map((row) => double.tryParse(row?.value ?? '') ?? kDefaultFireSwrPct);
});

// ── Price-change period default (persisted via long-press on the selector) ──

/// AppConfigs keys for the user's preferred default price-change period.
const kDefaultPriceChangeUnitKey = 'DEFAULT_PRICE_CHANGE_UNIT';
const kDefaultPriceChangeNumberKey = 'DEFAULT_PRICE_CHANGE_NUMBER';

/// Persisted default price-change unit ('d','w','m','y','WTD','MTD','YTD','All'),
/// or null when the user has never set one. Reactive from AppConfigs. The
/// dashboard card validates the value against its known units and falls back to
/// 'd' for display; null here also means "show no default marker".
final defaultPriceChangeUnitProvider = StreamProvider<String?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.appConfigs,
  )..where((c) => c.key.equals(kDefaultPriceChangeUnitKey))).watchSingleOrNull().map((row) => row?.value);
});

/// Persisted default price-change multiplier, or null when unset or invalid
/// (non-numeric / <= 0). Reactive from AppConfigs; the card falls back to 1.
final defaultPriceChangeNumberProvider = StreamProvider<int?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals(kDefaultPriceChangeNumberKey))).watchSingleOrNull().map((row) {
    final v = int.tryParse(row?.value ?? '');
    return (v == null || v <= 0) ? null : v;
  });
});

/// Persist the price-change period the user long-pressed as the new default.
/// Overwrites any existing default (key is the primary key, so no duplicates).
Future<void> savePriceChangePeriodDefault(AppDatabase db, {required String unit, required int number}) async {
  await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kDefaultPriceChangeUnitKey, value: unit));
  await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kDefaultPriceChangeNumberKey, value: number.toString()));
}
