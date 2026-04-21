import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/allocation_computation_service.dart';

/// Helper to create a minimal Asset for testing.
Asset _makeAsset({
  required int id,
  required String name,
  String currency = 'EUR',
  String? country,
  String? sector,
  AssetClass assetClass = AssetClass.equity,
  InstrumentType instrumentType = InstrumentType.etf,
}) {
  final now = DateTime(2025, 1, 1);
  return Asset(
    id: id,
    name: name,
    assetType: AssetType.stockEtf,
    instrumentType: instrumentType,
    assetClass: assetClass,
    intermediaryId: 1,
    assetGroup: '',
    currency: currency,
    country: country,
    sector: sector,
    valuationMethod: ValuationMethod.marketPrice,
    isActive: true,
    includeInNetWorth: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// Helper to create AssetComposition entries.
AssetComposition _makeComp({
  required int assetId,
  required String type,
  required String name,
  required double weight,
}) {
  return AssetComposition(
    id: 0,
    assetId: assetId,
    type: type,
    name: name,
    weight: weight,
    updatedAt: DateTime(2025, 1, 1),
  );
}

void main() {
  // ─────────────────────────────────────────────
  // groupByField
  // ─────────────────────────────────────────────

  group('groupByField', () {
    test('groups correctly and sorts descending', () {
      final assets = [
        _makeAsset(id: 1, name: 'A', currency: 'EUR'),
        _makeAsset(id: 2, name: 'B', currency: 'USD'),
        _makeAsset(id: 3, name: 'C', currency: 'EUR'),
      ];
      final values = {1: 1000.0, 2: 3000.0, 3: 500.0};

      final result = groupByField(assets, values, (a) => a.currency);

      expect(result.keys.toList(), ['USD', 'EUR']);
      expect(result['USD'], 3000.0);
      expect(result['EUR'], 1500.0);
    });

    test('skips zero and null values', () {
      final assets = [
        _makeAsset(id: 1, name: 'A', currency: 'EUR'),
        _makeAsset(id: 2, name: 'B', currency: 'USD'),
        _makeAsset(id: 3, name: 'C', currency: 'GBP'),
      ];
      final values = {1: 1000.0, 2: 0.0}; // 3 not in map (null)

      final result = groupByField(assets, values, (a) => a.currency);

      expect(result.length, 1);
      expect(result['EUR'], 1000.0);
    });

    test('empty list returns empty map', () {
      final result = groupByField([], {}, (a) => a.currency);
      expect(result, isEmpty);
    });

    test('single asset', () {
      final assets = [_makeAsset(id: 1, name: 'A', currency: 'EUR')];
      final values = {1: 500.0};

      final result = groupByField(assets, values, (a) => a.currency);

      expect(result.length, 1);
      expect(result['EUR'], 500.0);
    });

    test('all same value groups together', () {
      final assets = [
        _makeAsset(id: 1, name: 'A', currency: 'EUR'),
        _makeAsset(id: 2, name: 'B', currency: 'EUR'),
        _makeAsset(id: 3, name: 'C', currency: 'EUR'),
      ];
      final values = {1: 100.0, 2: 100.0, 3: 100.0};

      final result = groupByField(assets, values, (a) => a.currency);

      expect(result.length, 1);
      expect(result['EUR'], 300.0);
    });
  });

  // ─────────────────────────────────────────────
  // weightedBreakdown
  // ─────────────────────────────────────────────

  group('weightedBreakdown', () {
    test('uses composition weights', () {
      final assets = [_makeAsset(id: 1, name: 'ETF')];
      final values = {1: 10000.0};
      final compositions = {
        1: [
          _makeComp(assetId: 1, type: 'country', name: 'US', weight: 60),
          _makeComp(assetId: 1, type: 'country', name: 'EU', weight: 40),
        ],
      };

      final result = weightedBreakdown(
        assets, values, compositions, 'country', (a) => 'Other',
      );

      expect(result['US'], 6000.0);
      expect(result['EU'], 4000.0);
      // US should be first (larger)
      expect(result.keys.first, 'US');
    });

    test('falls back when no composition', () {
      final assets = [
        _makeAsset(id: 1, name: 'Stock', country: 'Italy'),
      ];
      final values = {1: 5000.0};
      final compositions = <int, List<AssetComposition>>{};

      final result = weightedBreakdown(
        assets, values, compositions, 'country', (a) => a.country ?? 'Unknown',
      );

      expect(result['Italy'], 5000.0);
    });

    test('mixed: some with composition, some without', () {
      final assets = [
        _makeAsset(id: 1, name: 'ETF'),
        _makeAsset(id: 2, name: 'Stock', country: 'DE'),
      ];
      final values = {1: 10000.0, 2: 5000.0};
      final compositions = {
        1: [
          _makeComp(assetId: 1, type: 'country', name: 'US', weight: 100),
        ],
      };

      final result = weightedBreakdown(
        assets, values, compositions, 'country', (a) => a.country ?? 'Unknown',
      );

      expect(result['US'], 10000.0);
      expect(result['DE'], 5000.0);
    });

    test('skips zero/negative market values', () {
      final assets = [
        _makeAsset(id: 1, name: 'A'),
        _makeAsset(id: 2, name: 'B'),
      ];
      final values = {1: 0.0, 2: -100.0};

      final result = weightedBreakdown(
        assets, values, {}, 'country', (a) => 'X',
      );

      expect(result, isEmpty);
    });

    test('empty assets returns empty', () {
      final result = weightedBreakdown([], {}, {}, 'country', (a) => 'X');
      expect(result, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // drillDownData
  // ─────────────────────────────────────────────

  group('drillDownData', () {
    test('correct nested map structure', () {
      final assets = [
        _makeAsset(id: 1, name: 'ETF-A'),
        _makeAsset(id: 2, name: 'ETF-B'),
      ];
      final values = {1: 10000.0, 2: 5000.0};
      final compositions = {
        1: [
          _makeComp(assetId: 1, type: 'sector', name: 'Tech', weight: 70),
          _makeComp(assetId: 1, type: 'sector', name: 'Health', weight: 30),
        ],
        2: [
          _makeComp(assetId: 2, type: 'sector', name: 'Tech', weight: 50),
          _makeComp(assetId: 2, type: 'sector', name: 'Energy', weight: 50),
        ],
      };

      final result = drillDownData(
        assets, values, compositions, 'sector', (a) => 'Other',
      );

      // Tech should have contributions from both ETFs
      expect(result['Tech']!['ETF-A'], 7000.0);
      expect(result['Tech']!['ETF-B'], 2500.0);
      expect(result['Health']!['ETF-A'], 3000.0);
      expect(result['Energy']!['ETF-B'], 2500.0);
    });

    test('fallback assets appear in drill-down', () {
      final assets = [_makeAsset(id: 1, name: 'Stock', country: 'FR')];
      final values = {1: 2000.0};

      final result = drillDownData(
        assets, values, {}, 'country', (a) => a.country ?? 'Unknown',
      );

      expect(result['FR']!['Stock'], 2000.0);
    });

    test('empty input returns empty', () {
      final result = drillDownData([], {}, {}, 'sector', (a) => 'X');
      expect(result, isEmpty);
    });
  });

  // ─────────────────────────────────────────────
  // computeConcentration
  // ─────────────────────────────────────────────

  group('computeConcentration', () {
    test('Top1/3/5 percentages correct', () {
      final holdings = [
        const MapEntry('A', 500.0),
        const MapEntry('B', 300.0),
        const MapEntry('C', 100.0),
        const MapEntry('D', 50.0),
        const MapEntry('E', 50.0),
      ];
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.top1, 50.0);
      expect(result.top3, 90.0);
      expect(result.top5, 100.0);
    });

    test('fewer than 3 holdings uses all for top3', () {
      final holdings = [
        const MapEntry('A', 600.0),
        const MapEntry('B', 400.0),
      ];
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.top1, 60.0);
      expect(result.top3, 100.0); // all holdings
      expect(result.top5, 100.0); // all holdings
    });

    test('HHI calculation', () {
      // Two equal holdings: HHI = 2 * (0.5^2) * 10000 = 5000
      final holdings = [
        const MapEntry('A', 500.0),
        const MapEntry('B', 500.0),
      ];
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.hhi, closeTo(5000.0, 0.01));
    });

    test('classification: diversified (HHI < 1500)', () {
      // 10 equal holdings: HHI = 10 * (0.1^2) * 10000 = 1000
      final holdings = List.generate(
        10,
        (i) => MapEntry('Asset$i', 100.0),
      );
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.hhi, closeTo(1000.0, 0.01));
      expect(result.classification, 'diversified');
    });

    test('classification: moderate (1500 <= HHI < 2500)', () {
      // 5 equal holdings: HHI = 5 * (0.2^2) * 10000 = 2000
      final holdings = List.generate(
        5,
        (i) => MapEntry('Asset$i', 200.0),
      );
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.hhi, closeTo(2000.0, 0.01));
      expect(result.classification, 'moderate');
    });

    test('classification: concentrated (HHI >= 2500)', () {
      // 2 equal holdings: HHI = 5000
      final holdings = [
        const MapEntry('A', 500.0),
        const MapEntry('B', 500.0),
      ];
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.hhi, closeTo(5000.0, 0.01));
      expect(result.classification, 'concentrated');
    });

    test('single asset: HHI = 10000', () {
      final holdings = [const MapEntry('Only', 1000.0)];
      final total = 1000.0;

      final result = computeConcentration(holdings, total);

      expect(result.top1, 100.0);
      expect(result.top3, 100.0);
      expect(result.top5, 100.0);
      expect(result.hhi, closeTo(10000.0, 0.01));
      expect(result.classification, 'concentrated');
    });

    test('empty list', () {
      final result = computeConcentration([], 0.0);

      expect(result.top1, 0.0);
      expect(result.top3, 0.0);
      expect(result.top5, 0.0);
      expect(result.hhi, 0.0);
      expect(result.classification, 'diversified');
    });
  });
}
