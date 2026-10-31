import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'database.dart';
import 'package:finance_copilot/services/sync/backup_stamp.dart';
import 'package:finance_copilot/services/sync/google_drive_sync_service.dart';

/// Increment to force the database provider to close and reopen (e.g. after import).
final dbReloadTrigger = StateProvider<int>((ref) => 0);

/// Single app-wide database instance. Opens at the internal Application Support path.
final databaseProvider = Provider<AppDatabase>((ref) {
  ref.watch(dbReloadTrigger);
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Google Drive sync service (singleton). Every backup is stamped with a
/// description of its snapshot and of what was edited in it by hand, read
/// back by the sync indicator.
final googleDriveSyncProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService(
    snapshotProperties: (path) async => {...await describeBackupSnapshot(path), ...await describeSnapshotEdits(path)},
  );
});
