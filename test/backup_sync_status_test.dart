// The sync indicator's rules: compare this device's last manual edit with the
// Drive backup's, both against this device's last backup or restore.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';

const _schema = 50;
const _atSync = '2026-10-01T10:00:00.000Z#0001';
const _editedHere = '2026-10-02T10:00:00.000Z#0002';
const _editedThere = '2026-10-03T10:00:00.000Z#0003';
const _base = SyncBase(lastManualEdit: _atSync, remoteMd5: 'synced-file');

RemoteBackupFacts _stamped(String? edit, {String md5 = 'new-file', int schema = _schema}) =>
    RemoteBackupFacts(md5: md5, stamped: true, lastManualEdit: edit, schemaVersion: schema);

BackupSyncStatus _resolve({String? local = _atSync, SyncBase? base = _base, required RemoteBackupFacts? remote}) =>
    resolveBackupSync(localEdit: local, base: base, remote: remote, schemaVersion: _schema);

const _newer = BackupSyncIndicator.backupNewer;
const _older = BackupSyncIndicator.backupOlder;
const _off = BackupSyncIndicator.off;

void main() {
  group('off until this device knows a sync', () {
    test('never backed up or restored here: off, whatever the backup holds', () {
      expect(_resolve(base: null, local: _editedHere, remote: _stamped(_editedThere)), BackupSyncStatus.off);
    });

    test('no lookup answered yet: off', () {
      expect(_resolve(local: _editedHere, remote: null), BackupSyncStatus.off);
    });
  });

  test('the backup was deleted from Drive: older', () {
    expect(_resolve(remote: const RemoteBackupFacts.none()).indicator, _older);
  });

  group('same', () {
    test('nothing edited on either side', () {
      expect(_resolve(remote: _stamped(_atSync, md5: 'synced-file')), BackupSyncStatus.off);
    });

    test('backed up again elsewhere without manual edits (only provider data changed)', () {
      expect(_resolve(remote: _stamped(_atSync, md5: 'reuploaded')), BackupSyncStatus.off);
    });

    test('both sides hold the very same edits', () {
      expect(_resolve(local: _editedThere, remote: _stamped(_editedThere)), BackupSyncStatus.off);
    });
  });

  group('older (red)', () {
    test('only this device was edited', () {
      expect(
        _resolve(
          local: _editedHere,
          remote: _stamped(_atSync, md5: 'synced-file'),
        ),
        const BackupSyncStatus(indicator: _older, restoreDiscardsLocalEdits: true),
      );
    });

    test('only this device was edited, against the unstamped file it last synced with', () {
      const legacy = RemoteBackupFacts(md5: 'synced-file', stamped: false);
      expect(_resolve(local: _editedHere, remote: legacy).indicator, _older);
    });

    test('only this device was edited, and the backup is from another schema version', () {
      expect(
        _resolve(
          local: _editedHere,
          remote: _stamped(_atSync, md5: 'synced-file', schema: 49),
        ).indicator,
        _older,
      );
    });
  });

  group('newer (green)', () {
    test('only the backup was edited (another device backed up)', () {
      expect(_resolve(remote: _stamped(_editedThere)), const BackupSyncStatus(indicator: _newer, backupOverwritesRemoteEdits: true));
    });

    test('never edited here since the sync, edits on Drive', () {
      expect(
        _resolve(
          local: null,
          base: const SyncBase(lastManualEdit: null, remoteMd5: 'synced-file'),
          remote: _stamped(_editedThere),
        ).indicator,
        _newer,
      );
    });

    test('but never for a backup from another schema version, which restore refuses', () {
      expect(_resolve(remote: _stamped(_editedThere, schema: 51)), const BackupSyncStatus(backupOverwritesRemoteEdits: true));
    });
  });

  group('both edited since the sync: the later edit wins, both confirmations warn', () {
    test('the backup was edited later', () {
      expect(
        _resolve(local: _editedHere, remote: _stamped(_editedThere)),
        const BackupSyncStatus(indicator: _newer, backupOverwritesRemoteEdits: true, restoreDiscardsLocalEdits: true),
      );
    });

    test('this device was edited later', () {
      expect(
        _resolve(local: _editedThere, remote: _stamped(_editedHere)),
        const BackupSyncStatus(indicator: _older, backupOverwritesRemoteEdits: true, restoreDiscardsLocalEdits: true),
      );
    });

    test('a backup edit stamp this app cannot read counts as the older one', () {
      expect(_resolve(local: _editedHere, remote: _stamped('garbled')).indicator, _older);
    });

    test('later but from another schema version: not offered for restore', () {
      expect(_resolve(local: _editedHere, remote: _stamped(_editedThere, schema: 51)).indicator, _off);
    });
  });

  test('replaced by an app version that does not stamp backups: off, its content is unknown', () {
    const foreign = RemoteBackupFacts(md5: 'someone-else', stamped: false);
    expect(_resolve(local: _editedHere, remote: foreign), BackupSyncStatus.off);
  });

  group('RemoteBackupFacts.of', () {
    test('no file: no backup', () {
      expect(RemoteBackupFacts.of(null).exists, isFalse);
    });
  });

  test('SyncBase survives its JSON round trip', () {
    final back = SyncBase.fromJson(_base.toJson());
    expect((back.lastManualEdit, back.remoteMd5), (_atSync, 'synced-file'));
  });
}
