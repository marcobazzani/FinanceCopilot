import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';

final _log = getLogger('AssetEventService');

class AssetEventService {
  final AppDatabase _db;

  AssetEventService(this._db);

  Stream<List<AssetEvent>> watchByAsset(int assetId, {DateTime? through}) {
    final query = _db.select(_db.assetEvents)
      ..where((e) => e.assetId.equals(assetId));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.valueDate)]);
    return query.watch();
  }

  Future<List<AssetEvent>> getByAsset(int assetId, {DateTime? through}) {
    final query = _db.select(_db.assetEvents)
      ..where((e) => e.assetId.equals(assetId));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.valueDate)]);
    return query.get();
  }

  /// Fetch events for multiple assets in a single query, grouped by asset ID.
  Future<Map<int, List<AssetEvent>>> getByAssets(
    List<int> assetIds, {
    DateTime? through,
  }) async {
    if (assetIds.isEmpty) return {};
    final query = _db.select(_db.assetEvents)
      ..where((e) => e.assetId.isIn(assetIds));
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive != null) {
      query.where((e) => e.valueDate.isSmallerThanValue(endExclusive));
    }
    query.orderBy([(e) => OrderingTerm.desc(e.valueDate)]);
    final events = await query.get();
    final result = <int, List<AssetEvent>>{};
    for (final event in events) {
      result.putIfAbsent(event.assetId, () => []).add(event);
    }
    return result;
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
  }) async {
    _log.info('create: assetId=$assetId, date=$date, type=${type.name}');
    // event.type carries direction — normalize qty to abs() so the stats
    // aggregation never double-negates a signed sell quantity. See #77.
    final id = await _db.into(_db.assetEvents).insert(AssetEventsCompanion.insert(
      assetId: assetId,
      date: date,
      valueDate: date,
      type: type,
      amount: amount,
      quantity: Value(quantity?.abs()),
      price: Value(price),
      currency: Value(currency),
      exchangeRate: Value(exchangeRate),
      commission: Value(commission),
      notes: Value(notes),
    ));
    await resyncRevaluePricesForAsset(assetId);
    return id;
  }

  Future<bool> update(int id, AssetEventsCompanion companion) async {
    _log.info('update: id=$id');
    final before = await (_db.select(_db.assetEvents)..where((e) => e.id.equals(id))).getSingleOrNull();
    final rows = await (_db.update(_db.assetEvents)..where((e) => e.id.equals(id)))
        .write(companion);
    if (rows > 0) {
      final after = await (_db.select(_db.assetEvents)..where((e) => e.id.equals(id))).getSingleOrNull();
      // Capture the displaced revalue date(s) so resync can clean up orphan
      // market_prices rows when a revalue's value_date moved or its type
      // changed away from 'revalue'.
      final orphanDates = <DateTime>[];
      if (before != null && before.type == EventType.revalue) {
        orphanDates.add(before.valueDate);
      }
      final assetIds = <int>{
        if (before != null) before.assetId,
        if (after != null) after.assetId,
      };
      for (final aid in assetIds) {
        await resyncRevaluePricesForAsset(aid, orphanDates: orphanDates);
      }
    }
    return rows > 0;
  }

  Future<int> delete(int id) async {
    _log.warning('delete: event id=$id');
    final before = await (_db.select(_db.assetEvents)..where((e) => e.id.equals(id))).getSingleOrNull();
    final rows = await (_db.delete(_db.assetEvents)..where((e) => e.id.equals(id))).go();
    if (rows > 0 && before != null) {
      final orphanDates = <DateTime>[
        if (before.type == EventType.revalue) before.valueDate,
      ];
      await resyncRevaluePricesForAsset(before.assetId, orphanDates: orphanDates);
    }
    return rows;
  }

  Future<int> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return 0;
    _log.warning('deleteMany: ${ids.length} events');
    final before = await (_db.select(_db.assetEvents)..where((e) => e.id.isIn(ids))).get();
    final rows = await (_db.delete(_db.assetEvents)..where((e) => e.id.isIn(ids))).go();
    if (rows > 0) {
      final orphansByAsset = <int, List<DateTime>>{};
      for (final e in before) {
        if (e.type == EventType.revalue) {
          orphansByAsset.putIfAbsent(e.assetId, () => []).add(e.valueDate);
        }
      }
      final affected = before.map((e) => e.assetId).toSet();
      for (final aid in affected) {
        await resyncRevaluePricesForAsset(aid, orphanDates: orphansByAsset[aid] ?? const []);
      }
    }
    return rows;
  }

  Future<int> deleteByAsset(int assetId) async {
    _log.warning('deleteByAsset: assetId=$assetId');
    final beforeRevalues = await (_db.select(_db.assetEvents)
          ..where((e) => e.assetId.equals(assetId) & e.type.equalsValue(EventType.revalue)))
        .get();
    final rows = await (_db.delete(_db.assetEvents)..where((e) => e.assetId.equals(assetId))).go();
    if (rows > 0) {
      await resyncRevaluePricesForAsset(
        assetId,
        orphanDates: beforeRevalues.map((e) => e.valueDate).toList(),
      );
    }
    return rows;
  }

  /// Materialise every `revalue` event into a `market_prices` row anchored to
  /// the qty-at-revalue-date. This makes manual assets behave like priced
  /// assets — every consumer of asset value reads from `market_prices` and
  /// picks up revaluations without per-consumer logic.
  ///
  /// Called after every CRUD mutation (regardless of event type) because a
  /// buy/sell whose date precedes a revalue shifts that revalue's qty-at-date.
  ///
  /// [orphanDates] are dates that previously held a revalue but no longer do
  /// (revalue moved away or was deleted) — their stale market_prices row must
  /// be removed so it doesn't pretend to be a market-data price tick.
  Future<void> resyncRevaluePricesForAsset(
    int assetId, {
    List<DateTime> orphanDates = const [],
  }) async {
    final revalueRows = await _db.customSelect(
      "SELECT value_date FROM asset_events "
      "WHERE asset_id = ? AND type = 'revalue'",
      variables: [Variable.withInt(assetId)],
    ).get();
    final revalueDates = revalueRows
        .map((r) => DateTime.fromMillisecondsSinceEpoch(r.read<int>('value_date') * 1000))
        .toList();

    // Step 1: delete market_prices rows at any current-revalue date AND any
    // orphan date passed in by the caller. Provider rows on other
    // dates are preserved.
    final datesToClear = <DateTime>{...revalueDates, ...orphanDates};
    if (datesToClear.isNotEmpty) {
      final placeholders = datesToClear.map((_) => '?').join(',');
      await _db.customStatement(
        'DELETE FROM market_prices WHERE asset_id = ? AND date IN ($placeholders)',
        [
          assetId,
          ...datesToClear.map((d) => d.millisecondsSinceEpoch ~/ 1000),
        ],
      );
    }

    if (revalueDates.isEmpty) return;

    final assetRow = await (_db.select(_db.assets)..where((a) => a.id.equals(assetId))).getSingleOrNull();
    if (assetRow == null) return;
    final currency = assetRow.currency;

    for (final rDate in revalueDates) {
      // When two revalues share a value_date, the latest-inserted wins (same
      // last-write-wins behavior as market_prices PK on (asset_id, date)).
      final amountRow = await _db.customSelect(
        "SELECT amount FROM asset_events "
        "WHERE asset_id = ? AND type = 'revalue' AND value_date = ? "
        "ORDER BY id DESC LIMIT 1",
        variables: [Variable.withInt(assetId), Variable.withInt(rDate.millisecondsSinceEpoch ~/ 1000)],
      ).getSingleOrNull();
      if (amountRow == null) continue;
      final amount = amountRow.read<double>('amount');

      // qty-at-revalue: buys add quantity, sells subtract. Pension
      // contributions are imported as `buy` events with synthesized
      // quantity=amount, price=1.0 (see import_service.dart A3
      // auto-fill), so they're naturally counted here without a special
      // case.
      // ABS(quantity): event.type encodes direction. See issue #77 — broker
      // exports with negative sell quantity would otherwise be added.
      final qtyRow = await _db.customSelect(
        "SELECT SUM(CASE WHEN type = 'buy' THEN ABS(COALESCE(quantity, 0)) "
        "WHEN type = 'sell' THEN -ABS(COALESCE(quantity, 0)) ELSE 0 END) AS qty "
        "FROM asset_events WHERE asset_id = ? AND value_date <= ?",
        variables: [Variable.withInt(assetId), Variable.withInt(rDate.millisecondsSinceEpoch ~/ 1000)],
      ).getSingleOrNull();
      final qty = qtyRow?.readNullable<double>('qty') ?? 0;
      if (qty <= 0) {
        _log.warning(
          'resyncRevalue: assetId=$assetId revalue at $rDate has qty<=0 ($qty), skipping market_prices write',
        );
        continue;
      }

      final closePrice = amount / qty;
      await _db.into(_db.marketPrices).insertOnConflictUpdate(
            MarketPricesCompanion(
              assetId: Value(assetId),
              date: Value(rDate),
              closePrice: Value(closePrice),
              currency: Value(currency),
            ),
          );
    }
  }

  /// Weighted average buy price: total_cost / total_qty for buy events.
  /// Returns null if no qualifying events exist.
  Future<double?> getAverageBuyPrice(int assetId, {DateTime? through}) async {
    final bounded = through != null;
    final row = await _db.customSelect(
      "SELECT SUM(ABS(COALESCE(quantity,0)) * COALESCE(price,0)) AS total_cost, "
      "SUM(ABS(COALESCE(quantity,0))) AS total_qty "
      "FROM asset_events WHERE asset_id = ? AND type = 'buy' "
      "AND quantity IS NOT NULL AND price IS NOT NULL "
      "${bounded ? 'AND value_date < ? ' : ''}",
      variables: [Variable.withInt(assetId), ..._throughVars(through)],
    ).getSingleOrNull();
    final totalCost = row?.readNullable<double>('total_cost') ?? 0;
    final totalQty = row?.readNullable<double>('total_qty') ?? 0;
    return totalQty > 0 ? totalCost / totalQty : null;
  }

  /// Latest revalue amount for an asset (used as manual market value fallback).
  /// Returns null if no revalue events exist.
  Future<double?> getLatestRevalueAmount(
    int assetId, {
    DateTime? through,
  }) async {
    final bounded = through != null;
    final row = await _db.customSelect(
      "SELECT amount FROM asset_events WHERE asset_id = ? AND type = 'revalue' "
      "${bounded ? 'AND value_date < ? ' : ''}"
      "ORDER BY value_date DESC, id DESC LIMIT 1",
      variables: [Variable.withInt(assetId), ..._throughVars(through)],
    ).getSingleOrNull();
    return row?.readNullable<double>('amount');
  }

  static DateTime? _throughEndExclusive(DateTime? through) {
    if (through == null) return null;
    return DateTime(
      through.year,
      through.month,
      through.day,
    ).add(const Duration(days: 1));
  }

  static List<Variable<int>> _throughVars(DateTime? through) {
    final endExclusive = _throughEndExclusive(through);
    if (endExclusive == null) return const [];
    return [Variable.withInt(endExclusive.millisecondsSinceEpoch ~/ 1000)];
  }
}
