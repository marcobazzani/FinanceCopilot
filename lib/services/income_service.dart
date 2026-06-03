import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('IncomeService');

class IncomeService {
  final AppDatabase _db;

  IncomeService(this._db);

  Stream<List<Income>> watchAll({DateTime? through}) {
    final query = _db.select(_db.incomes);
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((i) => i.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(i) => OrderingTerm.desc(i.valueDate)]);
    return query.watch();
  }

  Future<List<Income>> getAll({DateTime? through}) {
    final query = _db.select(_db.incomes);
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((i) => i.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(i) => OrderingTerm.desc(i.valueDate)]);
    return query.get();
  }

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

  static DateTime? _throughEndExclusive(DateTime? through) {
    if (through == null) return null;
    return DateTime(
      through.year,
      through.month,
      through.day,
    ).add(const Duration(days: 1));
  }
}
