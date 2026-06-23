import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/ai/finance_formulas.dart';

void main() {
  group('financeFormulas', () {
    test('is a substantial reference', () {
      expect(financeFormulas.length, greaterThan(500));
    });

    test('encodes the app\'s key formulas', () {
      for (final term in ['netWorth', 'savingsRate', 'FI number', 'HHI', 'pensionContrib', 'After-tax']) {
        expect(financeFormulas, contains(term), reason: term);
      }
    });
  });
}
