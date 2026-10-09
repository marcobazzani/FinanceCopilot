import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(
  int id,
  double amount,
  DateTime date, {
  int? categoryId,
  String currency = 'EUR',
  TransactionStatus status = TransactionStatus.settled,
}) => Transaction(
  id: id,
  accountId: 1,
  operationDate: date,
  valueDate: date,
  amount: amount,
  description: 'tx $id',
  status: status,
  categoryId: categoryId,
  currency: currency,
  tags: '[]',
  createdAt: date,
);

Category cat(int id, CategoryType type) => Category(id: id, name: 'c$id', type: type, isEssential: false, isArchived: false, sortOrder: id);

void main() {
  final cats = {
    1: cat(1, CategoryType.expense), // groceries
    2: cat(2, CategoryType.expense), // travel
    3: cat(3, CategoryType.transfer),
    4: cat(4, CategoryType.income),
    5: cat(5, CategoryType.reimbursement),
  };
  final now = DateTime(2025, 6, 15);

  Future<double?> rateOk(String c, int day) async => c == 'USD' ? 0.5 : null;

  test('sums outflows per year per category; transfers are left out but totalled; inflows never count', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [
        tx(1, -100, DateTime(2024, 1, 5), categoryId: 1),
        tx(2, -50, DateTime(2024, 3, 5), categoryId: 1),
        tx(3, -30, DateTime(2024, 3, 6), categoryId: 2),
        tx(4, -999, DateTime(2024, 3, 7), categoryId: 3), // transfer — excluded
        tx(5, -40, DateTime(2024, 3, 8), categoryId: 4), // outflow in an income category: money left — counts
        tx(6, -60, DateTime(2024, 3, 9), categoryId: 5), // outflow in a reimbursement category: counts
        tx(7, 500, DateTime(2024, 3, 10), categoryId: 1), // inflow — excluded
        tx(8, -20, DateTime(2025, 2, 1)), // uncategorized bucket
        tx(9, -70, DateTime(2025, 2, 2), categoryId: 2),
        tx(10, -999, DateTime(2025, 2, 3), categoryId: 1, status: TransactionStatus.cancelled),
        tx(11, -10, DateTime(2025, 2, 4), categoryId: 42), // dangling category id → uncategorized
      ],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
    );
    expect(d.years, [2024, 2025]);
    expect(d.currentYear, 2025);
    expect(d.amount(2024, 1), 150);
    expect(d.amount(2024, 2), 30);
    expect(d.amount(2024, null), 0);
    expect(d.amount(2024, 4), 40);
    expect(d.amount(2024, 5), 60);
    expect(d.amount(2024, 3), 0, reason: 'transfer: not spending');
    expect(d.transfersExcluded(2024), 999, reason: 'but its amount is reported, never silently dropped');
    expect(d.transfersExcluded(2025), 0);
    expect(d.totalFor(2024), 280);
    expect(d.share(2024, 1), closeTo(150 / 280, 1e-9));
    expect(d.amount(2025, null), 30, reason: 'uncategorized + dangling category id');
    expect(d.amount(2025, 2), 70);
    expect(d.fxExcluded, 0);
    expect(d.isEmpty, isFalse);
    // Ordered by all-years total: groceries 150, travel 100, reimbursement 60, income 40, uncategorized 30.
    expect(d.categoriesByTotal(), [1, 2, 5, 4, null]);
  });

  test('foreign currency rows are converted; missing rates are excluded and counted, never defaulted', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [
        tx(1, -100, DateTime(2024, 1, 5), categoryId: 1, currency: 'USD'),
        tx(2, -100, DateTime(2024, 1, 5), categoryId: 1, currency: 'GBP'),
        tx(3, -10, DateTime(2024, 1, 5), categoryId: 1),
      ],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
    );
    expect(d.amount(2024, 1), 60, reason: '100 USD * 0.5 + 10 EUR; GBP excluded');
    expect(d.fxExcluded, 1);
  });

  test('ledger-explained rows (excludedIds) are left out even when uncategorized', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [
        tx(1, -500, DateTime(2024, 1, 5)), // a transfer leg, uncategorized
        tx(2, -20, DateTime(2024, 1, 5)), // real uncategorized spending
        tx(3, -10, DateTime(2024, 1, 5), categoryId: 1), // adjustment anchor with a stale category
      ],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
      excludedIds: {1, 3},
    );
    expect(d.amount(2024, null), 20);
    expect(d.amount(2024, 1), 0);
    expect(d.totalFor(2024), 20);
  });

  test('through cutoff and empty data', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [tx(1, -100, DateTime(2024, 1, 5), categoryId: 1)],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
      through: DateTime(2023, 12, 31),
    );
    expect(d.isEmpty, isTrue);
    expect(d.years, isEmpty);
    expect(d.share(2024, 1), 0);
    expect(d.categoriesByTotal(), isEmpty);
  });

  test('categoriesByTotal tie-break: uncategorized last, then id asc', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [
        tx(1, -10, DateTime(2024, 1, 5)),
        tx(2, -10, DateTime(2024, 1, 5), categoryId: 2),
        tx(3, -10, DateTime(2024, 1, 5), categoryId: 1),
      ],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
    );
    expect(d.categoriesByTotal(), [1, 2, null]);
  });

  test('refunds received: inflows in reimbursement or expense categories, with their rows; unknown inflows are not refunds', () async {
    final d = await aggregateSpendingByCategory(
      transactions: [
        tx(1, 40, DateTime(2024, 2, 1), categoryId: 5), // reimbursement
        tx(2, 15, DateTime(2024, 2, 2), categoryId: 1), // money back in an expense category
        tx(3, 100, DateTime(2024, 2, 3), currency: 'USD', categoryId: 5), // 50 EUR
        tx(4, 999, DateTime(2024, 2, 4)), // uncategorized inflow: unknown, not a refund
        tx(5, 999, DateTime(2024, 2, 5), categoryId: 4), // income
        tx(6, 999, DateTime(2024, 2, 6), categoryId: 3), // transfer
        tx(7, 999, DateTime(2024, 2, 7), categoryId: 5, status: TransactionStatus.cancelled),
        tx(8, 999, DateTime(2024, 2, 8), categoryId: 5), // ledger-explained
        tx(9, 10, DateTime(2024, 2, 9), categoryId: 5, currency: 'GBP'), // no rate
        tx(10, -20, DateTime(2024, 2, 10), categoryId: 1),
      ],
      categories: cats,
      rate: rateOk,
      baseCurrency: 'EUR',
      now: now,
      excludedIds: {8},
    );
    expect(d.refunds(2024), 105);
    expect(d.refundIds(2024), [1, 2, 3]);
    expect(d.refunds(2023), 0);
    expect(d.fxExcluded, 1);
    expect(d.totalFor(2024), 20, reason: 'spending itself stays gross');
  });
}
