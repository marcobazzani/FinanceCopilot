import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('AssetEventService');

class AssetEventService {
  final AppDatabase _db;

  AssetEventService(this._db);

  Stream<List<AssetEvent>> watchByAsset(int assetId) {
    return (_db.select(_db.assetEvents)
          ..where((e) => e.assetId.equals(assetId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Future<List<AssetEvent>> getByAsset(int assetId) {
    return (_db.select(_db.assetEvents)
          ..where((e) => e.assetId.equals(assetId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }

  Future<int> create({
    required int assetId,
    required DateTime date,
    required EventType type,
    required double amount,
    double? quantity,
    double? price,
    required String currency,
    double? exchangeRate,
    double? commission,
    String? notes,
  }) {
    _log.info('create: assetId=$assetId, date=$date, type=${type.name}');
    return _db.into(_db.assetEvents).insert(AssetEventsCompanion.insert(
      assetId: assetId,
      date: date,
      type: type,
      amount: amount,
      quantity: Value(quantity),
      price: Value(price),
      currency: Value(currency),
      exchangeRate: Value(exchangeRate),
      commission: Value(commission),
      notes: Value(notes),
    ));
  }

  Future<bool> update(int id, AssetEventsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.assetEvents)..where((e) => e.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) {
    _log.warning('delete: event id=$id');
    return (_db.delete(_db.assetEvents)..where((e) => e.id.equals(id))).go();
  }

  Future<int> deleteByAsset(int assetId) {
    _log.warning('deleteByAsset: assetId=$assetId');
    return (_db.delete(_db.assetEvents)..where((e) => e.assetId.equals(assetId))).go();
  }

  /// Weighted average buy price: total_cost / total_qty for buy/contribute events.
  /// Returns null if no qualifying events exist.
  Future<double?> getAverageBuyPrice(int assetId) async {
    final row = await _db.customSelect(
      "SELECT SUM(ABS(COALESCE(quantity,0)) * COALESCE(price,0)) AS total_cost, "
      "SUM(ABS(COALESCE(quantity,0))) AS total_qty "
      "FROM asset_events WHERE asset_id = ? AND type IN ('buy','contribute') "
      "AND quantity IS NOT NULL AND price IS NOT NULL",
      variables: [Variable.withInt(assetId)],
    ).getSingleOrNull();
    final totalCost = row?.readNullable<double>('total_cost') ?? 0;
    final totalQty = row?.readNullable<double>('total_qty') ?? 0;
    return totalQty > 0 ? totalCost / totalQty : null;
  }
}
