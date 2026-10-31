import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/edit_log.dart';
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

/// App-property keys of a backup's [EditLog]: its row count, and one key per
/// area holding the tokens of the kinds of change made to it.
const _editsCountKey = 'edits_n';
String _editsKeyOf(EditArea area) => 'edits_${area.name}';

/// The app properties carrying [log] on a backup, so a lookup tells what it
/// holds without downloading it. Every area is written, null when it has no
/// edits: Drive keeps the keys an upload does not mention.
Map<String, String?> editLogProperties(EditLog log) => {
  _editsCountKey: '${log.changes}',
  for (final area in EditArea.values)
    _editsKeyOf(area): [
      for (final kind in EditKind.values)
        if (log.tokens[(area, kind)] case final token?) '${kind.name}:$token',
    ].join(',').nullIfEmpty,
};

/// [editLogProperties] for the snapshot file at [snapshotPath]. Empty when
/// the snapshot cannot be read: the backup goes up without the list of what
/// it holds.
Future<Map<String, String?>> describeSnapshotEdits(String snapshotPath) async {
  try {
    return editLogProperties(AppDatabase.readSnapshotFacts(snapshotPath).editLog);
  } catch (e, st) {
    _log.warning('Could not read the edit log of the backup snapshot', e, st);
    return const {};
  }
}

/// The [EditLog] carried by [properties]; null when the backup carries none
/// (made by an app version that does not write it).
EditLog? _editLogOf(Map<String, String> properties) {
  final changes = int.tryParse(properties[_editsCountKey] ?? '');
  if (changes == null) return null;
  final kinds = EditKind.values.asNameMap();
  final tokens = <EditChange, String>{
    for (final area in EditArea.values)
      for (final entry in (properties[_editsKeyOf(area)] ?? '').split(','))
        if (entry.split(':') case [final name, final token])
          if (kinds[name] case final kind?) (area, kind): token,
  };
  return EditLog(changes: changes, tokens: tokens);
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// The Drive backup as a lookup found it.
class RemoteBackupFacts {
  /// No backup on Drive.
  const RemoteBackupFacts.none() : exists = false, md5 = null, stamped = false, lastManualEdit = null, schemaVersion = null, editLog = null;

  const RemoteBackupFacts({required this.md5, required this.stamped, this.lastManualEdit, this.schemaVersion, this.editLog}) : exists = true;

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
      editLog: stamped ? _editLogOf(properties) : null,
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

  /// What was edited by hand in the backup's data, when [stamped] by an app
  /// version that records it.
  final EditLog? editLog;
}
