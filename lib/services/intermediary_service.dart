import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('IntermediaryService');

class IntermediaryService {
  final AppDatabase _db;

  IntermediaryService(this._db);

  Future<List<Intermediary>> getAll() =>
      (_db.select(_db.intermediaries)..orderBy([(i) => OrderingTerm.asc(i.sortOrder)])).get();

  Stream<List<Intermediary>> watchAll() =>
      (_db.select(_db.intermediaries)..orderBy([(i) => OrderingTerm.asc(i.sortOrder)])).watch();

  Future<int> create({required String name}) {
    _log.info('create: name=$name');
    return _db.into(_db.intermediaries).insert(IntermediariesCompanion.insert(
      name: name,
    ));
  }

  Future<void> update(int id, IntermediariesCompanion data) {
    _log.info('update: id=$id');
    return (_db.update(_db.intermediaries)..where((i) => i.id.equals(id)))
        .write(data.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> delete(int id) async {
    _log.info('delete: id=$id');
    // Assets need an intermediary since schema v29 — refuse to delete if any
    // are still attached. Caller should prompt the user to move them first.
    final assetCount = (await _db.customSelect(
      'SELECT COUNT(*) AS c FROM assets WHERE intermediary_id = ?',
      variables: [Variable.withInt(id)],
    ).getSingle()).read<int>('c');
    if (assetCount > 0) {
      throw StateError('intermediary_has_assets:$assetCount');
    }
    // Accounts are still nullable — unlink them.
    await _db.customUpdate(
      'UPDATE accounts SET intermediary_id = NULL WHERE intermediary_id = ?',
      variables: [Variable.withInt(id)],
      updates: {_db.accounts},
    );
    await (_db.delete(_db.intermediaries)..where((i) => i.id.equals(id))).go();
    _log.info('delete: id=$id - removed (accounts unlinked)');
  }

  Future<void> reorder(List<int> orderedIds) async {
    _log.info('reorder: ${orderedIds.length} intermediaries');
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.intermediaries,
          IntermediariesCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<void> moveAccount(int accountId, int? intermediaryId) async {
    _log.info('moveAccount: accountId=$accountId -> intermediaryId=$intermediaryId');
    await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
        .write(AccountsCompanion(intermediaryId: Value(intermediaryId)));
  }

  Future<void> moveAsset(int assetId, int intermediaryId) async {
    _log.info('moveAsset: assetId=$assetId -> intermediaryId=$intermediaryId');
    await (_db.update(_db.assets)..where((a) => a.id.equals(assetId)))
        .write(AssetsCompanion(intermediaryId: Value(intermediaryId)));
  }
}
