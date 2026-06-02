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

  /// Cost basis of the currently-held position, in the asset's currency.
  ///
  /// Computed as weighted-average buy price × remaining quantity, so a sell
  /// reduces invested proportionally to the cost of the shares disposed of —
  /// not by the sale proceeds. This is the value the dashboard uses for the
  /// "delta vs prezzo di carico" (unrealized gain) display: a position that
  /// has been partially sold shows the unrealized gain on what's left, not
  /// a phantom loss against the all-time cash deployed.
  ///
  /// Falls back to `SUM(buy.amount)` (gross cumulative buys) when buy events
  /// have no per-share quantity (pension contributions in cash-only mode,
  /// or any buy with `quantity IS NULL`) — those have no per-share price to
  /// weight against, so the gross sum is the only meaningful figure.
  final double totalInvested;

  final double totalQuantity; // net quantity (buys - sells), always ≥ 0

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

  Future<List<Asset>> getAll() => (_db.select(_db.assets)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).get();

  Stream<List<Asset>> watchAll() => (_db.select(_db.assets)..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])).watch();

  Stream<List<Asset>> watchActive() =>
      (_db.select(_db.assets)
            ..where((a) => a.isActive.equals(true))
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
          .watch();

  Future<Asset> getById(int id) => (_db.select(_db.assets)..where((a) => a.id.equals(id))).getSingle();

  Future<int> create({
    required String name,
    required int intermediaryId,
    String? ticker,
    String? isin,
    String? exchange,
    required String currency,
    double? taxRate,
    ValuationMethod valuationMethod = ValuationMethod.marketPrice,
    InstrumentType? instrumentType,
    AssetClass? assetClass,
    AssetType assetType = AssetType.stockEtf,
    double? ter,
    bool? isActive,
    bool? includeInSavings,
  }) {
    _log.info(
      'create: name=$name, ticker=$ticker, isin=$isin, exchange=$exchange, '
      'intermediary=$intermediaryId, valuation=${valuationMethod.name}, '
      'instrument=${instrumentType?.name}, class=${assetClass?.name}, '
      'assetType=${assetType.name}',
    );
    return _db
        .into(_db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: assetType,
            valuationMethod: valuationMethod,
            intermediaryId: intermediaryId,
            ticker: Value(ticker),
            isin: Value(isin),
            exchange: Value(exchange),
            currency: Value(currency),
            taxRate: Value(taxRate),
            instrumentType: instrumentType != null ? Value(instrumentType) : const Value.absent(),
            assetClass: assetClass != null ? Value(assetClass) : const Value.absent(),
            ter: Value(ter),
            isActive: isActive != null ? Value(isActive) : const Value.absent(),
            includeInSavings: includeInSavings != null ? Value(includeInSavings) : const Value.absent(),
          ),
        );
  }

  Future<bool> update(int id, AssetsCompanion companion) {
    _log.info('update: id=$id');
    return (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(companion).then((rows) => rows > 0);
  }

  Future<int> delete(int id) async {
    _log.warning('delete: id=$id (cascade: events, snapshots, prices)');
    await (_db.delete(_db.assetEvents)..where((e) => e.assetId.equals(id))).go();
    await (_db.delete(_db.assetSnapshots)..where((s) => s.assetId.equals(id))).go();
    await (_db.delete(_db.marketPrices)..where((p) => p.assetId.equals(id))).go();
    return (_db.delete(_db.assets)..where((a) => a.id.equals(id))).go();
  }

  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    _log.warning('deleteMany: ${ids.length} assets (cascade: events, snapshots, prices)');
    await (_db.delete(_db.assetEvents)..where((e) => e.assetId.isIn(ids))).go();
    await (_db.delete(_db.assetSnapshots)..where((s) => s.assetId.isIn(ids))).go();
    await (_db.delete(_db.marketPrices)..where((p) => p.assetId.isIn(ids))).go();
    return (_db.delete(_db.assets)..where((a) => a.id.isIn(ids))).go();
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

  // first/last date use value_date per CLAUDE.md (canonical "money moved"
  // date for display). operation_date is only for import dedup.
  //
  // ABS(quantity): event.type encodes direction; the source row's sign on
  // quantity is irrelevant. Some broker exports (Directa, Fineco, IB-style)
  // store sells with negative quantity. Without ABS, `-COALESCE(-199, 0)`
  // adds +199 instead of subtracting 199. See issue #77.
  //
  // total_invested is computed at the Dart layer (not in SQL) so that
  // the weighted-average × remaining-qty cost basis can fall back to
  // the gross buy sum when no per-share quantity is available — see
  // [_rowToStats] for the branching. The SQL exposes the three raw
  // aggregates needed for the calculation.
  static String _statsSql({required bool bounded}) =>
      'SELECT asset_id, COUNT(*) AS cnt, '
      'MIN(value_date) AS first_date, MAX(value_date) AS last_date, '
      "SUM(CASE WHEN type = 'buy' THEN ABS(amount) ELSE 0 END) AS total_buy_amount, "
      "SUM(CASE WHEN type = 'buy' THEN ABS(COALESCE(quantity, 0)) ELSE 0 END) AS total_buy_qty, "
      "SUM(CASE WHEN type = 'buy' THEN ABS(COALESCE(quantity, 0)) "
      "         WHEN type = 'sell' THEN -ABS(COALESCE(quantity, 0)) "
      '         ELSE 0 END) AS total_qty '
      'FROM asset_events '
      '${bounded ? 'WHERE value_date < ? ' : ''}'
      'GROUP BY asset_id';

  static AssetStats _rowToStats(QueryRow row) {
    final totalBuyAmount = row.read<double>('total_buy_amount');
    final totalBuyQty = row.read<double>('total_buy_qty');
    final remainingQty = row.read<double>('total_qty');

    // Weighted-average cost basis of the currently-held shares.
    // Three branches, each with a distinct intuition:
    //  - No per-share qty on any buy → cash-only event (pension contribute
    //    via A3 fallback, manual entries without qty). Weighted-avg can't
    //    be computed; report the gross buy sum, which matches the user's
    //    expectation for those assets ("how much I deposited").
    //  - Position is fully closed (remainingQty ≤ 0). No cost basis to
    //    report — the unrealized P&L on a zero position is zero.
    //  - Normal case: weighted-avg buy price × shares still held.
    final double totalInvested;
    if (totalBuyQty <= 0) {
      totalInvested = totalBuyAmount;
    } else if (remainingQty <= 0) {
      totalInvested = 0;
    } else {
      final avgCost = totalBuyAmount / totalBuyQty;
      totalInvested = avgCost * remainingQty;
    }

    return AssetStats(
      eventCount: row.read<int>('cnt'),
      firstDate: row.readNullable<DateTime>('first_date'),
      lastDate: row.readNullable<DateTime>('last_date'),
      totalInvested: totalInvested,
      totalQuantity: remainingQty,
    );
  }

  /// Get aggregated stats for all assets from their events.
  Future<Map<int, AssetStats>> getStatsForAll({DateTime? through}) async {
    final rows = await _db
        .customSelect(
          _statsSql(bounded: through != null),
          variables: _throughVars(through),
          readsFrom: {_db.assetEvents},
        )
        .get();
    return {for (final row in rows) row.read<int>('asset_id'): _rowToStats(row)};
  }

  /// Stream of aggregated stats for all assets, updates on event changes.
  Stream<Map<int, AssetStats>> watchStatsForAll({DateTime? through}) {
    return _db
        .customSelect(
          _statsSql(bounded: through != null),
          variables: _throughVars(through),
          readsFrom: {_db.assetEvents},
        )
        .watch()
        .map((rows) {
          return {for (final row in rows) row.read<int>('asset_id'): _rowToStats(row)};
        });
  }

  static List<Variable<int>> _throughVars(DateTime? through) {
    if (through == null) return const [];
    final endExclusive = DateTime(
      through.year,
      through.month,
      through.day,
    ).add(const Duration(days: 1));
    return [Variable.withInt(endExclusive.millisecondsSinceEpoch ~/ 1000)];
  }
}
