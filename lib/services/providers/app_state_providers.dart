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
final currentDateProvider = Provider<DateTime>((ref) {
  final override = ref.watch(waybackDateProvider);
  return dateOnly(override ?? DateTime.now());
});

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
  return (db.select(db.appConfigs)..where((c) => c.key.equals('LANGUAGE')))
      .watchSingleOrNull()
      .map((row) => row?.value ?? 'en');
});

/// Provides the current [AppStrings] instance from portable language setting.
final appStringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(portableLanguageProvider);
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

/// Default capital-gains tax rate (fraction, 0.26 = 26%). Reactive from
/// AppConfigs; defaults to [kDefaultTaxRate] when unset or invalid.
/// Per-asset `taxRate` overrides this on a position-by-position basis.
final defaultTaxRateProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('TAX_RATE')))
      .watchSingleOrNull()
      .map((row) {
    final v = double.tryParse(row?.value ?? '');
    if (v == null) return kDefaultTaxRate;
    return v.clamp(0.0, 1.0);
  });
});

/// Safe Withdrawal Rate (%) for the FIRE indicator. Reactive from AppConfigs;
/// defaults to [kDefaultFireSwrPct] when unset or invalid.
final fireSwrProvider = StreamProvider<double>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.appConfigs)..where((c) => c.key.equals('FIRE_SWR')))
      .watchSingleOrNull()
      .map((row) => double.tryParse(row?.value ?? '') ?? kDefaultFireSwrPct);
});
