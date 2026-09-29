import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/income_split.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';

final _log = getLogger('IncomeService');

class IncomeService {
  final AppDatabase _db;

  IncomeService(this._db);

  SimpleSelectStatement<$IncomesTable, Income> _all({DateTime? through}) {
    final query = _db.select(_db.incomes);
    if (through != null) query.where((i) => i.valueDate.isSmallerThanValue(startOfNextDay(through)));
    return query..orderBy([(i) => OrderingTerm.desc(i.valueDate)]);
  }

  Stream<List<Income>> watchAll({DateTime? through}) => _all(through: through).watch();

  Future<List<Income>> getAll({DateTime? through}) => _all(through: through).get();

  Future<Income> getById(int id) {
    return (_db.select(_db.incomes)..where((i) => i.id.equals(id))).getSingle();
  }

  Stream<Income> watchById(int id) {
    return (_db.select(_db.incomes)..where((i) => i.id.equals(id))).watchSingle();
  }

  Future<int> create({
    required DateTime date,
    required double amount,
    IncomeType type = IncomeType.income,
    required String currency,
  }) async {
    _log.info('create: date=$date, type=$type, currency=$currency');
    return _db
        .into(_db.incomes)
        .insert(
          IncomesCompanion.insert(
            date: date,
            valueDate: date,
            amount: amount,
            type: Value(type),
            currency: Value(currency),
          ),
        );
  }

  /// Persist a single inflow split across several [IncomeType]s as one row per
  /// non-zero slice, in ONE batch so a partial split can never be written.
  ///
  /// Used by "Flag as Income" on a bank transaction: the same date, currency
  /// and (optional) source asset apply to every slice.
  Future<void> createSplit({
    required DateTime date,
    required String currency,
    required List<IncomeSplitEntry> entries,
    int? assetId,
  }) async {
    if (entries.isEmpty) return;
    _log.info('createSplit: date=$date, currency=$currency, slices=${entries.length}');
    await bulkCreate([
      for (final entry in entries)
        IncomesCompanion.insert(
          date: date,
          valueDate: date,
          amount: entry.amount,
          type: Value(entry.type),
          currency: Value(currency),
          assetId: Value(assetId),
        ),
    ]);
  }

  Future<bool> update(int id, IncomesCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.incomes)..where((i) => i.id.equals(id))).write(companion);
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: income id=$id');
    return (_db.delete(_db.incomes)..where((i) => i.id.equals(id))).go();
  }

  Future<int> deleteMany(List<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    _log.warning('deleteMany: ${ids.length} incomes');
    return (_db.delete(_db.incomes)..where((i) => i.id.isIn(ids))).go();
  }

  Future<void> bulkCreate(List<IncomesCompanion> entries) async {
    _log.info('bulkCreate: ${entries.length} entries');
    await _db.batch((batch) {
      batch.insertAll(_db.incomes, entries);
    });
  }
}
