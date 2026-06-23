/// Pure, dependency-free validation of an LLM-proposed SQL statement.
///
/// This is the FIRST layer of defense; the second (and authoritative) layer is
/// the `query_only=ON` read-only connection in `read_only_db.dart`, which makes
/// any write impossible at the SQLite engine level. The guard here ensures the
/// statement is a single read-only SELECT/CTE (no stacked statements, no
/// comment-hidden payloads, no CTE-wrapped writes) and enforces a row LIMIT so
/// result sets stay bounded (tokens/cost).
class SqlGuardResult {
  final bool ok;

  /// Set when [ok] is false.
  final String? reason;

  /// Sanitized SQL (LIMIT enforced) when [ok] is true.
  final String? sql;

  const SqlGuardResult.ok(this.sql) : ok = true, reason = null;
  const SqlGuardResult.rejected(this.reason) : ok = false, sql = null;
}

class SqlGuard {
  /// Maximum rows any AI-generated query may return.
  static const int maxLimit = 200;

  /// Write/DDL/maintenance keywords that must never appear (whole-word). Caught
  /// here so a CTE-wrapped write (`WITH x AS (...) DELETE ...`) is rejected
  /// before it reaches the engine, even though `query_only` would also block it.
  static final RegExp _forbidden = RegExp(
    r'\b(insert|update|delete|drop|alter|create|replace|truncate|attach|detach|reindex|vacuum|pragma|grant|revoke|begin|commit|rollback|savepoint)\b',
    caseSensitive: false,
  );

  static final RegExp _limit = RegExp(r'\blimit\s+(\d+)\b', caseSensitive: false);

  /// Validates [raw] and returns either an OK result with sanitized SQL or a
  /// rejection with a human-readable reason.
  static SqlGuardResult validate(String raw) {
    var sql = raw.trim();
    if (sql.endsWith(';')) sql = sql.substring(0, sql.length - 1).trim();
    if (sql.isEmpty) return const SqlGuardResult.rejected('empty statement');

    // No comments — they can hide a second statement or bypass scanning.
    if (sql.contains('--') || sql.contains('/*')) {
      return const SqlGuardResult.rejected('comments are not allowed');
    }
    // Single statement only.
    if (sql.contains(';')) {
      return const SqlGuardResult.rejected('only a single statement is allowed');
    }
    // Must be a read query.
    final lower = sql.toLowerCase();
    if (!(lower.startsWith('select') || lower.startsWith('with'))) {
      return const SqlGuardResult.rejected('only SELECT / WITH queries are allowed');
    }
    // No write/DDL keywords anywhere (incl. inside a CTE main clause).
    if (_forbidden.hasMatch(sql)) {
      return const SqlGuardResult.rejected('only read-only SELECT queries are allowed');
    }

    // Enforce a row cap.
    final m = _limit.firstMatch(sql);
    if (m == null) {
      sql = '$sql LIMIT $maxLimit';
    } else {
      final n = int.tryParse(m.group(1)!) ?? maxLimit;
      if (n > maxLimit) sql = sql.replaceFirst(_limit, 'LIMIT $maxLimit');
    }
    return SqlGuardResult.ok(sql);
  }
}
