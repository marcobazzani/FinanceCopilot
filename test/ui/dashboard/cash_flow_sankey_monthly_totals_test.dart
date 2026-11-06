// The Cash Flow tab hands the Sankey the figures of the period it picked, as
// its own monthly table has them — income, savings and the refund Income
// records of each of its months; a year is its months.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  testWidgets('each month of the monthly table, with the refunds recorded in it; a year is its months', (tester) async {
    await h.seed();
    final july = DateTime(2025, 7, 1);
    await h.db
        .into(h.db.incomes)
        .insert(IncomesCompanion.insert(date: july, valueDate: july, amount: 200, type: const Value(IncomeType.refund)));
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      CashFlowSankeyCard card() => tester.widget<CashFlowSankeyCard>(find.byType(CashFlowSankeyCard));
      // The strip counts the months from December 2024, where the history opens.
      for (final (index, month, totals) in [
        (14, (2026, 2), (income: 3000.0, savings: 0.0, refunds: 0.0)),
        (7, (2025, 7), (income: 3000.0, savings: 0.0, refunds: 200.0)),
        (1, (2025, 1), (income: 3000.0, savings: 0.0, refunds: 0.0)),
      ]) {
        await h.pickMonthAt(tester, index);
        expect(card().periods, {month});
        expect(card().totals, totals, reason: '$month');
      }
      await h.pickYear(tester, 2025);
      expect(card().periods, {for (var m = 1; m <= 12; m++) (2025, m)});
      expect(card().totals, (income: 36000.0, savings: 0.0, refunds: 200.0), reason: 'the year as before');
      await h.pickYear(tester, 2026);
      expect(card().periods, containsAll([(2026, 1), (2026, 2)]));
      expect(card().periods.where((p) => p.$1 == 2026 && p.$2 > 3), isEmpty, reason: 'no month after today');
    } finally {
      await h.unmount(tester);
    }
  });
}
