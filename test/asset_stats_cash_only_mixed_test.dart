// Regression: an asset that mixes cash-only buys (no per-share quantity —
// pension contributions, manual entries) with quantified buys must report the
// cost of BOTH.
//
// The moving-average-cost pool can only hold buys that carry a quantity;
// there is no unit cost to attach to a cash-only amount. Treating the
// cash-only total as a mere fallback — used only when NO buy on the asset ever
// carried a quantity — silently drops it as soon as one quantified buy
// appears, understating invested capital with nothing sold.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';

void main() {
  late AppDatabase db;
  late AssetService assetService;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assetService = AssetService(db);
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });

  tearDown(() => db.close());

  Future<int> createAsset({ValuationMethod method = ValuationMethod.eventDriven}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: 'Pension',
          assetType: AssetType.pension,
          valuationMethod: method,
          intermediaryId: intermediaryId,
        ),
      );

  Future<void> addEvent(
    int assetId, {
    required DateTime date,
    required EventType type,
    required double amount,
    double? quantity,
  }) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: date,
          valueDate: date,
          type: type,
          amount: amount,
          quantity: Value(quantity),
        ),
      );

  Future<AssetStats> statsFor(int assetId) async => (await assetService.getStatsForAll())[assetId]!;

  test('a cash-only contribution keeps counting after a quantified buy arrives', () async {
    final assetId = await createAsset();
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.buy, amount: 200, quantity: 2);

    final stats = await statsFor(assetId);
    expect(stats.totalInvested, 300, reason: '100 contributed as cash + 200 of shares, nothing sold');
    expect(stats.totalQuantity, 2, reason: 'only the quantified buy contributes shares');
  });

  test('a purely cash-only asset still reports its gross contributions', () async {
    final assetId = await createAsset();
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.buy, amount: 150);

    final stats = await statsFor(assetId);
    expect(stats.totalInvested, 250);
    expect(stats.totalQuantity, 0);
  });

  test('a purely quantified position is unaffected', () async {
    final assetId = await createAsset(method: ValuationMethod.marketPrice);
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100, quantity: 1);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.buy, amount: 300, quantity: 2);

    expect((await statsFor(assetId)).totalInvested, 400);
  });

  test('selling every share zeroes the share cost but not the cash contributions', () async {
    final assetId = await createAsset();
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.buy, amount: 200, quantity: 2);
    await addEvent(assetId, date: DateTime(2026, 3, 1), type: EventType.sell, amount: 220, quantity: 2);

    final stats = await statsFor(assetId);
    expect(stats.totalQuantity, 0);
    expect(
      stats.totalInvested,
      100,
      reason: 'the shares are gone, but the cash contribution is still money in the asset',
    );
  });

  test('a fully closed share-only position still reports zero', () async {
    final assetId = await createAsset(method: ValuationMethod.marketPrice);
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100, quantity: 1);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.sell, amount: 120, quantity: 1);

    final stats = await statsFor(assetId);
    expect(stats.totalQuantity, 0);
    expect(stats.totalInvested, 0, reason: 'no cash-only contributions to carry over');
  });

  test('watchStatsForAll reports the same composition as getStatsForAll', () async {
    final assetId = await createAsset();
    await addEvent(assetId, date: DateTime(2026, 1, 1), type: EventType.buy, amount: 100);
    await addEvent(assetId, date: DateTime(2026, 2, 1), type: EventType.buy, amount: 200, quantity: 2);

    final watched = await assetService.watchStatsForAll().first;
    expect(watched[assetId]!.totalInvested, 300);
  });
}
