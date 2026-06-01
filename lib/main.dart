import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'utils/dialogs.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'l10n/app_strings.dart';
import 'services/app_actions_controller.dart';
import 'services/app_settings.dart';
import 'services/import_service.dart';
import 'services/db_transfer_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/google_drive_sync_service.dart';
import 'services/providers/providers.dart';
import 'utils/formatters.dart' as fmt;

import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/import/import_screen.dart';
import 'ui/screens/pillars/pillars_screen.dart';
import 'utils/asset_value_math.dart';
import 'utils/bug_reporter.dart';
import 'utils/logger.dart';
import 'version.dart';

part 'app_shell/share_intent.dart';
part 'app_shell/drive_db_ops.dart';
part 'app_shell/settings_dialog.dart';

final _log = getLogger('Main');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // pdfrx 2.x requires explicit initialization before the document API
  // (PdfDocument.openData) is used outside of a pdfrx widget.
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
  await initLogging();
  await initializeDateFormatting();
  final portableLanguage = await AppSettings.loadLanguageForStartup();
  // Print key paths to stdout for easy access
  // ignore: avoid_print
  print('LOG: $logFilePath');
  _log.info('FinanceCopilot v$appVersionDisplay starting up');
  runApp(
    ProviderScope(
      overrides: [
        portableLanguageProvider.overrideWith((ref) => portableLanguage),
      ],
      child: const FinanceCopilotApp(),
    ),
  );
}

class FinanceCopilotApp extends ConsumerWidget {
  const FinanceCopilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeStr = ref.watch(appLocaleProvider).value ?? 'en_US';
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
      // Apply bottom safe area globally so Android gesture/nav bar never
      // covers content (Next buttons, bottom sheets, etc.). SafeArea consumes
      // the MediaQuery padding so descendant NavigationBars won't double-pad.
      builder: (context, child) => SafeArea(
        top: false,
        bottom: true,
        child: child ?? const SizedBox(),
      ),
      home: const _SafeAppShell(),
    );
  }
}

/// Catches errors when opening the DB / building AppShell.
class _SafeAppShell extends ConsumerWidget {
  const _SafeAppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      ref.watch(databaseProvider);
    } catch (e, stack) {
      _log.severe('Failed to open database: $e\n$stack');
      return Scaffold(
        appBar: AppBar(title: const Text('FinanceCopilot')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to open database: $e', textAlign: TextAlign.center),
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
  bool _showLanding = false;
  bool _syncingDrive = false;
  final _repaintKey = GlobalKey();
  StreamSubscription? _shareIntentSub;

  bool get _isSyncing => ref.read(isManualSyncingProvider);
  set _isSyncing(bool v) =>
      ref.read(isManualSyncingProvider.notifier).state = v;

  List<NavigationDestination> _destinations(AppStrings s) => [
    NavigationDestination(icon: const Icon(Icons.dashboard), label: s.navDashboard),
    NavigationDestination(icon: const Icon(Icons.account_balance), label: s.navAccounts),
    NavigationDestination(icon: const Icon(Icons.pie_chart), label: s.navAssets),
    NavigationDestination(icon: const Icon(Icons.view_quilt_outlined), label: s.navPillars),
  ];

  List<(IconData, String)> _sidebarItems(AppStrings s) => [
    (Icons.dashboard, s.navDashboard),
    (Icons.account_balance, s.navAccounts),
    (Icons.pie_chart, s.navAssets),
    (Icons.view_quilt_outlined, s.navPillars),
  ];

  @override
  void initState() {
    super.initState();
    // Register global-action callbacks so any screen's AppBar can drive
    // refresh / settings / import-export / file import / network retry.
    Future.microtask(() {
      ref.read(globalActionsRegistryProvider.notifier).state =
          GlobalActionsRegistry(
        manualRefresh: _manualRefresh,
        showImportExportDialog: _showImportExportDialog,
        showSettingsDialog: _showSettingsDialog,
        openImportFiles: (ctx) async {
          await Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const ImportScreen()),
          );
        },
        retryNetwork: () async {
          if (!mounted) return;
          final monitor = ref.read(networkMonitorProvider);
          monitor.reset();
          final nowOnline = await monitor.check();
          if (!mounted) return;
          ref.read(networkOnlineProvider.notifier).state = nowOnline;
          if (nowOnline) _startBackgroundSync();
        },
      );
    });
    if (Platform.isAndroid) _initShareIntent();
    Future.microtask(() async {
      // Check if DB file exists before touching the provider.
      // If no DB file, show landing page immediately — let the user choose
      // "Start Fresh" or "Sync with Google Drive" before creating any DB.
      final dbFile = await AppDatabase.dbFile();
      if (!dbFile.existsSync()) {
        // Check for legacy DB at old Documents path and migrate if found
        final migrated = await _migrateLegacyDb(dbFile);
        if (!migrated) {
          _log.info('No DB file ${dbFile.path} found, showing landing page');
          if (mounted) setState(() => _showLanding = true);
          return;
        }
      }
      await _initDriveSync();
      await _checkEmptyDb();
      await _runPendingBalanceRecalc();
      if (!_showLanding) _startBackgroundSync();
    });
  }

  Future<void> _initDriveSync() async {
    final sync = ref.read(googleDriveSyncProvider);
    _wireSyncCallbacks(sync);
    final signedIn = await sync.trySilentSignIn();
    if (signedIn) {
      _log.info('Drive sync: signed in as ${sync.userEmail}');
    } else if (sync.needsReauth && mounted) {
      _log.info('Drive sync: needs re-auth (use Settings to sign in)');
      final s = ref.read(appStringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.syncReauthNeeded),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: s.settingsSyncSignIn,
          onPressed: () async {
            final ok = await sync.signIn();
            if (ok) _log.info('Drive sync: re-authenticated as ${sync.userEmail}');
          },
        ),
      ));
    }
  }

  @override
  void dispose() {
    _shareIntentSub?.cancel();
    super.dispose();
  }

  Future<void> _checkEmptyDb() async {
    try {
      final db = ref.read(databaseProvider);
      final hasData = await _dbHasUserData(db);
      if (!hasData && mounted) {
        setState(() => _showLanding = true);
      }
    } catch (_) {}
  }

  /// One-time recalculation of balances in value_date order after migration 25.
  Future<void> _runPendingBalanceRecalc() async {
    try {
      final db = ref.read(databaseProvider);
      final flag = await db.customSelect(
        "SELECT value FROM app_configs WHERE key = 'PENDING_BALANCE_RECALC'",
      ).getSingleOrNull();
      if (flag == null) return;

      final txService = ref.read(transactionServiceProvider);
      final configs = await db.customSelect(
        'SELECT account_id, mappings_json FROM import_configs',
      ).get();

      for (final row in configs) {
        final accountId = row.read<int>('account_id');
        final mappings = jsonDecode(row.read<String>('mappings_json')) as Map<String, dynamic>;
        final balanceMode = (mappings['__balanceMode'] as String?) ?? 'none';
        if (balanceMode == 'none' || balanceMode == 'column') continue;
        final updated = await txService.recalculateBalances(
          accountId,
          balanceMode: balanceMode,
          savedMappings: mappings,
        );
        _log.info('Balance recalc (migration 25): account=$accountId mode=$balanceMode updated=$updated');
      }

      await db.customStatement(
        "DELETE FROM app_configs WHERE key = 'PENDING_BALANCE_RECALC'",
      );
    } catch (e) {
      _log.warning('Pending balance recalc failed: $e');
    }
  }

  /// Check for a DB file at the legacy Documents path and copy it to the new location.
  /// Returns true if migration happened.
  Future<bool> _migrateLegacyDb(File newDbFile) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      // Legacy path: ~/Documents/FinanceCopilot/finance_copilot.db
      final legacyFile = File(p.join(docsDir.path, 'FinanceCopilot', 'finance_copilot.db'));
      if (legacyFile.existsSync()) {
        _log.info('Found legacy DB at ${legacyFile.path}, migrating...');
        await newDbFile.parent.create(recursive: true);
        await legacyFile.copy(newDbFile.path);
        _log.info('Legacy DB migrated to ${newDbFile.path}');
        return true;
      }
    } catch (e) {
      _log.warning('Legacy DB migration failed: $e');
    }
    return false;
  }

  Future<bool> _dbHasUserData(AppDatabase db) async {
    final assetCount = (await db.customSelect('SELECT COUNT(*) AS c FROM assets').getSingle()).read<int>('c');
    final accountCount = (await db.customSelect('SELECT COUNT(*) AS c FROM accounts').getSingle()).read<int>('c');
    return assetCount + accountCount > 0;
  }


  /// Wire up sync service callbacks needed for the explicit
  /// Backup/Restore-from-Drive operations.
  void _wireSyncCallbacks(GoogleDriveSyncService sync) {
    sync.copyFromAttached =
        (tmpPath) => ref.read(databaseProvider).mergeFromAttachedDb(tmpPath);
    sync.onDbReplaced = () {
      if (mounted) {
        _log.info('DB replaced by sync, reloading...');
        ref.read(dbReloadTrigger.notifier).state++;
      }
    };
  }

  Future<void> _startBackgroundSync() async {
    if (!mounted) return;
    final monitor = ref.read(networkMonitorProvider);
    final online = await monitor.check();
    if (!mounted) return;
    ref.read(networkOnlineProvider.notifier).state = online;
    if (!online) {
      _log.info('Network offline - skipping background sync');
      return;
    }

    Future.microtask(() async {
      if (!mounted) return;
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

  /// Full manual refresh: pull from Google Drive, then refresh market data.
  /// Drives [isManualSyncingProvider] so the global Refresh action's spinner
  /// reflects pulls triggered both from the AppBar button and the
  /// pull-to-refresh gesture on mobile. Each step is best-effort -- failures
  /// don't block subsequent steps.
  Future<void> _manualRefresh() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // Update network status indicator
      final online = await ref.read(networkMonitorProvider).check();
      ref.read(networkOnlineProvider.notifier).state = online;

      // Market data sync is best-effort
      _log.info('Manual refresh: syncing market data...');
      try {
        await Future.wait([
          ref.read(marketPriceServiceProvider).syncPrices(forceToday: true),
          ref.read(exchangeRateServiceProvider).syncRates(force: true),
        ]);
        ref.read(priceRefreshCounter.notifier).state++;
      } catch (e) {
        _log.warning('Manual refresh: market sync failed: $e');
      }

      // Rebuild market_prices from existing revalue events. Catches
      // cases where revalues were inserted via a path that bypasses
      // AssetEventService.create's post-CRUD resync (e.g. CSV import's
      // batched insert), and re-anchors close_price after any
      // intervening buy/sell that shifted the qty-at-revalue.
      try {
        final db = ref.read(databaseProvider);
        final eventService = ref.read(assetEventServiceProvider);
        final rows = await db.customSelect(
          "SELECT DISTINCT asset_id FROM asset_events WHERE type = 'revalue'",
          readsFrom: {db.assetEvents},
        ).get();
        for (final row in rows) {
          await eventService.resyncRevaluePricesForAsset(row.read<int>('asset_id'));
        }
        if (rows.isNotEmpty) {
          _log.info('Manual refresh: resynced market_prices for ${rows.length} asset(s) with revalues');
        }
      } catch (e) {
        _log.warning('Manual refresh: revalue resync failed: $e');
      }

      try {
        await ref.read(compositionServiceProvider).syncCompositions();
      } catch (e) {
        _log.warning('Manual refresh: composition sync failed: $e');
      }
    } catch (e) {
      _log.warning('Manual refresh error: $e');
    } finally {
      if (mounted) _isSyncing = false;
    }
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

    _isSyncing = true;
    try {
      _log.info('Starting market price sync (forceToday=$forceToday)...');
      await Future.wait([
        ref.read(marketPriceServiceProvider).syncPrices(forceToday: forceToday),
        ref.read(exchangeRateServiceProvider).syncRates(force: forceToday),
      ]);
      ref.read(priceRefreshCounter.notifier).state++;
    } finally {
      if (mounted) _isSyncing = false;
    }
  }

  Widget _body() {
    return switch (_selectedIndex) {
      0 => const DashboardScreen(),
      1 => const AccountsScreen(),
      2 => const AssetsScreen(),
      3 => const PillarsScreen(),
      _ => const SizedBox(),
    };
  }

  Widget _buildLandingPage() {
    final s = ref.watch(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(s.landingTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(s.landingSubtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  if (_syncingDrive)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          if (_syncingDrive) ...[
                            const SizedBox(height: 12),
                            Text(s.settingsSyncSignedIn(sync.userEmail ?? ''),
                              style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(s.landingSyncProgress,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              )),
                          ],
                        ],
                      ),
                    )
                  else ...[
                    // Google Drive sync — available on all platforms
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.cloud_sync),
                        label: Text(s.landingSyncDrive),
                        onPressed: () async {
                          final ok = await sync.signIn();
                          if (!ok) return;
                          if (mounted) setState(() => _syncingDrive = true);
                          _wireSyncCallbacks(sync);
                          try {
                            final restored = await sync.restoreFromDrive();
                            if (restored != null && mounted) {
                              ref.read(dbReloadTrigger.notifier).state++;
                            }
                          } catch (e) {
                            _log.warning('Landing sync: restore failed: $e');
                          }
                          if (mounted) {
                            setState(() {
                              _syncingDrive = false;
                              _showLanding = false;
                            });
                            _startBackgroundSync();
                          }
                        },
                      ),
                    ),
                    // Import existing DB file
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload),
                        label: Text(s.landingImportDb),
                        onPressed: () async {
                          final path = await DbTransferService.importDb(
                            ref.read(databaseProvider),
                          );
                          if (path != null && mounted) {
                            ref.read(dbReloadTrigger.notifier).state++;
                            setState(() => _showLanding = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() => _showLanding = false);
                        _startBackgroundSync();
                      },
                      child: Text(s.landingStartFresh),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'v$appVersionDisplay',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show landing page without any toolbar/navigation
    if (_showLanding) return _buildLandingPage();

    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final s = ref.watch(appStringsProvider);

    return RepaintBoundary(
      key: _repaintKey,
      child: Scaffold(
      // Outer AppBar removed: each tab body now carries its own AppBar with
      // both local actions and the globals from globalAppBarActions().
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
                              'v$appVersionDisplay',
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
                        'v$appVersionDisplay',
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
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _destinations(s),
            ),
    ));
  }

}

/// Locale dropdown options for the settings dialog. Top-level so the
/// extension-based settings_dialog.dart part can access it without a class
/// qualifier (Dart extensions can't reach unqualified static members of the
/// extended type).
const _localeOptions = [
  ('', 'System Default'),
  ('it_IT', 'Italiano (IT)'),
  ('en_US', 'English (US)'),
  ('en_GB', 'English (GB)'),
  ('de_DE', 'Deutsch (DE)'),
  ('fr_FR', 'Français (FR)'),
  ('es_ES', 'Español (ES)'),
];
