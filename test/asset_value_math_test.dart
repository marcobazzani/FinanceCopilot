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
          quantity: 0, price: 200, bondDivisor: 1, fxRate: 1.0,
        ),
        0.0,
      );
    });

    test('preserves sign of quantity (short position)', () {
      final value = computeAssetBaseValue(
        quantity: -10, price: 100, bondDivisor: 1, fxRate: 1.0,
      );
      expect(value, -1000.0);
    });
  });
}
