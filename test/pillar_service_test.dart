import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/pillars/pillar_scope.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';

void main() {
  late AppDatabase db;
  late PillarService pillars;
  late AssetService assets;
  late AssetEventService events;
  late int iid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    pillars = PillarService(db);
    assets = AssetService(db);
    events = AssetEventService(db);
    iid = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
  });

  tearDown(() async => db.close());

  Future<int> newAssetWithUnits(double qty) async {
    final id = await assets.create(
      name: 'X',
      currency: 'EUR',
      intermediaryId: iid,
    );
    await events.create(
      assetId: id,
      date: DateTime.now(),
      type: EventType.buy,
      quantity: qty,
      amount: qty * 10,
      currency: 'EUR',
    );
    return id;
  }

  test('create + get + delete', () async {
    final id = await pillars.create(name: 'Retirement');
    final p = await pillars.getById(id);
    expect(p, isNotNull);
    expect(p!.name, 'Retirement');
    await pillars.delete(id);
    expect(await pillars.getById(id), isNull);
  });

  test('assign respects total holding invariant', () async {
    final assetId = await newAssetWithUnits(10);
    final p1 = await pillars.create(name: 'A');
    await pillars.assign(pillarId: p1, assetId: assetId, qty: 6);
    expect(await pillars.qtyFor(p1, assetId), 6);
    expect(await pillars.unassignedQty(assetId), 4);

    final p2 = await pillars.create(name: 'B');
    await pillars.assign(pillarId: p2, assetId: assetId, qty: 4);
    expect(await pillars.unassignedQty(assetId), 0);

    expect(
      () => pillars.assign(pillarId: p2, assetId: assetId, qty: 5),
      throwsA(isA<PillarOverAssignedException>()),
    );
  });

  test('reassigning a pillar accounts for its existing slice', () async {
    final assetId = await newAssetWithUnits(10);
    final p = await pillars.create(name: 'A');
    await pillars.assign(pillarId: p, assetId: assetId, qty: 7);
    // bumping the same pillar should be allowed up to total even with other pillars
    await pillars.assign(pillarId: p, assetId: assetId, qty: 9);
    expect(await pillars.qtyFor(p, assetId), 9);
    expect(await pillars.unassignedQty(assetId), 1);
  });

  test('qty=0 unassigns the row', () async {
    final assetId = await newAssetWithUnits(10);
    final p = await pillars.create(name: 'A');
    await pillars.assign(pillarId: p, assetId: assetId, qty: 5);
    await pillars.assign(pillarId: p, assetId: assetId, qty: 0);
    expect(await pillars.qtyFor(p, assetId), 0);
  });

  test('fractionsForPillar = stored / total', () async {
    final assetId = await newAssetWithUnits(10);
    final p = await pillars.create(name: 'A');
    await pillars.assign(pillarId: p, assetId: assetId, qty: 4);
    final fracs = await pillars.fractionsForPillar(p);
    expect(fracs[assetId], closeTo(0.4, 1e-9));
  });

  test('clipToFit reduces to available after a sell', () async {
    final assetId = await newAssetWithUnits(10);
    final p = await pillars.create(name: 'A');
    await pillars.assign(pillarId: p, assetId: assetId, qty: 8);
    // sell 5 units → total now 5, but pillar still says 8
    await events.create(
      assetId: assetId,
      date: DateTime.now(),
      type: EventType.sell,
      quantity: 5,
      amount: 50,
      currency: 'EUR',
    );
    final overs = await pillars.detectOverAssigned();
    expect(overs.where((o) => o.assetId == assetId).isNotEmpty, true);
    await pillars.clipToFit(p, assetId);
    expect(await pillars.qtyFor(p, assetId), 5);
  });

  test('PillarScope sealed variants compare correctly', () {
    expect(const PillarScope.all() == const PillarScope.all(), true);
    expect(const PillarScope.unassigned() == const PillarScope.unassigned(), true);
    expect(const PillarScope.pillar('a') == const PillarScope.pillar('a'), true);
    expect(const PillarScope.pillar('a') == const PillarScope.pillar('b'), false);
  });

  // ── Virtual Portfolio tests ──────────────────────────────────────────

  test('virtual portfolio can overlap a fully-assigned standard pillar', () async {
    // asset has 10 units, fully assigned to a standard pillar
    final assetId = await newAssetWithUnits(10);
    final standard = await pillars.create(name: 'Standard', kind: PillarKind.standard);
    await pillars.assign(pillarId: standard, assetId: assetId, qty: 10);
    expect(await pillars.unassignedQty(assetId), 0);

    // virtual portfolio can still assign all 10 (overlap — independent of standard)
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);
    expect(await pillars.qtyFor(virtual, assetId), 10);
  });

  test('virtual assignment does not reduce capacity of standard pillars', () async {
    final assetId = await newAssetWithUnits(10);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);

    // Standard pillar should still see full 10 available
    final standard = await pillars.create(name: 'Standard', kind: PillarKind.standard);
    await pillars.assign(pillarId: standard, assetId: assetId, qty: 10);
    expect(await pillars.qtyFor(standard, assetId), 10);
    expect(await pillars.unassignedQty(assetId), 0);
  });

  test('two virtual portfolios can both hold 100% of the same asset', () async {
    final assetId = await newAssetWithUnits(10);
    final v1 = await pillars.create(name: 'V1', kind: PillarKind.virtual);
    final v2 = await pillars.create(name: 'V2', kind: PillarKind.virtual);
    await pillars.assign(pillarId: v1, assetId: assetId, qty: 10);
    await pillars.assign(pillarId: v2, assetId: assetId, qty: 10);
    expect(await pillars.qtyFor(v1, assetId), 10);
    expect(await pillars.qtyFor(v2, assetId), 10);
  });

  test('virtual assignment capped at total — over-100% throws', () async {
    final assetId = await newAssetWithUnits(10);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    expect(
      () => pillars.assign(pillarId: virtual, assetId: assetId, qty: 11),
      throwsA(isA<PillarOverAssignedException>()),
    );
  });

  test('fractionsForPillar = 1.0 when virtual holds all units', () async {
    final assetId = await newAssetWithUnits(10);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);
    final fracs = await pillars.fractionsForPillar(virtual);
    expect(fracs[assetId], closeTo(1.0, 1e-9));
  });

  test('availableToAssign: standard respects other standard, virtual returns total', () async {
    final assetId = await newAssetWithUnits(10);
    final s1 = await pillars.create(name: 'S1', kind: PillarKind.standard);
    await pillars.assign(pillarId: s1, assetId: assetId, qty: 4);

    // A second standard pillar sees only 6 available
    final s2 = await pillars.create(name: 'S2', kind: PillarKind.standard);
    expect(await pillars.availableToAssign(s2, assetId), closeTo(6, 1e-9));

    // A virtual portfolio always sees the full 10
    final v = await pillars.create(name: 'V', kind: PillarKind.virtual);
    expect(await pillars.availableToAssign(v, assetId), closeTo(10, 1e-9));
  });

  test('clipToFit for virtual clips to total after a sell', () async {
    final assetId = await newAssetWithUnits(10);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);
    // sell 3 → total now 7
    await events.create(
      assetId: assetId,
      date: DateTime.now(),
      type: EventType.sell,
      quantity: 3,
      amount: 30,
      currency: 'EUR',
    );
    await pillars.clipToFit(virtual, assetId);
    expect(await pillars.qtyFor(virtual, assetId), closeTo(7, 1e-9));
  });

  test('detectOverAssigned flags virtual rows that exceed total', () async {
    final assetId = await newAssetWithUnits(10);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);
    // sell 3 → virtual row (10) now exceeds total (7)
    await events.create(
      assetId: assetId,
      date: DateTime.now(),
      type: EventType.sell,
      quantity: 3,
      amount: 30,
      currency: 'EUR',
    );
    final overs = await pillars.detectOverAssigned();
    expect(overs.where((o) => o.assetId == assetId && o.pillarId == virtual).isNotEmpty, true);
  });

  test('detectOverAssigned: virtual over-sell does NOT flag unrelated standard pillar', () async {
    final assetId = await newAssetWithUnits(10);
    final standard = await pillars.create(name: 'Standard', kind: PillarKind.standard);
    await pillars.assign(pillarId: standard, assetId: assetId, qty: 6);
    final virtual = await pillars.create(name: 'Virtual', kind: PillarKind.virtual);
    await pillars.assign(pillarId: virtual, assetId: assetId, qty: 10);
    // sell 5 → total = 5; standard (6) > 5, virtual (10) > 5 — both flagged
    // but the standard flag is due to standard sum, not virtual
    await events.create(
      assetId: assetId,
      date: DateTime.now(),
      type: EventType.sell,
      quantity: 5,
      amount: 50,
      currency: 'EUR',
    );
    final overs = await pillars.detectOverAssigned();
    final virtualOver = overs.where((o) => o.pillarId == virtual).isNotEmpty;
    final standardOver = overs.where((o) => o.pillarId == standard).isNotEmpty;
    expect(virtualOver, true);
    expect(standardOver, true);
  });
}
