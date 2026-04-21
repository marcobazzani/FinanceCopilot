import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'database.dart';
import '../services/google_drive_sync_service.dart';

/// Increment to force the database provider to close and reopen (e.g. after import).
final dbReloadTrigger = StateProvider<int>((ref) => 0);

/// Single app-wide database instance. Opens at the internal Application Support path.
final databaseProvider = Provider<AppDatabase>((ref) {
  ref.watch(dbReloadTrigger);
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Google Drive sync service (singleton).
final googleDriveSyncProvider = Provider<GoogleDriveSyncService>((ref) {
  return GoogleDriveSyncService();
});
