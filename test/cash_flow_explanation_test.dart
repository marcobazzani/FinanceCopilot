// `explainCashFlowCell`: the table that justifies one Cash Flow figure.
//
// The figures themselves are: Income = the income records of the period;
// Savings = how much the Saving total grew over it, minus pension
// contributions; Expenses = Income − Savings. The Saving total is the sum of
// its series (accounts, investments, adjustments), each carried forward from
// its last point and 0 before its first, measured from the first point of the
// total. The explanation splits that same growth into rows that add up to it:
// an account's growth into the transactions that moved its balance (by
// category type, then category), an investment's or adjustment's into its own
// change, and whatever the transactions do not explain into a labelled row.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/cash_flow_explanation.dart';

void main() {
  final first = DateTime(2026, 1, 1);
  var nextId = 1;

  Transaction tx(
    DateTime day,
    double amount,
    double? balance, {
    int account = 1,
    int? category,
    TransactionStatus status = TransactionStatus.settled,
    String currency = 'EUR',
  }) => Transaction(
    id: nextId++,
    accountId: account,
    operationDate: day,
    valueDate: day,
    amount: amount,
    balanceAfter: balance,
    description: '',
    status: status,
    categoryId: category,
    currency: currency,
    tags: '[]',
    createdAt: day,
  );

  Category cat(int id, CategoryType type, {String name = ''}) => Category(
    id: id,
    name: name.isEmpty ? 'c$id' : name,
    type: type,
    isEssential: false,
    isArchived: false,
    sortOrder: id,
  );

  double x(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(first.year, first.month, first.day)).inDays.toDouble();

  ExplainSeries account(int id, String name, List<Transaction> rows) => ExplainSeries(
    kind: ExplainSeriesKind.account,
    id: id,
    name: name,
    currency: 'EUR',
    // One point per day: the last balance of the day, as the dashboard draws it.
    spots: [
      for (final r in rows.where((r) => r.balanceAfter != null)) (x(r.valueDate), r.balanceAfter!),
    ],
  );

  // Account 1: opening 1,000 on 1 Jan, salary 3,000 on 20 Jan; in February
  // groceries −200 and −50, a transfer −100, a refund +40, an uncategorized −10.
  final rows = <Transaction>[];
  late Map<int, Category> categories;
  late ExplainSeries main;
  late ExplainSeries fund;

  setUp(() {
    nextId = 1;
    rows
      ..clear()
      ..addAll([
        tx(DateTime(2026, 1, 1), 1000, 1000),
        tx(DateTime(2026, 1, 20), 3000, 4000, category: 1),
        tx(DateTime(2026, 2, 5), -200, 3800, category: 2),
        tx(DateTime(2026, 2, 10), -50, 3750, category: 2),
        tx(DateTime(2026, 2, 15), -100, 3650, category: 3),
        tx(DateTime(2026, 2, 20), 40, 3690, category: 4),
        tx(DateTime(2026, 2, 25), -10, 3680),
      ]);
    categories = {
      1: cat(1, CategoryType.income, name: 'Salary'),
      2: cat(2, CategoryType.expense, name: 'Groceries'),
      3: cat(3, CategoryType.transfer, name: 'Transfer'),
      4: cat(4, CategoryType.reimbursement, name: 'Refunds'),
    };
    main = account(1, 'Main', rows);
    // A 500 fund bought on 12 Feb: its invested series steps 0 → 500.
    fund = ExplainSeries(kind: ExplainSeriesKind.investment, id: 7, name: 'Fund', spots: [(x(DateTime(2026, 2, 12)), 500)]);
  });

  ExplainRecord rec(int id, DateTime date, double amount) => (id: id, date: date, amount: amount);

  Future<CashFlowExplanation> explain(
    CashFlowField field, {
    int year = 2026,
    int? month = 2,
    List<ExplainSeries>? series,
    List<Transaction>? transactions,
    List<ExplainRecord> income = const [],
    List<ExplainRecord> pension = const [],
    DateTime? from,
    DateTime? to,
  }) => explainCashFlowCell(
    field: field,
    year: year,
    month: month,
    firstDate: first,
    periodFrom: from ?? (month == null ? DateTime(year - 1, 12, 31) : DateTime(year, month, 0)),
    periodTo: to ?? (month == null ? DateTime(year, 12, 31) : DateTime(year, month + 1, 0)),
    baseCurrency: 'EUR',
    series: series ?? [main, fund],
    transactions: transactions ?? rows,
    categories: categories,
    income: income,
    pension: pension,
    rate: (currency, dayKey) async => currency == 'EUR' ? 1.0 : null,
  );

  ExplainSection section(CashFlowExplanation e, ExplainSectionKind k) => e.sections.singleWhere((s) => s.kind == k);

  group('Savings: the growth of the Saving total in the period', () {
    test('the rows add up to it: transactions by category type, the fund as its own row', () async {
      final e = await explain(CashFlowField.savings);
      // (3,680 + 500) − 4,000 = 180
      expect(e.total, closeTo(180, 0.005));

      final tx = section(e, ExplainSectionKind.accountTransactions);
      expect(tx.amount, closeTo(-320, 0.005));
      final byType = {for (final l in tx.lines) l.categoryType ?? 'uncategorized': l};
      expect(byType[CategoryType.expense]!.amount, closeTo(-250, 0.005));
      expect(byType[CategoryType.expense]!.count, 2);
      expect(byType[CategoryType.transfer]!.amount, closeTo(-100, 0.005));
      expect(byType[CategoryType.reimbursement]!.amount, closeTo(40, 0.005));
      expect(byType['uncategorized']!.amount, closeTo(-10, 0.005));
      expect(byType['uncategorized']!.count, 1);
      expect(byType.containsKey(CategoryType.income), isFalse, reason: 'no income transaction in February');

      expect(section(e, ExplainSectionKind.investments).amount, closeTo(500, 0.005));
      expect(e.sections.any((s) => s.kind == ExplainSectionKind.unexplained), isFalse, reason: 'EUR only: nothing is left over');
    });

    test('a type row is the sum of its categories, listed biggest first', () async {
      rows.add(tx(DateTime(2026, 2, 26), -5, 3675, category: 5));
      categories[5] = cat(5, CategoryType.expense, name: 'Coffee');
      main = account(1, 'Main', rows);
      final e = await explain(CashFlowField.savings, series: [main]);
      final expense = section(e, ExplainSectionKind.accountTransactions).lines.singleWhere((l) => l.categoryType == CategoryType.expense);
      expect(expense.amount, closeTo(-255, 0.005));
      expect(expense.children.map((c) => (c.categoryId, c.count)), [(2, 2), (5, 1)]);
      expect(expense.children.fold<double>(0, (s, c) => s + c.amount), closeTo(expense.amount, 0.005));
    });

    test('the first month of tracking is not savings: the balance that was already there is measured from', () async {
      final e = await explain(CashFlowField.savings, month: 1, from: DateTime(2025, 12, 31), to: DateTime(2026, 1, 31), series: [main]);
      // Total starts at 1,000 on 1 Jan: January's growth is the 3,000 salary only.
      expect(e.total, closeTo(3000, 0.005));
      expect(section(e, ExplainSectionKind.accountTransactions).amount, closeTo(3000, 0.005));
    });

    test('a period before anything is tracked has nothing to explain', () async {
      final e = await explain(CashFlowField.savings, year: 2025, month: 11, from: DateTime(2025, 10, 31), to: DateTime(2025, 11, 30));
      expect(e.total, 0);
      expect(e.sections.every((s) => s.lines.isEmpty), isTrue);
    });

    test('pension contributions are taken out of savings, in their own row', () async {
      final e = await explain(CashFlowField.savings, pension: [rec(31, DateTime(2026, 2, 12), 60.0)]);
      expect(section(e, ExplainSectionKind.pensionContributions).amount, closeTo(-60, 0.005));
      expect(e.total, closeTo(120, 0.005));
      final other = await explain(CashFlowField.savings, pension: [rec(32, DateTime(2026, 3, 12), 60.0)]);
      expect(other.total, closeTo(180, 0.005), reason: 'a March contribution is not February\'s');
    });

    test('an account that enters the total mid-period: its transactions, and the balance it already had, apart', () async {
      // Account 2 starts on 8 Feb with a 100 deposit but a statement balance of 600
      // (500 was there before the first row).
      final other = [tx(DateTime(2026, 2, 8), 100, 600, account: 2)];
      final e = await explain(
        CashFlowField.savings,
        series: [main, account(2, 'Savings', other)],
        transactions: [...rows, ...other],
      );
      expect(e.total, closeTo(-320 + 600, 0.005));
      final entering = section(e, ExplainSectionKind.accountOpening);
      expect(entering.lines.single.label, 'Savings');
      expect(entering.amount, closeTo(500, 0.005));
      // The 100 itself is a transaction row.
      final uncategorized = section(e, ExplainSectionKind.accountTransactions).lines.singleWhere((l) => l.categoryType == null);
      expect(uncategorized.amount, closeTo(-10 + 100, 0.005));
    });

    test('an investment and an adjustment are one row each, by name', () async {
      final adj = ExplainSeries(kind: ExplainSeriesKind.adjustment, id: 3, name: 'New roof', spots: [(x(DateTime(2026, 2, 3)), -2000)]);
      final e = await explain(CashFlowField.savings, series: [main, fund, adj]);
      expect(section(e, ExplainSectionKind.adjustments).lines.single.label, 'New roof');
      expect(section(e, ExplainSectionKind.adjustments).amount, closeTo(-2000, 0.005));
      expect(e.total, closeTo(180 - 2000, 0.005));
    });

    test('a row that left the balance unchanged (filtered out) is not in the table', () async {
      rows.add(tx(DateTime(2026, 2, 26), -999, 3680, status: TransactionStatus.cancelled));
      main = account(1, 'Main', rows);
      final e = await explain(CashFlowField.savings, series: [main]);
      expect(e.total, closeTo(-320, 0.005));
      final count = section(e, ExplainSectionKind.accountTransactions).lines.fold<int>(0, (s, l) => s + l.count);
      expect(count, 5);
    });

    test('whatever the transactions do not explain gets its own labelled row, never absorbed', () async {
      // The account is in USD: the balance moves with the exchange rate, and
      // a transaction row can only be converted at its own day's rate.
      final usd = ExplainSeries(
        kind: ExplainSeriesKind.account,
        id: 9,
        name: 'Dollars',
        currency: 'USD',
        spots: [(x(DateTime(2026, 1, 1)), 100), (x(DateTime(2026, 2, 10)), 150)],
      );
      final dollars = [
        tx(DateTime(2026, 1, 1), 100, 100, account: 9, currency: 'USD'),
        tx(DateTime(2026, 2, 10), 50, 150, account: 9, currency: 'USD'),
      ];
      final e = await explainCashFlowCell(
        field: CashFlowField.savings,
        year: 2026,
        month: 2,
        firstDate: first,
        periodFrom: DateTime(2026, 1, 31),
        periodTo: DateTime(2026, 2, 28),
        baseCurrency: 'EUR',
        series: [usd],
        transactions: dollars,
        categories: categories,
        income: const [],
        pension: const [],
        // The series was drawn at 0.8 on 10 Feb; the explanation has no rate that day.
        rate: (currency, dayKey) async => null,
      );
      // 150 USD at the series' own conversion: nothing explained row by row.
      expect(e.sections.where((s) => s.kind == ExplainSectionKind.accountTransactions).every((s) => s.lines.isEmpty), isTrue);
      expect(section(e, ExplainSectionKind.unexplained).amount, closeTo(50, 0.005));
      expect(e.total, closeTo(50, 0.005));
    });
  });

  group('drill-down: every row knows what it is made of', () {
    test('a category row lists exactly its transactions, a type row the union of its categories', () async {
      final e = await explain(CashFlowField.savings);
      final lines = section(e, ExplainSectionKind.accountTransactions).lines;
      final expense = lines.singleWhere((l) => l.categoryType == CategoryType.expense);
      final groceries = rows.where((t) => t.categoryId == 2).map((t) => t.id).toSet();
      expect(expense.children.single.transactionIds.toSet(), groceries);
      expect(expense.transactionIds.toSet(), groceries, reason: 'the type row is its categories together');
      final uncategorized = lines.singleWhere((l) => l.categoryType == null);
      expect(uncategorized.transactionIds, [rows.last.id]);
      // Every listed transaction moved the balance, and none is listed twice.
      final all = [for (final l in lines) ...l.transactionIds];
      expect(all.toSet().length, all.length);
      expect(all.toSet(), rows.where((t) => t.valueDate.month == 2).map((t) => t.id).toSet());
    });

    test('an income row is its record; the pension row lists its records', () async {
      final e = await explain(
        CashFlowField.expenses,
        income: [rec(11, DateTime(2026, 2, 27), 3000.0)],
        pension: [rec(31, DateTime(2026, 2, 12), 40.0), rec(33, DateTime(2026, 2, 13), 20.0), rec(32, DateTime(2026, 3, 12), 60.0)],
      );
      expect(section(e, ExplainSectionKind.incomeRecords).lines.single.recordIds, [11]);
      expect(section(e, ExplainSectionKind.pensionContributions).lines.single.recordIds, [31, 33]);
    });

    test('an investment row names its asset, an account row its account, with the balances it was read from', () async {
      final other = [tx(DateTime(2026, 2, 8), 100, 600, account: 2)];
      final e = await explain(
        CashFlowField.savings,
        series: [main, fund, account(2, 'Savings', other)],
        transactions: [...rows, ...other],
      );
      final inv = section(e, ExplainSectionKind.investments).lines.single;
      expect((inv.seriesKind, inv.seriesId), (ExplainSeriesKind.investment, 7));
      expect((inv.valueFrom, inv.valueTo), (0.0, 500.0));
      final opening = section(e, ExplainSectionKind.accountOpening).lines.single;
      expect((opening.seriesKind, opening.seriesId), (ExplainSeriesKind.account, 2));
      expect(opening.transactionIds, [other.single.id], reason: 'the first row of the account: its balance shows what was already there');
    });
  });

  group('Income: the income records of the period', () {
    test('one row per record, in date order; refunds and pension contributions are not income', () async {
      final e = await explain(
        CashFlowField.income,
        income: [
          rec(11, DateTime(2026, 2, 27), 3000.0),
          rec(12, DateTime(2026, 2, 3), 120.5),
          rec(13, DateTime(2026, 3, 1), 999.0),
        ],
      );
      expect(e.total, closeTo(3120.5, 0.005));
      final lines = section(e, ExplainSectionKind.incomeRecords).lines;
      expect(lines.map((l) => l.date), [DateTime(2026, 2, 3), DateTime(2026, 2, 27)]);
    });

    test('a year takes every month of it', () async {
      final e = await explain(
        CashFlowField.income,
        month: null,
        income: [rec(1, DateTime(2026, 1, 30), 10.0), rec(2, DateTime(2026, 12, 30), 5.0), rec(3, DateTime(2027, 1, 1), 99.0)],
      );
      expect(e.total, closeTo(15, 0.005));
    });

    test('a month without any income record has an empty table, not a made-up row', () async {
      final e = await explain(CashFlowField.income);
      expect(e.total, 0);
      expect(section(e, ExplainSectionKind.incomeRecords).lines, isEmpty);
    });
  });

  group('Expenses = Income − Savings', () {
    test('income first, then every savings row with its sign turned round', () async {
      final e = await explain(CashFlowField.expenses, income: [rec(11, DateTime(2026, 2, 27), 3000.0)]);
      // 3,000 − 180
      expect(e.total, closeTo(2820, 0.005));
      expect(e.sections.first.kind, ExplainSectionKind.incomeRecords);
      expect(e.sections.first.amount, closeTo(3000, 0.005));
      // The fund bought (+500 savings) lowers expenses; the groceries (−250) raise them.
      expect(section(e, ExplainSectionKind.investments).amount, closeTo(-500, 0.005));
      final expense = section(e, ExplainSectionKind.accountTransactions).lines.singleWhere((l) => l.categoryType == CategoryType.expense);
      expect(expense.amount, closeTo(250, 0.005));
    });

    test('September\'s case: a salary in the ledger but no income record reads as negative expenses', () async {
      final salary = tx(DateTime(2026, 2, 26), 8464.19, 12144.19, category: 1);
      final withSalary = [...rows, salary];
      final e = await explain(CashFlowField.expenses, series: [account(1, 'Main', withSalary)], transactions: withSalary);
      // 0 income − (3,680 + 8,464.19 − 4,000) savings
      expect(e.total, closeTo(-(12144.19 - 4000), 0.005));
      expect(section(e, ExplainSectionKind.incomeRecords).lines, isEmpty, reason: 'nothing recorded as income');
      final incomeTx = section(e, ExplainSectionKind.accountTransactions).lines.singleWhere((l) => l.categoryType == CategoryType.income);
      expect(incomeTx.amount, closeTo(-8464.19, 0.005), reason: 'the salary shows, pulling expenses down');
    });

    test('pension contributions raise expenses back: they never reached the bank', () async {
      final e = await explain(
        CashFlowField.expenses,
        income: [rec(11, DateTime(2026, 2, 27), 3000.0)],
        pension: [rec(31, DateTime(2026, 2, 12), 60.0)],
      );
      expect(section(e, ExplainSectionKind.pensionContributions).amount, closeTo(60, 0.005));
      expect(e.total, closeTo(3000 - 120, 0.005));
    });
  });
}
