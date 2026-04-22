/// Batch vs individual equivalence tests.
///
/// Every batch optimization must produce IDENTICAL results to calling the
/// original per-item method individually. These tests enforce that contract
/// so that future changes cannot silently diverge (e.g. missing fallback
/// paths, different date handling, different aggregation precision).
library;
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/investing_com_service.dart';

void main() {
  late AppDatabase db;
  late int iid;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
  });

  tearDown(() async => await db.close());

  // ── Helpers ──

  Future<int> createAsset(String name, {
    ValuationMethod valuation = ValuationMethod.marketPrice,
  }) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
      name: name,
      assetType: AssetType.stockEtf,
      valuationMethod: valuation,
      intermediaryId: iid,
    ));
  }

  Future<void> insertMarketPrices(int assetId, List<(DateTime, double)> prices) async {
    for (final (date, price) in prices) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
        assetId: assetId,
        date: date,
        closePrice: price,
        currency: 'EUR',
      ));
    }
  }

  Future<void> insertEvent(int assetId, {
    required DateTime date,
    required EventType type,
    required double amount,
    double? quantity,
  }) async {
    await db.into(db.assetEvents).insert(AssetEventsCompanion.insert(
      assetId: assetId,
      date: date,
      valueDate: date,
      type: type,
      amount: amount,
      quantity: Value(quantity),
      currency: Value('EUR'),
    ));
  }

  // ═══════════════════════════════════════════════════
  // getPriceHistoryBatch vs getPriceHistory
  // ═══════════════════════════════════════════════════

  group('getPriceHistoryBatch matches getPriceHistory for each asset', () {
    test('assets with market prices', () async {
      final service = InvestingComService(db);
      final a1 = await createAsset('Asset A');
      final a2 = await createAsset('Asset B');

      await insertMarketPrices(a1, [
        (DateTime(2024, 1, 1), 10.0),
        (DateTime(2024, 1, 2), 11.0),
        (DateTime(2024, 6, 15), 15.5),
      ]);
      await insertMarketPrices(a2, [
        (DateTime(2024, 3, 1), 50.0),
      ]);

      // Individual calls
      final individual1 = await service.getPriceHistory(a1);
      final individual2 = await service.getPriceHistory(a2);

      // Batch call
      final batch = await service.getPriceHistoryBatch([a1, a2]);

      // Must be identical
      expect(batch[a1]!.length, individual1.length);
      expect(batch[a2]!.length, individual2.length);
      for (var i = 0; i < individual1.length; i++) {
        expect(batch[a1]![i].key, individual1[i].key, reason: 'asset1 date[$i]');
        expect(batch[a1]![i].value, individual1[i].value, reason: 'asset1 price[$i]');
      }
      for (var i = 0; i < individual2.length; i++) {
        expect(batch[a2]![i].key, individual2[i].key, reason: 'asset2 date[$i]');
        expect(batch[a2]![i].value, individual2[i].value, reason: 'asset2 price[$i]');
      }
    });

    test('asset with NO market prices falls back to revalue events', () async {
      final service = InvestingComService(db);
      final assetId = await createAsset('Revalue Only');

      // No market prices -- only revalue events
      await insertEvent(assetId, date: DateTime(2024, 1, 1), type: EventType.buy, amount: 1000, quantity: 10);
      await insertEvent(assetId, date: DateTime(2024, 6, 1), type: EventType.revalue, amount: 1200);
      await insertEvent(assetId, date: DateTime(2024, 12, 1), type: EventType.revalue, amount: 1500);

      // Individual call (has revalue fallback)
      final individual = await service.getPriceHistory(assetId);
      expect(individual, isNotEmpty, reason: 'getPriceHistory should return revalue-based prices');

      // Batch call must match
      final batch = await service.getPriceHistoryBatch([assetId]);
      expect(batch[assetId], isNotNull, reason: 'batch must include revalue fallback');
      expect(batch[assetId]!.length, individual.length);
      for (var i = 0; i < individual.length; i++) {
        expect(batch[assetId]![i].key, individual[i].key, reason: 'date[$i]');
        expect(batch[assetId]![i].value, individual[i].value, reason: 'price[$i]');
      }
    });

    test('mix of assets with and without market prices', () async {
      final service = InvestingComService(db);
      final withPrices = await createAsset('Has Prices');
      final withRevalue = await createAsset('Revalue Only');
      final empty = await createAsset('No Data');

      await insertMarketPrices(withPrices, [
        (DateTime(2024, 1, 1), 100.0),
        (DateTime(2024, 2, 1), 105.0),
      ]);

      await insertEvent(withRevalue, date: DateTime(2024, 1, 1), type: EventType.buy, amount: 500, quantity: 5);
      await insertEvent(withRevalue, date: DateTime(2024, 3, 1), type: EventType.revalue, amount: 600);

      // Individual
      final ind1 = await service.getPriceHistory(withPrices);
      final ind2 = await service.getPriceHistory(withRevalue);
      final ind3 = await service.getPriceHistory(empty);

      // Batch
      final batch = await service.getPriceHistoryBatch([withPrices, withRevalue, empty]);

      // withPrices: must match
      expect(batch[withPrices]!.length, ind1.length);
      for (var i = 0; i < ind1.length; i++) {
        expect(batch[withPrices]![i].key, ind1[i].key);
        expect(batch[withPrices]![i].value, ind1[i].value);
      }

      // withRevalue: must match (revalue fallback)
      expect(batch[withRevalue]!.length, ind2.length);
      for (var i = 0; i < ind2.length; i++) {
        expect(batch[withRevalue]![i].key, ind2[i].key);
        expect(batch[withRevalue]![i].value, ind2[i].value);
      }

      // empty: both should return nothing
      expect(ind3, isEmpty);
      expect(batch.containsKey(empty), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════
  // getByAssets vs getByAsset
  // ═══════════════════════════════════════════════════

  group('getByAssets matches getByAsset for each asset', () {
    test('multiple assets with events', () async {
      final service = AssetEventService(db);
      final a1 = await createAsset('A', valuation: ValuationMethod.eventDriven);
      final a2 = await createAsset('B', valuation: ValuationMethod.eventDriven);

      await insertEvent(a1, date: DateTime(2024, 1, 1), type: EventType.buy, amount: 100, quantity: 1);
      await insertEvent(a1, date: DateTime(2024, 2, 1), type: EventType.buy, amount: 200, quantity: 2);
      await insertEvent(a1, date: DateTime(2024, 3, 1), type: EventType.buy, amount: 300, quantity: 3);
      await insertEvent(a2, date: DateTime(2024, 4, 1), type: EventType.buy, amount: 400, quantity: 4);
      await insertEvent(a2, date: DateTime(2024, 5, 1), type: EventType.buy, amount: 500, quantity: 5);

      // Individual
      final ind1 = await service.getByAsset(a1);
      final ind2 = await service.getByAsset(a2);

      // Batch
      final batch = await service.getByAssets([a1, a2]);

      // Must be identical
      expect(batch[a1]!.length, ind1.length);
      expect(batch[a2]!.length, ind2.length);
      for (var i = 0; i < ind1.length; i++) {
        expect(batch[a1]![i].id, ind1[i].id, reason: 'asset1 event[$i] id');
        expect(batch[a1]![i].amount, ind1[i].amount, reason: 'asset1 event[$i] amount');
        expect(batch[a1]![i].date, ind1[i].date, reason: 'asset1 event[$i] date');
      }
      for (var i = 0; i < ind2.length; i++) {
        expect(batch[a2]![i].id, ind2[i].id, reason: 'asset2 event[$i] id');
        expect(batch[a2]![i].amount, ind2[i].amount, reason: 'asset2 event[$i] amount');
        expect(batch[a2]![i].date, ind2[i].date, reason: 'asset2 event[$i] date');
      }
    });

    test('asset with no events returns empty in both', () async {
      final service = AssetEventService(db);
      final a = await createAsset('Empty', valuation: ValuationMethod.eventDriven);

      final individual = await service.getByAsset(a);
      final batch = await service.getByAssets([a]);

      expect(individual, isEmpty);
      expect(batch[a] ?? [], isEmpty);
    });
  });
}
