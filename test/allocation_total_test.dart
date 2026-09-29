// Allocation totals are taken over the same holdings the slices are drawn
// from — positive values of the assets shown — so the slices add up to 100%
// (a liability's negative value used to shrink the total while being in no
// slice, pushing the percentages past 100%). A held asset without a value is
// in no slice and is counted, never silently dropped.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/portfolio/allocation_computation_service.dart';

Asset _asset(int id, String currency) {
  final now = DateTime(2025, 1, 1);
  return Asset(
    id: id,
    name: 'A$id',
    assetType: AssetType.stockEtf,
    instrumentType: InstrumentType.etf,
    assetClass: AssetClass.equity,
    intermediaryId: 1,
    assetGroup: '',
    currency: currency,
    valuationMethod: ValuationMethod.marketPrice,
    isActive: true,
    includeInSavings: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // 1: 6,000 EUR; 2: 4,000 USD; 3: a -5,000 loan; 4: held, no value; 5: zero.
  final assets = [_asset(1, 'EUR'), _asset(2, 'USD'), _asset(3, 'EUR'), _asset(4, 'EUR'), _asset(5, 'GBP')];
  const values = {1: 6000.0, 2: 4000.0, 3: -5000.0, 5: 0.0};

  group('allocationTotal', () {
    test('adds up only what the slices show', () {
      expect(allocationTotal(assets, values), 10000);
      final slices = groupByField(assets, values, (a) => a.currency);
      expect(slices.values.fold(0.0, (a, b) => a + b), allocationTotal(assets, values));
    });

    test('a value of an asset not shown is not part of it', () {
      expect(allocationTotal([_asset(1, 'EUR')], values), 6000);
      expect(allocationTotal(const [], values), 0);
    });
  });

  group('unvaluedAssetCount', () {
    test('counts the held assets without a value', () {
      expect(unvaluedAssetCount(assets, values, heldIds: {1, 2, 3, 4, 5}), 1);
    });

    test('a position no longer held has no value to miss', () {
      expect(unvaluedAssetCount(assets, values, heldIds: {1, 2, 3}), 0);
    });
  });
}
