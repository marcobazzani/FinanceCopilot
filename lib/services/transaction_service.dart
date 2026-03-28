import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/amount_parser.dart' as amt;
import '../utils/logger.dart';

final _log = getLogger('TransactionService');

class TransactionService {
  final AppDatabase _db;

  TransactionService(this._db);

  Stream<List<Transaction>> watchByAccount(int accountId) {
    return (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.operationDate),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Future<List<Transaction>> getByAccount(int accountId) {
    return (_db.select(_db.transactions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.operationDate),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  Future<int> create({
    required int accountId,
    required DateTime operationDate,
    required double amount,
    String description = '',
    String? descriptionFull,
    double? balanceAfter,
    required String currency,
    TransactionStatus status = TransactionStatus.settled,
  }) {
    _log.info('create: accountId=$accountId, date=$operationDate, amount=$amount, desc=$description');
    return _db.into(_db.transactions).insert(TransactionsCompanion.insert(
      accountId: accountId,
      operationDate: operationDate,
      valueDate: operationDate,
      amount: amount,
      description: Value(description),
      descriptionFull: Value(descriptionFull),
      balanceAfter: Value(balanceAfter),
      currency: Value(currency),
      status: Value(status),
    ));
  }

  Future<bool> update(int id, TransactionsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) {
    _log.warning('delete: transaction id=$id');
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  /// Update the importHash for a single transaction.
  Future<void> updateHash(int id, String hash) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(importHash: Value(hash)));
  }

  /// Batch-update balanceAfter for multiple transactions in a single DB transaction.
  Future<void> batchUpdateBalances(Map<int, double?> updates) async {
    await _db.batch((batch) {
      for (final entry in updates.entries) {
        batch.update(
          _db.transactions,
          TransactionsCompanion(balanceAfter: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
    _log.info('batchUpdateBalances: updated ${updates.length} balances');
  }

  /// Batch-update importHash for multiple transactions in a single DB transaction.
  Future<void> batchUpdateHashes(Map<int, String> updates) async {
    await _db.batch((batch) {
      for (final entry in updates.entries) {
        batch.update(
          _db.transactions,
          TransactionsCompanion(importHash: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
    _log.info('batchUpdateHashes: updated ${updates.length} hashes');
  }

  /// Delete all transactions for an account.
  Future<int> deleteByAccount(int accountId) {
    _log.warning('deleteByAccount: wiping all transactions for account $accountId');
    return (_db.delete(_db.transactions)..where((t) => t.accountId.equals(accountId))).go();
  }

  /// Remove duplicate transactions for an account based on importHash.
  /// Keeps the first occurrence (lowest id), deletes the rest.
  /// Returns number of deleted duplicates.
  Future<int> removeDuplicates(int accountId) async {
    final txs = await getByAccount(accountId);
    final seen = <String>{};
    var deleted = 0;
    // Process in id order (ascending) to keep earliest
    final sorted = List.of(txs)..sort((a, b) => a.id.compareTo(b.id));
    for (final tx in sorted) {
      if (tx.importHash == null) continue;
      if (seen.contains(tx.importHash)) {
        await delete(tx.id);
        deleted++;
      } else {
        seen.add(tx.importHash!);
      }
    }
    if (deleted > 0) _log.info('removeDuplicates: deleted $deleted duplicates for account $accountId');
    return deleted;
  }

  /// Recalculate balanceAfter for all transactions in an account.
  /// Uses the saved import config (balance mode, filter settings).
  /// Returns the number of updated transactions.
  Future<int> recalculateBalances(
    int accountId, {
    required String balanceMode,
    Map<String, dynamic> savedMappings = const {},
  }) async {
    if (balanceMode == 'none') return 0;

    final txs = await getByAccount(accountId);
    if (txs.isEmpty) return 0;

    // Sort chronologically (date ASC, id ASC)
    final sorted = List.of(txs)..sort((a, b) {
      final cmp = a.operationDate.compareTo(b.operationDate);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    int toCents(double v) => (v * 100).round();
    double fromCents(int c) => c / 100;

    int balanceCents = 0;
    final updates = <int, double?>{};
    final balanceColumn = savedMappings['balanceAfter'] as String?;
    final filterColumn = savedMappings['__balanceFilterColumn'] as String?;
    final filterInclude = <String>{};
    if (savedMappings.containsKey('__balanceFilterInclude')) {
      filterInclude.addAll(
        (jsonDecode(savedMappings['__balanceFilterInclude'] as String) as List<dynamic>).cast<String>(),
      );
    }

    for (final tx in sorted) {
      double? newBalance;

      if (balanceMode == 'column') {
        if (balanceColumn != null && tx.rawMetadata != null) {
          final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
          final raw = meta[balanceColumn]?.toString() ?? '';
          newBalance = amt.tryParseAmount(raw);
        }
      } else if (balanceMode == 'cumulative') {
        balanceCents += toCents(tx.amount);
        newBalance = fromCents(balanceCents);
      } else if (balanceMode == 'filtered') {
        String filterVal = '';
        if (filterColumn != null && tx.rawMetadata != null) {
          final meta = jsonDecode(tx.rawMetadata!) as Map<String, dynamic>;
          filterVal = (meta[filterColumn]?.toString() ?? '').trim();
        }
        final included = filterInclude.isEmpty || filterInclude.contains(filterVal);
        if (included) {
          balanceCents += toCents(tx.amount);
        }
        newBalance = fromCents(balanceCents);
      }

      if (newBalance != tx.balanceAfter) {
        updates[tx.id] = newBalance;
      }
    }

    if (updates.isNotEmpty) {
      await batchUpdateBalances(updates);
    }
    _log.info('recalculateBalances: account=$accountId, mode=$balanceMode, updated=${updates.length}/${sorted.length}');
    return updates.length;
  }
}
