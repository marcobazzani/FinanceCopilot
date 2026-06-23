import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:finance_copilot/services/ai/read_only_db.dart';

void main() {
  group('ReadOnlyDb', () {
    late Database raw;
    late ReadOnlyDb db;

    setUp(() {
      raw = sqlite3.openInMemory();
      raw.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount REAL, description TEXT)');
      raw.execute("INSERT INTO transactions (amount, description) VALUES (100.0, 'Salary'), (-25.0, 'Coffee')");
      // Wrap as read-only AFTER seeding.
      db = ReadOnlyDb.fromDatabase(raw);
    });

    tearDown(() => db.dispose());

    test('select returns rows as column maps', () {
      final rows = db.select('SELECT amount, description FROM transactions ORDER BY id');
      expect(rows.length, 2);
      expect(rows.first['description'], 'Salary');
      expect(rows.first['amount'], 100.0);
    });

    test('writes are blocked at the engine (query_only)', () {
      expect(
        () => db.select("INSERT INTO transactions (amount, description) VALUES (1, 'x')"),
        throwsA(isA<SqliteException>()),
      );
      // The data is unchanged.
      final count = db.select('SELECT COUNT(*) AS c FROM transactions').first['c'];
      expect(count, 2);
    });

    test('schemaDdl exposes the CREATE TABLE text', () {
      final ddl = db.schemaDdl();
      expect(ddl, contains('CREATE TABLE transactions'));
      expect(ddl, contains('amount'));
    });
  });
}
