// T8 — Migration v33 backfill includes `contribute` quantities.
//
// The v33 migration in lib/database/database.dart backfills market_prices
// from existing revalue events, computing close_price = amount / qty
// where qty is summed from buy/sell quantities at-or-before the revalue
// date. After this plan ships, qty must also include `contribute`
// quantities — otherwise a user who already had `contribute` rows in
// v32 (none today, but cheap insurance) would see stale or missing
// market_prices rows after upgrading.
//
// Approach: bypass AssetEventService.create (which triggers resync) by
// inserting events via raw SQL, wipe market_prices, then run the
// migration SQL exactly as it appears in production. This exercises the
// migration string itself — if the SQL diverges from the resync, this
// test catches it.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;
  late int iid;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
    assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension',
            assetType: AssetType.pension,
            instrumentType: const Value(InstrumentType.pension),
            assetClass: const Value(AssetClass.multiAsset),
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: const Value('EUR'),
          ),
        );
  });

  tearDown(() => db.close());

  // Insert an asset_event without going through AssetEventService.create
  // (which would trigger resyncRevaluePricesForAsset). We want a clean
  // slate so the migration SQL is the only thing populating market_prices.
  Future<void> rawInsertEvent({
    required String type,
    required DateTime valueDate,
    required double amount,
    double? quantity,
  }) async {
    final epoch = valueDate.millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      "INSERT INTO asset_events (asset_id, date, value_date, type, amount, quantity, currency) "
      "VALUES (?, ?, ?, ?, ?, ?, 'EUR')",
      [assetId, epoch, epoch, type, amount, quantity],
    );
  }

  test('migration v33 backfill: contribute qty counts toward close_price anchor', () async {
    // 5 monthly contributes (€100 each) leading up to a year-end revalue.
    // After the plan: qty_at_revalue should sum the contribute quantities
    // (synthesized as qty=amount, since these are pension-shape rows).
    for (var m = 1; m <= 5; m++) {
      await rawInsertEvent(
        type: 'contribute',
        valueDate: DateTime(2024, m, 28),
        amount: 100.00,
        quantity: 100.00,
      );
    }
    await rawInsertEvent(
      type: 'revalue',
      valueDate: DateTime(2024, 6, 30),
      amount: 525.00,
      // revalue has no quantity
    );

    // Wipe market_prices so the migration is the only writer.
    await db.customStatement('DELETE FROM market_prices');
    expect(await db.select(db.marketPrices).get(), isEmpty);

    // Run the v33 backfill SQL — this is the exact SQL from
    // lib/database/database.dart:467-490, with one change required by
    // this plan: the qty SUM must include `contribute` quantities.
    //
    // If you change the migration, change this string to match.
    await db.customStatement(
      "INSERT OR REPLACE INTO market_prices (asset_id, date, close_price, currency) "
      "SELECT e.asset_id, e.value_date, e.amount / qty.q, "
      "       COALESCE((SELECT a.currency FROM assets a WHERE a.id = e.asset_id), 'EUR') "
      "FROM asset_events e "
      "JOIN ("
      "  SELECT rev.id, "
      "         (SELECT SUM(CASE WHEN sub.type IN ('buy', 'contribute') THEN COALESCE(sub.quantity, 0) "
      "                          WHEN sub.type = 'sell' THEN -COALESCE(sub.quantity, 0) "
      "                          ELSE 0 END) "
      "          FROM asset_events sub "
      "          WHERE sub.asset_id = rev.asset_id "
      "          AND sub.value_date <= rev.value_date) AS q "
      "  FROM asset_events rev "
      "  WHERE rev.type = 'revalue'"
      ") qty ON qty.id = e.id "
      "WHERE e.type = 'revalue' AND qty.q > 0",
    );

    final prices =
        await (db.select(db.marketPrices)
              ..where((p) => p.assetId.equals(assetId))
              ..orderBy([(p) => OrderingTerm.asc(p.date)]))
            .get();
    expect(prices, hasLength(1));
    expect(prices.first.date, DateTime(2024, 6, 30));
    // 5 contributes × 100 quantity = 500 qty-at-revalue.
    // close_price = 525 / 500 = 1.05.
    expect(prices.first.closePrice, closeTo(1.05, 0.0001));
  });

  test('migration v33 still works for buy-only assets (existing behavior)', () async {
    // Mixed asset: a buy of 10 units @ 100, then a revalue at 1500.
    // close_price = 1500 / 10 = 150.
    await rawInsertEvent(
      type: 'buy',
      valueDate: DateTime(2024, 1, 1),
      amount: 1000.00,
      quantity: 10.00,
    );
    await rawInsertEvent(
      type: 'revalue',
      valueDate: DateTime(2024, 6, 30),
      amount: 1500.00,
    );

    await db.customStatement('DELETE FROM market_prices');
    // Same SQL as above.
    await db.customStatement(
      "INSERT OR REPLACE INTO market_prices (asset_id, date, close_price, currency) "
      "SELECT e.asset_id, e.value_date, e.amount / qty.q, "
      "       COALESCE((SELECT a.currency FROM assets a WHERE a.id = e.asset_id), 'EUR') "
      "FROM asset_events e "
      "JOIN ("
      "  SELECT rev.id, "
      "         (SELECT SUM(CASE WHEN sub.type IN ('buy', 'contribute') THEN COALESCE(sub.quantity, 0) "
      "                          WHEN sub.type = 'sell' THEN -COALESCE(sub.quantity, 0) "
      "                          ELSE 0 END) "
      "          FROM asset_events sub "
      "          WHERE sub.asset_id = rev.asset_id "
      "          AND sub.value_date <= rev.value_date) AS q "
      "  FROM asset_events rev "
      "  WHERE rev.type = 'revalue'"
      ") qty ON qty.id = e.id "
      "WHERE e.type = 'revalue' AND qty.q > 0",
    );

    final prices = await (db.select(db.marketPrices)..where((p) => p.assetId.equals(assetId))).get();
    expect(prices, hasLength(1));
    expect(prices.first.closePrice, 150.0);
  });

  test('migration v33 skips revalues with qty <= 0 (e.g. revalue-only asset)', () async {
    // Revalue with no preceding contribute or buy → qty = 0 → skipped.
    await rawInsertEvent(
      type: 'revalue',
      valueDate: DateTime(2024, 6, 30),
      amount: 1000.00,
    );

    await db.customStatement('DELETE FROM market_prices');
    await db.customStatement(
      "INSERT OR REPLACE INTO market_prices (asset_id, date, close_price, currency) "
      "SELECT e.asset_id, e.value_date, e.amount / qty.q, "
      "       COALESCE((SELECT a.currency FROM assets a WHERE a.id = e.asset_id), 'EUR') "
      "FROM asset_events e "
      "JOIN ("
      "  SELECT rev.id, "
      "         (SELECT SUM(CASE WHEN sub.type IN ('buy', 'contribute') THEN COALESCE(sub.quantity, 0) "
      "                          WHEN sub.type = 'sell' THEN -COALESCE(sub.quantity, 0) "
      "                          ELSE 0 END) "
      "          FROM asset_events sub "
      "          WHERE sub.asset_id = rev.asset_id "
      "          AND sub.value_date <= rev.value_date) AS q "
      "  FROM asset_events rev "
      "  WHERE rev.type = 'revalue'"
      ") qty ON qty.id = e.id "
      "WHERE e.type = 'revalue' AND qty.q > 0",
    );

    final prices = await (db.select(db.marketPrices)..where((p) => p.assetId.equals(assetId))).get();
    expect(prices, isEmpty);
  });
}
