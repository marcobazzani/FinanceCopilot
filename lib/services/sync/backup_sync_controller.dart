import 'dart:async';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';
import 'package:finance_copilot/services/sync/sync_base_store.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('BackupSync');

/// Keeps the sync indicator ([BackupSyncStatus]) up to date: compares this
/// device's last manual edit with the one stamped on the Drive backup,
/// against this device's last backup or restore ([SyncBase]).
///
/// Backup and Restore flows never wait on the settings file: each account's
/// sync base is loaded once in the background, then kept in memory with every
/// change saved behind it.
class BackupSyncController {
  BackupSyncController({
    required RemoteBackupProbe drive,
    required SyncBaseStore store,
    required AppDatabase Function() database,
    required void Function(BackupSyncStatus status) publish,
  }) : _drive = drive,
       _store = store,
       _database = database,
       _publish = publish;

  final RemoteBackupProbe _drive;
  final SyncBaseStore _store;
  final AppDatabase Function() _database;
  final void Function(BackupSyncStatus status) _publish;

  /// The Drive backup as last looked up; null until a lookup answered.
  RemoteBackupFacts? _remote;

  /// The sync base in memory, and the account it belongs to (null: not
  /// loaded yet).
  SyncBase? _base;
  String? _baseAccount;
  String? _loadingAccount;

  /// Bumped by every change to the base, so a load finishing late never
  /// overwrites it.
  int _baseRevision = 0;

  int _evaluations = 0;
  StreamSubscription<void>? _edits;
  bool _disposed = false;

  String get _account => _drive.userEmail ?? '';

  /// Follows the manual edits made on [db] (again after each reload).
  void attach(AppDatabase db) {
    unawaited(_edits?.cancel());
    _edits = db.manualEdits?.edits.listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Looks up the Drive backup, then re-evaluates. A failed lookup keeps what
  /// was last known.
  Future<void> checkDrive() async {
    if (_drive.isSignedIn) {
      try {
        _remote = RemoteBackupFacts.of(await _drive.getRemoteInfo());
      } catch (e) {
        _log.info('Backup check: the Drive lookup failed, keeping the last state: $e');
      }
    }
    await refresh();
  }

  /// Takes the backup a Backup or Restore confirmation just looked up.
  Future<void> sawBackup(DriveFileInfo? info) {
    _remote = RemoteBackupFacts.of(info);
    return refresh();
  }

  /// A backup went up: it holds what the uploaded snapshot held.
  Future<void> backedUp(DriveFileInfo uploaded) async {
    final remote = _remote = RemoteBackupFacts.of(uploaded);
    final edit = remote.stamped ? remote.lastManualEdit : await _localEdit();
    _setBase(SyncBase(lastManualEdit: edit, remoteMd5: uploaded.md5Checksum));
    await refresh();
  }

  /// A restore replaced this device's data with the backup's. Called before
  /// the database reloads, while it still reads the restored data.
  Future<void> restored(DriveFileInfo restored) async {
    _remote = RemoteBackupFacts.of(restored);
    _setBase(SyncBase(lastManualEdit: await _localEdit(), remoteMd5: restored.md5Checksum));
    await refresh();
  }

  /// The database starts over (it was wiped): the LED stays off until its
  /// first backup or restore, whichever account signs in.
  void forgetSync() {
    _baseRevision++;
    _base = null;
    _baseAccount = _account;
    _loadingAccount = null;
    unawaited(_store.clear().then((_) {}, onError: (Object e) => _log.warning('Backup check: could not forget the last sync: $e')));
    unawaited(refresh());
  }

  /// Signed out: nothing to compare with until the next lookup.
  void signedOut() {
    _remote = null;
    unawaited(refresh());
  }

  /// Re-evaluates from what is known, without asking Drive.
  Future<void> refresh() async {
    final evaluation = ++_evaluations;
    final status = await _evaluate();
    if (_disposed || evaluation != _evaluations || status == null) return;
    _publish(status);
  }

  void dispose() {
    _disposed = true;
    unawaited(_edits?.cancel());
  }

  /// The status from what is known; null when the database cannot be read
  /// (it closed for a reload, and the new one re-attaches).
  Future<BackupSyncStatus?> _evaluate() async {
    if (!_drive.isSignedIn) return BackupSyncStatus.off;
    final account = _account;
    if (_baseAccount != account) {
      _loadBase(account);
      return BackupSyncStatus.off;
    }
    final db = _database();
    try {
      return resolveBackupSync(localEdit: await db.lastManualEdit(), base: _base, remote: _remote, schemaVersion: db.schemaVersion);
    } catch (e) {
      _log.fine('Backup check: could not read the local state: $e');
      return null;
    }
  }

  Future<String?> _localEdit() async {
    try {
      return await _database().lastManualEdit();
    } catch (e) {
      _log.warning('Backup check: could not read the last manual edit: $e');
      return null;
    }
  }

  void _loadBase(String account) {
    if (_loadingAccount == account) return;
    _loadingAccount = account;
    final revision = _baseRevision;
    unawaited(
      _store
          .read(account)
          .then(
            (base) {
              if (_disposed || _loadingAccount != account || _baseRevision != revision) return;
              _base = base;
              _baseAccount = account;
              _loadingAccount = null;
              unawaited(refresh());
            },
            onError: (Object e) {
              _log.warning('Backup check: could not read the last sync: $e');
              if (_loadingAccount == account) _loadingAccount = null;
            },
          ),
    );
  }

  void _setBase(SyncBase base) {
    final account = _account;
    _baseRevision++;
    _base = base;
    _baseAccount = account;
    _loadingAccount = null;
    unawaited(_store.write(account, base).then((_) {}, onError: (Object e) => _log.warning('Backup check: could not save the last sync: $e')));
  }
}
