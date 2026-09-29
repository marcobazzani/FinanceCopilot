import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/running_balance.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/import/import_config_service.dart' show ImportConfigScope, ImportConfigScopeName;
import 'package:finance_copilot/services/import/stored_import_data.dart';
import 'package:finance_copilot/utils/amount_parser.dart' as amt;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';

final _log = getLogger('TransactionService');

class TransactionService {
  final AppDatabase _db;

  TransactionService(this._db);

  Stream<List<Transaction>> watchByAccount(int accountId, {DateTime? through}) {
    final query = _db.select(_db.transactions)..where((t) => t.accountId.equals(accountId));
    final endExclusive = throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((t) => t.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.valueDate),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return query.watch();
  }

  /// All transactions across all *existing* accounts. Used by the virtual
  /// "All accounts" read-only screen. Orphan rows whose `account_id` no
  /// longer matches a row in `accounts` (e.g. left over from past imports
  /// into now-deleted accounts) are excluded — they would otherwise render
  /// as nameless `#<id>` rows that look like duplicates.
  Stream<List<Transaction>> watchAll({DateTime? through}) {
    final query =
        _db.select(_db.transactions).join([
          innerJoin(_db.accounts, _db.accounts.id.equalsExp(_db.transactions.accountId)),
        ])..orderBy([
          OrderingTerm.desc(_db.transactions.valueDate),
          OrderingTerm.desc(_db.transactions.id),
        ]);
    final endExclusive = throughEndExclusive(through);
    if (endExclusive != null) {
      query.where(_db.transactions.valueDate.isSmallerThanValue(endExclusive));
    }
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(_db.transactions)).toList(),
    );
  }

  Future<List<Transaction>> getByAccount(int accountId, {DateTime? through}) {
    final query = _db.select(_db.transactions)..where((t) => t.accountId.equals(accountId));
    final endExclusive = throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((t) => t.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.valueDate),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return query.get();
  }

  Future<int> create({
    required int accountId,
    required DateTime operationDate,
    DateTime? valueDate,
    required double amount,
    String description = '',
    String? descriptionFull,
    double? balanceAfter,
    required String currency,
    TransactionStatus status = TransactionStatus.settled,
    int? categoryId,
  }) {
    _log.info('create: accountId=$accountId, date=$operationDate');
    final keys = TransactionClassifierService.normalize(
      description: description,
      descriptionFull: descriptionFull,
      amount: amount,
    );
    // The row and the running balance it moves are written together: a failed
    // recalculation inserts nothing, so saving again cannot duplicate it.
    return _db.transaction(() async {
      final id = await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: accountId,
              operationDate: operationDate,
              valueDate: valueDate ?? operationDate,
              amount: amount,
              description: Value(description),
              descriptionFull: Value(descriptionFull),
              balanceAfter: Value(balanceAfter),
              currency: Value(currency),
              status: Value(status),
              categoryId: Value(categoryId),
              merchantKey: Value(keys.merchantKey),
              counterparty: Value(keys.counterparty),
              entryKind: Value(keys.entryKind),
            ),
          );
      // A new row moves the running balance of every later one: re-run it the
      // same way a delete does.
      await _recalcFromImportConfig(accountId, keepStatusOf: id);
      return id;
    });
  }

  /// Update a row. When the description, full description or amount sign
  /// changes, the derived merchant key / counterparty / entry kind are
  /// recomputed so grouping and merchant rules keep working. When the row's
  /// account, dates, amount, status, balance or raw data change, the running
  /// balance of the account it left and of the one it is in is re-run, as on
  /// delete — in the same DB transaction as the write, and without touching
  /// the status just written. In an account whose balances are computed
  /// ([computesBalances]) a written balance is replaced by the computed one.
  Future<bool> update(int id, TransactionsCompanion companion) async {
    _log.info('update: id=$id');
    final movesBalance =
        companion.accountId.present ||
        companion.valueDate.present ||
        companion.operationDate.present ||
        companion.amount.present ||
        companion.status.present ||
        companion.balanceAfter.present ||
        companion.rawMetadata.present;
    final rekeys = companion.description.present || companion.descriptionFull.present || companion.amount.present;
    Future<bool> write(TransactionsCompanion c) =>
        (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(c).then((rows) => rows > 0);
    if (!rekeys && !movesBalance) return write(companion);
    return _db.transaction(() async {
      final current = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (current == null) return false;
      var changes = companion;
      if (rekeys) {
        final keys = TransactionClassifierService.normalize(
          description: companion.description.present ? companion.description.value : current.description,
          descriptionFull: companion.descriptionFull.present ? companion.descriptionFull.value : current.descriptionFull,
          rawMetadataJson: current.rawMetadata,
          amount: companion.amount.present ? companion.amount.value : current.amount,
        );
        changes = changes.copyWith(
          merchantKey: Value(keys.merchantKey),
          counterparty: Value(keys.counterparty),
          entryKind: Value(keys.entryKind),
        );
      }
      final updated = await write(changes);
      if (updated && movesBalance) {
        for (final accountId in {current.accountId, if (companion.accountId.present) companion.accountId.value}) {
          await _recalcFromImportConfig(accountId, keepStatusOf: id);
        }
      }
      return updated;
    });
  }

  /// Delete a row and re-run the running balance of its account, in one DB
  /// transaction as [create] and [update] do: a failed recalculation deletes
  /// nothing.
  Future<int> delete(int id) => _db.transaction(() async {
    final existing = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;
    _log.warning('delete: transaction id=$id accountId=${existing.accountId}');
    final deleted = await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    if (deleted > 0) await recalcFromImportConfig(existing.accountId);
    return deleted;
  });

  /// [delete] for [ids], across their accounts: one DB transaction.
  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    return _db.transaction(() async {
      final affected = await (_db.select(_db.transactions)..where((t) => t.id.isIn(ids))).get();
      final accountIds = affected.map((t) => t.accountId).toSet();
      _log.warning('deleteMany: ${ids.length} transactions across ${accountIds.length} accounts');
      final deleted = await (_db.delete(_db.transactions)..where((t) => t.id.isIn(ids))).go();
      for (final accountId in accountIds) {
        await recalcFromImportConfig(accountId);
      }
      return deleted;
    });
  }

  /// Re-run balance recalculation for an account using its saved import config.
  /// No-op when the account has no import config — or only the number-format
  /// placeholder an import stores before its settings are saved, or a config
  /// that stores no balance mode — or when the saved balance mode is 'none' or
  /// in [skip]. Unreadable saved settings are logged and the stored balances
  /// left as they are, never recomputed in a mode the user did not save.
  Future<void> recalcFromImportConfig(int accountId, {Set<BalanceMode> skip = const {}}) => _recalcFromImportConfig(accountId, skip: skip);

  /// Whether [accountId]'s `balance_after` is computed: its saved import
  /// config re-runs the running balance (cumulative, column or filtered mode)
  /// after every create, edit and delete, so a balance written on a row is
  /// replaced by the computed one. False — a typed balance stays exactly as
  /// typed — for the accounts [recalcFromImportConfig] leaves alone.
  Future<bool> computesBalances(int accountId) async => await _balanceConfig(accountId) != null;

  /// [recalcFromImportConfig]. [keepStatusOf] is the row just created or
  /// edited: the recalculation leaves its status as the user set it.
  Future<void> _recalcFromImportConfig(int accountId, {Set<BalanceMode> skip = const {}, int? keepStatusOf}) async {
    final config = await _balanceConfig(accountId);
    if (config == null || skip.contains(config.settings.mode)) return;
    await _recalculate(accountId, config.settings, numberLocale: config.numberLocale, keepStatusOf: keepStatusOf);
  }

  /// The saved settings [accountId]'s balances are recomputed with, and the
  /// number format of its stored statement text. Null when its balances are
  /// left as they are: no import config, only the number-format placeholder,
  /// unreadable settings (logged), no stored mode or mode none.
  Future<({BalanceSettings settings, String? numberLocale})?> _balanceConfig(int accountId) async {
    final config = await (_db.select(_db.importConfigs)..where((c) => c.accountId.equals(accountId))).getSingleOrNull();
    if (config == null) return null;
    final saved = SavedImportMappings.decode(config.mappingsJson);
    if (saved.isEmpty) return null;
    final settings = saved.balance;
    if (settings == null) {
      _log.warning('recalcFromImportConfig: account=$accountId - saved balance settings unreadable, balances left as they are');
      return null;
    }
    // A mode the user never saved is not applied behind their back: the
    // wizard and the balance dialog offer the default, only they store it.
    if (!saved.storesBalanceMode) {
      _log.fine('recalcFromImportConfig: account=$accountId - saved import config stores no balance mode, balances left as they are');
      return null;
    }
    if (settings.mode == BalanceMode.none) return null;
    return (settings: settings, numberLocale: config.numberLocale);
  }

  /// [recalcFromImportConfig] for every account that has an import config.
  Future<void> recalcAllFromImportConfigs({Set<BalanceMode> skip = const {}}) async {
    final configs = await (_db.select(
      _db.importConfigs,
    )..where((c) => c.scope.equals(ImportConfigScope.transaction.wire) & c.accountId.isNotNull())).get();
    for (final config in configs) {
      await recalcFromImportConfig(config.accountId!, skip: skip);
    }
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

  /// Delete all transactions for an account.
  Future<int> deleteByAccount(int accountId) {
    _log.warning('deleteByAccount: wiping all transactions for account $accountId');
    return (_db.delete(_db.transactions)..where((t) => t.accountId.equals(accountId))).go();
  }

  /// Recalculate balanceAfter for all transactions in an account.
  /// [balanceMode] is a stored [BalanceMode] name; its settings (balance
  /// column, filter column and values) are read from [savedMappings], the
  /// saved import config. An unknown mode or unreadable settings change
  /// nothing (logged).
  /// Returns the number of updated transactions.
  Future<int> recalculateBalances(
    int accountId, {
    required String balanceMode,
    Map<String, dynamic> savedMappings = const {},
    String? numberLocale,
  }) async => (await recalculateBalancesDetailed(
    accountId,
    balanceMode: balanceMode,
    savedMappings: savedMappings,
    numberLocale: numberLocale,
  )).updated;

  /// [recalculateBalances] plus the reconciliation of `column` mode: the
  /// bank closing the series was anchored on and the opening it implies.
  Future<BalanceRecalcResult> recalculateBalancesDetailed(
    int accountId, {
    required String balanceMode,
    Map<String, dynamic> savedMappings = const {},
    String? numberLocale,
  }) async {
    final mode = BalanceMode.parse(balanceMode);
    final settings = mode == null ? null : SavedImportMappings(savedMappings).balanceFor(mode);
    if (settings == null) {
      _log.warning('recalculateBalances: account=$accountId mode=$balanceMode - unreadable balance settings, balances left as they are');
      return const BalanceRecalcResult(updated: 0);
    }
    return _recalculate(accountId, settings, numberLocale: numberLocale);
  }

  /// [keepStatusOf]: a row whose status is left as it is (the row just saved).
  Future<BalanceRecalcResult> _recalculate(int accountId, BalanceSettings settings, {String? numberLocale, int? keepStatusOf}) async {
    final balanceMode = settings.mode;
    if (balanceMode == BalanceMode.none) return const BalanceRecalcResult(updated: 0);
    final locale = numberLocale ?? 'en_US';

    // Chronological (value date ASC, id ASC): the order the balance runs in.
    final sorted = (await getByAccount(accountId)).reversed.toList();
    if (sorted.isEmpty) return const BalanceRecalcResult(updated: 0);

    // Filtered mode: rows whose filter value is excluded never moved the
    // balance and are cancelled. Keep status consistent with the importer so
    // a standalone recalc and a fresh import agree.
    final statusUpdates = <int, TransactionStatus>{};
    final balanceColumn = settings.balanceColumn;
    final filterColumn = settings.filterColumn;
    final filterInclude = settings.filterInclude;

    double? stated(Transaction tx) {
      if (balanceMode != BalanceMode.column || balanceColumn == null) return null;
      final meta = decodeRawMetadata(tx.rawMetadata);
      if (meta == null) return null;
      return amt.tryParseAmount(meta[balanceColumn]?.toString() ?? '', locale: locale);
    }

    final timeline = [
      for (final tx in sorted)
        RunningBalanceRow(
          valueDate: tx.valueDate,
          bookingDate: tx.operationDate,
          order: tx.id,
          amount: tx.amount,
          statedBalance: stated(tx),
        ),
    ];

    // Column mode: the bank's balance column is a booking-order figure; the
    // stored balance is the VALUE-DATE running balance anchored on the bank's
    // closing (see running_balance.dart). One timeline for lists and charts.
    AnchoredBalances? anchored;
    final List<double?> balances;
    if (balanceMode == BalanceMode.column) {
      anchored = anchoredRunningBalances(timeline);
      if (!anchored.anchored) {
        _log.warning('recalculateBalances: account=$accountId column mode without a stated balance to anchor on - running balance starts at 0');
      } else if (anchored.opening.abs() >= 0.005) {
        _log.fine(
          'recalculateBalances: account=$accountId opening balance ${anchored.opening} implied by bank closing ${anchored.bankClosing} - history before the first row is not in the app',
        );
      }
      balances = anchored.balances;
    } else {
      // Cumulative and filtered modes: the running sum from 0, which a
      // filtered-out row does not move.
      bool included(Transaction tx) {
        if (balanceMode != BalanceMode.filtered) return true;
        String filterVal = '';
        if (filterColumn != null) {
          final meta = decodeRawMetadata(tx.rawMetadata);
          if (meta != null) filterVal = (meta[filterColumn]?.toString() ?? '').trim();
        }
        return filterInclude.isEmpty || filterInclude.contains(filterVal);
      }

      final moves = [for (final tx in sorted) included(tx)];
      balances = runningBalances(timeline, opening: 0, moves: (i) => moves[i]);
      for (final (i, tx) in sorted.indexed) {
        if (!moves[i] && tx.status != TransactionStatus.cancelled && tx.id != keepStatusOf) {
          statusUpdates[tx.id] = TransactionStatus.cancelled;
        }
      }
    }

    final updates = {
      for (final (i, tx) in sorted.indexed)
        if (balances[i] != tx.balanceAfter) tx.id: balances[i],
    };

    if (updates.isNotEmpty) {
      await batchUpdateBalances(updates);
    }
    if (statusUpdates.isNotEmpty) {
      await _db.batch((batch) {
        for (final entry in statusUpdates.entries) {
          batch.update(
            _db.transactions,
            TransactionsCompanion(status: Value(entry.value)),
            where: (t) => t.id.equals(entry.key),
          );
        }
      });
    }
    _log.info(
      'recalculateBalances: account=$accountId, mode=${balanceMode.name}, updated=${updates.length}/${sorted.length}, cancelled=${statusUpdates.length}',
    );
    return BalanceRecalcResult(
      updated: updates.length,
      anchored: anchored?.anchored,
      opening: anchored?.opening,
      bankClosing: anchored?.bankClosing,
    );
  }
}

/// Outcome of a balance recalculation. The reconciliation fields are set in
/// `column` mode only.
class BalanceRecalcResult {
  final int updated;

  /// Whether the series could be anchored on a bank closing balance.
  final bool? anchored;

  /// Balance before the first row implied by the bank closing (0 when the
  /// whole history is in the app).
  final double? opening;
  final double? bankClosing;
  const BalanceRecalcResult({required this.updated, this.anchored, this.opening, this.bankClosing});
}
