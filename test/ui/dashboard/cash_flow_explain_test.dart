// Tapping a Cash Flow figure opens the table that justifies it: the rows add
// up to exactly the number in the cell, whichever cell it is, and in privacy
// mode the amounts are blurred while the labels and counts stay readable.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/classification/category_service.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// A 4,000 salary in March 2026 on top of the harness portfolio, with no
  /// income record for it: the savings grow, the income stays empty, and the
  /// month's expenses come out at −4,000 (the September 2026 case).
  Future<void> salaryWithoutIncomeRecord() async {
    await h.seed();
    final acct = (await h.db.select(h.db.accounts).get()).single.id;
    final salary = (await CategoryService(h.db).getByKey('salary'))!.id;
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2026, 3, 5),
            valueDate: DateTime(2026, 3, 5),
            amount: 4000,
            balanceAfter: const Value(19000),
            categoryId: Value(salary),
            description: const Value('Stipendio'),
          ),
        );
  }

  Future<void> expand(WidgetTester tester, String title) async {
    final tile = find.text(title);
    await tester.ensureVisible(tile);
    await h.settle(tester);
    await tester.tap(tile);
    await h.settle(tester);
  }

  Finder section(String title) => find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile)).first;

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// The amount in the dialog's last row, the one the rows add up to.
  String dialogTotal(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: find.byKey(const Key('cashFlowExplainTotal')), matching: find.byType(Text)).last).data!;

  Future<void> closeDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await h.settle(tester);
  }

  Future<void> tapAndWait(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester);
    await tester.tap(f, warnIfMissed: false);
    await h.settle(tester);
  }

  testWidgets('a month with a salary but no income record: the table shows the salary and says no income was recorded', (tester) async {
    await salaryWithoutIncomeRecord();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      await expand(tester, 'Monthly Expenses by Year (table)');
      final grid = section('Monthly Expenses by Year (table)');
      await tapAndWait(tester, find.descendant(of: grid, matching: find.text('-4,000.00 €')).first);

      expect(find.byType(AlertDialog), findsOneWidget);
      final text = h.dialogText(tester);
      expect(text, contains('Mar 2026 · Expenses'));
      expect(text, contains('Expenses = Income − Savings'));
      expect(text, contains('No income records in this period.'));
      expect(text, contains('Transactions on your accounts'));
      expect(text, contains('Income'), reason: 'the salary transaction, grouped by its category type');
      expect(text, contains('Salary'), reason: 'and by its category');
      expect(dialogTotal(tester), '-4,000.00 €', reason: 'the number in the cell');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('every monthly income and expenses cell: the rows add up to the number in the cell', (tester) async {
    await salaryWithoutIncomeRecord();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      for (final title in ['Monthly Income by Year (table)', 'Monthly Expenses by Year (table)']) {
        await expand(tester, title);
        final cells = find.descendant(of: section(title), matching: find.byType(Tooltip));
        final n = cells.evaluate().length;
        expect(n, greaterThan(12), reason: '$title: month cells and the year totals are tappable');
        for (var i = 0; i < n; i++) {
          final cell = cells.at(i);
          final shown = tester.widget<Text>(find.descendant(of: cell, matching: find.byType(Text)).first).data!;
          await tapAndWait(tester, cell);
          expect(find.byType(AlertDialog), findsOneWidget, reason: '$title cell $i opens its table');
          expect(dialogTotal(tester), shown, reason: '$title cell $i: the rows add up to the cell');
          await closeDialog(tester);
        }
      }
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the year totals and the yearly summary: Income lists the records, Savings the growth of the total', (tester) async {
    await salaryWithoutIncomeRecord();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');

      // 2026 income: the January and February records.
      await expand(tester, 'Monthly Income by Year (table)');
      await tapAndWait(tester, find.descendant(of: section('Monthly Income by Year (table)'), matching: find.text('6,000.00 €')).first);
      var text = h.dialogText(tester);
      expect(text, contains('2026 · Income'));
      expect(text, contains('1/15/2026'));
      expect(text, contains('2/15/2026'));
      expect(dialogTotal(tester), '6,000.00 €');
      await closeDialog(tester);

      // 2026 savings: the salary on the account.
      await expand(tester, 'Yearly Summary');
      await tapAndWait(tester, find.descendant(of: section('Yearly Summary'), matching: find.text('+4,000.00 €')).first);
      text = h.dialogText(tester);
      expect(text, contains('2026 · Savings'));
      expect(text, contains('Savings = how much the Saving total grew over the period − pension contributions'));
      expect(dialogTotal(tester), '4,000.00 €');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('privacy mode: the amounts are blurred, the labels and the transaction counts are not', (tester) async {
    await salaryWithoutIncomeRecord();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openTab(tester, 'Cash Flow');
      await expand(tester, 'Monthly Expenses by Year (table)');
      final grid = section('Monthly Expenses by Year (table)');
      // The grid itself is blurred, so find the March 2026 cell by position:
      // the only month cell whose table says -4,000.00 is the one that opens
      // this dialog, so open the cells in turn until it does.
      final cells = find.descendant(of: grid, matching: find.byType(Tooltip));
      var opened = false;
      for (var i = 0; i < cells.evaluate().length && !opened; i++) {
        await tapAndWait(tester, cells.at(i));
        if (dialogTotal(tester) == '-4,000.00 €' && h.dialogText(tester).contains('Mar 2026')) {
          opened = true;
          break;
        }
        await closeDialog(tester);
      }
      expect(opened, isTrue);

      final total = find.descendant(of: find.byKey(const Key('cashFlowExplainTotal')), matching: find.text('-4,000.00 €'));
      expect(masked(total), isTrue, reason: 'an amount is position size');
      expect(masked(find.text('Transactions on your accounts')), isFalse, reason: 'a label is no figure');
      expect(masked(find.text('1 transaction')), isFalse, reason: 'a count is shape, not magnitude');
      expect(masked(find.text('Total')), isFalse);
    } finally {
      await h.unmount(tester);
    }
  });

  group('drill-down: every row opens what it is made of', () {
    Future<void> openMarchExpenses(WidgetTester tester) async {
      await h.openTab(tester, 'Cash Flow');
      await expand(tester, 'Monthly Expenses by Year (table)');
      await tapAndWait(tester, find.descendant(of: section('Monthly Expenses by Year (table)'), matching: find.text('-4,000.00 €')).first);
    }

    testWidgets('a category row lists exactly its transactions, in the shared sheet', (tester) async {
      await salaryWithoutIncomeRecord();
      await h.pump(tester);
      try {
        await openMarchExpenses(tester);
        final salary = (await CategoryService(h.db).getByKey('salary'))!.id;
        await tapAndWait(tester, find.byKey(ValueKey('cfLine:category:income:$salary:null:')));

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.textContaining('Salary · Mar 2026 (1)'), findsOneWidget);
        final stipendio = (await h.db.select(h.db.transactions).get()).singleWhere((t) => t.description == 'Stipendio').id;
        expect(find.byKey(ValueKey('sankeyTx:$stipendio')), findsOneWidget);
        expect(find.text('Stipendio'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a type row lists the transactions of all its categories', (tester) async {
      await salaryWithoutIncomeRecord();
      await h.pump(tester);
      try {
        await openMarchExpenses(tester);
        await tapAndWait(tester, find.byKey(const ValueKey('cfLine:typeGroup:income:null:null:')));
        expect(find.textContaining('Income · Mar 2026 (1)'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('an income record row shows the record; amounts masked, dates readable', (tester) async {
      await h.seed();
      await h.pump(tester, isPrivate: true);
      try {
        await h.openTab(tester, 'Cash Flow');
        await expand(tester, 'Monthly Income by Year (table)');
        final cells = find.descendant(of: section('Monthly Income by Year (table)'), matching: find.byType(Tooltip));
        // January 2026 is the first month row of the 2026 column.
        var opened = false;
        for (var i = 0; i < cells.evaluate().length && !opened; i++) {
          await tapAndWait(tester, cells.at(i));
          opened = h.dialogText(tester).contains('Jan 2026 · Income');
          if (!opened) await closeDialog(tester);
        }
        expect(opened, isTrue);
        final record = (await h.db.select(h.db.incomes).get()).singleWhere((r) => r.valueDate == DateTime(2026, 1, 15));
        await tapAndWait(tester, find.byKey(ValueKey('cfLine:record:null:null:null:${record.id}')));

        final row = find.byKey(ValueKey('cfRecord:${record.id}'));
        expect(row, findsOneWidget);
        expect(
          masked(find.descendant(of: row, matching: find.text('3,000.00 €'))),
          isTrue,
          reason: 'an amount is position size',
        );
        expect(
          masked(find.descendant(of: row, matching: find.text('1/15/2026'))),
          isFalse,
          reason: 'a date is not',
        );
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('an investment row shows its value at both ends and its events in the period', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await expand(tester, 'Yearly Summary');
        // 2024: the fund bought on 2 Dec is the year's savings (+1,000).
        await tapAndWait(tester, find.descendant(of: section('Yearly Summary'), matching: find.text('+1,000.00 €')).first);
        expect(h.dialogText(tester), contains('2024 · Savings'));
        final fund = (await h.db.select(h.db.assets).get()).single.id;
        final fundRow = find.byKey(ValueKey('cfLine:series:null:null:$fund:'));
        expect(
          find.descendant(of: fundRow, matching: find.textContaining('transaction')),
          findsNothing,
          reason: 'a series is no count of transactions',
        );
        await tapAndWait(tester, fundRow);

        // The drill-down opens over the table: read the top dialog.
        final top = find.byType(AlertDialog).last;
        final text = [for (final w in tester.widgetList<Text>(find.descendant(of: top, matching: find.byType(Text)))) w.data ?? ''].join('\n');
        expect(text, contains('Fund inv. · 2024'));
        expect(text, contains('Start of the period'));
        expect(text, contains('End of the period'));
        expect(text, contains('Events in the period'));
        final buy = (await h.db.select(h.db.assetEvents).get()).single;
        expect(find.byKey(ValueKey('cfEvent:${buy.id}')), findsOneWidget);
        expect(text, contains('12/2/2024 · Buy'));
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('Italian: the table speaks Italian', (tester) async {
    await salaryWithoutIncomeRecord();
    await h.pump(tester, language: 'it', locale: 'it_IT');
    try {
      await h.openTab(tester, 'Flussi di cassa');
      await expand(tester, 'Uscite Mensili per Anno (tabella)');
      final grid = section('Uscite Mensili per Anno (tabella)');
      await tapAndWait(tester, find.descendant(of: grid, matching: find.text('-4.000,00 €')).first);
      final text = h.dialogText(tester);
      expect(text, contains('Uscite = Entrate − Risparmi'));
      expect(text, contains('Nessun reddito registrato in questo periodo.'));
      expect(text, contains('Movimenti sui conti'));
      expect(dialogTotal(tester), '-4.000,00 €');
    } finally {
      await h.unmount(tester);
    }
  });
}
