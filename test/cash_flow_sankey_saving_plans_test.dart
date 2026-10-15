// Spread saving plans in the yearly cash-flow Sankey. A spread outflow (a car
// saved for monthly before it is bought) lowers the yearly savings by every
// scheduled step no bank transaction accounts for: the ledger's synthetic
// "Saving for X" rows. They are spending the app knows about, so the Sankey
// tracks them as a band of their own, one per plan. They used to be left out
// of the ledger spending, which put them in "untracked expenses" or silently
// shrank "untracked income".
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/cash_flow_sankey.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart';
import 'package:finance_copilot/services/classification/spending_by_category.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';

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

/// A synthetic "Saving for [name]" row of event [eventId].
SavingScheduleItem step(int eventId, String name, DateTime date, double amount, {String currency = 'EUR'}) =>
    SavingScheduleItem(eventId: eventId, eventName: name, date: date, amount: amount, currency: currency);

void main() {
  final cats = {1: const Category(id: 1, name: 'Groceries', type: CategoryType.expense, isEssential: true, isArchived: false, sortOrder: 1)};

  Future<SpendingByCategoryData> spend(List<Transaction> txs, List<SavingScheduleItem> plans, {DateTime? through}) =>
      aggregateSpendingByCategory(
        transactions: txs,
        categories: cats,
        rate: (currency, day) async => currency == 'USD' ? 0.9 : null,
        baseCurrency: 'EUR',
        now: DateTime(2025, 6, 15),
        through: through,
        savingItems: plans,
      );

  CashFlowSankey build(SpendingByCategoryData d, {required double income, required double savings}) =>
      buildCashFlowSankey(year: 2024, income: income, savings: savings, spending: d, categories: cats);

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

  List<SavingScheduleItem> monthly(int eventId, String name, int year, double amount) => [
    for (var m = 1; m <= 12; m++) step(eventId, name, DateTime(year, m, 26), amount),
  ];

  group('aggregation', () {
    test('the steps of an outflow spread are summed per year and plan, in base currency, biggest first', () async {
      final d = await spend(const [], [
        step(2, 'T-Roc', DateTime(2024, 1, 26), -496),
        step(2, 'T-Roc', DateTime(2024, 2, 26), -496),
        step(7, 'Holidays', DateTime(2024, 3, 1), -100, currency: 'USD'),
        step(2, 'T-Roc', DateTime(2025, 1, 26), -496),
      ]);
      expect(d.savingPlans(2024), [(eventId: 2, name: 'T-Roc', amount: 992.0), (eventId: 7, name: 'Holidays', amount: 90.0)]);
      expect(d.savingPlansTotal(2024), 1082);
      expect(d.savingPlans(2025), [(eventId: 2, name: 'T-Roc', amount: 496.0)]);
      expect(d.amount(2024, null), 0, reason: 'no transaction: not uncategorized spending');
      expect(d.fxExcluded, 0);
    });

    test('a step with no rate to base is left out and counted, never converted 1:1', () async {
      final d = await spend(const [], [
        step(2, 'T-Roc', DateTime(2024, 1, 26), -496),
        step(8, 'Bike', DateTime(2024, 2, 1), -100, currency: 'CHF'),
      ]);
      expect(d.savingPlans(2024), [(eventId: 2, name: 'T-Roc', amount: 496.0)]);
      expect(d.fxExcluded, 1);
    });

    test('the steps of an inflow spread bring money in: they are not spending', () async {
      final d = await spend(const [], [step(9, 'Bonus', DateTime(2024, 4, 1), 300)]);
      expect(d.savingPlans(2024), isEmpty);
      expect(d.refunds(2024), 0);
    });

    test('steps after the as-of day are left out, those on it count', () async {
      final d = await spend(const [], monthly(2, 'T-Roc', 2024, -100), through: DateTime(2024, 2, 26, 9));
      expect(d.savingPlans(2024), [(eventId: 2, name: 'T-Roc', amount: 200.0)]);
    });
  });

  group('the Sankey', () {
    test('a saving plan is tracked spending: a band of its own, not untracked expenses', () async {
      // Savings 1,800 are already net of the 1,200 set aside for the car, so
      // expenses 8,200 = 7,000 groceries + 1,200 car: nothing is untracked.
      final d = await spend([tx(1, -7000, DateTime(2024, 5, 2), categoryId: 1)], monthly(2, 'T-Roc', 2024, -100));
      final g = build(d, income: 10000, savings: 1800);
      expect(g.savingPlans, 1200);
      expect(g.ledgerSpending, 8200);
      expect(g.untrackedExpenses, 0, reason: 'it used to be 1,200: the plan was not part of the ledger spending');
      expect(g.untrackedIncome, 0);
      expect(g.nodes.map((n) => n.toString()).toList(), [
        'income=10000.0',
        'total=10000.0',
        'grp:essential=7000.0',
        'plan:2=1200.0',
        'saved=1800.0',
        'out:1=7000.0',
      ]);
      final plan = g.nodes.singleWhere((n) => n.id == cashFlowSavingPlanNodeId(2));
      expect(plan.kind, CashFlowNodeKind.savingPlan);
      expect(plan.layer, 2);
      expect(plan.eventName, 'T-Roc');
      expectBalanced(g);
    });

    test('a year whose ledger spends more than its expenses: the plan no longer hides part of the untracked income', () async {
      final d = await spend([tx(1, -9000, DateTime(2024, 5, 2), categoryId: 1)], monthly(2, 'T-Roc', 2024, -100));
      final g = build(d, income: 10000, savings: 1800);
      expect(g.untrackedIncome, 2000, reason: '9,000 + 1,200 − 8,200; it used to show 800');
      expect(g.untrackedExpenses, 0);
      expectBalanced(g);
    });

    test('several plans: one band each, biggest first', () async {
      final d = await spend(const [], [...monthly(7, 'Holidays', 2024, -25), ...monthly(2, 'T-Roc', 2024, -100)]);
      final g = build(d, income: 5000, savings: 3500);
      expect([for (final n in g.nodes.where((n) => n.kind == CashFlowNodeKind.savingPlan)) n.toString()], ['plan:2=1200.0', 'plan:7=300.0']);
      expect(g.untrackedExpenses, 0);
      expectBalanced(g);
    });

    test('a year with nothing else than a saving plan still has a graph', () async {
      final d = await spend(const [], [step(2, 'T-Roc', DateTime(2024, 3, 26), -500)]);
      final g = build(d, income: 0, savings: 0);
      expect(g.isEmpty, isFalse);
      expect(g.nodes.map((n) => n.toString()).toList(), ['untrackedIncome=500.0', 'total=500.0', 'plan:2=500.0']);
      expectBalanced(g);
    });
  });

  test('the ledger rows behind the plans: scheduled steps no transaction accounts for, with their event', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final events = ExtraordinaryEventService(db);
    final id = await events.create(
      name: 'T-Roc',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200,
      currency: 'EUR',
      eventDate: DateTime(2025, 4, 26),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2025, 1, 26),
      spreadEnd: DateTime(2025, 3, 26),
    );
    final inputs = await events.getAdjustmentInputs();
    // The February step was paid by a real transaction: no synthetic row.
    final txs = [tx(1, -400, DateTime(2025, 2, 26))];

    final items = resolveSavingItems(transactions: txs, adjustments: inputs);
    expect(
      [for (final i in items) (i.eventId, i.eventName, i.date, i.amount)],
      [
        (id, 'T-Roc', DateTime(2025, 1, 26), -400.0),
        (id, 'T-Roc', DateTime(2025, 3, 26), -400.0),
      ],
    );

    // Exactly the rows the All-Accounts ledger shows.
    final ledger = resolveAdjustments(
      events: inputs.events,
      entriesByEvent: inputs.entriesByEvent,
      reimbursementsByEvent: inputs.reimbursementsByEvent,
      transactions: txs,
      dayKey: ledgerDayKey,
      adjustedLabel: (n) => n,
      reimbLabel: (n) => n,
      savingForLabel: (n) => n,
      financedLabel: (n) => n,
    );
    expect([for (final i in items) (i.date, i.amount)], [for (final i in ledger.savingItems) (i.date, i.amount)]);
    expect(resolveSavingItems(transactions: txs, adjustments: AdjustmentInputs.empty), isEmpty);
  });
}
