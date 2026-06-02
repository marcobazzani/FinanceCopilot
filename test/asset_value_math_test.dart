import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/utils/asset_value_math.dart';

void main() {
  group('computeAssetBaseValue', () {
    test('returns null when fxRate is null — must not silently use 1.0', () {
      // Same anti-pattern we fixed in round 1's CachedRateResolver. A foreign
      // currency asset with no available FX rate must not inflate the
      // portfolio total by treating its currency as if it were the base.
      final value = computeAssetBaseValue(
        quantity: 10,
        price: 100,
        bondDivisor: 1,
        fxRate: null,
      );
      expect(value, isNull);
    });

    test('multiplies quantity * price * fxRate for a normal asset', () {
      // 10 USD shares at $200, FX 0.92 EUR/USD -> 1840 EUR
      final value = computeAssetBaseValue(
        quantity: 10,
        price: 200,
        bondDivisor: 1,
        fxRate: 0.92,
      );
      expect(value, closeTo(10 * 200 * 0.92, 1e-9));
    });

    test('divides by 100 for bonds (price quoted as % of face)', () {
      // 1000 nominal at price 102.5 -> 1025 face value
      final value = computeAssetBaseValue(
        quantity: 1000,
        price: 102.5,
        bondDivisor: 100,
        fxRate: 1.0,
      );
      expect(value, closeTo(1025.0, 1e-9));
    });

    test('returns 0 for zero quantity', () {
      expect(
        computeAssetBaseValue(
          quantity: 0,
          price: 200,
          bondDivisor: 1,
          fxRate: 1.0,
        ),
        0.0,
      );
    });

    test('preserves sign of quantity (short position)', () {
      final value = computeAssetBaseValue(
        quantity: -10,
        price: 100,
        bondDivisor: 1,
        fxRate: 1.0,
      );
      expect(value, -1000.0);
    });
  });

  group('computeAssetNetValue', () {
    test('positive gain: net = invested + gain * (1 - tax)', () {
      // invested=10000, market=12000, gain=2000, tax=0.26
      // net = 10000 + 2000 * 0.74 = 11480
      expect(
        computeAssetNetValue(invested: 10000, market: 12000, taxRate: 0.26),
        closeTo(11480, 1e-9),
      );
    });

    test('zero gain: net = market = invested', () {
      expect(
        computeAssetNetValue(invested: 10000, market: 10000, taxRate: 0.26),
        10000,
      );
    });

    test('negative gain (loss): net = market — no phantom tax credit', () {
      // Loss must NOT be inflated by (1-tax). Net equals market value.
      expect(
        computeAssetNetValue(invested: 10000, market: 8000, taxRate: 0.26),
        8000,
      );
    });

    test('taxRate = 0: net equals market on positive gains', () {
      expect(
        computeAssetNetValue(invested: 10000, market: 12000, taxRate: 0),
        12000,
      );
    });

    test('taxRate = 1: net equals invested on positive gains', () {
      // 100% tax claws back the entire gain.
      expect(
        computeAssetNetValue(invested: 10000, market: 12000, taxRate: 1.0),
        10000,
      );
    });

    test('taxRate clamps below 0', () {
      expect(
        computeAssetNetValue(invested: 10000, market: 12000, taxRate: -0.5),
        12000,
      );
    });

    test('taxRate clamps above 1', () {
      expect(
        computeAssetNetValue(invested: 10000, market: 12000, taxRate: 5.0),
        10000,
      );
    });

    test('default tax rate constant is 0.26 (Italian retail)', () {
      expect(kDefaultTaxRate, 0.26);
    });

    test('zero invested with positive market: gain = market, net = market * (1-tax)', () {
      // Edge: free shares (grant) — invested is 0, all of market is gain.
      expect(
        computeAssetNetValue(invested: 0, market: 1000, taxRate: 0.26),
        closeTo(740, 1e-9),
      );
    });
  });
}
