import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Selected database file path. `null` means use the default sandbox path.
final dbPathProvider = StateProvider<String?>((ref) => null);

/// Single app-wide database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final path = ref.watch(dbPathProvider);
  final db = path != null ? AppDatabase.withPath(path) : AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
