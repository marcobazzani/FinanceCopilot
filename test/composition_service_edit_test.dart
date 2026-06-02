import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/composition_service.dart';

/// Pins the manual-edit path on `CompositionService`:
///
/// - `setEntries` round-trips: writes per-(assetId,type), wiping prior rows.
/// - `setEntries` is scoped: editing 'country' leaves 'sector' alone.
/// - `clearAndResync` wipes all rows for the asset (sync run is a no-op
///   in tests since there's no network and no investing service).
/// - The "any rows == skip sync" invariant is encoded by setEntries
///   leaving the rows in place; the sync-skip behavior itself is
///   exercised end-to-end in the integration test.
void main() {
  late AppDatabase db;
  late CompositionService service;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CompositionService(db);
    final iid = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Test ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: iid,
          ),
        );
  });

  tearDown(() async => await db.close());

  Future<List<AssetComposition>> rowsOfType(String type) =>
      (db.select(db.assetCompositions)..where((c) => c.assetId.equals(assetId) & c.type.equals(type))).get();

  test('setEntries inserts new rows', () async {
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('United States', 60.0),
      CompositionEntry('Italy', 25.0),
      CompositionEntry('Japan', 15.0),
    ]);

    final rows = await rowsOfType('country');
    expect(rows.length, 3);
    expect(rows.map((r) => r.name).toSet(), {'United States', 'Italy', 'Japan'});
    expect(rows.map((r) => r.weight).toList()..sort(), [15.0, 25.0, 60.0]);
  });

  test('setEntries replaces existing rows for the same (assetId, type)', () async {
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('United States', 100.0),
    ]);
    expect((await rowsOfType('country')).length, 1);

    await service.setEntries(assetId, 'country', const [
      CompositionEntry('Germany', 50.0),
      CompositionEntry('France', 50.0),
    ]);
    final rows = await rowsOfType('country');
    expect(rows.length, 2);
    expect(rows.map((r) => r.name).toSet(), {'Germany', 'France'});
  });

  test('setEntries with empty list clears the section', () async {
    await service.setEntries(assetId, 'sector', const [
      CompositionEntry('Tech', 100.0),
    ]);
    expect((await rowsOfType('sector')).length, 1);

    await service.setEntries(assetId, 'sector', const []);
    expect(await rowsOfType('sector'), isEmpty);
  });

  test('setEntries scoped per type: editing country leaves sector intact', () async {
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('US', 100.0),
    ]);
    await service.setEntries(assetId, 'sector', const [
      CompositionEntry('Tech', 100.0),
    ]);

    // Edit only country.
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('Italy', 100.0),
    ]);

    final country = await rowsOfType('country');
    final sector = await rowsOfType('sector');
    expect(country.single.name, 'Italy');
    expect(sector.single.name, 'Tech', reason: 'sector rows must not be touched by a country edit');
  });

  test('clearAndResync wipes every composition row for the asset', () async {
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('US', 100.0),
    ]);
    await service.setEntries(assetId, 'sector', const [
      CompositionEntry('Tech', 100.0),
    ]);

    await service.clearAndResync(assetId);

    final all = await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(assetId))).get();
    expect(all, isEmpty, reason: 'clearAndResync must wipe rows; sync may re-populate but in tests there is no network');
  });

  test('syncCompositions skips an asset that already has rows', () async {
    // Pre-populate one country row so the "rows exist" guard kicks in.
    await service.setEntries(assetId, 'country', const [
      CompositionEntry('Synthetic Holding', 100.0),
    ]);

    // Run sync; with no investing service injected and no network reachable
    // in tests, the only way to keep the row count at exactly 1 is for the
    // sync to short-circuit on the rows-exist check.
    await service.syncCompositions();

    final rows = await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(assetId))).get();
    expect(rows.length, 1, reason: 'sync must not touch an asset with rows');
    expect(rows.single.name, 'Synthetic Holding');
  });
}
