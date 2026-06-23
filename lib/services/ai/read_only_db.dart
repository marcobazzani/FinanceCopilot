import 'package:sqlite3/sqlite3.dart';

/// A dedicated, engine-enforced read-only connection to the app's SQLite file,
/// used exclusively to execute LLM-proposed SELECT queries.
///
/// It opens a SEPARATE connection from the app's main (read-write) drift
/// connection and sets `PRAGMA query_only = ON`, so SQLite rejects ANY write or
/// DDL on this handle at the engine level — the authoritative guard behind the
/// [SqlGuard] statement check. Opened read-write (not `OpenMode.readOnly`) so a
/// WAL-mode database can still create/read its shared-memory index; `query_only`
/// is what makes it read-only, not the file mode.
class ReadOnlyDb {
  final Database _db;
  ReadOnlyDb._(this._db);

  factory ReadOnlyDb.openFile(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readWrite);
    db.execute('PRAGMA query_only = ON;');
    db.execute('PRAGMA busy_timeout = 4000;');
    return ReadOnlyDb._(db);
  }

  /// For tests: wrap an already-open database (e.g. in-memory) as read-only.
  factory ReadOnlyDb.fromDatabase(Database db) {
    db.execute('PRAGMA query_only = ON;');
    return ReadOnlyDb._(db);
  }

  /// Runs [sql] and returns rows as ordered column→value maps. Throws
  /// [SqliteException] on a SQL error or attempted write.
  List<Map<String, Object?>> select(String sql) {
    final rs = _db.select(sql);
    final cols = rs.columnNames;
    return [
      for (final row in rs) <String, Object?>{for (final c in cols) c: row[c]},
    ];
  }

  /// The CREATE TABLE DDL for every user table — injected into the system
  /// prompt so the model knows the exact schema.
  String schemaDdl() {
    final rs = _db.select(
      "SELECT sql FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' "
      "AND sql IS NOT NULL ORDER BY name",
    );
    return rs.map((r) => (r['sql'] as String).trim()).join(';\n\n');
  }

  void dispose() => _db.dispose();
}
