// The cash-flow Sankey of one month. The ledger's spending (by category),
// refunds, transfers and spread saving plans are summed per month as well as
// per year — the months of a year add up to the year, whose figures do not
// change — and the Sankey of a month is built from that month's rows alone.
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/cash_flow_sankey.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(int id, double amount, DateTime date, {int? categoryId}) => Transaction(
  id: id,
  accountId: 1,
  operationDate: date,
  valueDate: date,
  amount: amount,
  description: 'tx $id',
  status: TransactionStatus.settled,
  categoryId: categoryId,
  currency: 'EUR',
  tags: '[]',
  createdAt: date,
);

void main() {
  const cats = {
    1: Category(id: 1, name: 'Groceries', type: CategoryType.expense, isEssential: true, isArchived: false, sortOrder: 1),
    2: Category(id: 2, name: 'Travel', type: CategoryType.expense, isEssential: false, isArchived: false, sortOrder: 2),
    3: Category(id: 3, name: 'Moves', type: CategoryType.transfer, isEssential: false, isArchived: false, sortOrder: 3),
  };
  final rows = [
    tx(1, -10, DateTime(2024, 1, 5), categoryId: 1),
    tx(2, -20, DateTime(2024, 1, 20), categoryId: 2),
    tx(3, -5, DateTime(2024, 3, 2), categoryId: 1),
    tx(4, -7, DateTime(2024, 3, 9)), // uncategorized
    tx(5, 4, DateTime(2024, 3, 10), categoryId: 1), // money back for groceries: a refund
    tx(6, -100, DateTime(2024, 3, 11), categoryId: 3), // a transfer: not spending, but counted
    tx(7, -50, DateTime(2024, 12, 31), categoryId: 2),
  ];
  final plans = [
    SavingScheduleItem(eventId: 9, eventName: 'Car', date: DateTime(2024, 1, 26), amount: -200, currency: 'EUR'),
    SavingScheduleItem(eventId: 9, eventName: 'Car', date: DateTime(2024, 3, 26), amount: -200, currency: 'EUR'),
  ];

  Future<SpendingByCategoryData> spend() => aggregateSpendingByCategory(
    transactions: rows,
    categories: cats,
    rate: (c, d) async => null,
    baseCurrency: 'EUR',
    now: DateTime(2025, 6, 1),
    savingItems: plans,
  );

  test('each month holds its own rows: spending by category, refunds, transfers and saving plans', () async {
    final d = await spend();
    final jan = d.period(2024, 1);
    expect(jan.byCategory, {1: 10.0, 2: 20.0});
    expect(jan.ids(1), [1]);
    expect(jan.ids(2), [2]);
    expect(jan.refunds, 0);
    expect(jan.transfersExcluded, 0);
    expect(jan.savingPlans, [(eventId: 9, name: 'Car', amount: 200.0)]);

    final mar = d.period(2024, 3);
    expect(mar.byCategory, {1: 5.0, null: 7.0});
    expect(mar.ids(null), [4]);
    expect(mar.refunds, 4);
    expect(mar.refundIds, [5]);
    expect(mar.transfersExcluded, 100);
    expect(mar.savingPlans, [(eventId: 9, name: 'Car', amount: 200.0)]);

    final feb = d.period(2024, 2);
    expect(feb.total, 0, reason: 'a month without rows is empty, not missing');
    expect(feb.byCategory, isEmpty);
    expect(feb.refundIds, isEmpty);
    expect(feb.savingPlans, isEmpty);
  });

  test('the months of a year add up to the year, whose figures are unchanged', () async {
    final d = await spend();
    final year = d.period(2024);
    final months = [for (var m = 1; m <= 12; m++) d.period(2024, m)];
    for (final c in [1, 2, null]) {
      expect(months.fold(0.0, (a, p) => a + p.amount(c)), year.amount(c), reason: 'category $c');
      expect([for (final p in months) ...p.ids(c)], year.ids(c), reason: 'category $c');
    }
    expect(months.fold(0.0, (a, p) => a + p.refunds), year.refunds);
    expect(months.fold(0.0, (a, p) => a + p.transfersExcluded), year.transfersExcluded);
    expect(months.fold(0.0, (a, p) => a + p.savingPlansTotal), year.savingPlansTotal);

    expect(d.years, [2024]);
    expect(d.amount(2024, 1), 15);
    expect(d.ids(2024, 2), [2, 7]);
    expect(d.refunds(2024), 4);
    expect(d.refundIds(2024), [5]);
    expect(d.transfersExcluded(2024), 100);
    expect(d.savingPlans(2024), [(eventId: 9, name: 'Car', amount: 400.0)]);
    expect(d.totalFor(2024), 92);
  });

  test('the Sankey of a month is built from that month alone', () async {
    final d = await spend();
    // March: income 1,000, savings 400 → expenses 600.
    final g = buildCashFlowSankey(year: 2024, month: 3, income: 1000, savings: 400, recordedRefunds: 6, spending: d, categories: cats);
    expect(g.expenses, 600);
    expect(g.categorized, 5);
    expect(g.uncategorized, 7);
    expect(g.savingPlans, 200);
    expect(g.refunds, 10, reason: '4 in the ledger + 6 recorded');
    expect(g.untrackedExpenses, 398, reason: '600 − (5 + 7 + 200 − 10)');
    expect([for (final n in g.nodes.where((n) => n.kind == CashFlowNodeKind.expense)) n.categoryId], [1], reason: 'no travel in March');

    final year = buildCashFlowSankey(year: 2024, income: 1000, savings: 400, spending: d, categories: cats);
    expect(year.categorized, 85, reason: 'without a month, the whole year as before');
  });
}
