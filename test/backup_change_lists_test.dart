// The change lists of the Backup and Restore confirmations: the edit log
// travels on the backup's Drive metadata (read without a download), and the
// rules turn it into "not backed up yet" / "new in the backup" lists and the
// red tooltip's count.

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/edit_log.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

const _atSync = '2026-10-01T10:00:00.000Z#0001';
const _editedHere = '2026-10-02T10:00:00.000Z#0002';
const _editedThere = '2026-10-03T10:00:00.000Z#0003';

const _accountsAdded = (EditArea.accounts, EditKind.added);
const _rulesChanged = (EditArea.rules, EditKind.changed);
const _assetsDeleted = (EditArea.assets, EditKind.deleted);

const _baseLog = EditLog(changes: 10, tokens: {_accountsAdded: 'a0'});
const _base = SyncBase(lastManualEdit: _atSync, remoteMd5: 'synced-file', editLog: _baseLog);

/// A Drive file stamped with [log], as the app uploads it.
DriveFileInfo _uploaded({required String? edit, required String md5, EditLog? log}) => DriveFileInfo(
  fileId: 'f1',
  modifiedTime: DateTime.utc(2026, 10, 28),
  size: 1,
  md5Checksum: md5,
  appProperties: {
    for (final MapEntry(:key, :value) in {
      ...backupStampProperties(lastManualEdit: edit, schemaVersion: 50, contentMd5: md5),
      if (log != null) ...editLogProperties(log),
    }.entries)
      key: ?value,
  },
);

BackupSyncStatus _resolve({required String? local, required EditLog localLog, required RemoteBackupFacts remote, SyncBase base = _base}) =>
    resolveBackupSync(localEdit: local, localLog: localLog, base: base, remote: remote, schemaVersion: 50);

void main() {
  group('the log on the Drive metadata', () {
    const log = EditLog(changes: 42, tokens: {_accountsAdded: 'k1', _rulesChanged: 'k2', _assetsDeleted: 'k3'});

    test('reads back as written', () {
      expect(RemoteBackupFacts.of(_uploaded(edit: _editedThere, md5: 'm', log: log)).editLog, log);
    });

    test('clears the areas a new upload no longer edits', () {
      final properties = editLogProperties(const EditLog(changes: 1, tokens: {_accountsAdded: 'k1'}));
      expect(properties['edits_accounts'], 'added:k1');
      expect(properties.containsKey('edits_rules'), isTrue);
      expect(properties['edits_rules'], isNull, reason: 'a null deletes the key on Drive');
    });

    test('fits within what Drive allows on a file', () {
      final everything = EditLog(
        changes: 999999999,
        tokens: {
          for (final area in EditArea.values)
            for (final kind in EditKind.values) (area, kind): 'zzzzzzz',
        },
      );
      final properties = {
        'deviceName': 'A-rather-long-device-name.local',
        ...backupStampProperties(lastManualEdit: '2026-10-28T09:00:00.123456Z#ffff', schemaVersion: 50, contentMd5: '0' * 32),
        ...editLogProperties(everything),
      };
      expect(properties.length, lessThanOrEqualTo(30), reason: 'Drive keeps at most 30 properties per app on a file');
      for (final MapEntry(:key, :value) in properties.entries) {
        expect(utf8.encode('$key${value ?? ''}').length, lessThanOrEqualTo(124), reason: '$key: key and value share 124 bytes');
      }
    });

    test('a backup without the log, or no longer matching its stamp, says nothing about its edits', () {
      expect(
        RemoteBackupFacts.of(_uploaded(edit: _editedThere, md5: 'm')).editLog,
        isNull,
        reason: 'made by an app version that does not record it',
      );
      final foreign = _uploaded(edit: _editedThere, md5: 'm', log: log);
      final reuploaded = DriveFileInfo(
        fileId: 'f1',
        modifiedTime: foreign.modifiedTime,
        size: 1,
        md5Checksum: 'other',
        appProperties: foreign.appProperties,
      );
      expect(RemoteBackupFacts.of(reuploaded).editLog, isNull);
    });

    test('a snapshot is described by the log of its data, and an unreadable one by nothing', () async {
      final dir = await Directory.systemTemp.createTemp('fc_change_lists_');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker());
      addTearDown(db.close);
      await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Current'));
      final path = '${dir.path}/snapshot.db';
      await db.vacuumInto(path);

      expect(await describeSnapshotEdits(path), editLogProperties(await db.manualEditLog()));
      expect(await describeSnapshotEdits((File('${dir.path}/garbage.db')..writeAsStringSync('x')).path), isEmpty);
    });
  });

  group('the lists and the count', () {
    const editedHereLog = EditLog(changes: 13, tokens: {_accountsAdded: 'a0', _rulesChanged: 'r1'});
    const editedThereLog = EditLog(changes: 15, tokens: {_accountsAdded: 'a0', _assetsDeleted: 'd1'});

    test('only this device edited: its changes, and how many rows', () {
      final status = _resolve(
        local: _editedHere,
        localLog: editedHereLog,
        remote: RemoteBackupFacts.of(_uploaded(edit: _atSync, md5: 'synced-file', log: _baseLog)),
      );
      expect(status.indicator, BackupSyncIndicator.backupOlder);
      expect(status.localEdits, {_rulesChanged});
      expect(status.remoteEdits, isEmpty);
      expect(status.localChanges, 3);
    });

    test('only the backup edited: its changes, read from the metadata', () {
      final status = _resolve(
        local: _atSync,
        localLog: _baseLog,
        remote: RemoteBackupFacts.of(_uploaded(edit: _editedThere, md5: 'new', log: editedThereLog)),
      );
      expect(status.indicator, BackupSyncIndicator.backupNewer);
      expect(status.remoteEdits, {_assetsDeleted});
      expect(status.localEdits, isEmpty);
      expect(status.localChanges, isNull, reason: 'nothing edited here');
    });

    test('both edited: both lists', () {
      final status = _resolve(
        local: _editedHere,
        localLog: editedHereLog,
        remote: RemoteBackupFacts.of(_uploaded(edit: _editedThere, md5: 'new', log: editedThereLog)),
      );
      expect(status.localEdits, {_rulesChanged});
      expect(status.remoteEdits, {_assetsDeleted});
    });

    test('a sync made before logs were recorded: no lists until the next one', () {
      final status = _resolve(
        local: _editedHere,
        localLog: editedHereLog,
        base: const SyncBase(lastManualEdit: _atSync, remoteMd5: 'synced-file'),
        remote: RemoteBackupFacts.of(_uploaded(edit: _atSync, md5: 'synced-file')),
      );
      expect(status.indicator, BackupSyncIndicator.backupOlder);
      expect((status.localEdits, status.remoteEdits, status.localChanges), (null, null, null));
    });

    test('a backup that carries no log: its list is unknown', () {
      final status = _resolve(
        local: _atSync,
        localLog: _baseLog,
        remote: RemoteBackupFacts.of(_uploaded(edit: _editedThere, md5: 'new')),
      );
      expect(status.indicator, BackupSyncIndicator.backupNewer);
      expect(status.remoteEdits, isNull);
    });

    test('a log of other data than the sync (an imported file): no count', () {
      const imported = EditLog(changes: 2, tokens: {_rulesChanged: 'x'});
      final status = _resolve(
        local: _editedHere,
        localLog: imported,
        remote: RemoteBackupFacts.of(_uploaded(edit: _atSync, md5: 'synced-file', log: _baseLog)),
      );
      expect(status.localChanges, isNull);
      expect(status.localEdits, {_rulesChanged});
    });

    test('the sync base keeps its log, and one saved before logs reads as none', () {
      expect(SyncBase.fromJson(_base.toJson()).editLog, _baseLog);
      expect(SyncBase.fromJson(const {'lastManualEdit': _atSync, 'remoteMd5': 'm'}).editLog, isNull);
    });
  });

  group('wording', () {
    const changes = {
      (EditArea.transactions, EditKind.added),
      (EditArea.assets, EditKind.added),
      (EditArea.settings, EditKind.changed),
      (EditArea.categories, EditKind.deleted),
    };

    test('one line per kind of change, naming the areas it touched', () {
      expect(
        AppStrings.en.syncChangeList('Not backed up yet:', changes),
        'Not backed up yet:\n• Added: account transactions, assets\n• Changed: settings\n• Deleted: categories',
      );
      expect(
        AppStrings.it.syncChangeList('Non ancora nel backup:', changes),
        'Non ancora nel backup:\n• Aggiunte: movimenti dei conti, asset\n• Modifiche: impostazioni\n• Eliminazioni: categorie',
      );
    });

    test('the red tooltip counts the changes', () {
      expect(AppStrings.en.syncBackupOlderCount(1), startsWith('1 change not backed up'));
      expect(AppStrings.en.syncBackupOlderCount(14), startsWith('14 changes not backed up'));
      expect(AppStrings.it.syncBackupOlderCount(1), startsWith('1 modifica non ancora salvata'));
      expect(AppStrings.it.syncBackupOlderCount(14), startsWith('14 modifiche non ancora salvate'));
    });

    test('every area and kind has a name in both languages', () {
      for (final s in [AppStrings.en, AppStrings.it]) {
        expect({for (final area in EditArea.values) s.editAreaName(area)}, hasLength(EditArea.values.length));
        expect({for (final kind in EditKind.values) s.editKindLabel(kind)}, hasLength(EditKind.values.length));
      }
    });
  });
}
