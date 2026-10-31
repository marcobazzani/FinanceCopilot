import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../utils/logger.dart';
import 'edit_log.dart';

final _log = getLogger('ManualEditTracker');

/// AppConfigs key holding when the data was last edited by hand. The backup
/// sync indicator compares it with the value stamped on the Drive backup.
/// Written only by [ManualEditTracker].
const kLastManualEditKey = 'LAST_MANUAL_EDIT';

final _automaticWriteZone = Object();

/// Runs [body] with its database writes marked automatic, so they do not count
/// as manual edits. Every job that writes without a person asking for that
/// change (provider sync, startup maintenance, built-in seeding, a restore)
/// runs in here; any write outside it is a manual edit. The mark follows
/// [body] through its asynchronous calls: it is a zone value, the mechanism
/// drift itself uses to scope transactions.
Future<T> automaticWrites<T>(Future<T> Function() body) => runZoned(body, zoneValues: {_automaticWriteZone: true});

bool get _inAutomaticWrites => Zone.current[_automaticWriteZone] == true;

/// A new [kLastManualEditKey] value: the UTC time of the edit and a random
/// suffix, so two edits never read as the same one.
String newManualEditStamp(DateTime time, Random random) =>
    '${time.toUtc().toIso8601String()}#${random.nextInt(0x10000).toRadixString(16).padLeft(4, '0')}';

/// When the edit stamped [stamp] was made, or null for a value this app did
/// not write.
DateTime? manualEditTime(String stamp) => DateTime.tryParse(stamp.split('#').first);

final _writeStatement = RegExp(
  r'^\s*(?:with\b.*?\b)?(insert(?:\s+or\s+(\w+))?\s+into|replace\s+into|update(?:\s+or\s+\w+)?|delete\s+from)\s+'
  r'(?:["`\[]?\w+["`\]]?\s*\.\s*)?["`\[]?(\w+)',
  caseSensitive: false,
  dotAll: true,
);

final _upsert = RegExp(r'\bon\s+conflict\b.*\bdo\s+update\b', caseSensitive: false, dotAll: true);

/// The table [sql] writes, or null when it writes none: reads, PRAGMAs,
/// ATTACH/DETACH, schema changes and transaction control are no writes.
@visibleForTesting
String? writtenTable(String sql) => _writeStatement.firstMatch(sql)?.group(3)?.toLowerCase();

/// The kind of change [sql] makes to which area, or null when it is no
/// manual edit (no write at all, or a write of provider data). An insert
/// that updates on conflict, or replaces, changes what may be there already.
@visibleForTesting
EditChange? classifyWrite(String sql) {
  final match = _writeStatement.firstMatch(sql);
  if (match == null) return null;
  final area = editAreaOf(match.group(3)!.toLowerCase());
  if (area == null) return null;
  final verb = match.group(1)!.toLowerCase();
  final EditKind kind;
  if (verb.startsWith('delete')) {
    kind = EditKind.deleted;
  } else if (verb.startsWith('insert') && match.group(2)?.toLowerCase() != 'replace' && !_upsert.hasMatch(sql)) {
    kind = EditKind.added;
  } else {
    kind = EditKind.changed;
  }
  return (area, kind);
}

/// The manual edits of an open transaction, recorded when it commits.
class _PendingEdits {
  final changes = <EditChange>{};
  var rows = 0;
}

/// Records what is edited by hand: when ([kLastManualEditKey]) and what
/// ([kManualEditLogKey], the [EditLog]).
///
/// Installed on the app's database connection, it sees every write. A write
/// is a manual edit unless it runs inside [automaticWrites] or only touches
/// provider data. Both are written with the edit: inside a transaction just
/// before it commits, otherwise just before the statement. A crash can
/// therefore at worst leave a record without its edit (the indicator then
/// asks for a backup that is not needed), never an edit without its record.
/// Opening and migrating the database run on drift's own connection, below
/// this interceptor, so they are never seen.
class ManualEditTracker extends QueryInterceptor {
  ManualEditTracker({DateTime Function()? now, Random? random}) : _now = now ?? DateTime.now, _random = random ?? Random();

  final DateTime Function() _now;
  final Random _random;

  final _pending = Expando<_PendingEdits>();
  final _edits = StreamController<void>.broadcast();

  /// Fires once a manual edit has been written together with its record.
  Stream<void> get edits => _edits.stream;

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], 1, () => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], 1, () => executor.runUpdate(statement, args), rowsOf: (n) => n);

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], 1, () => executor.runDelete(statement, args), rowsOf: (n) => n);

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], 1, () => executor.runCustom(statement, args));

  /// A batch edits one row per execution of a manual-edit statement.
  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) => _write(
    executor,
    statements.statements,
    statements.arguments.where((a) => classifyWrite(statements.statements[a.statementIndex]) != null).length,
    () => executor.runBatched(statements),
  );

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final pending = _pending[inner];
    if (pending == null) return inner.send();
    _pending[inner] = null;
    await _record(inner, pending.changes, pending.rows);
    await inner.send();
    _announce();
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    await _edits.close();
    await inner.close();
  }

  /// Runs [run], recording the manual edits among [statements]: [estimate]
  /// rows, or what [rowsOf] reads from the result once known.
  Future<T> _write<T>(
    QueryExecutor executor,
    List<String> statements,
    int estimate,
    Future<T> Function() run, {
    int Function(T result)? rowsOf,
  }) async {
    if (_inAutomaticWrites) return run();
    final changes = {for (final sql in statements) ?classifyWrite(sql)};
    if (changes.isEmpty) return run();
    if (executor is TransactionExecutor) {
      final result = await run();
      final pending = _pending[executor] ??= _PendingEdits();
      pending.changes.addAll(changes);
      pending.rows += rowsOf?.call(result) ?? estimate;
      return result;
    }
    await _record(executor, changes, estimate);
    final result = await run();
    if (rowsOf?.call(result) case final rows? when rows != estimate) await _addRows(executor, rows - estimate);
    _announce();
    return result;
  }

  /// Writes the stamp, and renews the [EditLog] token of every change in
  /// [changes] while adding [rows] to its count: one statement, so two edits
  /// running side by side cannot lose each other's update.
  Future<void> _record(QueryExecutor executor, Set<EditChange> changes, int rows) async {
    _log.fine('Manual edit: $changes, $rows row(s)');
    await executor.runCustom(
      'INSERT INTO app_configs (key, value, description) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [kLastManualEditKey, newManualEditStamp(_now(), _random), 'When the data was last edited by hand'],
    );
    final tokens = {for (final change in changes) EditLog.keyOf(change): _newToken()};
    final paths = [for (final key in tokens.keys) ", '\$.\"$key\"', ?"].join();
    await executor.runCustom(
      'INSERT INTO app_configs (key, value, description) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = json_set($_storedLog, '
      "'\$.${EditLog.changesKey}', COALESCE(json_extract($_storedLog, '\$.${EditLog.changesKey}'), 0) + ?$paths)",
      [
        kManualEditLogKey,
        jsonEncode({EditLog.changesKey: rows, ...tokens}),
        'What was edited by hand',
        rows,
        ...tokens.values,
      ],
    );
  }

  /// Adds [delta] to the [EditLog] row count, once a write said how many rows
  /// it really edited.
  Future<void> _addRows(QueryExecutor executor, int delta) => executor.runCustom(
    "UPDATE app_configs SET value = json_set($_storedLog, '\$.${EditLog.changesKey}', "
    "COALESCE(json_extract($_storedLog, '\$.${EditLog.changesKey}'), 0) + ?) WHERE key = ?",
    [delta, kManualEditLogKey],
  );

  /// The stored log, or an empty one in place of a value that is not JSON.
  static const _storedLog = "CASE WHEN json_valid(app_configs.value) THEN app_configs.value ELSE '{}' END";

  String _newToken() => _random.nextInt(0x100000000).toRadixString(36).padLeft(7, '0');

  void _announce() {
    if (!_edits.isClosed) _edits.add(null);
  }
}
