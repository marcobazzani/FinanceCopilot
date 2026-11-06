// The Year-over-year table with the month in progress: the month a year
// before counts for the same share of its days, never whole against a few.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();
  const s = AppStrings.en;

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  // The harness's 3,000 salary every month of 2025 and in January–February
  // 2026; today is 10 March 2026, and 1,000 came in on 5 March.
  Future<void> seed() async {
    await h.seed();
    final d = DateTime(2026, 3, 5);
    await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 1000));
  }

  testWidgets('Year-over-year: March 2026 so far against 10/31 of March 2025, said under the table', (tester) async {
    await seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      await tester.ensureVisible(find.text(s.cfMonthByMonth));
      await tester.tap(find.text(s.cfMonthByMonth));
      await h.settle(tester);
      await tester.ensureVisible(find.text(s.cfViewYoY));
      await tester.tap(find.text(s.cfViewYoY));
      await h.settle(tester);
      // 1,000 − 3,000 × 10/31 = +32.26: the March cell, marked, and the YoY row (January and February: +0.00).
      expect(find.text('+32.26 €*'), findsOneWidget);
      expect(find.text('+32.26 €'), findsOneWidget);
      expect(find.text('-2,000.00 €'), findsNothing, reason: 'never all of March 2025 against 10 days');
      expect(
        tester.widget<Text>(find.descendant(of: find.byKey(const Key('yoyPartialMonth')), matching: find.byType(Text))).data,
        '* ${s.cfPartialMonth('Mar 2026', 10, 31, 'Mar 2025')}',
      );
    } finally {
      await h.unmount(tester);
    }
  });
}
