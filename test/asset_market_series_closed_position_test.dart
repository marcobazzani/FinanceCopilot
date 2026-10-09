// Regression: a fully liquidated position (bought then completely sold)
// must contribute an EXACT zero to the asset-market chart series from the
// sell date onward — not silently drop out of the series.
//
// `allSeriesDataProvider`'s asset-market loop only emitted a spot when
// `cumQuantity > 0`. Once a position closed, no more spots were emitted for
// that asset, and `buildTotalSpots`'s carry-forward semantics then kept
// re-adding the LAST pre-sale market value into every later chart total
// (net worth, pillar totals, etc.) forever — a phantom position that no
// longer exists kept inflating the total.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider, buildTotalSpots;

class _TestMarketPriceService extends MarketPriceService {
  _TestMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
        accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
        accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
        assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
        assetStatsProvider.overrideWithValue(const AsyncData(<int, AssetStats>{})),
        extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'fully liquidated position emits an exact zero spot on the sell date, not a dropped series',
    () async {
      final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      final assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: intermediaryId,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 1),
              valueDate: DateTime(2026, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(1),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 2),
              valueDate: DateTime(2026, 1, 2),
              type: EventType.sell,
              amount: 100,
              quantity: const Value(1),
            ),
          );
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 1),
              closePrice: 100,
              currency: 'EUR',
            ),
          );

      final data = await container.read(allSeriesDataProvider.future);
      expect(data, isNotNull);

      final series = data!.assetMarket.singleWhere((s) => s.key == 'asset_market:$assetId');
      final byX = {for (final s in series.spots) s.x: s.y};
      // Day 0 = buy date (value 100), day 1 = sell date (must be EXACTLY 0 —
      // the position is known to be closed, not "no data available").
      expect(byX[0], 100);
      expect(byX[1], 0);

      // buildTotalSpots must carry the exact 0 forward from the sell date,
      // never the stale pre-sale 100 — this is the regression this test pins.
      final total = buildTotalSpots([series.spots]);
      expect(total.last.y, 0);
    },
  );

  test(
    'reopening a position after full liquidation starts fresh from the new quantity',
    () async {
      final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      final assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: intermediaryId,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 1),
              valueDate: DateTime(2026, 1, 1),
              type: EventType.buy,
              amount: 100,
              quantity: const Value(1),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 2),
              valueDate: DateTime(2026, 1, 2),
              type: EventType.sell,
              amount: 100,
              quantity: const Value(1),
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2026, 1, 3),
              valueDate: DateTime(2026, 1, 3),
              type: EventType.buy,
              amount: 200,
              quantity: const Value(2),
            ),
          );
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(assetId: assetId, date: DateTime(2026, 1, 1), closePrice: 100, currency: 'EUR'),
          );
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(assetId: assetId, date: DateTime(2026, 1, 3), closePrice: 100, currency: 'EUR'),
          );

      final data = await container.read(allSeriesDataProvider.future);
      final series = data!.assetMarket.singleWhere((s) => s.key == 'asset_market:$assetId');
      final byX = {for (final s in series.spots) s.x: s.y};
      expect(byX[0], 100); // 1 share @ 100
      expect(byX[1], 0); // fully closed
      expect(byX[2], 200); // reopened: 2 shares @ 100
    },
  );
}
