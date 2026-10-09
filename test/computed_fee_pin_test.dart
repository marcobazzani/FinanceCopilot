// Pin: the import's computed fee ("Computed" in the wizard) — what a row paid
// beyond the value of its units, |amount| − |quantity| × price [/ 100 for a
// bond] [/ rate] — for realistic trades, including products that carry float
// noise (3 × 0.1). The figures are the ones the fee produced before it
// valued the units with the amount auto-calc (autoCalcAmountFor) instead of
// its own copy of that product.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  for (final (amount, qty, price, isBond, rate, fee) in <(double, double, double, bool, double?, double)>[
    (-1234.56, 3, 0.1, false, null, 1234.26),
    (-1000.5, 7, 142.93, false, null, 0.01),
    (-9876.54, 10000, 98.7654, true, null, 0),
    (-4563.2, 5000, 99.13, true, 1.0873, 4.66049848248),
    (-1085, 10, 100, false, 1.1, 175.90909090909),
    (2501.25, -25, 100.1, false, null, 1.25),
    (-100.01, 0.123456, 809.9, false, null, 0.0229856),
    (9840, -10000, 98.5, true, 1.25, 1960),
    (-300.3, 3, 100.1, false, null, 0),
    (-1.3, 3, 0.1, false, null, 1),
    (-2034.79, 17.5, 116.12, false, 0.9981, 1.17833984571),
    (-15060.45, 150, 100.33, true, 1.0, 14909.955),
  ]) {
    test('amount $amount, $qty × $price${isBond ? ' (bond)' : ''}${rate == null ? '' : ' at $rate'}: $fee', () {
      expect(computedFeeFor(amount: amount, qty: qty, price: price, isBond: isBond, rateMapped: rate != null, rate: rate), fee);
    });
  }

  test('no fee without a quantity, a price, or a positive rate when one is mapped', () {
    expect(computedFeeFor(amount: -10, qty: null, price: 1, isBond: false, rateMapped: false), isNull);
    expect(computedFeeFor(amount: -10, qty: 1, price: null, isBond: true, rateMapped: false), isNull);
    for (final rate in [null, 0.0, -1.0, double.nan]) {
      expect(computedFeeFor(amount: -10, qty: 1, price: 1, isBond: false, rateMapped: true, rate: rate), isNull, reason: 'rate $rate');
    }
  });

  test('the value of the units is the amount auto-calc', () {
    expect(autoCalcAmountFor(qty: 3, price: 0.1, isBond: false), 0.3);
    expect(autoCalcAmountFor(qty: 10000, price: 98.7654, isBond: true), 9876.54);
    expect(autoCalcAmountFor(qty: null, price: 1, isBond: false), 0);
  });
}
