import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('IncomeService');

class IncomeService {
  final AppDatabase _db;

  IncomeService(this._db);

  Stream<List<Income>> watchAll() {
    return (_db.select(_db.incomes)
          ..orderBy([(i) => OrderingTerm.desc(i.date)]))
        .watch();
  }

  Future<List<Income>> getAll() {
    return (_db.select(_db.incomes)
          ..orderBy([(i) => OrderingTerm.desc(i.date)]))
        .get();
  }

  Future<Income> getById(int id) {
    return (_db.select(_db.incomes)
          ..where((i) => i.id.equals(id)))
        .getSingle();
  }

  Stream<Income> watchById(int id) {
    return (_db.select(_db.incomes)
          ..where((i) => i.id.equals(id)))
        .watchSingle();
  }

  Future<int> create({
    required DateTime date,
    required double amount,
    IncomeType type = IncomeType.income,
    required String currency,
  }) async {
    _log.info('create: date=$date, type=$type, currency=$currency');
    return _db.into(_db.incomes).insert(
      IncomesCompanion.insert(
        date: date,
        amount: amount,
        type: Value(type),
        currency: Value(currency),
      ),
    );
  }

  Future<bool> update(int id, IncomesCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.incomes)
          ..where((i) => i.id.equals(id)))
        .write(companion);
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: income id=$id');
    return (_db.delete(_db.incomes)
          ..where((i) => i.id.equals(id)))
        .go();
  }

  Future<void> bulkCreate(List<IncomesCompanion> entries) async {
    _log.info('bulkCreate: ${entries.length} entries');
    await _db.batch((batch) {
      batch.insertAll(_db.incomes, entries);
    });
  }
}
