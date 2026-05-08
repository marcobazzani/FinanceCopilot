import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';
import '../utils/uuid_v7.dart';

final _log = getLogger('PillarService');

class PillarOverAssignedException implements Exception {
  final int assetId;
  final double requested;
  final double available;
  PillarOverAssignedException(this.assetId, this.requested, this.available);
  @override
  String toString() => 'Pillar over-assign: asset $assetId requested $requested, available $available';
}

class PillarService {
  final AppDatabase _db;
  PillarService(this._db);

  // ── Pillar CRUD ──

  Future<List<Pillar>> getAll() => (_db.select(_db.pillars)
        ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
      .get();

  Stream<List<Pillar>> watchAll() => (_db.select(_db.pillars)
        ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
      .watch();

  Future<Pillar?> getById(String id) =>
      (_db.select(_db.pillars)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    double? targetValue,
    String targetCurrency = 'EUR',
  }) async {
    final id = UuidV7.generate();
    final maxSort = await (_db.selectOnly(_db.pillars)
          ..addColumns([_db.pillars.sortOrder.max()]))
        .map((row) => row.read(_db.pillars.sortOrder.max()))
        .getSingleOrNull();
    await _db.into(_db.pillars).insert(PillarsCompanion.insert(
          id: id,
          name: name,
          targetValue: Value(targetValue),
          targetCurrency: Value(targetCurrency),
          sortOrder: Value((maxSort ?? -1) + 1),
        ));
    _log.info('create pillar id=$id name=$name');
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    double? targetValue,
    String? targetCurrency,
    bool clearTargetValue = false,
  }) async {
    final companion = PillarsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      targetValue: clearTargetValue
          ? const Value(null)
          : (targetValue == null ? const Value.absent() : Value(targetValue)),
      targetCurrency: targetCurrency == null
          ? const Value.absent()
          : Value(targetCurrency),
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.pillars)..where((p) => p.id.equals(id)))
        .write(companion);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.pillars)..where((p) => p.id.equals(id))).go();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.pillars)..where((p) => p.id.equals(orderedIds[i])))
            .write(PillarsCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ── Pillar-asset assignments ──

  /// Total quantity an asset already has assigned to pillars (excluding `excludePillarId` if given).
  Future<double> _sumAssigned(int assetId, {String? excludePillarId}) async {
    final query = _db.selectOnly(_db.pillarAssets)
      ..addColumns([_db.pillarAssets.quantity.sum()])
      ..where(_db.pillarAssets.assetId.equals(assetId));
    if (excludePillarId != null) {
      query.where(_db.pillarAssets.pillarId.equals(excludePillarId).not());
    }
    final res = await query
        .map((row) => row.read(_db.pillarAssets.quantity.sum()))
        .getSingleOrNull();
    return res ?? 0.0;
  }

  /// Total holding of an asset (sum of buy − sell quantities). Mirrors
  /// AssetService stats math, but kept local to avoid a service-to-service
  /// dependency cycle.
  Future<double> _totalQuantity(int assetId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CASE WHEN type = ? THEN quantity '
          'WHEN type = ? THEN -quantity ELSE 0 END), 0) AS qty '
          'FROM asset_events WHERE asset_id = ? AND quantity IS NOT NULL',
          variables: [
            Variable.withString('buy'),
            Variable.withString('sell'),
            Variable.withInt(assetId),
          ],
        )
        .getSingle();
    return row.read<double>('qty');
  }

  Future<double> totalQuantity(int assetId) => _totalQuantity(assetId);

  Future<double> unassignedQty(int assetId) async {
    final total = await _totalQuantity(assetId);
    final assigned = await _sumAssigned(assetId);
    final remaining = total - assigned;
    return remaining < 0 ? 0 : remaining;
  }

  Future<double> qtyFor(String pillarId, int assetId) async {
    final row = await (_db.select(_db.pillarAssets)
          ..where((pa) =>
              pa.pillarId.equals(pillarId) & pa.assetId.equals(assetId)))
        .getSingleOrNull();
    return row?.quantity ?? 0.0;
  }

  /// Assign `qty` units of `assetId` to `pillarId`. Pass qty=0 to remove.
  /// Throws [PillarOverAssignedException] if it would violate the invariant
  /// SUM(pillar quantities) <= total holding.
  Future<void> assign({
    required String pillarId,
    required int assetId,
    required double qty,
  }) async {
    if (qty < 0) {
      throw ArgumentError('qty must be >= 0');
    }
    if (qty == 0) {
      await unassign(pillarId: pillarId, assetId: assetId);
      return;
    }
    final total = await _totalQuantity(assetId);
    final otherAssigned = await _sumAssigned(assetId, excludePillarId: pillarId);
    final available = total - otherAssigned;
    if (qty > available + 1e-9) {
      throw PillarOverAssignedException(assetId, qty, available);
    }
    await _db.into(_db.pillarAssets).insertOnConflictUpdate(
          PillarAssetsCompanion.insert(
            pillarId: pillarId,
            assetId: assetId,
            quantity: qty,
          ),
        );
  }

  Future<void> unassign({
    required String pillarId,
    required int assetId,
  }) async {
    await (_db.delete(_db.pillarAssets)
          ..where((pa) =>
              pa.pillarId.equals(pillarId) & pa.assetId.equals(assetId)))
        .go();
  }

  /// Batch-apply a map of (assetId → quantity) to one pillar in a single
  /// transaction. Validates the invariant per row before any write. qty=0
  /// removes the row.
  Future<void> applyBatch({
    required String pillarId,
    required Map<int, double> qtyByAsset,
  }) async {
    // Validate up front so partial writes never happen.
    for (final entry in qtyByAsset.entries) {
      if (entry.value < 0) {
        throw ArgumentError('qty must be >= 0 (asset ${entry.key})');
      }
      if (entry.value == 0) continue;
      final total = await _totalQuantity(entry.key);
      final otherAssigned =
          await _sumAssigned(entry.key, excludePillarId: pillarId);
      final available = total - otherAssigned;
      if (entry.value > available + 1e-9) {
        throw PillarOverAssignedException(entry.key, entry.value, available);
      }
    }
    await _db.transaction(() async {
      for (final entry in qtyByAsset.entries) {
        if (entry.value == 0) {
          await (_db.delete(_db.pillarAssets)
                ..where((pa) =>
                    pa.pillarId.equals(pillarId) &
                    pa.assetId.equals(entry.key)))
              .go();
        } else {
          await _db.into(_db.pillarAssets).insertOnConflictUpdate(
                PillarAssetsCompanion.insert(
                  pillarId: pillarId,
                  assetId: entry.key,
                  quantity: entry.value,
                ),
              );
        }
      }
    });
  }

  /// Sets the row to `total - other_pillars` so the invariant holds, in case a
  /// sell dropped the holding below the previously-assigned quantity.
  Future<void> clipToFit(String pillarId, int assetId) async {
    final total = await _totalQuantity(assetId);
    final otherAssigned = await _sumAssigned(assetId, excludePillarId: pillarId);
    final fit = total - otherAssigned;
    if (fit <= 0) {
      await unassign(pillarId: pillarId, assetId: assetId);
    } else {
      await _db.into(_db.pillarAssets).insertOnConflictUpdate(
            PillarAssetsCompanion.insert(
              pillarId: pillarId,
              assetId: assetId,
              quantity: fit,
            ),
          );
    }
  }

  // ── Reads for UI ──

  /// All rows for one pillar, joined as (assetId, qty in pillar).
  Future<List<({int assetId, double quantity})>> assetsInPillar(String pillarId) async {
    final rows = await (_db.select(_db.pillarAssets)
          ..where((pa) => pa.pillarId.equals(pillarId)))
        .get();
    return rows
        .map((r) => (assetId: r.assetId, quantity: r.quantity))
        .toList();
  }

  Stream<List<PillarAsset>> watchAssetsInPillar(String pillarId) =>
      (_db.select(_db.pillarAssets)
            ..where((pa) => pa.pillarId.equals(pillarId)))
          .watch();

  Stream<List<PillarAsset>> watchAllAssignments() =>
      _db.select(_db.pillarAssets).watch();

  /// For each asset id, returns its current fraction in this pillar
  /// (`pillar_qty / total_qty`). Used to scope dashboard time series.
  Future<Map<int, double>> fractionsForPillar(String pillarId) async {
    final rows = await assetsInPillar(pillarId);
    final out = <int, double>{};
    for (final r in rows) {
      final total = await _totalQuantity(r.assetId);
      if (total > 0) {
        out[r.assetId] = r.quantity / total;
      }
    }
    return out;
  }

  /// Returns the assets with rows that exceed their current total (after a sell).
  /// Each entry is (pillarId, assetId, storedQty, totalQty).
  Future<List<({String pillarId, int assetId, double stored, double total})>>
      detectOverAssigned() async {
    final rows = await _db.select(_db.pillarAssets).get();
    final out = <({String pillarId, int assetId, double stored, double total})>[];
    final byAsset = <int, double>{};
    final assignedPerAsset = <int, double>{};
    for (final r in rows) {
      assignedPerAsset[r.assetId] =
          (assignedPerAsset[r.assetId] ?? 0) + r.quantity;
    }
    for (final assetId in assignedPerAsset.keys) {
      byAsset[assetId] = await _totalQuantity(assetId);
    }
    for (final r in rows) {
      final total = byAsset[r.assetId] ?? 0;
      if (assignedPerAsset[r.assetId]! > total + 1e-9) {
        // mark only the rows in this asset that contribute > 0
        out.add((
          pillarId: r.pillarId,
          assetId: r.assetId,
          stored: r.quantity,
          total: total,
        ));
      }
    }
    return out;
  }
}
