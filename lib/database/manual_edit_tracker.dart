import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../utils/logger.dart';

final _log = getLogger('ManualEditTracker');

/// AppConfigs key holding when the data was last edited by hand. The backup
/// sync indicator compares it with the value stamped on the Drive backup.
/// Written only by [ManualEditTracker].
const kLastManualEditKey = 'LAST_MANUAL_EDIT';

/// Tables holding provider data only: market prices (fetched, or rebuilt from
/// revalue events) and exchange rates. Writing them is never a manual edit.
const _providerDataTables = {'market_prices', 'exchange_rates'};

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
  r'^\s*(?:with\b.*?\b)?(?:insert(?:\s+or\s+\w+)?\s+into|replace\s+into|update(?:\s+or\s+\w+)?|delete\s+from)\s+'
  r'(?:["`\[]?\w+["`\]]?\s*\.\s*)?["`\[]?(\w+)',
  caseSensitive: false,
  dotAll: true,
);

/// The table [sql] writes, or null when it writes none: reads, PRAGMAs,
/// ATTACH/DETACH, schema changes and transaction control are no writes.
@visibleForTesting
String? writtenTable(String sql) => _writeStatement.firstMatch(sql)?.group(1)?.toLowerCase();

/// The first table among [statements] whose write is a manual edit, or null.
String? _editedTable(Iterable<String> statements) {
  for (final sql in statements) {
    final table = writtenTable(sql);
    if (table != null && !_providerDataTables.contains(table)) return table;
  }
  return null;
}

/// Records when the data was last edited by hand ([kLastManualEditKey]).
///
/// Installed on the app's database connection, it sees every write. A write
/// is a manual edit unless it runs inside [automaticWrites] or only touches
/// provider-data tables. The stamp is written with the edit: inside a
/// transaction just before it commits, otherwise just before the statement.
/// A crash can therefore at worst leave a stamp without its edit (the
/// indicator then asks for a backup that is not needed), never an edit
/// without its stamp. Opening and migrating the database run on drift's own
/// connection, below this interceptor, so they are never seen.
class ManualEditTracker extends QueryInterceptor {
  ManualEditTracker({DateTime Function()? now, Random? random}) : _now = now ?? DateTime.now, _random = random ?? Random();

  final DateTime Function() _now;
  final Random _random;

  /// Open transactions that hold a manual edit, stamped when they commit.
  final _editingTransactions = Expando<String>();
  final _edits = StreamController<void>.broadcast();

  /// Fires once a manual edit has been written together with its stamp.
  Stream<void> get edits => _edits.stream;

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], () => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], () => executor.runUpdate(statement, args));

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], () => executor.runDelete(statement, args));

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) =>
      _write(executor, [statement], () => executor.runCustom(statement, args));

  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) =>
      _write(executor, statements.statements, () => executor.runBatched(statements));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final table = _editingTransactions[inner];
    if (table == null) return inner.send();
    _editingTransactions[inner] = null;
    await _stamp(inner, table);
    await inner.send();
    _announce();
  }

  @override
  Future<void> close(QueryExecutor inner) async {
    await _edits.close();
    await inner.close();
  }

  Future<T> _write<T>(QueryExecutor executor, List<String> statements, Future<T> Function() run) async {
    if (_inAutomaticWrites) return run();
    final table = _editedTable(statements);
    if (table == null) return run();
    if (executor is TransactionExecutor) {
      final result = await run();
      _editingTransactions[executor] ??= table;
      return result;
    }
    await _stamp(executor, table);
    final result = await run();
    _announce();
    return result;
  }

  Future<void> _stamp(QueryExecutor executor, String table) {
    _log.fine('Manual edit of $table');
    return executor.runCustom(
      'INSERT INTO app_configs (key, value, description) VALUES (?, ?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [kLastManualEditKey, newManualEditStamp(_now(), _random), 'When the data was last edited by hand'],
    );
  }

  void _announce() {
    if (!_edits.isClosed) _edits.add(null);
  }
}
