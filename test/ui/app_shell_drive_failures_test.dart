// The app shell tells the user when a Drive step did not happen, in their
// language, where it can be seen. Driven through the global-actions registry
// the shell publishes (the callbacks every AppBar uses) and the landing page.
//
// Pinned bugs:
//  * The remote-backup lookup swallowed its errors, so a failed lookup read as
//    "no backup": Backup went on to create a second remote file, Restore said
//    there was nothing to restore. The lookup now fails, and the shell reports
//    it and stops before the confirmation.
//  * An interactive sign-in that did not complete (cancelled, no browser, no
//    consent in time, the account did not answer) returned false and every
//    caller ignored it: from Settings, the landing page and the re-auth snack
//    bar the user got no message at all.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// The shell keys the local DB file and the Drive backup by this name; CI
/// always passes `--dart-define=DB_FILE_NAME=…`.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

class _FakeSync extends GoogleDriveSyncService {
  bool signedIn = false;
  bool reauth = false;

  /// What the next interactive sign-ins answer.
  bool signInSucceeds = false;

  /// Thrown by the remote-backup lookup, when set.
  Object? lookupError;

  int signIns = 0;
  int lookups = 0;
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
    return signedIn = signInSucceeds;
  }

  @override
  Future<void> signOut() async => signedIn = false;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async {
    lookups++;
    if (lookupError case final e?) throw e;
    return null;
  }

  @override
  Future<DriveFileInfo> backupToDrive() async {
    backups++;
    throw StateError('not expected in these tests');
  }

  @override
  Future<DriveFileInfo?> restoreFromDrive() async {
    restores++;
    return null;
  }
}

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late _FakeSync sync;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_drive_failures_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _FakeSync();
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, null);
    AppSettings.resetForTesting();
    await dir.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Pumps the shell. Without a database file on disk (or with an empty
  /// database) it settles on the landing page.
  Future<void> pumpShell(WidgetTester tester, {String language = 'en'}) async {
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          googleDriveSyncProvider.overrideWith((ref) => sync),
          marketPriceServiceProvider.overrideWith((ref) => _OfflinePrices(db)),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en_US')),
        ],
        child: const MaterialApp(home: AppShell(enableStartupSync: false)),
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
  BuildContext hostContext(WidgetTester tester, AppStrings s) => tester.element(find.text(s.landingTitle));

  void expectVisibleSnack(String message) {
    expect(find.widgetWithText(SnackBar, message), findsOneWidget);
    expect(find.widgetWithText(SnackBar, message).hitTestable(), findsOneWidget, reason: 'not under a modal barrier');
  }

  group('AppShell', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    group('a Drive backup lookup that fails', () {
      Future<void> choose(WidgetTester tester, AppStrings s, String action) async {
        unawaited(registry(tester).showImportExportDialog(hostContext(tester, s)));
        await settle(tester);
        await tester.tap(find.text(action));
        await settle(tester);
      }

      setUp(() {
        sync.signedIn = true;
        sync.lookupError = Exception('HTTP 500 token=secret');
      });

      testWidgets('stops the backup before its confirmation and is reported as a failed backup', (tester) async {
        const s = AppStrings.it;
        await pumpShell(tester, language: 'it');
        try {
          await choose(tester, s, s.importExportBackupDrive);

          expect(sync.lookups, 1);
          expect(find.byType(AlertDialog), findsNothing, reason: 'no confirmation claiming there is no backup to overwrite');
          expect(sync.backups, 0, reason: 'nothing is backed up: a second remote backup must never be created');
          expectVisibleSnack(s.importExportBackupFailed);
          expect(find.textContaining('secret'), findsNothing, reason: 'the raw error only goes to the log');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('is reported as a failed restore, not as "no backup on Drive"', (tester) async {
        const s = AppStrings.en;
        await pumpShell(tester);
        try {
          await choose(tester, s, s.importExportRestoreDrive);

          expect(find.byType(AlertDialog), findsNothing);
          expect(sync.restores, 0);
          expectVisibleSnack(s.importExportRestoreFailed);
          expect(find.text(s.importExportRestoreEmpty), findsNothing);
        } finally {
          await unmount(tester);
        }
      });
    });

    group('an interactive sign-in that does not complete', () {
      Future<void> openSettings(WidgetTester tester, AppStrings s) async {
        unawaited(registry(tester).showSettingsDialog(hostContext(tester, s)));
        await settle(tester);
        expect(find.widgetWithText(AlertDialog, s.settingsTitle), findsOneWidget);
      }

      Finder inSettings(Finder finder) => find.descendant(of: find.widgetWithText(AlertDialog, AppStrings.en.settingsTitle), matching: finder);

      testWidgets('Settings: is said in the dialog, in the UI language', (tester) async {
        const s = AppStrings.it;
        await pumpShell(tester, language: 'it');
        try {
          await openSettings(tester, s);
          expect(find.text(s.driveSignInFailed), findsNothing);

          await tester.tap(find.text(s.settingsSyncSignIn));
          await settle(tester);

          expect(sync.signIns, 1);
          expect(
            find.descendant(of: find.widgetWithText(AlertDialog, s.settingsTitle), matching: find.text(s.driveSignInFailed)),
            findsOneWidget,
            reason: 'in place: a snack bar would sit under the dialog barrier',
          );
          expect(find.byType(SnackBar), findsNothing);
          expect(find.text(s.settingsSyncSignIn), findsOneWidget, reason: 'the user can try again');
          expect(s.driveSignInFailed, isNot(AppStrings.en.driveSignInFailed));
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('Settings: a retry that signs in clears the message and shows the account', (tester) async {
        const s = AppStrings.en;
        await pumpShell(tester);
        try {
          await openSettings(tester, s);
          await tester.tap(find.text(s.settingsSyncSignIn));
          await settle(tester);
          expect(inSettings(find.text(s.driveSignInFailed)), findsOneWidget);

          sync.signInSucceeds = true;
          await tester.tap(find.text(s.settingsSyncSignIn));
          await settle(tester);

          expect(sync.signIns, 2);
          expect(find.text(s.driveSignInFailed), findsNothing);
          expect(inSettings(find.text(s.settingsSyncSignedIn('me@example.com'))), findsOneWidget);
          expect(sync.createSnapshot, isNotNull, reason: 'the signed-in session is wired for Backup/Restore');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('landing page: is reported, nothing is restored and the landing page stays', (tester) async {
        const s = AppStrings.it;
        await pumpShell(tester, language: 'it');
        try {
          await tester.tap(find.text(s.landingSyncDrive));
          await settle(tester);

          expect(sync.signIns, 1);
          expect(sync.restores, 0);
          expectVisibleSnack(s.driveSignInFailed);
          expect(find.text(s.landingTitle), findsOneWidget);
          expect(find.text(s.landingSyncDrive), findsOneWidget, reason: 'the user can try again');
        } finally {
          await unmount(tester);
        }
      });

      testWidgets('re-auth snack bar: its Sign in action is reported when it does not complete', (tester) async {
        const s = AppStrings.en;
        File(p.join(dir.path, _dbFileName)).writeAsBytesSync([]); // a database exists: start-up restores the Drive session
        sync.reauth = true;
        await pumpShell(tester);
        try {
          expect(find.widgetWithText(SnackBar, s.syncReauthNeeded), findsOneWidget);

          await tester.tap(find.widgetWithText(SnackBarAction, s.settingsSyncSignIn));
          await settle(tester);
          await settle(tester);

          expect(sync.signIns, 1);
          expectVisibleSnack(s.driveSignInFailed);
        } finally {
          await unmount(tester);
        }
      });
    });
  });
}
