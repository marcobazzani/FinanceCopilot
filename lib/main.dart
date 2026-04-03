import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'l10n/app_strings.dart';
import 'services/app_settings.dart';
import 'services/exchange_rate_service.dart';
import 'services/providers/providers.dart';

import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/capex_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/db_picker_screen.dart';
import 'ui/screens/import/import_screen.dart';
import 'ui/screens/income_screen.dart';
import 'utils/bug_reporter.dart';
import 'utils/logger.dart';
import 'version.dart';

final _log = getLogger('Main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLogging();
  await initializeDateFormatting();
  // Print key paths to stdout for easy access
  // ignore: avoid_print
  print('LOG: $logFilePath');
  _log.info('FinanceCopilot v$appVersion ($appCommit) starting up');
  runApp(const ProviderScope(child: FinanceCopilotApp()));
}

class FinanceCopilotApp extends ConsumerWidget {
  const FinanceCopilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPath = ref.watch(dbPathProvider);
    // Only read locale from DB after a database is selected to avoid opening the default DB
    final localeStr = dbPath != null
        ? (ref.watch(appLocaleProvider).value ?? 'en_US')
        : 'en_US';
    // Parse locale string like "it_IT" into Locale('it', 'IT')
    final parts = localeStr.split(RegExp(r'[_-]'));
    final appLocale = Locale(parts[0], parts.length > 1 ? parts[1] : '');

    return MaterialApp(
      title: 'FinanceCopilot',
      debugShowCheckedModeBanner: false,
      locale: appLocale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('it', 'IT'),
        Locale('de', 'DE'),
        Locale('fr', 'FR'),
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: dbPath == null ? const DbPickerScreen() : _SafeAppShell(dbPath: dbPath),
    );
  }
}

/// Catches errors when opening the DB / building AppShell.
class _SafeAppShell extends ConsumerWidget {
  final String dbPath;
  const _SafeAppShell({required this.dbPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      // Force the database to open now so we catch errors early
      ref.watch(databaseProvider);
      _log.info('Database provider resolved for: $dbPath');
    } catch (e, stack) {
      _log.severe('Failed to open database at $dbPath: $e\n$stack');
      return Scaffold(
        appBar: AppBar(title: const Text('FinanceCopilot')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(ref.read(appStringsProvider).dbOpenFailed(e),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.read(dbPathProvider.notifier).state = null,
                child: Text(ref.read(appStringsProvider).backToPicker),
              ),
            ],
          ),
        ),
      );
    }
    return const AppShell();
  }
}

/// Adaptive navigation shell: bottom nav on mobile, side rail on desktop.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _isSyncing = false;
  final _repaintKey = GlobalKey();

  List<NavigationDestination> _destinations(AppStrings s) => [
    NavigationDestination(icon: const Icon(Icons.dashboard), label: s.navDashboard),
    NavigationDestination(icon: const Icon(Icons.account_balance), label: s.navAccounts),
    NavigationDestination(icon: const Icon(Icons.pie_chart), label: s.navAssets),
    NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: s.navAdjustments),
    NavigationDestination(icon: const Icon(Icons.payments), label: s.navIncome),
  ];

  List<(IconData, String)> _sidebarItems(AppStrings s) => [
    (Icons.dashboard, s.navDashboard),
    (Icons.account_balance, s.navAccounts),
    (Icons.pie_chart, s.navAssets),
    (Icons.account_balance_wallet, s.navAdjustments),
    (Icons.payments, s.navIncome),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _startBackgroundSync());
  }

  Future<void> _startBackgroundSync() async {
    final monitor = ref.read(networkMonitorProvider);
    final online = await monitor.check();
    ref.read(networkOnlineProvider.notifier).state = online;
    if (!online) {
      _log.info('Network offline - skipping background sync');
      return;
    }

    Future.microtask(() async {
      try {
        await Future.wait([
          _syncPrices(),
          ref.read(exchangeRateServiceProvider).syncRates(),
          ref.read(compositionServiceProvider).syncCompositions(),
        ]);
      } catch (e) {
        _log.warning('Background sync error: $e');
      }
    });
  }

  Future<void> _syncPrices({bool forceToday = false}) async {
    if (_isSyncing) return;

    // Check network first
    final monitor = ref.read(networkMonitorProvider);
    final online = await monitor.check();
    ref.read(networkOnlineProvider.notifier).state = online;
    if (!online) {
      _log.info('Network offline - skipping price sync');
      return;
    }

    setState(() => _isSyncing = true);
    try {
      _log.info('Starting market price sync (forceToday=$forceToday)...');
      await Future.wait([
        ref.read(marketPriceServiceProvider).syncPrices(forceToday: forceToday),
        ref.read(exchangeRateServiceProvider).syncRates(),
      ]);
      ref.read(priceRefreshCounter.notifier).state++;
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _body() {
    return switch (_selectedIndex) {
      0 => const DashboardScreen(),
      1 => const AccountsScreen(),
      2 => const AssetsScreen(),
      3 => const CapexScreen(),
      4 => const IncomeScreen(),
      _ => const SizedBox(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final s = ref.watch(appStringsProvider);

    return RepaintBoundary(
      key: _repaintKey,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('FinanceCopilot'),
        actions: [
          Consumer(builder: (context, ref, _) {
            final isPrivate = ref.watch(privacyModeProvider);
            final ss = ref.watch(appStringsProvider);
            return IconButton(
              icon: Icon(isPrivate ? Icons.visibility_off : Icons.visibility),
              tooltip: isPrivate ? ss.tooltipHideAmounts : ss.tooltipShowAmounts,
              onPressed: () =>
                  ref.read(privacyModeProvider.notifier).state = !isPrivate,
            );
          }),
          Consumer(builder: (context, ref, _) {
            final online = ref.watch(networkOnlineProvider);
            if (!online) {
              return IconButton(
                icon: Icon(Icons.signal_wifi_off, color: Colors.red.shade300),
                tooltip: ref.read(appStringsProvider).noNetworkRetry,
                onPressed: () async {
                  final monitor = ref.read(networkMonitorProvider);
                  monitor.reset();
                  final nowOnline = await monitor.check();
                  ref.read(networkOnlineProvider.notifier).state = nowOnline;
                  if (nowOnline) _startBackgroundSync();
                },
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: s.tooltipRefreshPrices,
            onPressed: _isSyncing ? null : () async {
              await _syncPrices(forceToday: true);
              await ref.read(compositionServiceProvider).syncCompositions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: s.tooltipChangeDatabase,
            onPressed: () => ref.read(dbPathProvider.notifier).state = null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: s.tooltipSettings,
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: s.tooltipImportFile,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportScreen()),
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      ..._sidebarItems(s).asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final isSelected = i == _selectedIndex;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
                                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  Icon(item.$1, size: 20, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.$2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'v$appVersion ($appCommit)',
                              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => openBugReporter(context, ref, repaintKey: _repaintKey, enablePrivacy: true),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Icon(Icons.bug_report, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _body()),
              ],
            )
          : Stack(
              children: [
                _body(),
                Positioned(
                  left: 8,
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v$appVersion',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => openBugReporter(context, ref, repaintKey: _repaintKey, enablePrivacy: true),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.bug_report, size: 14, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _destinations(s),
            ),
    ));
  }

  static const _localeOptions = [
    ('', 'System Default'),
    ('it_IT', 'Italiano (IT)'),
    ('en_US', 'English (US)'),
    ('en_GB', 'English (GB)'),
    ('de_DE', 'Deutsch (DE)'),
    ('fr_FR', 'Français (FR)'),
    ('es_ES', 'Español (ES)'),
  ];


  Future<void> _showSettingsDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final db = ref.read(databaseProvider);
    final baseCurrency = ref.read(baseCurrencyProvider).value ?? 'EUR';
    final currentLocale = ref.read(appLocaleProvider).value ?? '';

    var selectedCurrency = baseCurrency;
    var selectedLocale = _localeOptions.any((o) => o.$1 == currentLocale)
        ? currentLocale
        : '';
    var selectedLanguage = ref.read(portableLanguageProvider);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.settingsTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  decoration: InputDecoration(labelText: s.settingsCurrency),
                  items: ExchangeRateService.allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCurrency = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedLocale,
                  decoration: InputDecoration(labelText: s.settingsNumberFormat),
                  items: _localeOptions
                      .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedLocale = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedLanguage,
                  decoration: InputDecoration(labelText: s.settingsLanguage),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'it', child: Text('Italiano')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedLanguage = v!),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.settingsClearCache,
                              style: Theme.of(ctx).textTheme.bodyMedium),
                          Text(
                            s.settingsClearCacheSubtitle,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(ctx).colorScheme.error,
                        side: BorderSide(color: Theme.of(ctx).colorScheme.error),
                      ),
                      onPressed: () async {
                        await ref.read(marketPriceServiceProvider).clearCache();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(s.settingsCacheCleared)),
                          );
                        }
                      },
                      child: Text(s.settingsClearButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                await db.into(db.appConfigs).insertOnConflictUpdate(
                  AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: selectedCurrency),
                );
                await db.into(db.appConfigs).insertOnConflictUpdate(
                  AppConfigsCompanion.insert(key: 'LOCALE', value: selectedLocale),
                );
                await AppSettings.setLanguage(selectedLanguage);
                ref.read(portableLanguageProvider.notifier).state = selectedLanguage;
                _log.info('Settings saved: currency=$selectedCurrency, locale=$selectedLocale, lang=$selectedLanguage');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}
