import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'l10n/app_strings.dart';
import 'services/app_settings.dart';
import 'services/db_transfer_service.dart';
import 'services/demo_db_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/google_drive_sync_service.dart';
import 'services/providers/providers.dart';

import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/capex_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/import/import_screen.dart';
import 'ui/screens/income_screen.dart';
import 'utils/bug_reporter.dart';
import 'utils/logger.dart';
import 'version.dart';

final _log = getLogger('Main');

/// Feature flag: enable demo DB generation (disabled by default, enable at compile time).
const _enableDemo = bool.fromEnvironment('ENABLE_DEMO', defaultValue: false);

/// Tables that are updated by background sync (prices, rates, compositions).
/// Changes to these should NOT trigger Google Drive upload.
const _backgroundTables = {
  'market_prices', 'exchange_rates', 'app_configs', 'asset_compositions',
};

/// Stream of user-initiated table updates only (excludes background sync tables).
Stream<void> _userTableUpdates(AppDatabase db) {
  return db.tableUpdates().where((updates) {
    return updates.any((u) => !_backgroundTables.contains(u.table));
  }).map((_) {});
}

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
  bool _isSyncing = false;
  bool _showLanding = false;
  bool _generatingDemo = false;
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
    Future.microtask(() async {
      // Check if DB file exists before touching the provider.
      // If no DB file, show landing page immediately — let the user choose
      // "Start Fresh" or "Sync with Google Drive" before creating any DB.
      final dbFile = await AppDatabase.dbFile();
      if (!dbFile.existsSync()) {
        // Check for legacy DB at old Documents path and migrate if found
        final migrated = await _migrateLegacyDb(dbFile);
        if (!migrated) {
          _log.info('No DB file found, showing landing page');
          if (mounted) setState(() => _showLanding = true);
          return;
        }
      }
      await _initDriveSync();
      await _checkEmptyDb();
      if (!_showLanding) _startBackgroundSync();
    });
  }

  Future<void> _initDriveSync() async {
    final sync = ref.read(googleDriveSyncProvider);
    final signedIn = await sync.trySilentSignIn();
    if (!signedIn) return;
    _log.info('Drive sync: signed in as ${sync.userEmail}');
    _wireSyncCallbacks(sync);

    final pulled = await sync.pullIfNewerOnStartup();
    if (pulled && mounted) {
      _log.info('Drive sync: pulled newer DB from remote');
      ref.read(dbReloadTrigger.notifier).state++;
    }

    // Start auto-push on DB changes
    final db = ref.read(databaseProvider);
    sync.startAutoSync(_userTableUpdates(db));
  }

  Future<void> _checkEmptyDb() async {
    try {
      final db = ref.read(databaseProvider);
      final sync = ref.read(googleDriveSyncProvider);
      final hasData = await _dbHasUserData(db);
      sync.setHasUserData(hasData);
      _wireSyncCallbacks(sync);
      if (!hasData && mounted) {
        setState(() => _showLanding = true);
      }
    } catch (_) {}
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

  Future<ConflictChoice> _showConflictDialog(ConflictInfo info) async {
    if (!mounted) return ConflictChoice.keepRemote;
    final s = ref.read(appStringsProvider);
    final remoteTime = '${info.remoteModifiedTime.toLocal()}'.split('.').first;
    final choice = await showDialog<ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: 8),
            Text(s.conflictTitle),
          ],
        ),
        content: Text(s.conflictBody(info.remoteDeviceName, remoteTime)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.cancel),
            child: Text(s.conflictCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.keepRemote),
            child: Text(s.conflictKeepRemote),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ConflictChoice.keepLocal),
            child: Text(s.conflictKeepLocal),
          ),
        ],
      ),
    );
    return choice ?? ConflictChoice.cancel;
  }

  /// Wire up sync service callbacks (user data check + conflict dialog + DB reload).
  void _wireSyncCallbacks(GoogleDriveSyncService sync) {
    sync.checkHasUserData = () => _dbHasUserData(ref.read(databaseProvider));
    sync.onConflict = _showConflictDialog;
    sync.onDbReplaced = () {
      if (mounted) {
        _log.info('DB replaced by sync, reloading...');
        ref.read(dbReloadTrigger.notifier).state++;
      }
    };
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
                  if (_generatingDemo)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
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
                          if (ok) {
                            _wireSyncCallbacks(sync);
                            final pulled = await sync.pullIfNewerOnStartup();
                            if (pulled) ref.read(dbReloadTrigger.notifier).state++;
                            final db = ref.read(databaseProvider);
                            sync.setHasUserData(await _dbHasUserData(db));
                            sync.startAutoSync(_userTableUpdates(db));
                            if (mounted) {
                              setState(() => _showLanding = false);
                              _startBackgroundSync();
                            }
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
                          final path = await DbTransferService.importDb();
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
                    // Demo — behind feature flag
                    if (_enableDemo) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _createDemo,
                        child: Text(s.landingCreateDemo),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'v$appVersion${appCommit.isNotEmpty ? ' ($appCommit)' : ''}',
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

  Future<void> _createDemo() async {
    setState(() => _generatingDemo = true);
    try {
      final dbPath = await DbTransferService.dbPath;
      await DemoDbService.generateDemoDb(dbPath);
      if (mounted) {
        ref.read(dbReloadTrigger.notifier).state++;
        setState(() {
          _showLanding = false;
          _generatingDemo = false;
        });
        _startBackgroundSync();
      }
    } catch (e) {
      _log.severe('Demo generation failed: $e');
      if (mounted) setState(() => _generatingDemo = false);
    }
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
      appBar: AppBar(
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
            icon: const Icon(Icons.import_export),
            tooltip: s.tooltipImportExportDb,
            onPressed: () => _showImportExportDialog(context),
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


  Future<void> _showImportExportDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: Text(s.settingsExportDb),
              subtitle: Text(s.importExportExportHint),
              onTap: () => Navigator.pop(ctx, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: Text(s.settingsImportDb),
              subtitle: Text(s.importExportImportHint),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'export') {
      final path = await DbTransferService.exportDb();
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.settingsExportSuccess)),
        );
      }
    } else if (action == 'import') {
      await _importDb(context);
    }
  }

  Future<void> _importDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final db = ref.read(databaseProvider);

    // Check if DB has user data
    final assetCount = (await db.customSelect('SELECT COUNT(*) AS c FROM assets').getSingle()).read<int>('c');
    final accountCount = (await db.customSelect('SELECT COUNT(*) AS c FROM accounts').getSingle()).read<int>('c');

    if (assetCount + accountCount > 0) {
      if (!context.mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.settingsImportWarningTitle),
          content: Text(s.settingsImportWarningBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'export'),
              child: Text(s.settingsExportFirst),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: Text(s.settingsReplaceAnyway),
            ),
          ],
        ),
      );
      if (action == null) return;
      if (action == 'export') {
        final exported = await DbTransferService.exportDb();
        if (exported == null) return; // cancelled
      }
    }

    // Close current DB, import, reload
    if (!context.mounted) return;
    final path = await DbTransferService.importDb();
    if (path == null) return;

    ref.read(dbReloadTrigger.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsImportSuccess)),
      );
    }
  }

  Future<void> _wipeDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    // Force export first
    final exported = await DbTransferService.exportDb();
    if (exported == null) {
      // User cancelled the export — abort wipe
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.settingsWipeCancelled)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Confirm wipe
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning, color: Theme.of(ctx).colorScheme.error),
          const SizedBox(width: 8),
          Text(s.settingsWipeConfirmTitle),
        ]),
        content: Text(s.settingsWipeConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.settingsWipeConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Delete the DB file and reload
    try {
      final path = await DbTransferService.dbPath;
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      ref.read(dbReloadTrigger.notifier).state++;
      if (context.mounted) {
        Navigator.pop(context); // close settings
        setState(() => _showLanding = true);
      }
    } catch (e) {
      _log.severe('Wipe DB failed: $e');
    }
  }

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
            child: SingleChildScrollView(
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 4),
                Text(s.settingsGoogleDrive, style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final sync = ref.read(googleDriveSyncProvider);
                  if (sync.isSignedIn) {
                    return Row(
                      children: [
                        const Icon(Icons.cloud_done, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.settingsSyncSignedIn(sync.userEmail ?? ''),
                            style: Theme.of(ctx).textTheme.bodySmall),
                        ),
                        TextButton(
                          onPressed: () async {
                            await sync.signOut();
                            setDialogState(() {});
                          },
                          child: Text(s.settingsSyncSignOut),
                        ),
                      ],
                    );
                  } else {
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: Text(s.settingsSyncSignIn),
                      onPressed: () async {
                        final ok = await sync.signIn();
                        if (ok) {
                          // Pull remote DB if newer, then start auto-sync
                          _wireSyncCallbacks(sync);
                          final pulled = await sync.pullIfNewerOnStartup();
                          if (pulled) {
                            ref.read(dbReloadTrigger.notifier).state++;
                          }
                          final db = ref.read(databaseProvider);
                          sync.setHasUserData(await _dbHasUserData(db));
                          sync.startAutoSync(_userTableUpdates(db));
                          setDialogState(() {});
                        }
                      },
                    );
                  }
                }),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.settingsWipeDb,
                              style: Theme.of(ctx).textTheme.bodyMedium),
                          Text(s.settingsWipeDbSubtitle,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
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
                      onPressed: () => _wipeDb(ctx),
                      child: Text(s.settingsWipeButton),
                    ),
                  ],
                ),
              ],
            ),
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
