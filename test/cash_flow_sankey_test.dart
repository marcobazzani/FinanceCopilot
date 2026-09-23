import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/cash_flow_sankey.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
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

Category cat(int id, CategoryType type, {bool essential = false}) =>
    Category(id: id, name: 'c$id', type: type, isEssential: essential, isArchived: false, sortOrder: id);

void main() {
  final cats = {
    1: cat(1, CategoryType.expense, essential: true), // groceries
    2: cat(2, CategoryType.expense), // travel
    6: cat(6, CategoryType.expense, essential: true), // housing
  };

  Future<SpendingByCategoryData> spend(List<Transaction> txs) => aggregateSpendingByCategory(
    transactions: txs,
    categories: cats,
    rate: (c, d) async => null,
    baseCurrency: 'EUR',
    now: DateTime(2025, 6, 15),
  );

  CashFlowSankey build(SpendingByCategoryData d, {required double income, required double savings, int year = 2024}) =>
      buildCashFlowSankey(year: year, income: income, savings: savings, spending: d, categories: cats);

  void expectBalanced(CashFlowSankey g) {
    for (final n in g.nodes) {
      final inflow = g.links.where((l) => l.to == n.id).fold(0.0, (a, l) => a + l.value);
      final outflow = g.links.where((l) => l.from == n.id).fold(0.0, (a, l) => a + l.value);
      if (n.layer > 0) expect(inflow, closeTo(n.value, 1e-9), reason: '${n.id} in');
      if (n.layer < 3 && outflow > 0) expect(outflow, closeTo(n.value, 1e-9), reason: '${n.id} out');
    }
    final layer2 = g.nodes.where((n) => n.layer == 2).fold(0.0, (a, n) => a + n.value);
    expect(layer2, closeTo(g.scaleTotal, 1e-9));
  }

  test('ledger < expenses: categorized and uncategorized are both ledger spending; only the rest is untracked', () async {
    final d = await spend([
      tx(1, -800, DateTime(2024, 2, 2), categoryId: 6),
      tx(2, -200, DateTime(2024, 2, 3), categoryId: 1),
      tx(3, -500, DateTime(2024, 2, 4), categoryId: 2),
      tx(4, -250, DateTime(2024, 2, 5)), // uncategorized: tracked, not classified — never "untracked"
    ]);
    // Yearly chart: income 3100, savings 1000 → expenses 2100.
    final g = build(d, income: 3100, savings: 1000);
    expect(g.expenses, 2100);
    expect(g.categorized, 1500);
    expect(g.uncategorized, 250);
    expect(g.ledgerSpending, 1750);
    expect(g.savingsRate, closeTo(1000 / 3100, 1e-12));
    expect(g.untrackedExpenses, 350, reason: '2100 − (1500 + 250)');
    expect(g.untrackedIncome, 0);
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=3100.0',
      'total=3100.0',
      'grp:essential=1000.0',
      'grp:discretionary=500.0',
      'grp:uncategorized=250.0',
      'grp:untracked=350.0',
      'saved=1000.0',
      'out:6=800.0',
      'out:1=200.0',
      'out:2=500.0',
    ]);
    expectBalanced(g);
  });

  test('ledger > expenses because of uncategorized spending: the excess is untracked income, uncategorized kept whole', () async {
    final d = await spend([
      tx(1, -500, DateTime(2024, 2, 2), categoryId: 2),
      tx(2, -9999, DateTime(2024, 2, 3)),
    ]);
    final g = build(d, income: 3100, savings: 1000); // expenses 2100
    expect(g.untrackedIncome, 500 + 9999 - 2100);
    expect(g.untrackedExpenses, 0);
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=3100.0',
      'untrackedIncome=8399.0',
      'total=11499.0',
      'grp:discretionary=500.0',
      'grp:uncategorized=9999.0',
      'saved=1000.0',
      'out:2=500.0',
    ]);
    expectBalanced(g);
  });

  test('savings went down: the drop enters from savings and funds the expenses', () async {
    final d = await spend([tx(1, -1200, DateTime(2024, 1, 2), categoryId: 2)]);
    final g = build(d, income: 1000, savings: -500);
    expect(g.expenses, 1500);
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=1000.0',
      'fromSavings=500.0',
      'total=1500.0',
      'grp:discretionary=1200.0',
      'grp:untracked=300.0',
      'out:2=1200.0',
    ]);
    expectBalanced(g);
  });

  test('categorized spending above the yearly expenses: the excess enters as untracked income, categories kept whole', () async {
    final d = await spend([tx(1, -2000, DateTime(2024, 1, 2), categoryId: 2)]);
    final g = build(d, income: 3000, savings: 1500); // expenses 1500
    expect(g.untrackedIncome, 500);
    expect(g.untrackedExpenses, 0);
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=3000.0',
      'untrackedIncome=500.0',
      'total=3500.0',
      'grp:discretionary=2000.0',
      'saved=1500.0',
      'out:2=2000.0',
    ]);
    expectBalanced(g);
  });

  test('categorized spending above expenses in a year savings went down: untracked income and from savings together', () async {
    final d = await spend([tx(1, -2000, DateTime(2024, 1, 2), categoryId: 2)]);
    final g = build(d, income: 1000, savings: -500); // expenses 1500
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=1000.0',
      'untrackedIncome=500.0',
      'fromSavings=500.0',
      'total=2000.0',
      'grp:discretionary=2000.0',
      'out:2=2000.0',
    ]);
    expectBalanced(g);
  });

  test('savings above income (negative expenses): untracked income covers savings and spending', () async {
    final d = await spend([tx(1, -300, DateTime(2024, 1, 2), categoryId: 2)]);
    final g = build(d, income: 1000, savings: 1800); // expenses −800
    expect(g.expenses, -800);
    expect(g.untrackedIncome, 1100);
    expect(g.nodes.map((n) => n.toString()).toList(), [
      'income=1000.0',
      'untrackedIncome=1100.0',
      'total=2100.0',
      'grp:discretionary=300.0',
      'saved=1800.0',
      'out:2=300.0',
    ]);
    expectBalanced(g);
  });

  test('no income and no savings change is empty; no income gives no savings rate', () async {
    final d = await spend(const []);
    expect(build(d, income: 0, savings: 0).isEmpty, isTrue);
    final g = build(d, income: 0, savings: -300);
    expect(g.savingsRate, isNull);
    expect(g.nodes.map((n) => n.id), ['fromSavings', 'total', 'grp:untracked']);
  });

  test('spending aggregation records exactly the summed transaction ids per bucket', () async {
    final d = await spend([
      tx(1, -10, DateTime(2024, 1, 2), categoryId: 2),
      tx(2, -20, DateTime(2024, 1, 3), categoryId: 2),
      tx(3, 30, DateTime(2024, 1, 4), categoryId: 2), // inflow: not spending
      tx(4, -5, DateTime(2024, 1, 5)),
    ]);
    expect(d.ids(2024, 2), [1, 2]);
    expect(d.ids(2024, null), [4]);
    expect(d.ids(2023, 2), isEmpty);
  });
}
