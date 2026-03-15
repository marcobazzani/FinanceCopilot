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
    String currency = 'EUR',
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

  Future<int> delete(int id) {
    _log.warning('delete: id=$id');
    return (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  /// Reorder accounts by updating sortOrder for each account.
  /// [orderedIds] is the list of account IDs in the desired display order.
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

  /// Get transaction stats (count, first date, last date, latest balance) for all accounts.
  Future<Map<int, AccountStats>> getStatsForAll() async {
    final results = await _db.customSelect(
      'SELECT account_id, COUNT(*) AS cnt, '
      'MIN(operation_date) AS first_date, MAX(operation_date) AS last_date '
      'FROM transactions GROUP BY account_id',
    ).get();

    // Latest balance: the last imported row (highest id) per account holds the final balance
    final balanceRows = await _db.customSelect(
      'SELECT account_id, balance_after FROM transactions '
      'WHERE id IN (SELECT MAX(id) FROM transactions GROUP BY account_id)',
    ).get();
    final balances = <int, double?>{};
    for (final row in balanceRows) {
      balances[row.read<int>('account_id')] = row.readNullable<double>('balance_after');
    }

    final stats = <int, AccountStats>{};
    for (final row in results) {
      final accountId = row.read<int>('account_id');
      final count = row.read<int>('cnt');
      final firstEpoch = row.readNullable<int>('first_date');
      final lastEpoch = row.readNullable<int>('last_date');
      stats[accountId] = AccountStats(
        count: count,
        firstDate: firstEpoch != null ? DateTime.fromMillisecondsSinceEpoch(firstEpoch * 1000) : null,
        lastDate: lastEpoch != null ? DateTime.fromMillisecondsSinceEpoch(lastEpoch * 1000) : null,
        balance: balances[accountId],
      );
    }
    return stats;
  }

  /// Watch transaction stats reactively (re-emits when transactions table changes).
  Stream<Map<int, AccountStats>> watchStatsForAll() {
    // Watch for any change in transactions table, then compute stats
    return _db.customSelect(
      'SELECT account_id, COUNT(*) AS cnt, '
      'MIN(operation_date) AS first_date, MAX(operation_date) AS last_date '
      'FROM transactions GROUP BY account_id',
      readsFrom: {_db.transactions},
    ).watch().asyncMap((rows) async {
      // Latest balance: the last imported row (highest id) per account holds the final balance
      final balanceRows = await _db.customSelect(
        'SELECT account_id, balance_after FROM transactions '
        'WHERE id IN (SELECT MAX(id) FROM transactions GROUP BY account_id)',
      ).get();
      final balances = <int, double?>{};
      for (final bRow in balanceRows) {
        balances[bRow.read<int>('account_id')] = bRow.readNullable<double>('balance_after');
      }

      final stats = <int, AccountStats>{};
      for (final row in rows) {
        final accountId = row.read<int>('account_id');
        final count = row.read<int>('cnt');
        final firstEpoch = row.readNullable<int>('first_date');
        final lastEpoch = row.readNullable<int>('last_date');
        stats[accountId] = AccountStats(
          count: count,
          firstDate: firstEpoch != null ? DateTime.fromMillisecondsSinceEpoch(firstEpoch * 1000) : null,
          lastDate: lastEpoch != null ? DateTime.fromMillisecondsSinceEpoch(lastEpoch * 1000) : null,
          balance: balances[accountId],
        );
      }
      return stats;
    });
  }
}
