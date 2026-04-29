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
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'database/database.dart';
import 'database/providers.dart';
import 'l10n/app_strings.dart';
import 'services/app_settings.dart';
import 'services/import_service.dart';
import 'services/db_transfer_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/google_drive_sync_service.dart';
import 'services/providers/providers.dart';

import 'ui/screens/accounts_screen.dart';
import 'ui/screens/assets_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/import/import_screen.dart';
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
  _log.info('FinanceCopilot v$appVersionDisplay starting up');
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
  bool _isSyncing = false;
  bool _showLanding = false;
  bool _syncingDrive = false;
  final _repaintKey = GlobalKey();
  StreamSubscription? _shareIntentSub;

  List<NavigationDestination> _destinations(AppStrings s) => [
    NavigationDestination(icon: const Icon(Icons.dashboard), label: s.navDashboard),
    NavigationDestination(icon: const Icon(Icons.account_balance), label: s.navAccounts),
    NavigationDestination(icon: const Icon(Icons.pie_chart), label: s.navAssets),
  ];

  List<(IconData, String)> _sidebarItems(AppStrings s) => [
    (Icons.dashboard, s.navDashboard),
    (Icons.account_balance, s.navAccounts),
    (Icons.pie_chart, s.navAssets),
  ];

  @override
  void initState() {
    super.initState();
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

  void _initShareIntent() {
    // Handle file shared while app was closed
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleSharedFiles(files);
    });
    // Handle file shared while app is running
    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleSharedFiles);
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final path = files.first.path;
    final ext = path.toLowerCase().split('.').last;
    if (!{'csv', 'xlsx', 'xls', 'tsv'}.contains(ext)) {
      _log.warning('Shared file ignored (unsupported type): $path');
      return;
    }
    _log.info('Received shared file: $path');
    if (mounted) _showShareImportDialog(path);
  }

  Future<void> _showShareImportDialog(String filePath) async {
    final s = ref.read(appStringsProvider);
    final accounts = ref.read(accountsProvider).value ?? [];
    var target = ImportTarget.transaction;
    int? accountId = accounts.isNotEmpty ? accounts.first.id : null;

    final result = await showModalBottomSheet<(ImportTarget, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.importTitle, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(filePath.split('/').last, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 20),
              Text(s.importAs, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<ImportTarget>(
                segments: [
                  ButtonSegment(value: ImportTarget.transaction, icon: const Icon(Icons.receipt_long, size: 18), label: Text(s.importTypeTransaction, style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: ImportTarget.assetEvent, icon: const Icon(Icons.trending_up, size: 18), label: Text(s.importTypeAssetEvent, style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: ImportTarget.income, icon: const Icon(Icons.payments, size: 18), label: Text(s.importTypeIncome, style: const TextStyle(fontSize: 12))),
                ],
                selected: {target},
                onSelectionChanged: (v) => setSheetState(() => target = v.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                showSelectedIcon: false,
              ),
              if (target == ImportTarget.transaction && accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.selectAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setSheetState(() => accountId = v),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, (target, target == ImportTarget.transaction ? accountId : null)),
                  child: Text(s.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final (selectedTarget, selectedAccountId) = result;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImportScreen(
        initialFilePath: filePath,
        preselectedTarget: selectedTarget,
        preselectedAccountId: selectedAccountId,
      )),
    );
  }

  @override
  void dispose() {
    _shareIntentSub?.cancel();
    super.dispose();
  }

  /// Restore the Drive sign-in session silently (if possible) so the manual
  /// Backup/Restore buttons in Import/Export can call Drive without an
  /// interactive prompt every time. We do NOT auto-pull or auto-push — all
  /// Drive operations are explicit user actions; see _backupToDrive /
  /// _restoreFromDrive in the Import/Export dialog.
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
    sync.copyFromAttached = (tmpPath) => _mergeRemoteDb(tmpPath);
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

  /// Merge the contents of a downloaded remote DB file into the currently
  /// open drift instance. Called from GoogleDriveSyncService._download via
  /// the `copyFromAttached` callback.
  ///
  /// Uses SQLite `ATTACH DATABASE` to expose the remote file as `src`, then
  /// for every user table in `src`: DELETE FROM main + INSERT FROM SELECT.
  /// Everything runs inside a single drift transaction — either the whole
  /// merge succeeds or it rolls back leaving local data untouched.
  ///
  /// This avoids the Windows file-lock problem (no close, no file swap) and
  /// the drift-close concurrent-modification bug entirely.
  Future<void> _mergeRemoteDb(String tmpPath) async {
    final db = ref.read(databaseProvider);
    // Escape single quotes in the path for SQL string literal safety.
    final sqlPath = tmpPath.replaceAll("'", "''");
    await db.customStatement("ATTACH DATABASE '$sqlPath' AS src");
    try {
      // Discover user tables in the source DB. Exclude SQLite's schema table
      // and Android's auto-generated metadata table, but we DO want
      // `sqlite_sequence` so AUTOINCREMENT counters stay in sync — otherwise
      // the next insert locally could reuse an ID already present in the
      // data we just copied.
      final rows = await db.customSelect(
        "SELECT name FROM src.sqlite_master "
        "WHERE type='table' "
        "AND name NOT LIKE 'sqlite_stat%' "
        "AND name NOT IN ('sqlite_master', 'sqlite_temp_master', 'android_metadata')",
      ).get();
      final tables = rows.map((r) => r.read<String>('name')).toList();
      _log.info('_mergeRemoteDb: copying ${tables.length} tables from $tmpPath');

      await db.transaction(() async {
        // FK constraints would fire during intermediate states while we wipe
        // and repopulate tables. Disable them for the duration of the copy —
        // we trust the remote DB is internally consistent.
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in tables) {
          try {
            // Use column intersection so schema differences (extra columns in
            // either the source or target) don't cause INSERT failures.
            final srcCols = (await db.customSelect('PRAGMA src.table_info("$table")').get())
                .map((r) => r.read<String>('name'))
                .toSet();
            final dstCols = (await db.customSelect('PRAGMA main.table_info("$table")').get())
                .map((r) => r.read<String>('name'))
                .toSet();
            final common = srcCols.intersection(dstCols);
            if (common.isEmpty) {
              _log.warning('_mergeRemoteDb: no common columns for $table, skipping');
              continue;
            }
            final cols = common.map((c) => '"$c"').join(', ');
            await db.customStatement('DELETE FROM main."$table"');
            await db.customStatement(
              'INSERT INTO main."$table" ($cols) SELECT $cols FROM src."$table"',
            );
          } catch (e) {
            _log.warning('_mergeRemoteDb: failed to copy table $table: $e');
            rethrow;
          }
        }
      });
      _log.info('_mergeRemoteDb: merge committed');
    } finally {
      try {
        await db.customStatement('DETACH DATABASE src');
      } catch (e) {
        _log.warning('_mergeRemoteDb: DETACH failed (harmless): $e');
      }
    }
  }

  /// Full manual refresh: pull from Google Drive, then refresh market data.
  /// Keeps the `_isSyncing` spinner active for the entire duration so the UI
  /// reflects that work is in progress even during the Drive pull phase.
  /// Each step is best-effort -- failures don't block subsequent steps.
  Future<void> _manualRefresh() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
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

      try {
        await ref.read(compositionServiceProvider).syncCompositions();
      } catch (e) {
        _log.warning('Manual refresh: composition sync failed: $e');
      }
    } catch (e) {
      _log.warning('Manual refresh error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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

    setState(() => _isSyncing = true);
    try {
      _log.info('Starting market price sync (forceToday=$forceToday)...');
      await Future.wait([
        ref.read(marketPriceServiceProvider).syncPrices(forceToday: forceToday),
        ref.read(exchangeRateServiceProvider).syncRates(force: forceToday),
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
            onPressed: _isSyncing ? null : _manualRefresh,
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
    final sync = ref.read(googleDriveSyncProvider);
    final isSignedIn = sync.isSignedIn;
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: Text(s.importExportBackupDrive),
              subtitle: Text(isSignedIn ? s.importExportBackupDriveHint : s.importExportSignInFirst),
              enabled: isSignedIn,
              onTap: isSignedIn ? () => Navigator.pop(ctx, 'backup') : null,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: Text(s.importExportRestoreDrive),
              subtitle: Text(isSignedIn ? s.importExportRestoreDriveHint : s.importExportSignInFirst),
              enabled: isSignedIn,
              onTap: isSignedIn ? () => Navigator.pop(ctx, 'restore') : null,
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
        showInfoSnack(context, s.settingsExportSuccess);
      }
    } else if (action == 'import') {
      await _importDb(context);
    } else if (action == 'backup') {
      await _backupToDrive(context);
    } else if (action == 'restore') {
      await _restoreFromDrive(context);
    }
  }

  String _formatRemoteInfo(AppStrings s, DriveFileInfo info) {
    final size = _formatBytes(info.size);
    final date = '${info.modifiedTime.toLocal()}'.split('.').first;
    return s.importExportRemoteInfo(size, date, info.deviceName);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _backupToDrive(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);

    // Pre-flight: show the user what will be overwritten on Drive.
    final existing = await sync.getRemoteInfo();
    if (!context.mounted) return;
    final remoteInfo = existing != null ? _formatRemoteInfo(s, existing) : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportBackupConfirmTitle),
        content: Text(s.importExportBackupConfirmBody(remoteInfo)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.importExportBackupDrive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await sync.backupToDrive();
      if (!context.mounted) return;
      showInfoSnack(context, s.importExportBackupSuccess);
    } catch (e) {
      _log.warning('backupToDrive failed: $e');
      if (!context.mounted) return;
      showInfoSnack(context, '${s.importExportBackupFailed}: $e');
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final sync = ref.read(googleDriveSyncProvider);

    // Pre-flight: show the user what will be pulled from Drive.
    final existing = await sync.getRemoteInfo();
    if (!context.mounted) return;
    if (existing == null) {
      showInfoSnack(context, s.importExportRestoreEmpty);
      return;
    }
    final remoteInfo = _formatRemoteInfo(s, existing);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importExportRestoreConfirmTitle),
        content: Text(s.importExportRestoreConfirmBody(remoteInfo)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.importExportRestoreDrive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      _wireSyncCallbacks(sync);
      final restored = await sync.restoreFromDrive();
      if (!context.mounted) return;
      if (restored == null) {
        showInfoSnack(context, s.importExportRestoreEmpty);
        return;
      }
      ref.read(dbReloadTrigger.notifier).state++;
      showInfoSnack(context, s.importExportRestoreSuccess);
    } catch (e) {
      _log.warning('restoreFromDrive failed: $e');
      if (!context.mounted) return;
      showInfoSnack(context, '${s.importExportRestoreFailed}: $e');
    }
  }

  Future<void> _importDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);
    final db = ref.read(databaseProvider);

    if (await _dbHasUserData(db)) {
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
      showInfoSnack(context, s.settingsImportSuccess);
    }
  }

  Future<void> _wipeDb(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    // Force export first
    final exported = await DbTransferService.exportDb();
    if (exported == null) {
      // User cancelled the export — abort wipe
      if (context.mounted) {
        showInfoSnack(context, s.settingsWipeCancelled);
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
                          // Just sign in. Backup/Restore are explicit user
                          // actions in the Import/Export dialog.
                          _wireSyncCallbacks(sync);
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
