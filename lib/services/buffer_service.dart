import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('BufferService');

class BufferService {
  final AppDatabase _db;

  BufferService(this._db);

  // ── Buffer CRUD ──

  Stream<List<Buffer>> watchAll() {
    return (_db.select(_db.buffers)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([(b) => OrderingTerm.asc(b.name)]))
        .watch();
  }

  Future<int> create({
    required String name,
    double? targetAmount,
    int? linkedDepreciationId,
  }) {
    _log.info('create: name=$name, target=$targetAmount, linkedDepId=$linkedDepreciationId');
    return _db.into(_db.buffers).insert(BuffersCompanion.insert(
      name: name,
      targetAmount: Value(targetAmount),
      linkedDepreciationId: Value(linkedDepreciationId),
    ));
  }

  Future<bool> update(int id, BuffersCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.buffers)..where((b) => b.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())))
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) async {
    _log.warning('delete: buffer id=$id');
    await (_db.delete(_db.bufferTransactions)..where((t) => t.bufferId.equals(id))).go();
    return (_db.delete(_db.buffers)..where((b) => b.id.equals(id))).go();
  }

  // ── BufferTransaction CRUD ──

  Stream<List<BufferTransaction>> watchByBuffer(int bufferId) {
    return (_db.select(_db.bufferTransactions)
          ..where((t) => t.bufferId.equals(bufferId))
          ..orderBy([(t) => OrderingTerm.desc(t.operationDate)]))
        .watch();
  }

  Future<List<BufferTransaction>> getByBuffer(int bufferId) {
    return (_db.select(_db.bufferTransactions)
          ..where((t) => t.bufferId.equals(bufferId))
          ..orderBy([(t) => OrderingTerm.asc(t.operationDate)]))
        .get();
  }

  Future<int> createTransaction({
    required int bufferId,
    required DateTime operationDate,
    DateTime? valueDate,
    String description = '',
    required double amount,
    String currency = 'EUR',
    bool isReimbursement = false,
  }) async {
    _log.info('createTransaction: bufferId=$bufferId, amount=$amount, reimb=$isReimbursement');
    final balance = (await computeBalance(bufferId)) + amount;
    return _db.into(_db.bufferTransactions).insert(
      BufferTransactionsCompanion.insert(
        bufferId: bufferId,
        operationDate: operationDate,
        valueDate: valueDate ?? operationDate,
        description: Value(description),
        amount: amount,
        currency: Value(currency),
        balanceAfter: balance,
        isReimbursement: Value(isReimbursement),
      ),
    );
  }

  Future<bool> updateTransaction(int id, BufferTransactionsCompanion companion) {
    _log.info('updateTransaction: id=$id');
    return (_db.update(_db.bufferTransactions)..where((t) => t.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> deleteTransaction(int id) {
    _log.warning('deleteTransaction: id=$id');
    return (_db.delete(_db.bufferTransactions)..where((t) => t.id.equals(id))).go();
  }

  Future<double> computeBalance(int bufferId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(amount), 0.0) AS total FROM buffer_transactions WHERE buffer_id = ?',
      variables: [Variable.withInt(bufferId)],
    ).getSingle();
    return row.read<double>('total');
  }
}
