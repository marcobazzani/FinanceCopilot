import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('AssetService');

/// Aggregated stats for a single asset, computed from its events.
class AssetStats {
  final int eventCount;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final double totalInvested; // sum of buy amounts (absolute)
  final double totalQuantity; // net quantity (buys - sells)

  const AssetStats({
    required this.eventCount,
    this.firstDate,
    this.lastDate,
    this.totalInvested = 0,
    this.totalQuantity = 0,
  });
}

class AssetService {
  final AppDatabase _db;

  AssetService(this._db);

  Future<List<Asset>> getAll() =>
      (_db.select(_db.assets)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).get();

  Stream<List<Asset>> watchAll() =>
      (_db.select(_db.assets)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).watch();

  Future<Asset> getById(int id) =>
      (_db.select(_db.assets)..where((a) => a.id.equals(id))).getSingle();

  Future<int> create({
    required String name,
    String? ticker,
    String? isin,
    String? exchange,
    required String currency,
    double? taxRate,
    InstrumentType instrumentType = InstrumentType.etf,
    AssetClass assetClass = AssetClass.equity,
  }) {
    _log.info('create: name=$name, ticker=$ticker, isin=$isin, exchange=$exchange');
    return _db.into(_db.assets).insert(AssetsCompanion.insert(
      name: name,
      assetType: AssetType.stockEtf,
      valuationMethod: ValuationMethod.eventDriven,
      ticker: Value(ticker),
      isin: Value(isin),
      exchange: Value(exchange),
      currency: Value(currency),
      taxRate: Value(taxRate),
      instrumentType: Value(instrumentType),
      assetClass: Value(assetClass),
    ));
  }

  Future<bool> update(int id, AssetsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.assets)..where((a) => a.id.equals(id)))
        .write(companion)
        .then((rows) => rows > 0);
  }

  Future<int> delete(int id) async {
    _log.warning('delete: id=$id (cascade: events, snapshots, prices)');
    await (_db.delete(_db.assetEvents)..where((e) => e.assetId.equals(id))).go();
    await (_db.delete(_db.assetSnapshots)..where((s) => s.assetId.equals(id))).go();
    await (_db.delete(_db.marketPrices)..where((p) => p.assetId.equals(id))).go();
    return (_db.delete(_db.assets)..where((a) => a.id.equals(id))).go();
  }

  Future<void> reorder(List<int> orderedIds) async {
    _log.info('reorder: ${orderedIds.length} assets');
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.assets,
          AssetsCompanion(sortOrder: Value(i)),
          where: (a) => a.id.equals(orderedIds[i]),
        );
      }
    });
  }

  static const _statsQuery =
      'SELECT asset_id, COUNT(*) AS cnt, '
      'MIN(date) AS first_date, MAX(date) AS last_date, '
      "SUM(CASE WHEN type IN ('buy', 'contribute') THEN ABS(amount) ELSE 0 END) AS total_invested, "
      "SUM(CASE WHEN type = 'buy' THEN COALESCE(quantity, 0) "
      "         WHEN type = 'sell' THEN -COALESCE(quantity, 0) "
      '         ELSE 0 END) AS total_qty '
      'FROM asset_events GROUP BY asset_id';

  static AssetStats _rowToStats(QueryRow row) => AssetStats(
        eventCount: row.read<int>('cnt'),
        firstDate: row.readNullable<DateTime>('first_date'),
        lastDate: row.readNullable<DateTime>('last_date'),
        totalInvested: row.read<double>('total_invested'),
        totalQuantity: row.read<double>('total_qty'),
      );

  /// Get aggregated stats for all assets from their events.
  Future<Map<int, AssetStats>> getStatsForAll() async {
    final rows = await _db.customSelect(
      _statsQuery, readsFrom: {_db.assetEvents},
    ).get();
    return {for (final row in rows) row.read<int>('asset_id'): _rowToStats(row)};
  }

  /// Stream of aggregated stats for all assets, updates on event changes.
  Stream<Map<int, AssetStats>> watchStatsForAll() {
    return _db.customSelect(
      _statsQuery, readsFrom: {_db.assetEvents},
    ).watch().map((rows) {
      return {for (final row in rows) row.read<int>('asset_id'): _rowToStats(row)};
    });
  }
}
