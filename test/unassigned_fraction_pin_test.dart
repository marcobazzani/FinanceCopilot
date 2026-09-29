// Pins the "Unassigned" share per asset (unassignedFractionProvider) for the
// batch its per-asset reads are due to become (today three queries per asset,
// the holding read twice): for each active asset holding units, the part no
// standard pillar holds, over the holding. Virtual portfolios overlap and take
// nothing away; an over-assigned asset has nothing unassigned; an asset
// holding nothing has no share at all.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  var sortOrder = 0;
  Future<int> asset(String name, {bool active = true}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: broker,
          isActive: Value(active),
          sortOrder: Value(sortOrder++),
        ),
      );

  Future<void> event(int assetId, EventType type, double? qty) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: DateTime(2024, 1, 5),
          valueDate: DateTime(2024, 1, 5),
          type: type,
          amount: 100,
          quantity: Value(qty),
        ),
      );

  /// Stored as is, past the checks of [PillarService.assign]: a sell can leave
  /// an asset holding less than its pillars were given.
  Future<void> holds(String pillarId, int assetId, double qty) =>
      db.into(db.pillarAssets).insert(PillarAssetsCompanion.insert(pillarId: pillarId, assetId: assetId, quantity: qty));

  Future<Map<int, double>> unassigned() async {
    final sub = container.listen(unassignedFractionProvider.future, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  test('pinned: the part of each held, active asset that no standard pillar holds', () async {
    final pillars = PillarService(db);
    final core = await pillars.create(name: 'Core');
    final house = await pillars.create(name: 'House');
    final virtual = await pillars.create(name: 'Model', kind: PillarKind.virtual);

    final split = await asset('Split'); // 10 bought, 2 sold (stored negative): 8 held
    await event(split, EventType.buy, 10);
    await event(split, EventType.sell, -2);
    await event(split, EventType.revalue, null);
    await holds(core, split, 3);
    await holds(house, split, 1);
    await holds(virtual, split, 8);

    final full = await asset('Full'); // all of it in a standard pillar
    await event(full, EventType.buy, 5);
    await holds(core, full, 5);

    final over = await asset('Over'); // its pillars hold more than it does
    await event(over, EventType.buy, 4);
    await holds(core, over, 3);
    await holds(house, over, 3);

    final sold = await asset('Sold'); // nothing held
    await event(sold, EventType.buy, 2);
    await event(sold, EventType.sell, 2);

    final cashOnly = await asset('Cash only'); // a buy without units counts nothing
    await event(cashOnly, EventType.buy, null);
    await event(cashOnly, EventType.buy, 4);

    final inactive = await asset('Inactive', active: false);
    await event(inactive, EventType.buy, 7);

    await asset('No events');

    final fractions = await unassigned();
    expect(fractions.keys, [split, full, over, cashOnly], reason: 'in the active assets order');
    expect(fractions, {split: 0.5, full: 0.0, over: 0.0, cashOnly: 1.0});
  });
}
