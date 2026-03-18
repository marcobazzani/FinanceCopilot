import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'services/exchange_rate_service.dart';
import 'services/providers.dart';
import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/capex_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/import_screen.dart';
import 'utils/logger.dart';
import 'version.dart';

final _log = getLogger('Main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLogging();
  _log.info('FinanceCopilot v$appVersion starting up');
  runApp(const ProviderScope(child: AssetManagerApp()));
}

class AssetManagerApp extends StatelessWidget {
  const AssetManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinanceCopilot',
      debugShowCheckedModeBanner: false,
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
      home: const AppShell(),
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
  ];

  static const _railDestinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.account_balance), label: Text('Accounts')),
    NavigationRailDestination(icon: Icon(Icons.pie_chart), label: Text('Assets')),
    NavigationRailDestination(icon: Icon(Icons.account_balance_wallet), label: Text('Adjustments')),
  ];

  @override
  void initState() {
    super.initState();
    // Kick off exchange rate sync in background (non-blocking)
    Future.microtask(() {
      _log.info('Starting exchange rate sync...');
      ref.read(exchangeRateServiceProvider).syncRates();
    });
    // Kick off market price sync in background
    Future.microtask(() => _syncPrices());
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

  Future<void> _showSettingsDialog(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final baseCurrency = ref.read(baseCurrencyProvider).valueOrNull ?? 'EUR';

    var selectedCurrency = baseCurrency;

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
                _log.info('Settings saved: currency=$selectedCurrency');
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
