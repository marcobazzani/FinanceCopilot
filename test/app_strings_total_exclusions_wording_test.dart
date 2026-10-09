import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';

// The footnote under a total counts every contributor it leaves out for want
// of a price or an exchange rate — assets, but also accounts and adjustments
// without a rate — so it names items, not assets, in both languages, for one
// and for many.
void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;

  test('under one total', () {
    expect(en.unpricedExcludedFromTotal(1), '1 item without a price or exchange rate excluded from the total');
    expect(en.unpricedExcludedFromTotal(2), '2 items without a price or exchange rate excluded from the total');
    expect(it.unpricedExcludedFromTotal(1), '1 elemento senza prezzo o tasso di cambio escluso dal totale');
    expect(it.unpricedExcludedFromTotal(2), '2 elementi senza prezzo o tasso di cambio esclusi dal totale');
  });

  test('under several totals', () {
    expect(en.unpricedExcludedFromTotals(1), '1 item without a price or exchange rate excluded from the totals');
    expect(en.unpricedExcludedFromTotals(3), '3 items without a price or exchange rate excluded from the totals');
    expect(it.unpricedExcludedFromTotals(1), '1 elemento senza prezzo o tasso di cambio escluso dai totali');
    expect(it.unpricedExcludedFromTotals(3), '3 elementi senza prezzo o tasso di cambio esclusi dai totali');
  });
}
