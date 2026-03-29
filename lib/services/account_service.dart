import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('AccountService');

/// Lightweight stats for an account's transactions.
class AccountStats {
  final int count;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double? balance;

  const AccountStats({required this.count, this.firstDate, this.lastDate, this.balance});
}

/// SQL to get the latest balance per account: the balance_after from the
/// transaction with the latest date, tiebroken by highest id within that date.
const _latestBalanceSql =
    'SELECT t.account_id, t.balance_after FROM transactions t '
    'INNER JOIN ('
    '  SELECT account_id, MAX(operation_date) AS max_date FROM transactions GROUP BY account_id'
    ') md ON t.account_id = md.account_id AND t.operation_date = md.max_date '
    'WHERE t.id = ('
    '  SELECT MAX(id) FROM transactions t2 '
    '  WHERE t2.account_id = t.account_id AND t2.operation_date = md.max_date'
    ')';

class AccountService {
  final AppDatabase _db;

  AccountService(this._db);

  Future<List<Account>> getAll() async {
    final result = await (_db.select(_db.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
    _log.fine('getAll: ${result.length} accounts');
    return result;
  }

  Stream<List<Account>> watchAll() => (_db.select(_db.accounts)
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .watch();

  Future<Account> getById(int id) =>
      (_db.select(_db.accounts)..where((a) => a.id.equals(id))).getSingle();

  Future<int> create({
    required String name,
    required String currency,
    String institution = '',
  }) async {
    _log.info('create: name=$name, currency=$currency');

    // Set sortOrder to max+1 so new accounts appear at the end
    final maxOrder = await _db.customSelect(
      'SELECT COALESCE(MAX(sort_order), 0) AS max_order FROM accounts',
    ).getSingle();
    final nextOrder = (maxOrder.read<int>('max_order')) + 1;

    return _db.into(_db.accounts).insert(AccountsCompanion.insert(
      name: name,
      type: const Value(AccountType.bank),
      currency: Value(currency),
      institution: Value(institution),
      sortOrder: Value(nextOrder),
    ));
  }

  Future<bool> update(int id, AccountsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) async {
    _log.warning('delete: id=$id (cascade: transactions, import configs)');
    await (_db.delete(_db.transactions)..where((t) => t.accountId.equals(id))).go();
    await (_db.delete(_db.importConfigs)..where((c) => c.accountId.equals(id))).go();
    return (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  /// Reorder accounts by updating sortOrder for each account.
  Future<void> reorder(List<int> orderedIds) async {
    _log.info('reorder: ${orderedIds.length} accounts');
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.accounts,
          AccountsCompanion(sortOrder: Value(i)),
          where: (a) => a.id.equals(orderedIds[i]),
        );
      }
    });
  }

  static const _statsQuery =
      'SELECT account_id, COUNT(*) AS cnt, '
      'MIN(operation_date) AS first_date, MAX(operation_date) AS last_date '
      'FROM transactions GROUP BY account_id';

  /// Get transaction stats for all accounts.
  Future<Map<int, AccountStats>> getStatsForAll() async {
    final statsRows = await _db.customSelect(_statsQuery).get();
    final balances = await _fetchLatestBalances();
    return _buildStats(statsRows, balances);
  }

  /// Watch transaction stats reactively.
  Stream<Map<int, AccountStats>> watchStatsForAll() {
    return _db.customSelect(
      _statsQuery, readsFrom: {_db.transactions},
    ).watch().asyncMap((statsRows) async {
      final balances = await _fetchLatestBalances();
      return _buildStats(statsRows, balances);
    });
  }

  Future<Map<int, double?>> _fetchLatestBalances() async {
    final rows = await _db.customSelect(_latestBalanceSql).get();
    return {
      for (final row in rows)
        row.read<int>('account_id'): row.readNullable<double>('balance_after'),
    };
  }

  Map<int, AccountStats> _buildStats(
    List<QueryRow> statsRows,
    Map<int, double?> balances,
  ) {
    return {
      for (final row in statsRows)
        row.read<int>('account_id'): AccountStats(
          count: row.read<int>('cnt'),
          firstDate: _epochToDate(row.readNullable<int>('first_date')),
          lastDate: _epochToDate(row.readNullable<int>('last_date')),
          balance: balances[row.read<int>('account_id')],
        ),
    };
  }

  static DateTime? _epochToDate(int? epochSec) =>
      epochSec != null ? DateTime.fromMillisecondsSinceEpoch(epochSec * 1000) : null;
}
