// Pins that the batched `quantitiesForPillar` returns exactly what the
// per-asset `totalQuantity` / `qtyFor` / `availableToAssign` trio returns.
//
// The pillar detail screen issued five queries per asset, sequentially, before
// it could render — 65 round trips on a 13-asset portfolio, which is why the
// screen took seconds to appear. The batched version is only safe to adopt if
// it is provably equivalent, including the awkward cases: virtual portfolios
// (overlap cap), over-assignment clamping, negative-quantity sells, and assets
// with no events at all.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';

void main() {
  late AppDatabase db;
  late PillarService svc;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    svc = PillarService(db);
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> asset(String name) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: intermediaryId,
        ),
      );

  Future<void> event(int assetId, EventType type, double qty, {DateTime? on}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on ?? DateTime(2025, 1, 10),
          valueDate: on ?? DateTime(2025, 1, 10),
          type: type,
          amount: qty * 10,
          quantity: Value(qty),
        ),
      );

  /// The per-asset path, i.e. exactly what the UI used to do.
  Future<Map<int, PillarAssetQuantities>> oneByOne(String pillarId, List<int> assetIds) async {
    final out = <int, PillarAssetQuantities>{};
    for (final id in assetIds) {
      out[id] = PillarAssetQuantities(
        total: await svc.totalQuantity(id),
        current: await svc.qtyFor(pillarId, id),
        available: await svc.availableToAssign(pillarId, id),
      );
    }
    return out;
  }

  Future<void> expectEquivalent(String pillarId, List<int> assetIds) async {
    final batched = await svc.quantitiesForPillar(pillarId, assetIds);
    final looped = await oneByOne(pillarId, assetIds);
    expect(batched.keys.toSet(), looped.keys.toSet());
    for (final id in assetIds) {
      expect(batched[id]!.total, closeTo(looped[id]!.total, 1e-9), reason: 'total for asset $id');
      expect(batched[id]!.current, closeTo(looped[id]!.current, 1e-9), reason: 'current for asset $id');
      expect(batched[id]!.available, closeTo(looped[id]!.available, 1e-9), reason: 'available for asset $id');
    }
  }

  test('empty asset list short-circuits', () async {
    final p = await svc.create(name: 'P');
    expect(await svc.quantitiesForPillar(p, const []), isEmpty);
  });

  test('matches the per-asset path across standard pillars sharing assets', () async {
    final a1 = await asset('ETF one');
    final a2 = await asset('ETF two');
    final a3 = await asset('Never traded');

    await event(a1, EventType.buy, 100);
    await event(a1, EventType.sell, 30);
    await event(a2, EventType.buy, 50);
    // a3 deliberately has no events at all.

    final p1 = await svc.create(name: 'Retirement');
    final p2 = await svc.create(name: 'House');
    await svc.assign(pillarId: p1, assetId: a1, qty: 40);
    await svc.assign(pillarId: p2, assetId: a1, qty: 20);
    await svc.assign(pillarId: p1, assetId: a2, qty: 50);

    await expectEquivalent(p1, [a1, a2, a3]);
    await expectEquivalent(p2, [a1, a2, a3]);

    // Spot-check the actual numbers so the equivalence isn't between two
    // equally-wrong implementations.
    final b = await svc.quantitiesForPillar(p1, [a1, a2, a3]);
    expect(b[a1]!.total, 70, reason: '100 bought − 30 sold');
    expect(b[a1]!.current, 40);
    expect(b[a1]!.available, 50, reason: '70 − 20 held by the other standard pillar');
    expect(b[a3]!.total, 0);
    expect(b[a3]!.available, 0);
  });

  test('virtual portfolios are capped by the full holding, not the partition', () async {
    final a1 = await asset('ETF one');
    await event(a1, EventType.buy, 100);

    final standard = await svc.create(name: 'Retirement');
    final virtual = await svc.create(name: 'Shadow', kind: PillarKind.virtual);
    await svc.assign(pillarId: standard, assetId: a1, qty: 80);
    await svc.assign(pillarId: virtual, assetId: a1, qty: 100);

    await expectEquivalent(standard, [a1]);
    await expectEquivalent(virtual, [a1]);

    final v = await svc.quantitiesForPillar(virtual, [a1]);
    expect(v[a1]!.available, 100, reason: 'overlap model: a virtual portfolio may hold 100%');
    final s = await svc.quantitiesForPillar(standard, [a1]);
    expect(s[a1]!.available, 100, reason: 'the virtual assignment must not reduce the standard cap');
  });

  test('negative-quantity sells are not double-counted', () async {
    // Some broker exports store sells with a negative quantity (issue #77).
    final a1 = await asset('ETF one');
    await event(a1, EventType.buy, 100);
    await event(a1, EventType.sell, -10);

    final p = await svc.create(name: 'P');
    await expectEquivalent(p, [a1]);
  });

  test('an unknown pillar id degrades the same way on both paths', () async {
    final a1 = await asset('ETF one');
    await event(a1, EventType.buy, 10);
    await expectEquivalent('does-not-exist', [a1]);
  });

  test('assets never asked about are absent from the result', () async {
    final a1 = await asset('ETF one');
    final a2 = await asset('ETF two');
    await event(a1, EventType.buy, 10);
    await event(a2, EventType.buy, 10);

    final p = await svc.create(name: 'P');
    final batched = await svc.quantitiesForPillar(p, [a1]);
    expect(batched.keys, [a1]);
  });
}
