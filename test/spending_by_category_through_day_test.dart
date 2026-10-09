// The spending-by-category aggregation in the wayback view is cut at the end
// of the as-of day, not at its midnight.
//
// `through` is the wayback day at local midnight. Filtering with
// `valueDate.isAfter(through)` dropped every row of that day carrying a clock
// time (a card payment at 15:42), while the ledger — which bounds reads at the
// next midnight — shows it, so the chart and the ledger disagreed on the very
// day being looked at.

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx(int id, double amount, DateTime valueDate, {int? categoryId}) => Transaction(
  id: id,
  accountId: 1,
  operationDate: valueDate,
  valueDate: valueDate,
  amount: amount,
  description: 'tx $id',
  status: TransactionStatus.settled,
  categoryId: categoryId,
  currency: 'EUR',
  tags: '[]',
  createdAt: valueDate,
);

void main() {
  final reimbursement = Category(id: 5, name: 'refunds', type: CategoryType.reimbursement, isEssential: false, isArchived: false, sortOrder: 5);

  for (final (label, through, lateSameDay, earlyNextDay) in [
    ('an ordinary day', DateTime(2026, 5, 10), DateTime(2026, 5, 10, 15, 42), DateTime(2026, 5, 11, 0, 30)),
    ('the spring-forward day', DateTime(2026, 3, 29), DateTime(2026, 3, 29, 23, 30), DateTime(2026, 3, 30, 0, 30)),
    ('the fall-back day', DateTime(2026, 10, 25), DateTime(2026, 10, 25, 23, 30), DateTime(2026, 10, 26, 0, 30)),
  ]) {
    test('as of $label, rows of that day count whatever their clock time; the next day does not', () async {
      final d = await aggregateSpendingByCategory(
        transactions: [
          _tx(1, -30, lateSameDay),
          _tx(2, -70, earlyNextDay),
          _tx(3, 25, lateSameDay, categoryId: reimbursement.id),
          _tx(4, 40, earlyNextDay, categoryId: reimbursement.id),
        ],
        categories: {reimbursement.id: reimbursement},
        rate: (currency, dayKey) async => null,
        baseCurrency: 'EUR',
        now: through,
        through: through,
      );

      expect(d.ids(through.year, null), [1]);
      expect(d.totalFor(through.year), 30);
      expect(d.refundIds(through.year), [3]);
      expect(d.refunds(through.year), 25);
    });
  }
}
