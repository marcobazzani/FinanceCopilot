// Classification progress in money: the three money figures (total,
// categorized, their currency) exist together or not at all. Pins what the
// progress reports with and without a ledger valuation, so the figures can be
// carried as one value instead of three fields read with `!`.

import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';

Transaction _tx(int id, double amount, {int? categoryId, int accountId = 1}) => Transaction(
  id: id,
  accountId: accountId,
  operationDate: DateTime(2024, 3, 1),
  valueDate: DateTime(2024, 3, 1),
  amount: amount,
  description: 'row $id',
  status: TransactionStatus.settled,
  categoryId: categoryId,
  currency: 'EUR',
  tags: '',
  createdAt: DateTime(2024, 3, 1),
);

void main() {
  final ledger = LedgerSnapshot([_tx(1, -10, categoryId: 7), _tx(2, -30), _tx(3, -99)], const {});

  test('valued: money totals, the categorized part and what is left, in the base currency', () {
    final p = TransactionClassifierService.progressOf(ledger, valuation: const LedgerValuation('EUR', {1: 10, 2: 30, 3: null}));

    expect((p.total, p.categorized, p.uncategorized), (3, 1, 2));
    expect((p.totalAmount, p.categorizedAmount, p.uncategorizedAmount, p.baseCurrency), (40.0, 10.0, 30.0, 'EUR'));
    expect(p.fxExcluded, 1, reason: 'the row without a rate is counted, not valued');
    expect(p.fraction, 0.25, reason: 'progress is money, not rows');
    expect(p.amounts, (total: 40.0, categorized: 10.0, currency: 'EUR'), reason: 'the three figures travel together');
  });

  test('valued with nothing worth anything: zero money, fully explained', () {
    final p = TransactionClassifierService.progressOf(ledger, valuation: const LedgerValuation('CHF', {1: null, 2: null, 3: null}));

    expect((p.totalAmount, p.categorizedAmount, p.uncategorizedAmount, p.baseCurrency), (0.0, 0.0, 0.0, 'CHF'));
    expect(p.fxExcluded, 3);
    expect(p.fraction, 1.0);
  });

  test('not valued: no money figures at all, progress counts rows', () {
    final p = TransactionClassifierService.progressOf(ledger);

    expect((p.totalAmount, p.categorizedAmount, p.uncategorizedAmount, p.baseCurrency), (null, null, null, null));
    expect(p.fxExcluded, 0);
    expect(p.fraction, closeTo(1 / 3, 1e-12));
    expect(p.amounts, isNull);
  });

  test('an account scope values only that account', () {
    final mixed = LedgerSnapshot([_tx(1, -10, categoryId: 7), _tx(2, -30, accountId: 2)], const {});
    final p = TransactionClassifierService.progressOf(mixed, accountId: 2, valuation: const LedgerValuation('EUR', {1: 10, 2: 30}));

    expect((p.total, p.categorized), (1, 0));
    expect((p.totalAmount, p.categorizedAmount, p.uncategorizedAmount, p.baseCurrency), (30.0, 0.0, 30.0, 'EUR'));
    expect(p.fraction, 0.0);
  });
}
