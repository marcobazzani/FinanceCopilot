part of 'providers.dart';

// ── Network ──

final networkMonitorProvider = Provider<NetworkMonitor>((ref) => NetworkMonitor());

/// Whether network is currently available. Polled reactively.
final networkOnlineProvider = StateProvider<bool>((ref) => true);

/// Bumped after market price sync to trigger chart rebuilds.
final priceRefreshCounter = StateProvider<int>((ref) => 0);

/// Privacy mode: blur all monetary amounts for screenshot sharing.
final privacyModeProvider = StateProvider<bool>((ref) => false);

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
