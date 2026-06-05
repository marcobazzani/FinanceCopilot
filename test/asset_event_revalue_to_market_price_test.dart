import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';

void main() {
  late AppDatabase db;
  late AssetEventService service;
  late int iid;

  Future<int> createAsset(String name, {String currency = 'EUR'}) async {
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: Value(currency),
          ),
        );
  }

  Future<List<MarketPrice>> pricesFor(int assetId) async {
    return (db.select(db.marketPrices)
          ..where((p) => p.assetId.equals(assetId))
          ..orderBy([(p) => OrderingTerm.asc(p.date)]))
        .get();
  }

  Future<int> createBond(String name, {String currency = 'EUR'}) async {
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.bondEtf,
            instrumentType: const Value(InstrumentType.bond),
            assetClass: const Value(AssetClass.fixedIncome),
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: Value(currency),
          ),
        );
  }

  Future<int> createMarketPriced(String name, {String currency = 'EUR'}) async {
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.etf),
            assetClass: const Value(AssetClass.equity),
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: iid,
            currency: Value(currency),
          ),
        );
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
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 1),
              valueDate: DateTime(2024, 1, 1),
              type: EventType.buy,
              amount: 1000.0,
              quantity: const Value(10.0),
              currency: const Value('EUR'),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 5),
              valueDate: DateTime(2024, 1, 5),
              type: EventType.revalue,
              amount: 1200.0,
              currency: const Value('EUR'),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 10),
              valueDate: DateTime(2024, 1, 10),
              type: EventType.buy,
              amount: 500.0,
              quantity: const Value(5.0),
              currency: const Value('EUR'),
            ),
          );
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

    test('8. adding a revalue to a market-priced asset flips it event-driven '
        'and wipes prior provider rows', () async {
      // Per the manual-revalue model, ANY asset that receives a revalue
      // becomes event-driven (its value is now manually maintained), so its
      // previously-fetched provider ticks are wiped — the price history is
      // rebuilt purely from revalues. (Market-priced assets without revalues
      // keep their feed untouched; that path is exercised elsewhere.)
      final assetId = await createMarketPriced('Market EUR');
      // Pretend a provider price tick was already stored on day 3
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 3),
              closePrice: 99.0,
              currency: 'EUR',
            ),
          );
      // Buy on day 1
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      // Revalue on day 5 -> asset flips event-driven, day-3 provider row wiped.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices[0].date, DateTime(2024, 1, 5));
      expect(prices[0].closePrice, 120.0);
    });

    test('8b. event-driven asset: a revalue wipes ALL prior market_prices and '
        'rebuilds only from revalue events', () async {
      // Event-driven assets have no feed; their whole price history derives
      // from revalues. Any stray/stale price row (e.g. a leftover from an
      // earlier revalue that was later deleted) must be wiped on resync.
      final assetId = await createAsset('Manual EUR');
      // A stale price row on a non-revalue date (should NOT survive).
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 1, 3),
              closePrice: 99.0,
              currency: 'EUR',
            ),
          );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );

      // Only the revalue-derived row remains; the day-3 stray is wiped.
      final prices = await pricesFor(assetId);
      expect(prices.length, 1);
      expect(prices[0].date, DateTime(2024, 1, 5));
      expect(prices[0].closePrice, 120.0);
    });
  });

  group('contribute-only assets (pension shape)', () {
    // Pension contributes carry synthetic quantity=amount, price=1.0 so
    // the resync's qty SUM picks them up. close_price = revalue.amount /
    // Σ contribute.quantity = "growth ratio per €1 invested". These pin
    // the same anchoring guarantees as the buy-only tests above, but
    // for the cashflow-only path that PPP / Riester / UK SIPP rely on.

    test('1. contribute-only asset: revalue close_price = amount / Σ qty', () async {
      final assetId = await createAsset('PPP-shape');
      // 3 monthly contributes of 100 each → qty = 300.
      for (var m = 1; m <= 3; m++) {
        await service.create(
          assetId: assetId,
          date: DateTime(2024, m, 28),
          type: EventType.buy,
          amount: 100.0,
          quantity: 100.0,
          price: 1.0,
          currency: 'EUR',
        );
      }
      // Revalue at 315 → growth of 5% on €300 contributed.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 31),
        type: EventType.revalue,
        amount: 315.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices, hasLength(1));
      expect(prices.first.date, DateTime(2024, 3, 31));
      expect(prices.first.closePrice, closeTo(1.05, 0.0001));
    });

    test('2. pre-revalue contribute reduces close_price (more denominator)', () async {
      final assetId = await createAsset('PPP-shape');
      // First contribute + revalue: 100 contrib, 110 position → 1.10.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 31),
        type: EventType.buy,
        amount: 100.0,
        quantity: 100.0,
        price: 1.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 30),
        type: EventType.revalue,
        amount: 110.0,
        currency: 'EUR',
      );
      var prices = await pricesFor(assetId);
      expect(prices.first.closePrice, closeTo(1.10, 0.0001));

      // Add a pre-revalue contribute: now qty = 200, but the revalue
      // amount stays 110 (it's an absolute snapshot). Resync recomputes
      // close_price = 110/200 = 0.55. Note: this is a *retroactive*
      // edit to history — usually the user would update the revalue too.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 3, 31),
        type: EventType.buy,
        amount: 100.0,
        quantity: 100.0,
        price: 1.0,
        currency: 'EUR',
      );
      prices = await pricesFor(assetId);
      expect(prices.first.closePrice, closeTo(0.55, 0.0001), reason: 'pre-revalue contribute must reduce the close_price');
    });

    test('3. post-revalue contribute does NOT shift close_price', () async {
      final assetId = await createAsset('PPP-shape');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 31),
        type: EventType.buy,
        amount: 100.0,
        quantity: 100.0,
        price: 1.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 30),
        type: EventType.revalue,
        amount: 110.0,
        currency: 'EUR',
      );
      var prices = await pricesFor(assetId);
      expect(prices.first.closePrice, closeTo(1.10, 0.0001));

      // Add a post-revalue contribute: qty grows to 200 but the
      // revalue's anchor is fixed at value_date 2024-06-30, where qty=100.
      // close_price must stay 1.10. (Subsequent value tracking happens
      // via `qty(t) × last_close_price` at consumer-time.)
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 7, 31),
        type: EventType.buy,
        amount: 100.0,
        quantity: 100.0,
        price: 1.0,
        currency: 'EUR',
      );
      prices = await pricesFor(assetId);
      expect(prices.first.closePrice, closeTo(1.10, 0.0001), reason: 'post-revalue contribute must NOT shift the anchored price');
    });
  });

  group('bond revalue (issue #87 — position must not collapse ×1/100)', () {
    // A bond's market value is computed downstream as
    //   qty * close_price / bondDivisor(=100) * fxRate
    // A revalue carries a TOTAL position value (currency). To make the
    // displayed value equal that total, the materialised close_price must be
    // pre-multiplied by the bond divisor so the read-time /100 cancels out.
    // Pre-fix: close_price = amount/qty → displayed = amount/100 → vanishes.

    double displayedValue(double qty, double closePrice) {
      const bondDivisor = 100.0;
      return qty * closePrice / bondDivisor; // fxRate = 1 (EUR)
    }

    test('bond revalue close_price is scaled so displayed value == revalue amount', () async {
      final assetId = await createBond('Mystery BTP');
      // Bond: qty 3000 (face), price 100 (% of par) → cost 3000.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 10),
        type: EventType.buy,
        amount: 3000.0,
        quantity: 3000.0,
        price: 100.0,
        currency: 'EUR',
      );
      // Revalue the whole position to 3100.
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        type: EventType.revalue,
        amount: 3100.0,
        currency: 'EUR',
      );

      final prices = await pricesFor(assetId);
      expect(prices, hasLength(1));
      // 3100 / 3000 * 100 = 103.333…
      expect(prices.first.closePrice, closeTo(3100.0 / 3000.0 * 100.0, 1e-9));
      // The number consumers actually render must equal the revalue total.
      expect(
        displayedValue(3000.0, prices.first.closePrice),
        closeTo(3100.0, 1e-6),
        reason: 'bond revalue must not collapse the position to 1/100',
      );
    });

    test('non-bond revalue is unaffected (no ×100 scaling)', () async {
      final assetId = await createAsset('Manual EUR');
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        price: 100.0,
        currency: 'EUR',
      );
      await service.create(
        assetId: assetId,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      final prices = await pricesFor(assetId);
      expect(prices.first.closePrice, 120.0); // 1200 / 10, bondDivisor = 1
    });
  });

  group('manual-revalue auto-toggle (valuationMethod)', () {
    Future<ValuationMethod> methodOf(int id) async {
      final a = await (db.select(db.assets)..where((x) => x.id.equals(id))).getSingle();
      return a.valuationMethod;
    }

    test('adding a revalue flips a market-priced asset to eventDriven', () async {
      final id = await createMarketPriced('Bond no feed');
      expect(await methodOf(id), ValuationMethod.marketPrice); // default OFF
      await service.create(
        assetId: id,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      // Still OFF after a plain buy (no revalue yet).
      expect(await methodOf(id), ValuationMethod.marketPrice);
      await service.create(
        assetId: id,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      expect(await methodOf(id), ValuationMethod.eventDriven); // ON
    });

    test('removing the last revalue flips eventDriven back to marketPrice and '
        'wipes the revalue-derived prices', () async {
      final id = await createMarketPriced('Bond no feed');
      await service.create(
        assetId: id,
        date: DateTime(2024, 1, 1),
        type: EventType.buy,
        amount: 1000.0,
        quantity: 10.0,
        currency: 'EUR',
      );
      final revId = await service.create(
        assetId: id,
        date: DateTime(2024, 1, 5),
        type: EventType.revalue,
        amount: 1200.0,
        currency: 'EUR',
      );
      expect(await methodOf(id), ValuationMethod.eventDriven);
      expect((await pricesFor(id)).length, 1);

      await service.delete(revId);
      expect(await methodOf(id), ValuationMethod.marketPrice); // OFF again
      expect(await pricesFor(id), isEmpty); // revalue-derived price wiped
    });

    test('with multiple revalues, removing one keeps eventDriven ON', () async {
      final id = await createMarketPriced('Bond no feed');
      await service.create(assetId: id, date: DateTime(2024, 1, 1), type: EventType.buy, amount: 1000, quantity: 10, currency: 'EUR');
      final r1 = await service.create(assetId: id, date: DateTime(2024, 1, 5), type: EventType.revalue, amount: 1200, currency: 'EUR');
      await service.create(assetId: id, date: DateTime(2024, 2, 5), type: EventType.revalue, amount: 1300, currency: 'EUR');
      expect(await methodOf(id), ValuationMethod.eventDriven);
      await service.delete(r1);
      expect(await methodOf(id), ValuationMethod.eventDriven); // still ON (one revalue left)
    });
  });
}
