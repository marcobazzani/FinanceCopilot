// Spending per merchant: the same spending rows the categories sum, grouped
// by merchant key, named as the statement names them; and month sums that
// count a month for part of it, for comparisons with a month in progress.
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction tx(
  int id,
  double amount,
  DateTime date, {
  int? categoryId,
  String? merchantKey,
  String? counterparty,
  BankEntryKind? entryKind = BankEntryKind.cardPayment,
}) => Transaction(
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
  merchantKey: merchantKey,
  counterparty: counterparty,
  entryKind: entryKind,
);

Category cat(int id, CategoryType type) => Category(id: id, name: 'c$id', type: type, isEssential: false, isArchived: false, sortOrder: id);

void main() {
  final cats = {
    1: cat(1, CategoryType.expense), // groceries
    2: cat(2, CategoryType.expense), // cash
    3: cat(3, CategoryType.transfer), // investments
    4: cat(4, CategoryType.expense), // shopping
    5: cat(5, CategoryType.reimbursement),
  };
  Future<double?> noRate(String c, int day) async => null;

  Future<SpendingByCategoryData> aggregate(List<Transaction> txs) => aggregateSpendingByCategory(
    transactions: txs,
    categories: cats,
    rate: noRate,
    baseCurrency: 'EUR',
    now: DateTime(2026, 3, 10),
  );

  group('merchants', () {
    test('the spending rows, by merchant key, named as the statement names them', () async {
      final d = await aggregate([
        tx(1, -40, DateTime(2026, 1, 5), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(2, -60, DateTime(2026, 1, 20), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(3, -25, DateTime(2026, 1, 9), merchantKey: 'AMAZON', counterparty: 'Amazon'),
        tx(4, -15, DateTime(2026, 1, 12), categoryId: 4, merchantKey: 'AMAZON', counterparty: 'Amazon'),
        tx(5, -30, DateTime(2026, 1, 13), categoryId: 4, merchantKey: 'AMAZON', counterparty: 'Amazon'),
      ]);
      final jan = d.period(2026, 1);
      expect(jan.merchants.keys, unorderedEquals(['CONAD', 'AMAZON']));
      final conad = jan.merchants['CONAD']!;
      expect((conad.name, conad.amount, conad.mainCategory), ('Conad', 100.0, 1));
      expect(conad.ids, [1, 2]);
      final amazon = jan.merchants['AMAZON']!;
      expect(amazon.amount, 70);
      expect(amazon.mainCategory, 4, reason: '45 of its 70 are shopping, 25 uncategorized');
      expect(d.period(2026).merchants['CONAD']!.amount, 100, reason: 'the year holds its months');
    });

    test('what is no merchant spending: cash withdrawals, transfers, refunds, rows without a key', () async {
      final d = await aggregate([
        tx(1, -200, DateTime(2026, 2, 1), categoryId: 2, merchantKey: 'PRELEVAMENTOCARTA', entryKind: BankEntryKind.atmWithdrawal),
        tx(2, -5000, DateTime(2026, 2, 2), categoryId: 3, merchantKey: 'BROKER'),
        tx(3, 30, DateTime(2026, 2, 3), categoryId: 5, merchantKey: 'CONAD'),
        tx(4, -12, DateTime(2026, 2, 4), categoryId: 1),
        tx(5, -8, DateTime(2026, 2, 5), categoryId: 1, merchantKey: 'BAR'),
      ]);
      final feb = d.period(2026, 2);
      expect(feb.merchants.keys, ['BAR']);
      expect(feb.amount(2), 200, reason: 'the withdrawal stays spending in its category');
      expect(feb.amount(1), 20, reason: 'a row without a key still counts in its category');
    });

    test('a merchant without a name in the statement is named by its key until a row names it', () async {
      final d = await aggregate([
        tx(1, -10, DateTime(2026, 1, 5), categoryId: 1, merchantKey: 'ESSO'),
        tx(2, -10, DateTime(2026, 1, 6), categoryId: 1, merchantKey: 'ESSO', counterparty: 'Esso'),
      ]);
      expect(d.period(2026, 1).merchants['ESSO']!.name, 'Esso');
    });

    test('the merchants paid most, biggest first', () async {
      final d = await aggregate([
        for (var i = 1; i <= 12; i++) tx(i, -i * 10.0, DateTime(2026, 1, i), categoryId: 1, merchantKey: 'M$i', counterparty: 'Merchant $i'),
      ]);
      final top = d.period(2026, 1).topMerchants(3);
      expect([for (final m in top) m.key], ['M12', 'M11', 'M10']);
    });
  });

  group('months summed, some of them for part of it', () {
    late SpendingByCategoryData d;
    setUp(() async {
      d = await aggregate([
        tx(1, -300, DateTime(2025, 2, 10), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(2, -310, DateTime(2025, 3, 10), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(3, -62, DateTime(2025, 3, 20), categoryId: 4, merchantKey: 'AMAZON', counterparty: 'Amazon'),
      ]);
    });

    test('whole months add up', () {
      final p = d.sumOfMonths([(2025, 2), (2025, 3)]);
      expect(p.amount(1), 610);
      expect(p.merchants['CONAD']!.amount, 610);
      expect(p.merchants['CONAD']!.ids, [1, 2]);
    });

    test('a month in shares counts for that share of it: categories and merchants alike', () {
      final p = d.sumOfMonths([(2025, 2), (2025, 3)], shares: {(2025, 3): 10 / 31});
      expect(p.amount(1), closeTo(300 + 310 * 10 / 31, 1e-9));
      expect(p.amount(4), closeTo(62 * 10 / 31, 1e-9));
      expect(p.merchants['CONAD']!.amount, closeTo(400, 1e-9));
      expect(p.merchants['AMAZON']!.amount, closeTo(20, 1e-9));
      expect(p.merchants['CONAD']!.ids, [1, 2], reason: 'the rows behind it are all still listed');
    });
  });

  group('day by day', () {
    late SpendingByCategoryData d;
    setUp(() async {
      d = await aggregate([
        tx(1, -40, DateTime(2026, 2, 3), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(2, -10, DateTime(2026, 2, 3), categoryId: 4, merchantKey: 'AMAZON', counterparty: 'Amazon'),
        tx(3, -5000, DateTime(2026, 2, 4), categoryId: 3, merchantKey: 'BROKER'),
        tx(4, -30, DateTime(2026, 3, 1), categoryId: 1, merchantKey: 'CONAD', counterparty: 'Conad'),
        tx(5, -200, DateTime(2026, 3, 2), categoryId: 2, merchantKey: 'PRELEVAMENTOCARTA', entryKind: BankEntryKind.atmWithdrawal),
      ]);
    });

    test('every spending row on its day, transfers left out', () {
      expect(
        [for (final e in d.entries) (e.day, e.amount)],
        [
          (DateTime(2026, 2, 3), 40.0),
          (DateTime(2026, 2, 3), 10.0),
          (DateTime(2026, 3, 1), 30.0),
          (DateTime(2026, 3, 2), 200.0),
        ],
      );
    });

    test('any run of days adds up as a month does', () {
      expect(d.spentBetween(DateTime(2026, 2, 1), DateTime(2026, 2, 28)), d.period(2026, 2).total);
      expect(d.spentBetween(DateTime(2026, 2, 4), DateTime(2026, 3, 1)), 30);
      final p = d.sumOfDays(DateTime(2026, 2, 1), DateTime(2026, 3, 2));
      expect(p.amount(1), 70);
      expect(p.merchants['CONAD']!.ids, [1, 4]);
      expect(p.merchants.keys, isNot(contains('PRELEVAMENTOCARTA')), reason: 'cash withdrawals are no merchant');
      expect(p.amount(2), 200, reason: 'they still count in their category');
    });

    test('a running total, one figure a day, across months', () {
      final run = d.runningBetween(DateTime(2026, 2, 1), DateTime(2026, 3, 31));
      expect(run.length, 28 + 31);
      expect(run[1], 0, reason: '2 February: nothing yet');
      expect(run[2], 50, reason: '3 February');
      expect(run[28], 80, reason: '1 March');
      expect(run.last, 280);
    });
  });
}
