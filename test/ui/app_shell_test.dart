// The app shell: Drive / database transfer flows, the Settings dialog, the
// start-up screens and the background sync, driven through the global-actions
// registry the shell publishes (the same callbacks every AppBar uses).
//
// Pinned bugs:
//  * Export, import (file and landing page) and wipe let their exceptions
//    escape (e.g. a backup from another schema version): nobody was told.
//  * Backup / restore failures appended the raw exception to the message.
//  * The remote backup's date was an ISO-ish string split at the '.', not the
//    locale's date format.
//  * Wiping deleted the SQLite file while its connection was still open (fails
//    on Windows, the error was only logged) — the database is now closed first
//    and a failure is reported.
//  * Snack bars raised from inside the Settings dialog rendered under its modal
//    barrier.
//  * The base-currency change and the settings writes were separate statements:
//    a failing write left the rates re-stamped and the currency half-saved.
//  * The start-up background sync ran syncRates() next to _syncPrices(), which
//    runs it too; and _syncPrices() set its busy flag only after an await, so
//    two overlapping syncs both ran.
//  * 'System Default' and 'Failed to open database' were not localized.
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/network_monitor.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The shell keys the local DB file and the Drive backup by this name; CI
/// always passes `--dart-define=DB_FILE_NAME=…`.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _filePicker = MethodChannel('miguelruivo.flutter.plugins.filepicker');

class _FakeSync extends GoogleDriveSyncService {
  bool signedIn = false;
  bool reauth = false;
  DriveFileInfo? remote;
  Object? backupError;
  Object? restoreError;
  int signIns = 0;
  int backups = 0;
  int restores = 0;

  @override
  bool get isSignedIn => signedIn;

  @override
  String? get userEmail => signedIn ? 'me@example.com' : null;

  @override
  bool get needsReauth => reauth;

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<bool> signIn() async {
    signIns++;
    return false;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<DriveFileInfo?> getRemoteInfo() async => remote;

  @override
  Future<DriveFileInfo> backupToDrive() async {
    backups++;
    if (backupError case final e?) throw e;
    return remote!;
  }

  @override
  Future<DriveFileInfo?> restoreFromDrive() async {
    restores++;
    if (restoreError case final e?) throw e;
    return remote;
  }
}

class _FakePrices extends MarketPriceService {
  _FakePrices(super.db);

  int syncs = 0;
  int cacheClears = 0;
  Completer<void>? gate;

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {
    syncs++;
    await gate?.future;
  }

  @override
  Future<void> clearCache() async => cacheClears++;
}

class _FakeRates extends ExchangeRateService {
  _FakeRates(super.db);

  int syncs = 0;

  @override
  Future<void> syncRates({bool force = false}) async => syncs++;
}

class _FakeCompositions extends CompositionService {
  _FakeCompositions(super.db);

  @override
  Future<void> syncCompositions() async {}
}

class _OnlineMonitor extends NetworkMonitor {
  @override
  Future<bool> check() async => true;
}

/// An in-memory database that records its first close: whether the database
/// file still existed at that moment, and optionally fails.
class _TrackedDb extends AppDatabase {
  _TrackedDb(this.file, {this.failClose = false}) : super.forTesting(NativeDatabase.memory());

  final File file;
  final bool failClose;
  bool? fileExistedAtFirstClose;
  int closes = 0;

  bool _closeStarted = false;

  @override
  Future<void> close() async {
    closes++;
    fileExistedAtFirstClose ??= file.existsSync();
    if (failClose && closes == 1) throw StateError('database is locked');
    if (_closeStarted) return;
    _closeStarted = true;
    // Started once and not awaited: under the test's fake clock drift's close
    // waits for its stream listeners, which only settle between frames. The
    // call order is what these tests check.
    unawaited(super.close());
  }
}

void main() {
  const s = AppStrings.en;
  late Directory dir;
  late File dbFile;
  late _TrackedDb db;
  late List<_TrackedDb> dbs;
  late _FakeSync sync;
  late _FakePrices prices;
  late _FakeRates rates;
  var tempDirFails = false;
  List<Map<String, Object?>>? pickedFiles;
  String? saveResult;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_');
    dbFile = File(p.join(dir.path, _dbFileName));
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    tempDirFails = false;
    pickedFiles = null;
    saveResult = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProvider, (call) async {
      if (call.method == 'getTemporaryDirectory' && tempDirFails) throw PlatformException(code: 'no_temp_dir');
      return dir.path;
    });
    messenger.setMockMethodCallHandler(_filePicker, (call) async {
      return call.method == 'save' ? saveResult : pickedFiles;
    });
    db = _TrackedDb(dbFile);
    dbs = [db];
    sync = _FakeSync();
    prices = _FakePrices(db);
    rates = _FakeRates(db);
  });

  tearDown(() async {
    for (final d in dbs) {
      try {
        await d.close();
      } catch (_) {} // a database made to fail its first close
    }
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProvider, null);
    messenger.setMockMethodCallHandler(_filePicker, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Taps [finder] and lets the flow it starts run through real file I/O (the
  /// export snapshot, the database file, the settings file), alternating real
  /// time with frames until [until] holds (at most ~2 s of real time).
  Future<void> tapWithIo(WidgetTester tester, Finder finder, {required bool Function() until}) async {
    await tester.runAsync(() async => tester.tap(finder));
    for (var i = 0; i < 40 && !until(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);
  }

  bool dialogClosed() => find.byType(AlertDialog).evaluate().isEmpty;
  bool shown(String text) => find.text(text).evaluate().isNotEmpty;

  /// Pumps the shell. Without a database file on disk (or with an empty
  /// database) it settles on the landing page, which keeps the dashboard and
  /// its charts out of these tests after the first frame.
  Future<void> pumpShell(
    WidgetTester tester, {
    bool enableStartupSync = false,
    String language = 'en',
    String locale = 'en_US',
    List extraOverrides = const [],
  }) async {
    // Narrow (bottom-navigation) layout, tall enough for the whole Settings dialog.
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Like production: a reload closes the database and opens a new one.
          databaseProvider.overrideWith((ref) {
            final generation = ref.watch(dbReloadTrigger);
            if (generation >= dbs.length) dbs.add(_TrackedDb(dbFile));
            final current = dbs[generation];
            ref.onDispose(current.close);
            return current;
          }),
          googleDriveSyncProvider.overrideWith((ref) => sync),
          marketPriceServiceProvider.overrideWith((ref) => prices),
          exchangeRateServiceProvider.overrideWith((ref) => rates),
          compositionServiceProvider.overrideWith((ref) => _FakeCompositions(db)),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          ...extraOverrides,
        ],
        child: MaterialApp(home: AppShell(enableStartupSync: enableStartupSync)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  GlobalActionsRegistry registry(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AppShell))).read(globalActionsRegistryProvider)!;

  /// A context inside the landing page's Scaffold, standing in for the AppBar
  /// action that opens a global dialog.
  BuildContext hostContext(WidgetTester tester) => tester.element(find.text(s.landingTitle));

  /// Every snack bar on screen can be hit (none is hidden under a barrier).
  void expectVisibleSnack(String message) {
    expect(find.widgetWithText(SnackBar, message), findsOneWidget);
    expect(find.widgetWithText(SnackBar, message).hitTestable(), findsOneWidget, reason: 'not under a modal barrier');
  }

  /// A SQLite file from another app version (schema 7).
  String writeOldBackup() {
    final path = p.join(dir.path, 'old_backup.db');
    sqlite.sqlite3.open(path)
      ..execute('PRAGMA user_version = 7')
      ..execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY)')
      ..close();
    return path;
  }

  Map<String, Object?> picked(String path) => {'name': p.basename(path), 'path': path, 'size': File(path).lengthSync()};

  group('AppShell', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    testWidgets('re-auth: an 8 s snack with a Sign in action that starts the sign-in', (tester) async {
      dbFile.writeAsBytesSync([]); // a database exists, so start-up restores the Drive session
      sync.reauth = true;
      await pumpShell(tester);
      try {
        final bar = tester.widget<SnackBar>(find.widgetWithText(SnackBar, s.syncReauthNeeded));
        expect(bar.duration, const Duration(seconds: 8));
        expect(bar.action?.label, s.settingsSyncSignIn);

        await tester.tap(find.text(s.settingsSyncSignIn));
        await settle(tester);
        expect(sync.signIns, 1);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a database that cannot be opened is reported in the UI language', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) => throw StateError('disk full')),
            portableLanguageProvider.overrideWith((ref) => 'it'),
          ],
          child: const FinanceCopilotApp(enableStartupSync: false),
        ),
      );
      await tester.pump();
      try {
        expect(find.text(AppStrings.it.dbOpenFailed(StateError('disk full'))), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('landing: a database from another app version is refused with a message', (tester) async {
      pickedFiles = [picked(writeOldBackup())];
      await pumpShell(tester);
      try {
        await tester.tap(find.text(s.landingImportDb));
        await settle(tester);

        expectVisibleSnack(s.dbSchemaMismatch(7, db.schemaVersion));
        expect(find.text(s.landingTitle), findsOneWidget, reason: 'still on the landing page');
      } finally {
        await unmount(tester);
      }
    });

    group('Import / Export dialog', () {
      Future<void> choose(WidgetTester tester, String action) async {
        unawaited(registry(tester).showImportExportDialog(hostContext(tester)));
        await settle(tester);
        await tester.tap(find.text(action));
        await settle(tester);
      }

      testWidgets('a failing export is reported', (tester) async {
        await pumpShell(tester);
        tempDirFails = true;
        try {
          await choose(tester, s.settingsExportDb);
          expectVisibleSnack(s.dbExportFailed);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('importing a database from another app version is refused with a message', (tester) async {
        pickedFiles = [picked(writeOldBackup())];
        await pumpShell(tester);
        try {
          await choose(tester, s.settingsImportDb);
          expectVisibleSnack(s.dbSchemaMismatch(7, db.schemaVersion));
        } finally {
          await unmount(tester);
        }
      });

      group('Drive', () {
        final modified = DateTime.utc(2026, 1, 2, 3, 4, 5);

        setUp(() {
          sync.signedIn = true;
          sync.remote = DriveFileInfo(fileId: 'f1', modifiedTime: modified, size: 2048, deviceName: 'Laptop');
        });

        /// The remote backup as the confirmations quote it, in the it_IT format.
        String remoteInfo() => s.importExportRemoteInfo('2,0 KB', DateFormat.yMMMd('it_IT').add_Hm().format(modified.toLocal()), 'Laptop');

        testWidgets('backup: confirmation quotes the remote backup in the locale format; confirm backs up', (tester) async {
          await pumpShell(tester, locale: 'it_IT');
          try {
            await choose(tester, s.importExportBackupDrive);
            final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
            expect((alert.title! as Text).data, s.importExportBackupConfirmTitle);
            expect((alert.content! as Text).data, s.importExportBackupConfirmBody(remoteInfo()));
            final confirm = find.widgetWithText(FilledButton, s.importExportBackupDrive);
            expect(tester.widget<FilledButton>(confirm).style, isNull, reason: 'the confirm button keeps the default colour');

            await tester.tap(find.widgetWithText(TextButton, s.cancel));
            await settle(tester);
            expect(sync.backups, 0);

            await choose(tester, s.importExportBackupDrive);
            await tester.tap(find.widgetWithText(FilledButton, s.importExportBackupDrive));
            await settle(tester);
            expect(sync.backups, 1);
            expectVisibleSnack(s.importExportBackupSuccess);
          } finally {
            await unmount(tester);
          }
        });

        testWidgets('backup failure: a localized message, not the raw error', (tester) async {
          sync.backupError = Exception('HTTP 500 token=secret');
          await pumpShell(tester);
          try {
            await choose(tester, s.importExportBackupDrive);
            await tester.tap(find.widgetWithText(FilledButton, s.importExportBackupDrive));
            await settle(tester);
            expectVisibleSnack(s.importExportBackupFailed);
            expect(find.textContaining('secret'), findsNothing);
          } finally {
            await unmount(tester);
          }
        });

        testWidgets('restore: red confirmation quoting the remote backup; confirm restores and reloads', (tester) async {
          await pumpShell(tester, locale: 'it_IT');
          try {
            await choose(tester, s.importExportRestoreDrive);
            final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
            expect((alert.title! as Text).data, s.importExportRestoreConfirmTitle);
            expect((alert.content! as Text).data, s.importExportRestoreConfirmBody(remoteInfo()));
            final confirm = find.widgetWithText(FilledButton, s.importExportRestoreDrive);
            expect(tester.widget<FilledButton>(confirm).style?.backgroundColor?.resolve({}), Colors.red);

            await tester.tap(confirm);
            await settle(tester);
            expect(sync.restores, 1);
            final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
            expect(container.read(dbReloadTrigger), 1, reason: 'the restored database is reopened');
            expectVisibleSnack(s.importExportRestoreSuccess);
          } finally {
            await unmount(tester);
          }
        });

        testWidgets('restore of a backup from another app version: the reason, not the raw error', (tester) async {
          sync.restoreError = const SchemaVersionMismatchException(localVersion: 50, remoteVersion: 7);
          await pumpShell(tester);
          try {
            await choose(tester, s.importExportRestoreDrive);
            await tester.tap(find.widgetWithText(FilledButton, s.importExportRestoreDrive));
            await settle(tester);
            expectVisibleSnack(s.dbSchemaMismatch(7, 50));
            expect(find.textContaining('SchemaVersionMismatchException'), findsNothing);
          } finally {
            await unmount(tester);
          }
        });
      });
    });

    group('Settings dialog', () {
      Future<void> openSettings(WidgetTester tester) async {
        unawaited(registry(tester).showSettingsDialog(hostContext(tester)));
        await settle(tester);
        expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget);
      }

      Finder taxField() => find.widgetWithText(TextFormField, s.settingsDefaultTaxRate);

      Future<String?> config(String key) async => (await (db.select(db.appConfigs)..where((c) => c.key.equals(key))).getSingleOrNull())?.value;

      testWidgets('the system-default number format is labelled in the UI language', (tester) async {
        await pumpShell(tester, language: 'it');
        try {
          unawaited(registry(tester).showSettingsDialog(tester.element(find.text(AppStrings.it.landingTitle))));
          await settle(tester);
          await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
          await settle(tester);
          expect(find.text(AppStrings.it.systemDefault), findsWidgets);
          expect(find.text('System Default'), findsNothing);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Cancel with the tax field focused closes without saving', (tester) async {
        await pumpShell(tester);
        try {
          await openSettings(tester);
          await tester.enterText(taxField(), '30');
          await tester.tap(find.widgetWithText(TextButton, s.cancel));
          await settle(tester);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('TAX_RATE'), '0.26');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Save keeps the stored base currency and tax rate the dialog opened with', (tester) async {
        await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: 'GBP'));
        await db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: 'TAX_RATE', value: '0.3'));
        await pumpShell(tester);
        try {
          await openSettings(tester);
          expect(find.text('GBP'), findsOneWidget);
          expect(tester.widget<TextFormField>(taxField()).controller!.text, '30');
          await tapWithIo(tester, find.widgetWithText(FilledButton, s.save), until: dialogClosed);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('BASE_CURRENCY'), 'GBP');
          expect(await config('TAX_RATE'), '0.3');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Save with the tax field focused stores the typed rate', (tester) async {
        await pumpShell(tester);
        try {
          await openSettings(tester);
          // The shell runs in en_US here: the rate is typed in its spelling.
          await tester.enterText(taxField(), '26.5');
          await tester.pump();
          // Saving writes the portable language file: real I/O.
          await tapWithIo(tester, find.widgetWithText(FilledButton, s.save), until: dialogClosed);

          expect(find.byType(AlertDialog), findsNothing);
          expect(await config('TAX_RATE'), '0.265');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('a base-currency change is saved atomically: a failing write changes nothing and is reported', (tester) async {
        final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
        final asset = await db
            .into(db.assets)
            .insert(
              AssetsCompanion.insert(
                name: 'Fund',
                assetType: AssetType.stockEtf,
                valuationMethod: ValuationMethod.marketPrice,
                intermediaryId: broker,
                currency: const Value('USD'),
              ),
            );
        await db
            .into(db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                assetId: asset,
                date: DateTime(2025, 1, 1),
                valueDate: DateTime(2025, 1, 1),
                type: EventType.buy,
                amount: 100,
                quantity: const Value(1),
                price: const Value(110),
                exchangeRate: const Value(1.1),
              ),
            );
        // The last of the settings writes fails.
        await db.customStatement(
          "CREATE TRIGGER fail_tax BEFORE INSERT ON app_configs WHEN NEW.key = 'TAX_RATE' "
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        await pumpShell(tester);
        try {
          await openSettings(tester);
          await tester.tap(find.byType(DropdownButtonFormField<String>).first);
          await settle(tester);
          await tester.tap(find.text('USD').last);
          await settle(tester);
          await tester.tap(find.widgetWithText(FilledButton, s.save));
          await settle(tester);

          expect(await config('BASE_CURRENCY'), 'EUR');
          final event = await db.select(db.assetEvents).getSingle();
          expect(event.exchangeRateBase, isNull, reason: 'the rate re-stamping rolled back with the failed save');
          expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget, reason: 'the dialog stays open to retry');
          expect(find.text(s.settingsSaveFailed), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Clear cache: nothing is shown under the dialog; the confirmation is visible once it closes', (tester) async {
        await pumpShell(tester);
        try {
          await openSettings(tester);
          await tester.tap(find.text(s.settingsClearButton));
          await settle(tester);
          expect(prices.cacheClears, 1);
          expect(find.byType(SnackBar), findsNothing, reason: 'a snack bar here would sit under the dialog barrier');

          await tester.tap(find.widgetWithText(TextButton, s.cancel));
          await settle(tester);
          expectVisibleSnack(s.settingsCacheCleared);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Export & Wipe: a cancelled export is reported where it can be seen and wipes nothing', (tester) async {
        dbFile.writeAsBytesSync([]);
        await pumpShell(tester);
        try {
          await openSettings(tester);
          await tapWithIo(tester, find.text(s.settingsWipeButton), until: () => shown(s.settingsWipeCancelled));

          expectVisibleSnack(s.settingsWipeCancelled);
          expect(dbFile.existsSync(), isTrue);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Export & Wipe: a failing export is reported and wipes nothing', (tester) async {
        dbFile.writeAsBytesSync([]);
        await pumpShell(tester);
        tempDirFails = true;
        try {
          await openSettings(tester);
          await tester.tap(find.text(s.settingsWipeButton));
          await settle(tester);

          expectVisibleSnack(s.settingsWipeExportFailed);
          expect(dbFile.existsSync(), isTrue);
        } finally {
          await unmount(tester);
        }
      });

      Future<void> exportAndConfirmWipe(WidgetTester tester) async {
        saveResult = p.join(dir.path, 'exported.db');
        await openSettings(tester);
        await tapWithIo(tester, find.text(s.settingsWipeButton), until: () => shown(s.settingsWipeConfirmBody));
        expect(find.text(s.settingsWipeConfirmBody), findsOneWidget);
        await tapWithIo(
          tester,
          find.widgetWithText(FilledButton, s.settingsWipeConfirm),
          until: () => !dbFile.existsSync() || shown(s.settingsWipeFailed),
        );
      }

      testWidgets('Export & Wipe: the database is closed before its file is deleted, then reopened empty', (tester) async {
        dbFile.writeAsBytesSync([]);
        await pumpShell(tester);
        try {
          await exportAndConfirmWipe(tester);

          expect(db.fileExistedAtFirstClose, isTrue, reason: 'closed while its file was still there');
          expect(dbFile.existsSync(), isFalse);
          final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
          expect(container.read(databaseProvider), isNot(same(db)), reason: 'a fresh database replaces the closed one');
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text(s.landingTitle), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Export & Wipe: a database that cannot be closed is not deleted and the user is told', (tester) async {
        dbFile.writeAsBytesSync([]);
        db = _TrackedDb(dbFile, failClose: true);
        dbs = [db];
        await pumpShell(tester);
        try {
          await exportAndConfirmWipe(tester);

          expect(dbFile.existsSync(), isTrue);
          expectVisibleSnack(s.settingsWipeFailed);
        } finally {
          await unmount(tester);
        }
      });
    });

    group('Background sync', () {
      List onlineOverrides() => [networkMonitorProvider.overrideWith((ref) => _OnlineMonitor())];

      testWidgets('one background sync refreshes the exchange rates once', (tester) async {
        await pumpShell(tester, enableStartupSync: true, extraOverrides: onlineOverrides());
        try {
          await registry(tester).retryNetwork();
          await settle(tester);
          expect(prices.syncs, 1);
          expect(rates.syncs, 1);
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('overlapping background syncs share one price sync', (tester) async {
        await pumpShell(tester, enableStartupSync: true, extraOverrides: onlineOverrides());
        prices.gate = Completer<void>();
        final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
        try {
          unawaited(registry(tester).retryNetwork());
          unawaited(registry(tester).retryNetwork());
          await settle(tester);
          expect(prices.syncs, 1);
          expect(container.read(isManualSyncingProvider), isTrue);

          prices.gate!.complete();
          await settle(tester);
          expect(prices.syncs, 1);
          expect(rates.syncs, 1);
          expect(container.read(isManualSyncingProvider), isFalse);
        } finally {
          await unmount(tester);
        }
      });
    });
  });
}
