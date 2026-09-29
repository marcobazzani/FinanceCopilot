import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/asset_value_math.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';

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
  ///
  /// Each buy counts with its amount as recorded: one recorded in another
  /// currency is not converted. The base-currency cost basis
  /// (`convertedAssetStatsProvider`) converts every buy instead.
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

  Future<bool> update(int id, AssetsCompanion companion) async {
    _log.info('update: id=$id');
    // Detect a bond reclassification so we can rescale event amounts: bond
    // prices are quoted as % of face value, so amount = qty*price/100 for
    // bonds vs qty*price otherwise. A provider-unrecognized bond imported as
    // an ETF stores 100x-too-large amounts; correcting the type here must
    // also correct the stored amounts, or invested/cost-basis stays 100x off
    // while the live market value (read-time divisor) looks right — the
    // "incongruenza" in issue #87.
    InstrumentType? before;
    if (companion.instrumentType.present) {
      final old = await (_db.select(_db.assets)..where((a) => a.id.equals(id))).getSingleOrNull();
      before = old?.instrumentType;
    }
    final rows = await (_db.update(_db.assets)..where((a) => a.id.equals(id))).write(companion);
    if (rows > 0 && companion.instrumentType.present && before != null) {
      final after = companion.instrumentType.value;
      final wasBond = before == InstrumentType.bond;
      final isBond = after == InstrumentType.bond;
      if (wasBond != isBond) {
        await AssetEventService(_db).rescaleEventAmountsForBondReclassification(id, toBond: isBond);
      }
    }
    return rows > 0;
  }

  /// Deletes the asset with its events, snapshots and prices in one
  /// transaction: a failure part-way deletes nothing.
  Future<int> delete(int id) => deleteMany([id]);

  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    _log.warning('deleteMany: ${ids.length} assets $ids (cascade: events, snapshots, prices)');
    return _db.transaction(() async {
      await (_db.delete(_db.assetEvents)..where((e) => e.assetId.isIn(ids))).go();
      await (_db.delete(_db.assetSnapshots)..where((s) => s.assetId.isIn(ids))).go();
      await (_db.delete(_db.marketPrices)..where((p) => p.assetId.isIn(ids))).go();
      return (_db.delete(_db.assets)..where((a) => a.id.isIn(ids))).go();
    });
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

  // first/last date use value_date per AGENTS.md (canonical "money moved"
  // date for display). operation_date is only for import dedup.
  //
  // total_invested is computed by walking each asset's events in
  // chronological order and maintaining a running weighted-average cost
  // pool (see [_computeAssetStats]) rather than a single all-time SQL
  // aggregate. A global aggregate (SUM(buy)/SUM(buyQty) × remainingQty)
  // is only correct when the position never fully closes: once every share
  // is sold, any later re-buy must start a fresh pool at its own price —
  // blending it with the disposed lot's cost produces a phantom average
  // (e.g. buy 1@100, sell it, buy 1@200 must show cost 200, not 150).

  SimpleSelectStatement<$AssetEventsTable, AssetEvent> _statsEventsQuery({DateTime? through}) {
    final query = _db.select(_db.assetEvents)
      ..orderBy([
        (e) => OrderingTerm.asc(e.valueDate),
        (e) => OrderingTerm.asc(e.id),
      ]);
    if (through != null) query.where((e) => e.valueDate.isSmallerThanValue(startOfNextDay(through)));
    return query;
  }

  /// Group already chronologically-sorted events by asset and reduce each
  /// group to its [AssetStats] via [_computeAssetStats].
  static Map<int, AssetStats> _computeStatsFromEvents(List<AssetEvent> events) {
    final byAsset = <int, List<AssetEvent>>{};
    for (final e in events) {
      byAsset.putIfAbsent(e.assetId, () => []).add(e);
    }
    return {for (final entry in byAsset.entries) entry.key: _computeAssetStats(entry.value)};
  }

  /// Reduce one asset's events (already ordered by valueDate, then id) to
  /// its aggregated [AssetStats]; the cost basis is the moving-average pool
  /// of [CostBasisPool].
  //
  // ABS(quantity): event.type encodes direction; the source row's sign on
  // quantity is irrelevant. Some broker exports (Directa, Fineco, IB-style)
  // store sells with negative quantity. See issue #77.
  //
  // Buys that carry NO per-share quantity (cash-only events — pension
  // contribute via the A3 fallback, manual entries without qty) can't join a
  // per-share pool: there is no quantity to attach a unit cost to. The pool
  // keeps their gross amount apart and ADDS it to the result, so an asset
  // that mixes both shapes reports the full amount the user put in. Dropping
  // it whenever some other buy happened to carry a quantity would silently
  // understate invested capital (a 100 contribution followed by a 200
  // two-share buy must report 300, not 200).
  static AssetStats _computeAssetStats(List<AssetEvent> events) {
    var eventCount = 0;
    DateTime? firstDate;
    DateTime? lastDate;
    final pool = CostBasisPool();

    for (final e in events) {
      eventCount++;
      if (firstDate == null || e.valueDate.isBefore(firstDate)) firstDate = e.valueDate;
      if (lastDate == null || e.valueDate.isAfter(lastDate)) lastDate = e.valueDate;

      if (e.type == EventType.buy) {
        pool.buy(e.amount.abs(), (e.quantity ?? 0.0).abs());
      } else if (e.type == EventType.sell) {
        pool.sell((e.quantity ?? 0.0).abs());
      }
      // Other event types (revalue) don't affect quantity or cost basis,
      // but still count toward eventCount/first/lastDate above.
    }

    // Cost basis of what is still held = the per-share pool (already reduced
    // for every sell) plus any cash-only contributions. Selling every share
    // zeroes the per-share side — the unrealized P&L on a closed position is
    // zero — while cash-only contributions are unaffected by share sales and
    // keep counting. A purely cash-only asset therefore reports its gross
    // contributions, and a purely share-based one its pool, with no special
    // casing needed for either.
    return AssetStats(
      eventCount: eventCount,
      firstDate: firstDate,
      lastDate: lastDate,
      totalInvested: pool.costBasis(),
      totalQuantity: pool.heldQuantity,
    );
  }

  /// Get aggregated stats for all assets from their events.
  Future<Map<int, AssetStats>> getStatsForAll({DateTime? through}) async {
    final events = await _statsEventsQuery(through: through).get();
    return _computeStatsFromEvents(events);
  }

  /// Stream of aggregated stats for all assets, updates on event changes.
  Stream<Map<int, AssetStats>> watchStatsForAll({DateTime? through}) {
    return _statsEventsQuery(through: through).watch().map(_computeStatsFromEvents);
  }
}
