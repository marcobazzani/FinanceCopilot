import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'services/exchange_rate_service.dart';
import 'services/providers.dart';
import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/capex_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/db_picker_screen.dart';
import 'ui/screens/import_screen.dart';
import 'ui/screens/income_screen.dart';
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
  _log.info('FinanceCopilot v$appVersion starting up');
  runApp(const ProviderScope(child: AssetManagerApp()));
}

class AssetManagerApp extends ConsumerWidget {
  const AssetManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbPath = ref.watch(dbPathProvider);
    // Only read locale from DB after a database is selected to avoid opening the default DB
    final localeStr = dbPath != null
        ? (ref.watch(appLocaleProvider).valueOrNull ?? 'en_US')
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
      home: dbPath == null ? const DbPickerScreen() : const AppShell(),
    );
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

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.account_balance), label: 'Accounts'),
    NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Assets'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Adjustments'),
    NavigationDestination(icon: Icon(Icons.payments), label: 'Income'),
  ];

  static const _railDestinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.account_balance), label: Text('Accounts')),
    NavigationRailDestination(icon: Icon(Icons.pie_chart), label: Text('Assets')),
    NavigationRailDestination(icon: Icon(Icons.account_balance_wallet), label: Text('Adjustments')),
    NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Income')),
  ];

  @override
  void initState() {
    super.initState();
    // Kick off exchange rate sync in background (non-blocking)
    Future.microtask(() async {
      try {
        _log.info('Starting exchange rate sync...');
        await ref.read(exchangeRateServiceProvider).syncRates();
      } catch (e) {
        _log.warning('Exchange rate sync failed: $e');
      }
    });
    // Kick off market price sync in background
    Future.microtask(() => _syncPrices());
    // Kick off composition sync in background
    Future.microtask(() async {
      try {
        await ref.read(compositionServiceProvider).syncCompositions();
      } catch (e) {
        _log.warning('Composition sync failed: $e');
      }
    });
  }

  Future<void> _syncPrices({bool forceToday = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      _log.info('Starting market price sync (forceToday=$forceToday)...');
      await ref.read(marketPriceServiceProvider).syncPrices(forceToday: forceToday);
      // Bump refresh counter so chart providers rebuild with new prices
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('FinanceCopilot'),
        actions: [
          // Refresh market prices button
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Market Prices',
            onPressed: _isSyncing ? null : () => _syncPrices(forceToday: true),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change Database',
            onPressed: () => ref.read(dbPathProvider.notifier).state = null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import File',
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
                Column(
                  children: [
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                        labelType: NavigationRailLabelType.all,
                        destinations: _railDestinations,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'v$appVersion',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
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
                  child: Text(
                    'v$appVersion',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _destinations,
            ),
    );
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
    final db = ref.read(databaseProvider);
    final baseCurrency = ref.read(baseCurrencyProvider).valueOrNull ?? 'EUR';
    final currentLocale = ref.read(appLocaleProvider).valueOrNull ?? '';

    var selectedCurrency = baseCurrency;
    // Map back to stored value: if current resolved locale matches a known option, use '' for system default
    var selectedLocale = _localeOptions.any((o) => o.$1 == currentLocale)
        ? currentLocale
        : '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Settings'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCurrency,
                  decoration: const InputDecoration(labelText: 'Default Currency'),
                  items: ExchangeRateService.allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCurrency = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLocale,
                  decoration: const InputDecoration(labelText: 'Number/Date Format'),
                  items: _localeOptions
                      .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedLocale = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await db.into(db.appConfigs).insertOnConflictUpdate(
                  AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: selectedCurrency),
                );
                await db.into(db.appConfigs).insertOnConflictUpdate(
                  AppConfigsCompanion.insert(key: 'LOCALE', value: selectedLocale),
                );
                _log.info('Settings saved: currency=$selectedCurrency, locale=$selectedLocale');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
