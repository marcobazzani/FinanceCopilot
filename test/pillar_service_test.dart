import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/pillar_scope.dart';
import 'package:finance_copilot/services/pillar_service.dart';

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
}
