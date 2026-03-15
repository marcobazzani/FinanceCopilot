import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('AssetService');

class AssetService {
  final AppDatabase _db;

  AssetService(this._db);

  Future<List<Asset>> getAll() => _db.select(_db.assets).get();

  Stream<List<Asset>> watchAll() => _db.select(_db.assets).watch();

  Future<Asset> getById(int id) =>
      (_db.select(_db.assets)..where((a) => a.id.equals(id))).getSingle();

  Future<int> create({
    required String name,
    required AssetType assetType,
    required ValuationMethod valuationMethod,
    String? ticker,
    String? isin,
    String currency = 'EUR',
    double? taxRate,
  }) {
    _log.info('create: name=$name, type=${assetType.name}, valuation=${valuationMethod.name}');
    return _db.into(_db.assets).insert(AssetsCompanion.insert(
      name: name,
      assetType: assetType,
      valuationMethod: valuationMethod,
      ticker: Value(ticker),
      isin: Value(isin),
      currency: Value(currency),
      taxRate: Value(taxRate),
    ));
  }

  Future<bool> update(int id, AssetsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.assets)..where((a) => a.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) {
    _log.warning('delete: id=$id');
    return (_db.delete(_db.assets)..where((a) => a.id.equals(id))).go();
  }
}
