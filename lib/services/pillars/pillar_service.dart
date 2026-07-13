import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/uuid_v7.dart';

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

  Future<List<Pillar>> getAll() => (_db.select(_db.pillars)..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])).get();

  Stream<List<Pillar>> watchAll() => (_db.select(_db.pillars)..orderBy([(p) => OrderingTerm.asc(p.sortOrder)])).watch();

  Future<Pillar?> getById(String id) => (_db.select(_db.pillars)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    double? targetValue,
    String targetCurrency = 'EUR',
    String? portfolioModelId,
    PillarKind kind = PillarKind.standard,
  }) async {
    final id = UuidV7.generate();
    final maxSort = await (_db.selectOnly(
      _db.pillars,
    )..addColumns([_db.pillars.sortOrder.max()])).map((row) => row.read(_db.pillars.sortOrder.max())).getSingleOrNull();
    await _db
        .into(_db.pillars)
        .insert(
          PillarsCompanion.insert(
            id: id,
            name: name,
            kind: Value(kind),
            targetValue: Value(targetValue),
            targetCurrency: Value(targetCurrency),
            portfolioModelId: Value(portfolioModelId),
            sortOrder: Value((maxSort ?? -1) + 1),
          ),
        );
    _log.info('create pillar id=$id name=$name kind=${kind.name}');
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    double? targetValue,
    String? targetCurrency,
    String? portfolioModelId,
    bool clearTargetValue = false,
    bool clearPortfolioModel = false,
  }) async {
    final companion = PillarsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      targetValue: clearTargetValue ? const Value(null) : (targetValue == null ? const Value.absent() : Value(targetValue)),
      targetCurrency: targetCurrency == null ? const Value.absent() : Value(targetCurrency),
      portfolioModelId: clearPortfolioModel ? const Value(null) : (portfolioModelId == null ? const Value.absent() : Value(portfolioModelId)),
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.pillars)..where((p) => p.id.equals(id))).write(companion);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.pillars)..where((p) => p.id.equals(id))).go();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.pillars)..where((p) => p.id.equals(orderedIds[i]))).write(PillarsCompanion(sortOrder: Value(i)));
      }
    });
  }

  // ── Pillar-asset assignments ──

  /// Total quantity an asset already has assigned to **standard** pillars
  /// (excluding `excludePillarId` if given).
  ///
  /// Virtual portfolios are deliberately excluded from this sum so that their
  /// overlapping assignments do not reduce the capacity of standard pillars or
  /// the implicit "Unassigned" bucket.
  Future<double> _sumStandardAssigned(int assetId, {String? excludePillarId}) async {
    // Join pillar_assets → pillars so we can filter on kind = 'standard'.
    final query = _db.selectOnly(_db.pillarAssets)
      ..join([innerJoin(_db.pillars, _db.pillars.id.equalsExp(_db.pillarAssets.pillarId))])
      ..addColumns([_db.pillarAssets.quantity.sum()])
      ..where(_db.pillarAssets.assetId.equals(assetId))
      ..where(_db.pillars.kind.equalsValue(PillarKind.standard));
    if (excludePillarId != null) {
      query.where(_db.pillarAssets.pillarId.equals(excludePillarId).not());
    }
    final res = await query.map((row) => row.read(_db.pillarAssets.quantity.sum())).getSingleOrNull();
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

  /// Quantity not yet assigned to any **standard** pillar (the "Unassigned" bucket).
  /// Virtual assignments are independent and never reduce this value.
  Future<double> unassignedQty(int assetId) async {
    final total = await _totalQuantity(assetId);
    final assigned = await _sumStandardAssigned(assetId);
    final remaining = total - assigned;
    return remaining < 0 ? 0 : remaining;
  }

  Future<double> qtyFor(String pillarId, int assetId) async {
    final row = await (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId) & pa.assetId.equals(assetId))).getSingleOrNull();
    return row?.quantity ?? 0.0;
  }

  /// Maximum quantity that can be assigned to [pillarId] for [assetId].
  ///
  /// - **Standard** pillars: `total − sum assigned to other standard pillars`
  ///   (partition model; each unit can only live in one standard pillar).
  /// - **Virtual** portfolios: `total` (overlap model; a virtual portfolio can
  ///   hold up to 100% of the real holding independently of all other pillars).
  Future<double> availableToAssign(String pillarId, int assetId) async {
    final pillar = await getById(pillarId);
    final total = await _totalQuantity(assetId);
    if (pillar == null || pillar.kind == PillarKind.virtual) return total;
    final otherStandard = await _sumStandardAssigned(assetId, excludePillarId: pillarId);
    final available = total - otherStandard;
    return available < 0 ? 0 : available;
  }

  /// Assign `qty` units of [assetId] to [pillarId]. Pass qty=0 to remove.
  ///
  /// For standard pillars, throws [PillarOverAssignedException] if the
  /// assignment would violate SUM(standard quantities) <= total holding.
  /// For virtual portfolios, the cap is simply the total holding (100%).
  Future<void> assign({
    required String pillarId,
    required int assetId,
    required double qty,
  }) async {
    if (qty < 0) throw ArgumentError('qty must be >= 0');
    if (qty == 0) {
      await unassign(pillarId: pillarId, assetId: assetId);
      return;
    }
    final available = await availableToAssign(pillarId, assetId);
    if (qty > available + 1e-9) {
      throw PillarOverAssignedException(assetId, qty, available);
    }
    await _db
        .into(_db.pillarAssets)
        .insertOnConflictUpdate(
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
    await (_db.delete(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId) & pa.assetId.equals(assetId))).go();
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
      if (entry.value < 0) throw ArgumentError('qty must be >= 0 (asset ${entry.key})');
      if (entry.value == 0) continue;
      final available = await availableToAssign(pillarId, entry.key);
      if (entry.value > available + 1e-9) {
        throw PillarOverAssignedException(entry.key, entry.value, available);
      }
    }
    await _db.transaction(() async {
      for (final entry in qtyByAsset.entries) {
        if (entry.value == 0) {
          await (_db.delete(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId) & pa.assetId.equals(entry.key))).go();
        } else {
          await _db
              .into(_db.pillarAssets)
              .insertOnConflictUpdate(
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

  /// Sets the row to `availableToAssign` so the invariant holds after a sell
  /// dropped the holding below the previously-assigned quantity.
  ///
  /// For standard pillars: clamps to `total − other standard assigned`.
  /// For virtual portfolios: clamps to `total` (each virtual is independent).
  Future<void> clipToFit(String pillarId, int assetId) async {
    final fit = await availableToAssign(pillarId, assetId);
    final current = await qtyFor(pillarId, assetId);
    // Nothing to do if the current assignment already fits.
    if (current <= fit + 1e-9) return;
    if (fit <= 0) {
      await unassign(pillarId: pillarId, assetId: assetId);
    } else {
      await _db
          .into(_db.pillarAssets)
          .insertOnConflictUpdate(
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
    final rows = await (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId))).get();
    return rows.map((r) => (assetId: r.assetId, quantity: r.quantity)).toList();
  }

  Stream<List<PillarAsset>> watchAssetsInPillar(String pillarId) =>
      (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId))).watch();

  Stream<List<PillarAsset>> watchAllAssignments() => _db.select(_db.pillarAssets).watch();

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

  /// Returns assignments that exceed the per-kind capacity after a sell.
  ///
  /// - Standard pillars: the per-asset SUM across all standard pillar rows is
  ///   compared to the total holding.
  /// - Virtual portfolios: each row is checked individually against the total
  ///   (they are independent; no cross-row sum applies).
  Future<List<({String pillarId, int assetId, double stored, double total})>> detectOverAssigned() async {
    final rows = await _db.select(_db.pillarAssets).get();
    if (rows.isEmpty) return const [];

    // Collect all unique asset ids and fetch their totals once.
    final assetIds = rows.map((r) => r.assetId).toSet();
    final totalByAsset = <int, double>{};
    for (final id in assetIds) {
      totalByAsset[id] = await _totalQuantity(id);
    }

    // Fetch the kind for each pillar that appears in the rows (batch).
    final pillarIds = rows.map((r) => r.pillarId).toSet().toList();
    final pillarRows = await (_db.select(_db.pillars)..where((p) => p.id.isIn(pillarIds))).get();
    final kindById = {for (final p in pillarRows) p.id: p.kind};

    // Standard: sum across all standard rows per asset, flag if sum > total.
    final standardSumByAsset = <int, double>{};
    for (final r in rows) {
      if (kindById[r.pillarId] == PillarKind.standard) {
        standardSumByAsset[r.assetId] = (standardSumByAsset[r.assetId] ?? 0) + r.quantity;
      }
    }

    final out = <({String pillarId, int assetId, double stored, double total})>[];

    for (final r in rows) {
      final total = totalByAsset[r.assetId] ?? 0;
      final kind = kindById[r.pillarId];
      if (kind == PillarKind.virtual) {
        // Virtual: each row is independent — flag if this row alone exceeds total.
        if (r.quantity > total + 1e-9) {
          out.add((pillarId: r.pillarId, assetId: r.assetId, stored: r.quantity, total: total));
        }
      } else {
        // Standard: flag any row in a standard pillar whose asset's total
        // standard-assigned sum exceeds the holding.
        final sum = standardSumByAsset[r.assetId] ?? 0;
        if (sum > total + 1e-9) {
          out.add((pillarId: r.pillarId, assetId: r.assetId, stored: r.quantity, total: total));
        }
      }
    }
    return out;
  }
}
