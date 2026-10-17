// The Cash Flow tab hands the Sankey the monthly figures of its own monthly
// table — income, savings and the refund Income records of each month —
// beside the yearly ones, which do not change.
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

  testWidgets('each month of the monthly table, with the refunds recorded in it', (tester) async {
    await h.seed();
    final july = DateTime(2025, 7, 1);
    await h.db
        .into(h.db.incomes)
        .insert(IncomesCompanion.insert(date: july, valueDate: july, amount: 200, type: const Value(IncomeType.refund)));
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      final card = tester.widget<CashFlowSankeyCard>(find.byType(CashFlowSankeyCard));
      expect(card.months[(2025, 1)], (income: 3000.0, savings: 0.0, refunds: 0.0));
      expect(card.months[(2025, 7)], (income: 3000.0, savings: 0.0, refunds: 200.0));
      expect(card.months[(2026, 2)], (income: 3000.0, savings: 0.0, refunds: 0.0));
      expect(card.months[(2026, 4)], isNull, reason: 'after today');
      expect(card.years[2025], (income: 36000.0, savings: 0.0, refunds: 200.0), reason: 'the year as before');
    } finally {
      await h.unmount(tester);
    }
  });
}
