import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/investing_com_service.dart';

void main() {
  late AppDatabase db;
  late InvestingComService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = InvestingComService(db);
  });

  tearDown(() async => await db.close());

  group('getPriceHistoryBatch', () {
    test('returns prices grouped by asset', () async {
      // Create two assets
      final asset1Id = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Asset A',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
      ));
      final asset2Id = await db.into(db.assets).insert(AssetsCompanion.insert(
        name: 'Asset B',
        assetType: AssetType.stockEtf,
        valuationMethod: ValuationMethod.marketPrice,
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
}
