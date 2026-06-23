import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/ai/sql_guard.dart';

void main() {
  group('SqlGuard.validate', () {
    test('accepts a plain SELECT and appends a LIMIT', () {
      final r = SqlGuard.validate('SELECT * FROM transactions');
      expect(r.ok, isTrue);
      expect(r.sql, 'SELECT * FROM transactions LIMIT ${SqlGuard.maxLimit}');
    });

    test('accepts lowercase select', () {
      expect(SqlGuard.validate('select 1').ok, isTrue);
    });

    test('accepts a CTE (WITH ... SELECT)', () {
      final r = SqlGuard.validate('WITH x AS (SELECT 1 AS n) SELECT n FROM x');
      expect(r.ok, isTrue);
    });

    test('strips a trailing semicolon', () {
      final r = SqlGuard.validate('SELECT 1;');
      expect(r.ok, isTrue);
      expect(r.sql, contains('LIMIT'));
      expect(r.sql, isNot(contains(';')));
    });

    test('keeps an existing in-range LIMIT', () {
      final r = SqlGuard.validate('SELECT * FROM t LIMIT 50');
      expect(r.sql, 'SELECT * FROM t LIMIT 50');
    });

    test('clamps an over-max LIMIT', () {
      final r = SqlGuard.validate('SELECT * FROM t LIMIT 5000');
      expect(r.sql, 'SELECT * FROM t LIMIT ${SqlGuard.maxLimit}');
    });

    test('rejects empty', () {
      expect(SqlGuard.validate('   ').ok, isFalse);
    });

    test('rejects INSERT/UPDATE/DELETE/DROP', () {
      for (final w in ['INSERT INTO t VALUES (1)', 'UPDATE t SET a=1', 'DELETE FROM t', 'DROP TABLE t']) {
        expect(SqlGuard.validate(w).ok, isFalse, reason: w);
      }
    });

    test('rejects a CTE-wrapped write', () {
      expect(SqlGuard.validate('WITH x AS (SELECT 1) DELETE FROM t').ok, isFalse);
    });

    test('rejects PRAGMA / ATTACH', () {
      expect(SqlGuard.validate('PRAGMA table_info(t)').ok, isFalse);
      expect(SqlGuard.validate("SELECT 1; ATTACH DATABASE 'x' AS y").ok, isFalse);
    });

    test('rejects multiple statements', () {
      expect(SqlGuard.validate('SELECT 1; SELECT 2').ok, isFalse);
    });

    test('rejects comments', () {
      expect(SqlGuard.validate('SELECT 1 -- sneaky').ok, isFalse);
      expect(SqlGuard.validate('SELECT 1 /* x */').ok, isFalse);
    });

    test('rejects a non-select leading statement', () {
      expect(SqlGuard.validate('EXPLAIN SELECT 1').ok, isFalse);
    });
  });
}
