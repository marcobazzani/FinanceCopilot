import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('BackupStamp');

/// App-property keys a backup is stamped with (see [backupStampProperties]).
const _lastManualEditKey = 'lastManualEdit';
const _schemaVersionKey = 'schemaVersion';
const _contentMd5Key = 'contentMd5';

/// The app properties stamped on a backup: when its data was last edited by
/// hand ([lastManualEdit], null when never), its [schemaVersion], and the
/// checksum of the snapshot uploaded ([contentMd5]). The checksum lets a later
/// lookup tell whether the stamp still describes the file: an app version that
/// does not stamp leaves the old properties on a new upload. A null value
/// deletes the key on Drive, which keeps every key an upload does not mention.
Map<String, String?> backupStampProperties({required String? lastManualEdit, required int schemaVersion, required String contentMd5}) => {
  _lastManualEditKey: lastManualEdit,
  _schemaVersionKey: '$schemaVersion',
  _contentMd5Key: contentMd5,
};

/// [backupStampProperties] for the snapshot file at [snapshotPath]. Empty
/// when the snapshot cannot be read: the backup still goes up, unstamped.
Future<Map<String, String?>> describeBackupSnapshot(String snapshotPath) async {
  try {
    final facts = AppDatabase.readSnapshotFacts(snapshotPath);
    final checksum = await md5.bind(File(snapshotPath).openRead()).first;
    return backupStampProperties(lastManualEdit: facts.lastManualEdit, schemaVersion: facts.schemaVersion, contentMd5: '$checksum');
  } catch (e, st) {
    _log.warning('Could not describe the backup snapshot; uploading it unstamped', e, st);
    return const {};
  }
}

/// The Drive backup as a lookup found it.
class RemoteBackupFacts {
  /// No backup on Drive.
  const RemoteBackupFacts.none() : exists = false, md5 = null, stamped = false, lastManualEdit = null, schemaVersion = null;

  const RemoteBackupFacts({required this.md5, required this.stamped, this.lastManualEdit, this.schemaVersion}) : exists = true;

  /// Reads the stamp on [info] (null: no backup). The stamp counts only while
  /// it matches the file's content.
  factory RemoteBackupFacts.of(DriveFileInfo? info) {
    if (info == null) return const RemoteBackupFacts.none();
    final properties = info.appProperties;
    final stamped = info.md5Checksum != null && properties[_contentMd5Key] == info.md5Checksum;
    return RemoteBackupFacts(
      md5: info.md5Checksum,
      stamped: stamped,
      lastManualEdit: stamped ? properties[_lastManualEditKey] : null,
      schemaVersion: stamped ? int.tryParse(properties[_schemaVersionKey] ?? '') : null,
    );
  }

  final bool exists;

  /// Drive's checksum of the backup's content.
  final String? md5;

  /// Whether the stamp describes this content (else the backup was uploaded
  /// by an app version that does not stamp it).
  final bool stamped;

  /// When the backup's data was last edited by hand (null: never, or not
  /// [stamped]).
  final String? lastManualEdit;

  /// The backup's drift schema version, when [stamped].
  final int? schemaVersion;
}
