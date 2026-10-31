// The change lists through the app shell: the Backup confirmation lists what
// is not backed up yet, the Restore confirmation what is new in the backup
// (read from its Drive metadata, nothing downloaded), each with what the
// other side holds when both changed; the warning stays last.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/edit_log.dart';
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

const _dbFileName = String.fromEnvironment('DB_FILE_NAME');
const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _account = 'me@example.com';
const _later = '2099-01-01T00:00:00.000Z#beef';
const s = AppStrings.en;

/// A Drive file stamped, with its edit log, as the app uploads it.
DriveFileInfo _uploaded({required String? edit, required String md5, required EditLog log}) => DriveFileInfo(
  fileId: 'f1',
  modifiedTime: DateTime.utc(2026, 10, 28, 9),
  size: 2048,
  deviceName: 'Pixel 7a',
  md5Checksum: md5,
  appProperties: {
    for (final MapEntry(:key, :value) in {
      ...backupStampProperties(lastManualEdit: edit, schemaVersion: 50, contentMd5: md5),
      ...editLogProperties(log),
    }.entries)
      key: ?value,
  },
);

/// What another device edited: account transactions.
const _editedThere = EditLog(changes: 4, tokens: {(EditArea.transactions, EditKind.changed): 'there1'});

class _FakeSync extends GoogleDriveSyncService {
  _FakeSync(this.db);

  final AppDatabase db;
  DriveFileInfo? remote;
  int backups = 0;
  int restores = 0;

  @override
  bool get isSignedIn => true;

  @override
  String? get userEmail => _account;

  @override
  Future<bool> trySilentSignIn() async => false;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async => remote;

  @override
  Future<DriveFileInfo> backupToDrive() async {
    backups++;
    return remote = _uploaded(edit: await db.lastManualEdit(), md5: 'uploaded', log: await db.manualEditLog());
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
    dir = await Directory.systemTemp.createTemp('fc_shell_change_lists_');
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

  /// This device last synced with the file 'synced', when nothing had been
  /// edited yet; [editedHere] then adds an intermediary by hand.
  Future<void> given(WidgetTester tester, {required bool editedHere}) => tester.runAsync(() async {
    await const SettingsSyncBaseStore().write(_account, const SyncBase(lastManualEdit: null, remoteMd5: 'synced', editLog: EditLog.empty));
    if (editedHere) await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Edited here'));
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

  Future<void> refreshAndClick(WidgetTester tester) async {
    unawaited(registry(tester).manualRefresh());
    await settle(tester);
    unawaited(registry(tester).openSyncIndicator!(tester.element(find.text(s.landingTitle))));
    await settle(tester);
  }

  String dialogText(WidgetTester tester) => (tester.widget<AlertDialog>(find.byType(AlertDialog)).content! as Text).data!;

  final notBackedUp = s.syncChangeList(s.syncNotBackedUpYet, {(EditArea.intermediaries, EditKind.added)});
  final onlyHere = s.syncChangeList(s.syncOnlyOnThisDevice, {(EditArea.intermediaries, EditKind.added)});
  final onlyOnDrive = s.syncChangeList(s.syncOnlyOnDrive, {(EditArea.transactions, EditKind.changed)});
  final newInBackup = s.syncChangeList(s.syncNewInBackup, {(EditArea.transactions, EditKind.changed)});

  group('AppShell change lists', skip: _dbFileName.isEmpty ? 'needs --dart-define=DB_FILE_NAME=<name>' : null, () {
    setUp(() => sync = _FakeSync(db));

    testWidgets('red: the Backup confirmation lists what is not backed up yet; the tooltip counts it', (tester) async {
      await given(tester, editedHere: true);
      sync.remote = _uploaded(edit: null, md5: 'synced', log: EditLog.empty);
      await pumpShell(tester);
      try {
        await refreshAndClick(tester);
        expect(status(tester).indicator, BackupSyncIndicator.backupOlder);
        expect(status(tester).localChanges, 1);

        expect(find.text(s.importExportBackupConfirmTitle), findsOneWidget);
        expect(dialogText(tester), endsWith('\n\n$notBackedUp'));
        expect(dialogText(tester), isNot(contains(s.syncOnlyOnDrive)));

        // Backed up: the backup now holds this device's log; nothing left to list.
        await tester.tap(find.widgetWithText(FilledButton, s.importExportBackupDrive));
        await settle(tester);
        expect(sync.backups, 1);
        expect(status(tester).indicator, BackupSyncIndicator.off);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('green: the Restore confirmation lists what is new in the backup, from its metadata', (tester) async {
      await given(tester, editedHere: false);
      sync.remote = _uploaded(edit: _later, md5: 'newer', log: _editedThere);
      await pumpShell(tester);
      try {
        await refreshAndClick(tester);
        expect(status(tester).indicator, BackupSyncIndicator.backupNewer);

        expect(find.text(s.importExportRestoreConfirmTitle), findsOneWidget);
        expect(dialogText(tester), endsWith('\n\n$newInBackup'));
        expect(sync.restores, 0, reason: 'listed without restoring or downloading anything');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('both changed: each confirmation lists both sides, its warning last', (tester) async {
      await given(tester, editedHere: true);
      sync.remote = _uploaded(edit: _later, md5: 'newer', log: _editedThere);
      await pumpShell(tester);
      try {
        await refreshAndClick(tester);
        expect(dialogText(tester), endsWith('\n\n$newInBackup\n\n$onlyHere\n\n${s.syncRestoreDiscardsLocalEdits}'));

        await tester.tap(find.widgetWithText(TextButton, s.syncMoreOptions));
        await settle(tester);
        await tester.tap(find.text(s.importExportBackupDrive));
        await settle(tester);
        expect(dialogText(tester), endsWith('\n\n$notBackedUp\n\n$onlyOnDrive\n\n${s.syncBackupOverwritesRemoteEdits}'));
      } finally {
        await unmount(tester);
      }
    });
  });
}
