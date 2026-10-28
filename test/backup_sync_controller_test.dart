// The controller behind the sync indicator: it publishes newer / older / same
// from this device's manual edits, the Drive backup's stamp and this device's
// last backup or restore, and keeps that sync base in memory so Backup and
// Restore never wait on the settings file.

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/backup_sync_controller.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';
import 'package:finance_copilot/services/sync/sync_base_store.dart';

class _FakeDrive implements RemoteBackupProbe {
  @override
  bool isSignedIn = true;

  @override
  String? userEmail = 'me@example.com';

  DriveFileInfo? remote;
  Object? lookupError;
  int lookups = 0;

  @override
  Future<DriveFileInfo?> getRemoteInfo() async {
    lookups++;
    if (lookupError case final e?) throw e;
    return remote;
  }
}

class _MemoryStore implements SyncBaseStore {
  final bases = <String, SyncBase>{};
  Completer<void>? readGate;

  @override
  Future<SyncBase?> read(String account) async {
    await readGate?.future;
    return bases[account];
  }

  @override
  Future<void> write(String account, SyncBase base) async => bases[account] = base;

  @override
  Future<void> clear() async => bases.clear();
}

/// A Drive file stamped as a backup whose data was last edited by hand at
/// [edit], with content checksum [md5].
DriveFileInfo _backup({required String? edit, required String md5, int schemaVersion = 50}) => DriveFileInfo(
  fileId: 'f1',
  modifiedTime: DateTime.utc(2026, 10, 28),
  size: 1,
  md5Checksum: md5,
  appProperties: {
    for (final MapEntry(:key, :value) in backupStampProperties(lastManualEdit: edit, schemaVersion: schemaVersion, contentMd5: md5).entries)
      key: ?value,
  },
);

const _later = '2099-01-01T00:00:00.000Z#beef';

void main() {
  late AppDatabase db;
  late _FakeDrive drive;
  late _MemoryStore store;
  late List<BackupSyncStatus> published;
  late BackupSyncController controller;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker());
    drive = _FakeDrive();
    store = _MemoryStore();
    published = [];
    controller = BackupSyncController(drive: drive, store: store, database: () => db, publish: published.add)..attach(db);
    await pumpEventQueue();
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  BackupSyncIndicator? shown() => published.isEmpty ? null : published.last.indicator;

  Future<void> editByHand([String name = 'Edited']) async {
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: name));
    await pumpEventQueue();
  }

  /// This device backed up its current data (file [md5]).
  Future<void> backUp(String md5) async => controller.backedUp(_backup(edit: await db.lastManualEdit(), md5: md5));

  test('off until this device backed up or restored once, whatever Drive holds', () async {
    await editByHand();
    drive.remote = _backup(edit: _later, md5: 'there');
    await controller.checkDrive();

    expect(drive.lookups, 1);
    expect(shown(), BackupSyncIndicator.off);
  });

  test('a backup brings it in sync; the next manual edit turns it red at once', () async {
    await editByHand();
    await backUp('m1');
    expect(shown(), BackupSyncIndicator.off);
    expect(store.bases['me@example.com']?.remoteMd5, 'm1', reason: 'the sync is saved');

    await editByHand('After the backup');
    expect(shown(), BackupSyncIndicator.backupOlder, reason: 'no Drive lookup needed');
    expect(published.last.restoreDiscardsLocalEdits, isTrue);
  });

  test('provider writes after a backup leave it in sync', () async {
    await editByHand();
    await backUp('m1');
    await automaticWrites(() => db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Provider')));
    await controller.refresh();
    expect(shown(), BackupSyncIndicator.off);
  });

  test('a newer backup from another device turns it green', () async {
    await editByHand();
    await backUp('m1');

    drive.remote = _backup(edit: _later, md5: 'm2');
    await controller.checkDrive();

    expect(published.last, const BackupSyncStatus(indicator: BackupSyncIndicator.backupNewer, backupOverwritesRemoteEdits: true));
  });

  test('a failed lookup keeps what was last known', () async {
    await editByHand();
    await backUp('m1');
    drive.remote = _backup(edit: _later, md5: 'm2');
    await controller.checkDrive();

    drive.lookupError = const SocketException('offline');
    await controller.checkDrive();

    expect(shown(), BackupSyncIndicator.backupNewer);
  });

  test('a restore takes the restored data as the sync', () async {
    final restored = _backup(edit: _later, md5: 'm2');
    // The restore copied the backup's data and stamp here.
    await automaticWrites(
      () => db.into(db.appConfigs).insertOnConflictUpdate(AppConfigsCompanion.insert(key: kLastManualEditKey, value: _later)),
    );

    await controller.restored(restored);

    expect(shown(), BackupSyncIndicator.off);
    expect(store.bases['me@example.com']?.lastManualEdit, _later);
  });

  test('a backup that could not be stamped records this device edit as the sync', () async {
    await editByHand();
    await controller.backedUp(DriveFileInfo(fileId: 'f1', modifiedTime: DateTime.utc(2026), size: 1, md5Checksum: 'm1'));

    expect(store.bases['me@example.com']?.lastManualEdit, await db.lastManualEdit());
    expect(shown(), BackupSyncIndicator.off);
  });

  test('a Backup or Restore confirmation feeds in the backup it looked up', () async {
    await editByHand();
    await backUp('m1');
    await controller.sawBackup(null);
    expect(shown(), BackupSyncIndicator.backupOlder, reason: 'the backup was deleted from Drive');
  });

  test('signing out turns it off; another account starts without a sync', () async {
    await editByHand();
    await backUp('m1');
    await editByHand('More');
    expect(shown(), BackupSyncIndicator.backupOlder);

    drive.isSignedIn = false;
    controller.signedOut();
    await pumpEventQueue();
    expect(shown(), BackupSyncIndicator.off);

    drive
      ..isSignedIn = true
      ..userEmail = 'other@example.com'
      ..remote = _backup(edit: null, md5: 'other');
    await controller.checkDrive();
    await pumpEventQueue();
    expect(shown(), BackupSyncIndicator.off);
  });

  test('a wiped database forgets the sync', () async {
    await editByHand();
    await backUp('m1');
    await editByHand('More');

    controller.forgetSync();
    await pumpEventQueue();

    expect(shown(), BackupSyncIndicator.off);
    expect(store.bases, isEmpty);
  });

  test('the sync base loads in the background; a sync recorded meanwhile wins over the late load', () async {
    final gated = _MemoryStore()
      ..readGate = Completer<void>()
      ..bases['me@example.com'] = const SyncBase(lastManualEdit: 'stale', remoteMd5: 'stale');
    final later = <BackupSyncStatus>[];
    final c = BackupSyncController(drive: drive, store: gated, database: () => db, publish: later.add)..attach(db);
    addTearDown(c.dispose);
    await editByHand();
    await c.refresh();
    expect(later.last.indicator, BackupSyncIndicator.off, reason: 'not loaded yet');

    await c.backedUp(_backup(edit: await db.lastManualEdit(), md5: 'fresh'));
    gated.readGate!.complete();
    await pumpEventQueue();
    await c.refresh();

    expect(later.last.indicator, BackupSyncIndicator.off);
    expect(gated.bases['me@example.com']?.remoteMd5, 'fresh');
  });

  test('a database that cannot be read publishes nothing', () async {
    await editByHand();
    await backUp('m1');
    final before = published.length;
    await db.close();

    await controller.refresh();

    expect(published, hasLength(before));
  });

  group('SettingsSyncBaseStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fc_sync_base_');
      AppSettings.resetForTesting();
      AppSettings.testConfigDir = dir;
    });

    tearDown(() async {
      AppSettings.resetForTesting();
      await dir.delete(recursive: true);
    });

    test('keeps one sync per account and database file, and forgets them all', () async {
      const prod = SettingsSyncBaseStore(databaseName: 'prod.db');
      const dev = SettingsSyncBaseStore(databaseName: 'dev.db');
      await prod.write('a@example.com', const SyncBase(lastManualEdit: 's1', remoteMd5: 'm1'));
      await prod.write('b@example.com', const SyncBase(lastManualEdit: null, remoteMd5: 'm2'));

      expect((await prod.read('a@example.com'))?.lastManualEdit, 's1');
      expect((await prod.read('b@example.com'))?.remoteMd5, 'm2');
      expect(await dev.read('a@example.com'), isNull, reason: 'dev and prod builds never share a sync');

      await prod.clear();
      expect(await prod.read('a@example.com'), isNull);
    });
  });
}
