import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/web_market_data_service.dart';

void main() {
  late AppDatabase db;
  late WebMarketDataService service;
  late int iid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = WebMarketDataService(db);
    iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
  });

  tearDown(() async => await db.close());

  group('getPriceHistoryBatch', () {
    test('returns prices grouped by asset', () async {
      // Create two assets
      final asset1Id = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Asset A',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));
      final asset2Id = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Asset B',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));

      // Insert 3 prices for asset1
      final dates1 = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
        DateTime(2024, 1, 3),
      ];
      for (var i = 0; i < dates1.length; i++) {
        await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
          assetId: asset1Id,
          date: dates1[i],
          closePrice: 10.0 + i,
          currency: 'EUR',
        ));
      }

      // Insert 2 prices for asset2
      final dates2 = [
        DateTime(2024, 2, 1),
        DateTime(2024, 2, 2),
      ];
      for (var i = 0; i < dates2.length; i++) {
        await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
          assetId: asset2Id,
          date: dates2[i],
          closePrice: 20.0 + i,
          currency: 'USD',
        ));
      }

      final result = await service.getPriceHistoryBatch([asset1Id, asset2Id]);

      expect(result.keys.length, 2);
      expect(result[asset1Id]!.length, 3);
      expect(result[asset2Id]!.length, 2);

      // Verify sorted by date ascending
      expect(result[asset1Id]![0].value, 10.0);
      expect(result[asset1Id]![1].value, 11.0);
      expect(result[asset1Id]![2].value, 12.0);

      expect(result[asset2Id]![0].value, 20.0);
      expect(result[asset2Id]![1].value, 21.0);
    });

    test('returns empty map for empty asset list', () async {
      final result = await service.getPriceHistoryBatch([]);
      expect(result, isEmpty);
    });
  });

  group('getFirstBuyDate — valueDate convention', () {
    test('returns the earliest valueDate, not operationDate', () async {
      // A buy with a much-later operationDate but earlier valueDate must
      // win. Pre-fix code used MIN(date) which returned 2024-06-01.
      final assetId = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Buy VD',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));
      // Late operationDate, early valueDate
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 6, 1),
        valueDate: DateTime(2024, 1, 15),
        type: EventType.buy,
        amount: 100,
      ));
      // Earlier operationDate, later valueDate (red herring for the
      // pre-fix code: MIN(date) here returns 2024-03-01)
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 3, 1),
        valueDate: DateTime(2024, 4, 1),
        type: EventType.buy,
        amount: 50,
      ));

      final firstBuy = await service.getFirstBuyDate(assetId);
      expect(firstBuy, DateTime(2024, 1, 15),
          reason: 'must be the earliest valueDate (Jan 15), not the earliest operationDate (Mar 1)');
    });

    test('ignores non-buy events even if their valueDate is earlier', () async {
      final assetId = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'NonBuy ignored',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));
      // A revalue with earlier valueDate must NOT count
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 1, 1),
        valueDate: DateTime(2024, 1, 1),
        type: EventType.revalue,
        amount: 1000,
      ));
      // A buy is the only thing that should count
      await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
        assetId: assetId,
        date: DateTime(2024, 5, 1),
        valueDate: DateTime(2024, 5, 1),
        type: EventType.buy,
        amount: 100,
      ));

      final firstBuy = await service.getFirstBuyDate(assetId);
      expect(firstBuy, DateTime(2024, 5, 1));
    });
  });

  group('initialSyncDefaultFrom — widened window', () {
    test('subtracts the 14-day buffer from firstBuy', () {
      // Buy on a holiday: prior trading days must still be reachable.
      // 2026-05-01 is a public holiday in Italy; without the buffer the
      // fetch window collapses to a single non-trading day and the API
      // returns no rows.
      final firstBuy = DateTime(2026, 5, 1);
      expect(
        WebMarketDataService.initialSyncDefaultFrom(firstBuy),
        DateTime(2026, 4, 17),
      );
    });

    test('falls back to 2020-01-01 when firstBuy is null', () {
      expect(
        WebMarketDataService.initialSyncDefaultFrom(null),
        DateTime(2020, 1, 1),
      );
    });
  });

  group('assetsWithoutMarketPrice query', () {
    // Pin the SQL used by assetsWithoutMarketPriceProvider so the UI badge
    // surfaces precisely the assets whose displayed value is a buy/revalue
    // fallback rather than a real market quote.
    test('flags marketPrice assets with no rows in market_prices', () async {
      // Asset with no market_prices -> should be flagged.
      final flagged = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Stale bond',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));
      // Asset with a stored price -> should NOT be flagged.
      final priced = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Live ETF',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        intermediaryId: iid,
      ));
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
        assetId: priced,
        date: DateTime(2026, 4, 30),
        closePrice: 101.24,
        currency: 'EUR',
      ));
      // Event-driven asset (e.g. real estate) -> should NOT be flagged
      // even with no market_prices row, since marketPrice isn't its source.
      final manual = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Apartment',
        assetType: AssetType.realEstate,
        valuationMethod: ValuationMethod.eventDriven,
        intermediaryId: iid,
      ));
      // Inactive marketPrice asset with no prices -> excluded too.
      final inactiveId = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Old position',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
        isActive: const drift.Value(false),
        intermediaryId: iid,
      ));

      final rows = await db.customSelect(
        "SELECT a.id FROM assets a "
        "WHERE a.is_active = 1 "
        "AND a.valuation_method = 'marketPrice' "
        "AND NOT EXISTS (SELECT 1 FROM market_prices mp WHERE mp.asset_id = a.id)",
      ).get();
      final ids = rows.map((r) => r.read<int>('id')).toSet();
      expect(ids, {flagged});
      expect(ids.contains(priced), isFalse);
      expect(ids.contains(manual), isFalse);
      expect(ids.contains(inactiveId), isFalse);
    });
  });
}
