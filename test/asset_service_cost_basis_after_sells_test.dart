// Regression test for cost-basis-after-sells.
//
// Before this fix `AssetStats.totalInvested` was `SUM(buy.amount)` — the
// gross cost ever deployed, never reduced by sells. For a position that
// had been partially sold, the dashboard then computed
// `gain = currentMarketValue − totalInvested`, which subtracted the cost
// of *already-sold* shares from the *currently-held* market value and
// produced a phantom loss.
//
// After the fix `totalInvested` is the weighted-average buy price times
// the remaining quantity, so the displayed gain reflects only the
// unrealised P&L of the position the user still holds.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';

void main() {
  late AppDatabase db;
  late AssetService assetService;
  late int intermediaryId;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assetService = AssetService(db);
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Broker'),
        );
    assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'ACME',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            currency: const Value('EUR'),
            intermediaryId: intermediaryId,
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> insertEvent({
    required DateTime date,
    required EventType type,
    required double amount,
    required double quantity,
  }) async {
    await db
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
  }

  test('partial sell at profit: cost basis reflects only remaining shares', () async {
    // 100 shares @ €10 (cost 1000), sell 30 @ €12 (proceeds 360).
    // Remaining 70 shares carry cost basis 70 × 10 = 700.
    await insertEvent(
      date: DateTime(2024, 1, 1),
      type: EventType.buy,
      amount: 1000,
      quantity: 100,
    );
    await insertEvent(
      date: DateTime(2024, 6, 1),
      type: EventType.sell,
      amount: 360,
      quantity: 30,
    );

    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 70);
    expect(
      stats.totalInvested,
      700,
      reason:
          'avg 10/share × 70 remaining — sale proceeds do not reduce '
          'invested, the disposed cost does',
    );
  });

  test('partial sell at loss: cost basis still uses weighted-avg', () async {
    // 100 shares @ €10, sell 30 @ €8 (proceeds 240). The loss is realised
    // and out of scope here; remaining 70 still carry 700 cost basis.
    await insertEvent(
      date: DateTime(2024, 1, 1),
      type: EventType.buy,
      amount: 1000,
      quantity: 100,
    );
    await insertEvent(
      date: DateTime(2024, 6, 1),
      type: EventType.sell,
      amount: 240,
      quantity: 30,
    );

    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 70);
    expect(stats.totalInvested, 700);
  });

  test('two buys at different prices then partial sell — weighted-avg', () async {
    // 200 shares @ €10  → cost 2000
    // 100 shares @ €13  → cost 1300
    //   weighted-avg = 3300 / 300 = 11.0 €/share
    // Sell 100. Remaining 200 × 11.0 = 2200.
    await insertEvent(
      date: DateTime(2024, 1, 1),
      type: EventType.buy,
      amount: 2000,
      quantity: 200,
    );
    await insertEvent(
      date: DateTime(2024, 3, 1),
      type: EventType.buy,
      amount: 1300,
      quantity: 100,
    );
    await insertEvent(
      date: DateTime(2024, 6, 1),
      type: EventType.sell,
      amount: 1400,
      quantity: 100,
    );

    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 200);
    expect(stats.totalInvested, 2200, reason: 'avg 11.0 €/share × 200 remaining');
  });

  test("Pietro's case (#77 follow-up): 399 bought, 199 sold, 200 held", () async {
    // Reporter's exact numbers — three buys totalling 399 shares for 4288,
    // two sells totalling 199 shares. After the fix the user should see
    // the cost basis of the 200 they still hold, not the all-time 4288.
    await insertEvent(
      date: DateTime(2024, 1, 1),
      type: EventType.buy,
      amount: 2000,
      quantity: 200,
    );
    await insertEvent(
      date: DateTime(2024, 2, 1),
      type: EventType.buy,
      amount: 1100,
      quantity: 100,
    );
    await insertEvent(
      date: DateTime(2024, 3, 1),
      type: EventType.buy,
      amount: 1188,
      quantity: 99,
    );
    await insertEvent(
      date: DateTime(2024, 4, 1),
      type: EventType.sell,
      amount: 1300,
      quantity: 100,
    );
    await insertEvent(
      date: DateTime(2024, 5, 1),
      type: EventType.sell,
      amount: 1386,
      quantity: 99,
    );

    final stats = (await assetService.getStatsForAll())[assetId]!;
    expect(stats.totalQuantity, 200);
    expect(
      stats.totalInvested,
      closeTo(2149.37, 0.01),
      reason:
          'avg 4288/399 × 200 — the figure Pietro expects vs the '
          'pre-fix 4288 that produced a phantom loss',
    );
  });
}
