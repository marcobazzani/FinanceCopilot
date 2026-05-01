import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';

void main() {
  late AppDatabase db;
  late AssetEventService service;
  late int iid;

  Future<int> createAsset(String name, {String currency = 'EUR'}) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          instrumentType: const Value(InstrumentType.etf),
          assetClass: const Value(AssetClass.equity),
          valuationMethod: ValuationMethod.eventDriven,
          intermediaryId: iid,
          currency: Value(currency),
        ));
  }

  Future<List<MarketPrice>> pricesFor(int assetId) async {
    return (db.select(db.marketPrices)
          ..where((p) => p.assetId.equals(assetId))
          ..orderBy([(p) => OrderingTerm.asc(p.date)]))
        .get();
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AssetEventService(db);
    iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
  });

  tearDown(() async => await db.close());

  group('revalue -> market_prices', () {
    test('1. create revalue writes a market_prices row anchored to qty-at-date', () async {
      final assetId = await createAsset('Manual EUR');
      // Buy 10 @ 100 on day 1
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        price: 100.0,
        currency: 'EUR',
      );
      // Revalue to 1200 on day 5
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices.first.date, DateTime(2024, 1, 5));
      expect(prices.first.closePrice, 120.0); // 1200 / 10
      expect(prices.first.currency, 'EUR');
    });

    test('2. update revalue.amount updates the market_prices row', () async {
      final assetId = await createAsset('Manual EUR');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      final revalueId = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      // Update amount to 1500
      await service.update(
        revalueId,
        AssetEventsCompanion(amount: const Value(1500.0)),
      );

      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices.first.closePrice, 150.0); // 1500 / 10
    });

    test('3. delete revalue removes the market_prices row', () async {
      final assetId = await createAsset('Manual EUR');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      final revalueId = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      expect((await pricesFor(assetId)).length, 1);

      await service.delete(revalueId);

      final prices = await pricesFor(assetId);
      expect(prices, isEmpty);
    });

    test('4. buy added before existing revalue recomputes the revalue row', () async {
      final assetId = await createAsset('Manual EUR');
      // Buy 10 on day 1
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      // Revalue 1200 on day 10 -> qty=10, close_price=120
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 10),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      expect((await pricesFor(assetId)).first.closePrice, 120.0);

      // Now add a buy of 5 on day 5 (between buy and revalue)
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.buy,
        amount: 500.0,
        quantity: 5.0,
        currency: 'EUR',
      );

      // Revalue's market_prices row must recompute against qty-at-day-10 = 15
      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices.first.closePrice, 80.0); // 1200 / 15
    });

    test('5. revalue with qty=0 at value_date writes no row', () async {
      final assetId = await createAsset('Manual EUR');
      // No buys at all -> qty-at-date = 0
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices, isEmpty);
    });

    test('6. multiple revalues each anchored to their own qty-at-date', () async {
      final assetId = await createAsset('Manual EUR');
      // Buy 10 on day 1
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      // First revalue on day 5: qty=10 -> price=120
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      // Buy 5 more on day 7
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 7),
        type: EventType.buy,
        amount: 500.0,
        quantity: 5.0,
        currency: 'EUR',
      );
      // Second revalue on day 10: qty=15 -> price=120 (1800/15)
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 10),
        type: EventType.revalue,
        amount: 1800.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices.length, 2);
      // Day-5 revalue must remain anchored to qty=10 even after the day-7 buy
      expect(prices[0].date, DateTime(2024, 1, 5));
      expect(prices[0].closePrice, 120.0);
      // Day-10 revalue uses qty=15
      expect(prices[1].date, DateTime(2024, 1, 10));
      expect(prices[1].closePrice, 120.0); // 1800 / 15
    });

    test('7. delete pre-revalue buy raises revalue close_price', () async {
      final assetId = await createAsset('Manual EUR');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      final extraBuyId = await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.buy,
        amount: 500.0,
        quantity: 5.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 10),
        type: EventType.revalue,
        amount: 1500.0,
        currency: 'EUR',
      );
      // qty-at-day-10 = 15 -> close_price = 100
      expect((await pricesFor(assetId)).first.closePrice, 100.0);

      // Delete the pre-revalue extra buy. Now qty-at-day-10 = 10 -> price = 150.
      await service.delete(extraBuyId);

      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices.first.closePrice, 150.0);
    });

    test('9. migration backfill rewrites market_prices for existing revalues', () async {
      final assetId = await createAsset('Manual EUR');
      // Bypass the service so the resync hook does NOT run (simulates a DB
      // populated before this fix landed).
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 1, 1),
            type: EventType.buy,
            amount: 1000.0,
            quantity: const Value(10.0),
            currency: const Value('EUR'),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 5),
            valueDate: DateTime(2024, 1, 5),
            type: EventType.revalue,
            amount: 1200.0,
            currency: const Value('EUR'),
          ));
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 10),
            valueDate: DateTime(2024, 1, 10),
            type: EventType.buy,
            amount: 500.0,
            quantity: const Value(5.0),
            currency: const Value('EUR'),
          ));
      // Pre-fix DB has no market_prices rows for revalues.
      final pricesBefore = await pricesFor(assetId);
      expect(pricesBefore, isEmpty);

      // Run the same SQL the migration runs.
      await db.customStatement(
        "INSERT OR REPLACE INTO market_prices (asset_id, date, close_price, currency) "
        "SELECT e.asset_id, e.value_date, e.amount / qty.q, "
        "       COALESCE((SELECT a.currency FROM assets a WHERE a.id = e.asset_id), 'EUR') "
        "FROM asset_events e "
        "JOIN ("
        "  SELECT rev.id, "
        "         (SELECT SUM(CASE WHEN sub.type = 'buy' THEN COALESCE(sub.quantity, 0) "
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

      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices.first.date, DateTime(2024, 1, 5));
      // qty-at-day-5 = 10 (only first buy); revalue.amount=1200; price=120
      expect(prices.first.closePrice, 120.0);
    });

    test('8. existing investing.com prices on other dates are preserved', () async {
      final assetId = await createAsset('Manual EUR');
      // Pretend an investing.com price tick was already stored on day 3
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 3),
            closePrice: 99.0,
            currency: 'EUR',
          ));
      // Buy on day 1
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      // Revalue on day 5 -> writes row at day 5 only, day 3 untouched
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices.length, 2);
      expect(prices[0].date, DateTime(2024, 1, 3));
      expect(prices[0].closePrice, 99.0); // untouched investing.com row
      expect(prices[1].date, DateTime(2024, 1, 5));
      expect(prices[1].closePrice, 120.0);
    });
  });
}
