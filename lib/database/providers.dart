import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Selected database file path. `null` means no DB selected yet (show picker).
final dbPathProvider = StateProvider<String?>((ref) => null);

/// Single app-wide database instance. Throws if accessed before a path is selected.
final databaseProvider = Provider<AppDatabase>((ref) {
  final path = ref.watch(dbPathProvider);
  if (path == null) throw StateError('No database selected');
  final db = AppDatabase.withPath(path);
  ref.onDispose(() => db.close());
  return db;
});
