// The Cash Flow tab's Sankey gets the spread saving plans from the ledger:
// the scheduled steps of a spread outflow no bank transaction accounts for
// (the "Saving for X" rows) are a band of their own in the years they fall
// in. The yearly savings already went down by them; they used to reach the
// Sankey only through that drop, and so read as untracked expenses.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Finder inNode(String id, String text) => find.descendant(of: find.byKey(ValueKey('sankeyNode:$id')), matching: find.text(text));

  testWidgets('a car saved for monthly in 2025 is its own band of the 2025 Sankey, not untracked expenses', (tester) async {
    await h.seed();
    // Bought in January 2026; 6 × 200 set aside from July to December 2025.
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
      final card = find.byType(CashFlowSankeyCard);
      final y2025 = tester.widget<CashFlowSankeyCard>(card).years[2025]!;
      expect(y2025.income, 36000);
      expect(y2025.savings, -1200, reason: 'the yearly savings went down by what was set aside');

      final chip = find.byKey(const Key('sankeyYear:2025'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await h.settle(tester);

      expect(inNode('plan:$car', 'Saving for Car'), findsOneWidget);
      expect(inNode('plan:$car', '€1,200'), findsOneWidget);
      // Expenses 37,200: the 1,200 set aside and 36,000 the ledger does not
      // hold (the harness imports no spending). It used to read 37,200.
      expect(inNode('grp:untracked', '€36,000'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
