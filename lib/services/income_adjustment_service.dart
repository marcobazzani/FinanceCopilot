import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('IncomeAdjustmentService');

class IncomeAdjustmentService {
  final AppDatabase _db;

  IncomeAdjustmentService(this._db);

  // ── Adjustment CRUD ──

  Stream<List<IncomeAdjustment>> watchAll() {
    return (_db.select(_db.incomeAdjustments)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.desc(a.incomeDate)]))
        .watch();
  }

  Future<List<IncomeAdjustment>> getAll() {
    return (_db.select(_db.incomeAdjustments)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.desc(a.incomeDate)]))
        .get();
  }

  Future<IncomeAdjustment> getById(int id) {
    return (_db.select(_db.incomeAdjustments)
          ..where((a) => a.id.equals(id)))
        .getSingle();
  }

  Stream<IncomeAdjustment> watchById(int id) {
    return (_db.select(_db.incomeAdjustments)
          ..where((a) => a.id.equals(id)))
        .watchSingle();
  }

  Future<int> create({
    required String name,
    required double totalAmount,
    required String currency,
    required DateTime incomeDate,
  }) async {
    _log.info('create: name=$name, date=$incomeDate');
    return _db.into(_db.incomeAdjustments).insert(
      IncomeAdjustmentsCompanion.insert(
        name: name,
        totalAmount: totalAmount,
        currency: Value(currency),
        incomeDate: incomeDate,
      ),
    );
  }

  Future<bool> update(int id, IncomeAdjustmentsCompanion companion) async {
    _log.info('update: id=$id');
    final rows = await (_db.update(_db.incomeAdjustments)
          ..where((a) => a.id.equals(id)))
        .write(companion);
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: income adjustment id=$id');
    await (_db.delete(_db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.equals(id)))
        .go();
    return (_db.delete(_db.incomeAdjustments)
          ..where((a) => a.id.equals(id)))
        .go();
  }

  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    _log.warning('deleteMany: ${ids.length} income adjustments (cascade: expenses)');
    await (_db.delete(_db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.isIn(ids)))
        .go();
    return (_db.delete(_db.incomeAdjustments)
          ..where((a) => a.id.isIn(ids)))
        .go();
  }

  // ── Expenses CRUD ──

  Stream<List<IncomeAdjustmentExpense>> watchExpenses(int adjustmentId) {
    return (_db.select(_db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.equals(adjustmentId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .watch();
  }

  Future<List<IncomeAdjustmentExpense>> getExpenses(int adjustmentId) {
    return (_db.select(_db.incomeAdjustmentExpenses)
          ..where((e) => e.adjustmentId.equals(adjustmentId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();
  }

  Future<int> addExpense({
    required int adjustmentId,
    required DateTime date,
    required double amount,
    String description = '',
  }) async {
    _log.info('addExpense: adjustmentId=$adjustmentId, date=$date');
    return _db.into(_db.incomeAdjustmentExpenses).insert(
      IncomeAdjustmentExpensesCompanion.insert(
        adjustmentId: adjustmentId,
        date: date,
        amount: amount,
        description: Value(description),
      ),
    );
  }

  Future<void> updateExpense(int id, IncomeAdjustmentExpensesCompanion companion) {
    return (_db.update(_db.incomeAdjustmentExpenses)
          ..where((e) => e.id.equals(id)))
        .write(companion);
  }

  Future<void> deleteExpense(int id) {
    _log.info('deleteExpense: id=$id');
    return (_db.delete(_db.incomeAdjustmentExpenses)
          ..where((e) => e.id.equals(id)))
        .go();
  }

  /// Total spent across all expenses for an adjustment.
  Future<double> totalSpent(int adjustmentId) async {
    final result = await _db.customSelect(
      'SELECT COALESCE(SUM(amount), 0.0) AS total '
      'FROM income_adjustment_expenses WHERE adjustment_id = ?',
      variables: [Variable.withInt(adjustmentId)],
      readsFrom: {_db.incomeAdjustmentExpenses},
    ).getSingle();
    return result.read<double>('total');
  }
}
