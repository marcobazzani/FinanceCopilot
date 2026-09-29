// Pillar quantities count a sell stored with a NEGATIVE quantity as a sell.
//
// Some broker exports store sells with a negative quantity (issue #77); the
// event type carries the direction, so every holding computation takes
// ABS(quantity). The pillar service summed the raw value with the type sign
// instead: a buy of 100 plus a sell stored as −10 gave 110 units in pillars
// against 90 in the asset stats, letting the user assign units they had sold.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';

void main() {
  late AppDatabase db;
  late PillarService pillars;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a sell stored with a negative quantity reduces the holding on every pillar path', () async {
    pillars = PillarService(db);
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
          ),
        );
    for (final (type, qty) in [(EventType.buy, 100.0), (EventType.sell, -10.0)]) {
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2025, 1, 10),
              valueDate: DateTime(2025, 1, 10),
              type: type,
              amount: qty.abs() * 10,
              quantity: Value(qty),
            ),
          );
    }
    final held = (await AssetService(db).getStatsForAll())[assetId]!.totalQuantity;
    expect(held, 90, reason: 'the asset stats: 100 bought − 10 sold');

    final pillarId = await pillars.create(name: 'Retirement');
    expect(await pillars.totalQuantity(assetId), held);
    expect(await pillars.unassignedQty(assetId), held);
    expect(await pillars.availableToAssign(pillarId, assetId), held);
    expect((await pillars.quantitiesForPillar(pillarId, [assetId]))[assetId]!.total, held);

    await expectLater(pillars.assign(pillarId: pillarId, assetId: assetId, qty: 100), throwsA(isA<PillarOverAssignedException>()));
    await pillars.assign(pillarId: pillarId, assetId: assetId, qty: 45);
    expect((await pillars.fractionsForPillar(pillarId))[assetId], closeTo(0.5, 1e-9));
  });
}
