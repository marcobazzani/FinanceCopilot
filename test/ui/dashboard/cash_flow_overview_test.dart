// Cash Flow overview: Expenses, Income and Savings cards — the same figures as
// Year by year and the Sankey — each opening its screen; the span selector
// (1W 1M 6M 1Y, ⋯ for a custom period); paging back a period with the strip or
// a swipe; each figure set against the same days of the period it is
// compared with.
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();
  const s = AppStrings.en;
  final money = fmt.currencyFormat('en_US', '€', decimalDigits: 0);

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  late int groceries;
  late int fuel;

  // Today is Tuesday 10 March 2026. The harness's salary, 3,000 on the 15th of
  // every month of 2025 and of January–February 2026, lands in the account the
  // same day. Conad: 200, 200 and 310 on 10 January, 10 February and 20 March
  // 2025; 220, 220 and 120 on 10 January, 10 February and 5 March 2026; 100 of
  // fuel on 15 February 2026. On 20 January 2026, 40 back for a parcel
  // returned; on the 25th, a gift of 100 that no income record shows.
  //
  // 2026 to 10 March, as Year by year counts it: 6,000 of income, 5,480 saved
  // (the account grew by 6,000 − 660 + 40 + 100), so 520 of expenses — 660 of
  // spending, less 40 of refunds, less the 100 no income record shows.
  Future<void> seed() async {
    await h.seed();
    Future<int> categoryId(String key) async => (await (h.db.select(h.db.categories)..where((c) => c.key.equals(key))).getSingle()).id;
    groceries = await categoryId('groceries');
    fuel = await categoryId('carFuelTolls');
    final salary = await categoryId('salary');
    final refunds = await categoryId('refunds');
    final otherIncome = await categoryId('otherIncome');
    final account = (await h.db.select(h.db.accounts).get()).single.id;
    final rows = [
      for (final (year, months) in [(2025, 12), (2026, 2)])
        for (var m = 1; m <= months; m++) (DateTime(year, m, 15), 3000.0, salary, 'SALARY', 'Employer', BankEntryKind.transfer),
      (DateTime(2025, 1, 10), -200.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
      (DateTime(2025, 2, 10), -200.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
      (DateTime(2025, 3, 20), -310.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
      (DateTime(2026, 1, 10), -220.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
      (DateTime(2026, 1, 20), 40.0, refunds, 'AMAZON', 'Amazon', BankEntryKind.cardPayment),
      (DateTime(2026, 1, 25), 100.0, otherIncome, 'GIFT', 'Gift', BankEntryKind.transfer),
      (DateTime(2026, 2, 10), -220.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
      (DateTime(2026, 2, 15), -100.0, fuel, 'DISTRIBUTOREIP', 'Distributore Ip', BankEntryKind.cardPayment),
      (DateTime(2026, 3, 5), -120.0, groceries, 'CONAD', 'Conad', BankEntryKind.cardPayment),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var balance = 15000.0;
    for (final (date, amount, category, key, name, kind) in rows) {
      balance += amount;
      await h.db
          .into(h.db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: account,
              operationDate: date,
              valueDate: date,
              amount: amount,
              balanceAfter: Value(balance),
              description: Value('$key ${fmt.formatYmd(date)}'),
              categoryId: Value(category),
              merchantKey: Value(key),
              counterparty: Value(name),
              entryKind: Value(kind),
            ),
          );
    }
  }

  // Scrolling to a target on the dashboard would slide its tabs sideways too:
  // only a pushed screen's list is scrolled to it ([scroll]).
  Future<void> tap(WidgetTester tester, Finder f, {bool scroll = false}) async {
    if (scroll) {
      await tester.ensureVisible(f);
      await h.settle(tester);
    }
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> span(WidgetTester tester, String name) => tap(tester, find.byKey(Key('cfSpan:$name')));

  Future<void> compareWith(WidgetTester tester, String option) async {
    await tap(tester, find.byKey(const Key('cfCompare')).first);
    await tester.tap(find.text(option).last);
    await h.settle(tester);
  }

  Finder inKey(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  String period(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('cfOverviewPeriod'))).data!;
  double amountIn(String text) => double.parse(text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  String textIn(WidgetTester tester, String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .firstWhere((t) => t.contains('€'));

  String screenTitle(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('cfStatTitle'))).textSpan!.toPlainText();

  // The running total on the Expenses card: the chart and its period's line.
  LineChart spentChart(WidgetTester tester) =>
      tester.widget<LineChart>(find.descendant(of: find.byKey(const Key('cfExpensesCard')), matching: find.byType(LineChart)));

  group('the overview', () {
    testWidgets('it opens on this month, each figure against the same days of last month', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        expect(period(tester), 'Mar 2026');
        // 1–10 March: 120 at Conad; 1–10 February: 220. Expenses are down 100.
        expect(inKey('cfExpensesCard', money.format(120)), findsOneWidget);
        expect(inKey('cfExpensesCard', '▼ ${money.format(100)}'), findsOneWidget);
        // No income yet this month, none by the same day last month: nothing to compare.
        expect(inKey('cfIncomeCard', money.format(0)), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('cfIncomeCard')), matching: find.textContaining('▲')), findsNothing);
        // No salary yet, 120 out of the account.
        expect(inKey('cfSavingsCard', money.format(-120)), findsOneWidget);
        expect(inKey('cfSavingsCard', s.cfInNegative), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('cfComparedWith'))).data,
          [s.cfComparedWith('Feb 2026'), s.cfSoFarAgainst('Mar 2026', 10, 31, 'Feb 1 – Feb 10 2026'), s.cfNoIncomeToCompare].join('\n'),
        );
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the running total spans the whole month, today\'s part only drawn, green below last month', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        final data = spentChart(tester).data;
        expect((data.minX, data.maxX), (1.0, 31.0), reason: 'the x axis is the month, not the days gone by');
        final line = data.lineBarsData.last;
        expect(line.spots.length, 10, reason: '1 to 10 March');
        expect(line.color, Colors.green.shade500, reason: 'less spent by the 10th than by the 10th of February');
        expect(data.lineBarsData.first.spots.length, 28, reason: 'February, whole, in grey');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('red when spending runs above the same days of the other period', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        await compareWith(tester, s.cfCompareYearEarlier);
        // 2026 to 10 March: 520 of expenses; 2025 to 10 March: 400 (200 and 200 at Conad).
        expect(inKey('cfExpensesCard', money.format(520)), findsOneWidget);
        expect(inKey('cfExpensesCard', '▲ ${money.format(120)}'), findsOneWidget);
        final data = spentChart(tester).data;
        expect(data.maxX, 365.0);
        expect(data.lineBarsData.last.color, isNot(Colors.green.shade500));
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a 31-day month against a shorter one: the line takes the colour of the change shown', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        // Back to March 2025 (31 days) against February 2025 (28): 310 against 200.
        await tap(tester, find.byKey(const Key('cfStripOlder')));
        await tap(tester, find.byKey(const Key('cfStripOlder')));
        await tap(tester, find.byKey(const Key('cfStrip:3')));
        expect(period(tester), 'Mar 2025');
        expect(inKey('cfExpensesCard', '▲ ${money.format(110)}'), findsOneWidget);
        final error = Theme.of(tester.element(find.byKey(const Key('cfExpensesCard')))).colorScheme.error;
        final line = spentChart(tester).data.lineBarsData.last;
        expect(line.spots.length, 31, reason: 'every day of March');
        expect(line.color, error, reason: 'more spent than in February: red, as the change');
        // April 2025 (30 days) against March (31): nothing against 310.
        await tester.fling(find.byKey(const Key('cfExpensesCard')), const Offset(-500, 0), 1500);
        await h.settle(tester);
        expect(period(tester), 'Apr 2025');
        expect(spentChart(tester).data.lineBarsData.last.color, Colors.green.shade500);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the strip names five months and stays put; a name goes to its month, a swipe back a month', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        // The history opens in December 2024: 16 months, the last five on the strip.
        String strip() => [
          for (var i = 11; i <= 15; i++)
            tester.widget<Text>(find.descendant(of: find.byKey(Key('cfStrip:$i')), matching: find.byType(Text))).data,
        ].join(' ');
        expect(strip(), 'Nov Dec Jan Feb Mar');
        await tap(tester, find.byKey(const Key('cfStrip:14')));
        expect(period(tester), 'Feb 2026');
        expect(inKey('cfExpensesCard', money.format(320)), findsOneWidget, reason: '220 at Conad and 100 of fuel');
        expect(strip(), 'Nov Dec Jan Feb Mar', reason: 'the five do not slide under the finger');
        await tester.fling(find.byKey(const Key('cfExpensesCard')), const Offset(500, 0), 1500);
        await h.settle(tester);
        expect(period(tester), 'Jan 2026');
        expect(tester.widget<IconButton>(find.byKey(const Key('cfStripNewer'))).onPressed, isNull, reason: 'nothing after March');
        await tap(tester, find.byKey(const Key('cfStripOlder')));
        expect(period(tester), 'Oct 2025', reason: 'the five before end in October');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the Income card names its bars, and its screen opens on the same bars', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        for (final month in ['Nov', 'Dec', 'Jan', 'Feb', 'Mar']) {
          expect(inKey('cfIncomeCard', month), findsOneWidget);
        }
        await tap(tester, find.byKey(const Key('cfIncomeCard')));
        final chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.barGroups.length, 5, reason: 'November to March, as on the card');
        expect(chart.data.barGroups[3].barRods.single.toY, 3000, reason: 'February: one salary');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('privacy mode masks the amounts, change amounts included, never the In the black / red', (tester) async {
      await seed();
      await h.pump(tester, isPrivate: true);
      try {
        await h.openTab(tester, 'Cash Flow');
        expect(masked(inKey('cfExpensesCard', money.format(120))), isTrue);
        expect(masked(inKey('cfExpensesCard', '▼ ${money.format(100)}')), isTrue, reason: 'a change in money is position size');
        expect(masked(inKey('cfSavingsCard', money.format(-120))), isTrue);
        expect(masked(inKey('cfSavingsCard', s.cfInNegative)), isFalse);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('one set of figures', () {
    testWidgets('the cards are Year by year\'s Income, Expenses and Savings, and Savings is the Sankey\'s Saved', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        expect(inKey('cfIncomeCard', money.format(6000)), findsOneWidget);
        expect(inKey('cfExpensesCard', money.format(520)), findsOneWidget);
        expect(inKey('cfSavingsCard', money.format(5480)), findsOneWidget);
        expect(inKey('sankeyNode:saved', s.sankeySaved), findsOneWidget);
        final sankeySaved = amountIn(textIn(tester, 'sankeyNode:saved'));
        await tap(tester, find.text(s.cfViewTable).first);
        final cells = tester
            .widgetList<Text>(find.descendant(of: find.byType(DataTable), matching: find.byType(Text)))
            .map((t) => t.data ?? '')
            .toList();
        final row = cells.sublist(cells.indexOf('2026*'));
        final (income, expenses, savings) = (amountIn(row[1]), amountIn(row[2]), amountIn(row[3]));
        expect(amountIn(textIn(tester, 'cfIncomeTotal')), closeTo(income, 0.5));
        expect(amountIn(textIn(tester, 'cfExpensesTotal')), closeTo(expenses, 0.5));
        expect(amountIn(textIn(tester, 'cfSavingsTotal')), closeTo(savings, 0.5));
        expect(sankeySaved, closeTo(savings, 0.5));
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the Expenses list adds up to its headline: the categories, less the refunds, and what no transaction shows', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        expect(inKey('cfStatTotal', money.format(520)), findsOneWidget);
        // 560 at Conad and 100 of fuel; 40 back; 100 no income record shows.
        expect(inKey('cfSpendingCategory:$groceries', money.format(560)), findsOneWidget);
        expect(inKey('cfSpendingCategory:$fuel', money.format(100)), findsOneWidget);
        // Under the rows, always shown: their sum, then what closes the gap to the Expenses.
        expect(inKey('cfExpensesCategories', s.cfAllCategories), findsOneWidget);
        expect(inKey('cfExpensesCategories', money.format(660)), findsOneWidget);
        expect(inKey('cfExpensesCategories', s.cfTransactions(4)), findsOneWidget);
        expect(inKey('cfExpensesRefunds', s.sankeyRefunds), findsOneWidget);
        expect(inKey('cfExpensesRefunds', money.format(-40)), findsOneWidget);
        expect(inKey('cfExpensesUntracked', s.sankeyUntrackedIncome), findsOneWidget);
        expect(inKey('cfExpensesUntracked', money.format(-100)), findsOneWidget);
        expect(inKey('cfExpensesTotalRow', money.format(520)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('the span selector', () {
    testWidgets('1W 6M 1Y go to this week, this half year, this year; the selected one is highlighted', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'week');
        expect(period(tester), 'Mar 9 – Mar 15 2026');
        await span(tester, 'half');
        expect(period(tester), 'Jan–Jun 2026');
        await span(tester, 'year');
        expect(period(tester), '2026 YTD');
        await span(tester, 'month');
        expect(period(tester), 'Mar 2026');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('⋯ opens a custom period', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfSpanCustom')));
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a custom period typed in: the overview shows those days', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfSpanCustom')));
        await tap(tester, find.byIcon(Icons.edit_outlined));
        await tester.enterText(find.byType(TextField).at(0), '02/01/2026');
        await tester.enterText(find.byType(TextField).at(1), '02/10/2026');
        await tap(tester, find.text('OK'));
        expect(period(tester), 'Feb 1 – Feb 10 2026');
        // 220 at Conad on 10 February.
        expect(inKey('cfExpensesCard', money.format(220)), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a week is too short for the Sankey: it says so', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'week');
        expect(find.byKey(const Key('cfSankeyNeedsMonths')), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('the Expenses list', () {
    Future<void> spend(Map<String, double> byCategory, DateTime day) async {
      final account = (await h.db.select(h.db.accounts).get()).single.id;
      for (final MapEntry(:key, :value) in byCategory.entries) {
        final category = (await (h.db.select(h.db.categories)..where((c) => c.key.equals(key))).getSingle()).id;
        await h.db
            .into(h.db.transactions)
            .insert(
              TransactionsCompanion.insert(
                accountId: account,
                operationDate: day,
                valueDate: day,
                amount: -value,
                description: Value('$key ${fmt.formatYmd(day)}'),
                categoryId: Value(category),
              ),
            );
      }
    }

    testWidgets('five rows, then Show all the rest and Show less back', (tester) async {
      await seed();
      await spend({'restaurantsBars': 50, 'utilities': 40, 'health': 30, 'shopping': 20, 'transport': 10}, DateTime(2026, 3, 6));
      final transport = (await (h.db.select(h.db.categories)..where((c) => c.key.equals('transport'))).getSingle()).id;
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        // Six categories in March: the smallest waits behind Show all.
        expect(find.byKey(Key('cfSpendingCategory:$transport')), findsNothing);
        await tap(tester, find.byKey(const Key('cfRowsShowAll')), scroll: true);
        expect(find.byKey(Key('cfSpendingCategory:$transport')), findsOneWidget);
        expect(find.text(s.showLessRows), findsOneWidget);
        await tap(tester, find.byKey(const Key('cfRowsShowAll')), scroll: true);
        expect(find.byKey(Key('cfSpendingCategory:$transport')), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a spread saving plan is a row of its own, beside the categories', (tester) async {
      await seed();
      // 6 × 200 set aside from July to December 2025 for a car bought in January.
      final car = await ExtraordinaryEventService(h.db).create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 26),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2025, 7, 26),
        spreadEnd: DateTime(2025, 12, 26),
      );
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await h.pickYear(tester, 2025);
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        final row = find.byKey(Key('cfSpendingPlan:$car'));
        expect(row, findsOneWidget);
        expect(find.descendant(of: row, matching: find.text(s.savingForLabel('Car'))), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text(money.format(1200))), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Manage opens Categories & rules', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        await tap(tester, find.byKey(const Key('cfSpendingManage')), scroll: true);
        expect(find.byType(CategoriesRulesScreen), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a month with nothing spent and no expenses: the shared empty state', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        // April 2025: the salary in, nothing out.
        await h.pickMonthAt(tester, 4);
        expect(period(tester), 'Apr 2025');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        expect(find.byKey(const Key('cfSpendingEmpty')), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('every card opens its screen', () {
    testWidgets('Expenses: by category and by merchant, each row opening its transactions', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        expect(screenTitle(tester), '${s.legendExpenses} · 2026 YTD');
        expect(inKey('cfStatTotal', money.format(520)), findsOneWidget);
        // 560 of 660 at Conad, 3 transactions.
        expect(inKey('cfSpendingCategory:$groceries', s.cfTransactions(3)), findsOneWidget);
        expect(inKey('cfSpendingCategory:$groceries', '85%'), findsOneWidget);
        expect(inKey('cfSpendingCategory:$fuel', '15%'), findsOneWidget);
        // The note under the list says what Spent counts, on a screen with nothing below it.
        final note = find.descendant(of: find.byKey(const Key('cfSpendingNote')), matching: find.byType(Text));
        expect(tester.widget<Text>(note).data, s.cfExpensesNote(s.legendExpenses, s.cfYearByYear, s.spendingByCategoryTitle));
        expect(tester.widget<Text>(note).data, isNot(anyOf(contains('below'), contains('summary'))));

        await tap(tester, find.byKey(const Key('cfSpentBy')), scroll: true);
        await tester.tap(find.text(s.cfByMerchant).last);
        await h.settle(tester);
        expect(inKey('cfSpendingMerchant:CONAD', 'Conad'), findsOneWidget);
        await tap(tester, find.byKey(const Key('cfSpendingMerchant:CONAD')), scroll: true);
        for (final day in ['2026-01-10', '2026-02-10', '2026-03-05']) {
          expect(find.text('CONAD $day'), findsOneWidget);
        }
        expect(find.text('CONAD 2025-03-20'), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Expenses: running total, bars and ring', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        expect(find.byType(LineChart), findsOneWidget, reason: 'as on its card');
        await tap(tester, find.byKey(const Key('cfChartMode:bars')), scroll: true);
        expect(
          tester.widget<BarChart>(find.byType(BarChart)).data.barGroups.length,
          5,
          reason: 'March and the four months before it, as the card',
        );
        await tap(tester, find.byKey(const Key('cfChartMode:ring')), scroll: true);
        expect(find.byType(PieChart), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('on a screen, a point or a bar tells its amount, in short', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await tap(tester, find.byKey(const Key('cfExpensesCard')));
        final line = tester.widget<LineChart>(find.byType(LineChart)).data;
        final today = line.lineBarsData.last;
        final point = line.lineTouchData.touchTooltipData.getTooltipItems([LineBarSpot(today, line.lineBarsData.length - 1, today.spots.last)]);
        expect(point.single!.text, '120 €', reason: 'spent by 10 March');
        await tap(tester, find.byKey(const Key('cfChartMode:bars')), scroll: true);
        final bars = tester.widget<BarChart>(find.byType(BarChart)).data;
        final march = bars.barGroups.last;
        expect(bars.barTouchData.touchTooltipData.getTooltipItem(march, march.x, march.barRods.single, 0)!.text, '120 €');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Income: the months of the year, a month opening that month', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        await tap(tester, find.byKey(const Key('cfIncomeCard')));
        expect(screenTitle(tester), '${s.legendIncome} · 2026 YTD');
        expect(inKey('cfStatTotal', money.format(6000)), findsOneWidget);
        expect(inKey('cfIncomeBucket:2026-2', s.cfRecords(1)), findsOneWidget);
        await tap(tester, find.byKey(const Key('cfIncomeBucket:2026-2')), scroll: true);
        expect(screenTitle(tester), '${s.legendIncome} · Feb 2026');
        expect(find.byKey(const Key('cfChartMode:ring')), findsNothing, reason: 'income has no categories to make a ring of');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('each bar counts its own period\'s income: a salary recorded for Sunday is this week\'s, not the weeks before', (tester) async {
      await seed();
      final sunday = DateTime(2026, 3, 15);
      await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: sunday, valueDate: sunday, amount: 3000));
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'week');
        await tap(tester, find.byKey(const Key('cfIncomeCard')));
        final bars = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
        // 9–15 February (the salary of the 15th), the three weeks after it, then this week.
        expect([for (final g in bars) g.barRods.single.toY], [3000, 0, 0, 0, 3000]);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Savings: income against expenses, bar by bar, then both lists', (tester) async {
      await seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await span(tester, 'year');
        await tap(tester, find.byKey(const Key('cfSavingsCard')));
        expect(screenTitle(tester), '${s.legendSavings} · 2026 YTD');
        // 6,000 in, 520 of expenses.
        expect(inKey('cfStatTotal', money.format(5480)), findsOneWidget);
        final pairs = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;
        expect([for (final g in pairs) g.barRods.length], [2, 2, 2, 2, 2], reason: 'income and expenses, the year and the four before it');
        expect(pairs.last.barRods.map((r) => r.toY), [6000, 520]);
        expect(find.text('+${money.format(6000)}'), findsOneWidget);
        expect(find.text('−${money.format(520)}'), findsOneWidget);
        // 5,480 saved to 10 March against 5,600 a year earlier (6,000 in, 400 spent).
        expect(find.text('▼ ${money.format(120)}'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
