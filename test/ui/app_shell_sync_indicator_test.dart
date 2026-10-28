// The sync indicator through the app shell: Refresh looks the Drive backup up
// and lights the LED; a click opens the Restore or Backup confirmation, which
// warns about edits it would lose and offers the Import/Export dialog; a
// backup or a restore records the sync, which turns the LED off.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/app_actions_controller.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/network_monitor.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';
import 'package:finance_copilot/services/sync/sync_base_store.dart';

/// The shell keys the local DB file and the Drive backup by this name; CI
/// always passes `--dart-define=DB_FILE_NAME=…`.
const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _account = 'me@example.com';
const _later = '2099-01-01T00:00:00.000Z#beef';
const s = AppStrings.en;

/// A Drive file stamped as a backup last edited by hand at [edit].
DriveFileInfo _stamped({required String? edit, required String md5}) => DriveFileInfo(
  fileId: 'f1',
  modifiedTime: DateTime.utc(2026, 10, 28, 9),
  size: 2048,
  deviceName: 'Laptop',
  md5Checksum: md5,
  appProperties: {
    for (final MapEntry(:key, :value) in backupStampProperties(lastManualEdit: edit, schemaVersion: 50, contentMd5: md5).entries) key: ?value,
  },
);

class _FakeSync extends GoogleDriveSyncService {
  _FakeSync(this.db);

  final AppDatabase db;
  DriveFileInfo? remote;
  int lookups = 0;
  int backups = 0;
  int restores = 0;

  @override
  bool get isSignedIn => true;

  @override
  String? get userEmail => _account;

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async {
    lookups++;
    return remote;
  }

  /// Uploads this device's data as it is now.
  @override
  Future<DriveFileInfo> backupToDrive() async {
    backups++;
    return remote = _stamped(edit: await db.lastManualEdit(), md5: 'uploaded');
  }

  @override
  Future<DriveFileInfo?> restoreFromDrive() async {
    restores++;
    return remote;
  }
}

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

class _OnlineMonitor extends NetworkMonitor {
  @override
  Future<bool> check() async => true;
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late _FakeSync sync;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fc_shell_sync_indicator_');
    AppSettings.resetForTesting();
    AppSettings.testConfigDir = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pathProvider, (call) async => dir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker());
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

  /// This device's state before the shell starts: [editedHere] adds a manual
  /// edit, [synced] is the last backup or restore it remembers.
  Future<void> given(WidgetTester tester, {required bool editedHere, required SyncBase? synced}) => tester.runAsync(() async {
    if (editedHere) await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Edited here'));
    if (synced != null) await const SettingsSyncBaseStore().write(_account, synced);
    // Loads the settings file now: under the test clock its I/O would not complete.
    await AppSettings.get('language');
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(599, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          googleDriveSyncProvider.overrideWith((ref) => sync),
          marketPriceServiceProvider.overrideWith((ref) => _OfflinePrices(db)),
          networkMonitorProvider.overrideWith((ref) => _OnlineMonitor()),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
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

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(AppShell)));
  GlobalActionsRegistry registry(WidgetTester tester) => container(tester).read(globalActionsRegistryProvider)!;
  BackupSyncStatus status(WidgetTester tester) => container(tester).read(backupSyncStatusProvider);

  /// A context inside the landing page, standing in for the AppBar icon.
  BuildContext host(WidgetTester tester) => tester.element(find.text(s.landingTitle));

  Future<void> refresh(WidgetTester tester) async {
    unawaited(registry(tester).manualRefresh());
    await settle(tester);
  }

  Future<void> clickIndicator(WidgetTester tester) async {
    unawaited(registry(tester).openSyncIndicator!(host(tester)));
    await settle(tester);
  }

  String dialogText(WidgetTester tester) => (tester.widget<AlertDialog>(find.byType(AlertDialog)).content! as Text).data!;

  group('AppShell sync indicator', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    setUp(() => sync = _FakeSync(db));

    testWidgets('Refresh finds a newer backup: green; the Restore confirmation warns and leads to the dialog', (tester) async {
      await given(tester, editedHere: true, synced: const SyncBase(lastManualEdit: null, remoteMd5: 'synced'));
      sync.remote = _stamped(edit: _later, md5: 'newer');
      await pumpShell(tester);
      try {
        await refresh(tester);
        expect(sync.lookups, 1);
        expect(status(tester).indicator, BackupSyncIndicator.backupNewer);

        await clickIndicator(tester);
        expect(find.text(s.importExportRestoreConfirmTitle), findsOneWidget);
        expect(dialogText(tester), endsWith(s.syncRestoreDiscardsLocalEdits), reason: 'this device has edits the backup lacks');

        await tester.tap(find.widgetWithText(TextButton, s.syncMoreOptions));
        await settle(tester);
        expect(find.text(s.importExportTitle), findsOneWidget);
        expect(sync.restores, 0);

        // From the dialog, a backup instead: it warns that the newer backup is overwritten.
        await tester.tap(find.text(s.importExportBackupDrive));
        await settle(tester);
        expect(dialogText(tester), endsWith(s.syncBackupOverwritesRemoteEdits));
        expect(find.widgetWithText(TextButton, s.syncMoreOptions), findsNothing, reason: 'not opened from the indicator');

        await tester.tap(find.widgetWithText(FilledButton, s.importExportBackupDrive));
        await settle(tester);
        expect(sync.backups, 1);
        expect(status(tester).indicator, BackupSyncIndicator.off, reason: 'the backup now holds this device data');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an edit since the last sync: red; the Backup confirmation, cancelled, backs nothing up', (tester) async {
      await given(tester, editedHere: true, synced: const SyncBase(lastManualEdit: null, remoteMd5: 'synced'));
      sync.remote = _stamped(edit: null, md5: 'synced');
      await pumpShell(tester);
      try {
        await refresh(tester);
        expect(status(tester).indicator, BackupSyncIndicator.backupOlder);

        await clickIndicator(tester);
        expect(find.text(s.importExportBackupConfirmTitle), findsOneWidget);
        expect(dialogText(tester), isNot(contains(s.syncBackupOverwritesRemoteEdits)), reason: 'the backup holds nothing this device lacks');
        expect(find.widgetWithText(TextButton, s.syncMoreOptions), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(sync.backups, 0);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a restore from the indicator records the sync: the LED goes off', (tester) async {
      await given(tester, editedHere: false, synced: const SyncBase(lastManualEdit: null, remoteMd5: 'synced'));
      sync.remote = _stamped(edit: _later, md5: 'newer');
      await pumpShell(tester);
      try {
        await refresh(tester);
        expect(status(tester).indicator, BackupSyncIndicator.backupNewer);

        await clickIndicator(tester);
        expect(dialogText(tester), isNot(contains(s.syncRestoreDiscardsLocalEdits)), reason: 'nothing edited here since the sync');
        await tester.tap(find.widgetWithText(FilledButton, s.importExportRestoreDrive));
        await settle(tester);

        expect(sync.restores, 1);
        expect(status(tester).indicator, BackupSyncIndicator.off);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('never synced on this device: off, and the click opens the Import/Export dialog', (tester) async {
      await given(tester, editedHere: true, synced: null);
      sync.remote = _stamped(edit: _later, md5: 'newer');
      await pumpShell(tester);
      try {
        await refresh(tester);
        expect(status(tester).indicator, BackupSyncIndicator.off);

        await clickIndicator(tester);
        expect(find.text(s.importExportTitle), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
