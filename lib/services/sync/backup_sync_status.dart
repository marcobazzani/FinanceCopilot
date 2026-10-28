import 'package:finance_copilot/database/manual_edit_tracker.dart' show manualEditTime;
import 'package:finance_copilot/services/sync/backup_stamp.dart';

/// The LED on the import/export icon.
enum BackupSyncIndicator {
  /// Nothing to do, or nothing known: a click opens the Import/Export dialog.
  off,

  /// The Drive backup holds newer manual edits: a click offers to restore it.
  backupNewer,

  /// This device holds manual edits the backup lacks: a click offers a backup.
  backupOlder,
}

/// What the sync indicator shows, and what the Backup and Restore
/// confirmations must warn about.
class BackupSyncStatus {
  const BackupSyncStatus({
    this.indicator = BackupSyncIndicator.off,
    this.backupOverwritesRemoteEdits = false,
    this.restoreDiscardsLocalEdits = false,
  });

  static const off = BackupSyncStatus();

  final BackupSyncIndicator indicator;

  /// The backup holds manual edits this device lacks: backing up overwrites
  /// them.
  final bool backupOverwritesRemoteEdits;

  /// This device holds manual edits the backup lacks: restoring discards them.
  final bool restoreDiscardsLocalEdits;

  @override
  bool operator ==(Object other) =>
      other is BackupSyncStatus &&
      other.indicator == indicator &&
      other.backupOverwritesRemoteEdits == backupOverwritesRemoteEdits &&
      other.restoreDiscardsLocalEdits == restoreDiscardsLocalEdits;

  @override
  int get hashCode => Object.hash(indicator, backupOverwritesRemoteEdits, restoreDiscardsLocalEdits);

  @override
  String toString() => 'BackupSyncStatus($indicator, overwritesRemote: $backupOverwritesRemoteEdits, discardsLocal: $restoreDiscardsLocalEdits)';
}

/// This device's last backup or restore: the manual-edit stamp its data had
/// then, and the content checksum of the Drive file it matched.
class SyncBase {
  const SyncBase({required this.lastManualEdit, required this.remoteMd5});

  factory SyncBase.fromJson(Map<String, Object?> json) =>
      SyncBase(lastManualEdit: json['lastManualEdit'] as String?, remoteMd5: json['remoteMd5'] as String?);

  final String? lastManualEdit;
  final String? remoteMd5;

  Map<String, Object?> toJson() => {'lastManualEdit': lastManualEdit, 'remoteMd5': remoteMd5};
}

/// Compares this device's last manual edit ([localEdit]) with the Drive
/// backup's ([remote], null until a lookup answered), both against this
/// device's last backup or restore ([base]).
///
/// The LED stays off until this device has backed up or restored once (no
/// [base]): before that nothing tells which side holds edits the other lacks.
/// Only one side edited since: the LED points at the other. Both edited: the
/// later edit wins, and both confirmations warn. A backup made by another
/// schema version is never offered for restore, which would refuse it.
BackupSyncStatus resolveBackupSync({
  required String? localEdit,
  required SyncBase? base,
  required RemoteBackupFacts? remote,
  required int schemaVersion,
}) {
  if (base == null || remote == null) return BackupSyncStatus.off;
  if (!remote.exists) return const BackupSyncStatus(indicator: BackupSyncIndicator.backupOlder);

  final localEdited = localEdit != base.lastManualEdit;
  final bool remoteEdited;
  if (remote.md5 != null && remote.md5 == base.remoteMd5) {
    remoteEdited = false; // the very file this device last synced with
  } else if (remote.stamped) {
    remoteEdited = remote.lastManualEdit != base.lastManualEdit;
  } else {
    // Replaced by an app version that does not stamp: what it holds is unknown.
    return BackupSyncStatus.off;
  }

  if (!localEdited && !remoteEdited) return BackupSyncStatus.off;
  if (!remoteEdited) {
    return const BackupSyncStatus(indicator: BackupSyncIndicator.backupOlder, restoreDiscardsLocalEdits: true);
  }
  if (remote.lastManualEdit == localEdit) return BackupSyncStatus.off; // the same edits on both sides

  final restorable = remote.schemaVersion == schemaVersion;
  final backupWins = !localEdited || _isLater(remote.lastManualEdit, localEdit);
  return BackupSyncStatus(
    indicator: backupWins ? (restorable ? BackupSyncIndicator.backupNewer : BackupSyncIndicator.off) : BackupSyncIndicator.backupOlder,
    backupOverwritesRemoteEdits: true,
    restoreDiscardsLocalEdits: localEdited,
  );
}

/// Whether manual edit [a] was made after [b]. A missing or unreadable stamp
/// is the oldest; on a tie this device's edit wins.
bool _isLater(String? a, String? b) {
  final timeA = a == null ? null : manualEditTime(a);
  final timeB = b == null ? null : manualEditTime(b);
  if (timeA == null) return false;
  if (timeB == null) return true;
  return timeA.isAfter(timeB);
}
