// The Cash Flow year and month buckets across a daylight-saving change
// (Europe/Rome dates). The current year's length in days — the divisor of the
// daily and monthly averages — was the elapsed time from 1 January to today
// in whole 24-hour days, plus one: a day short all summer (270 instead of 271
// on 28 September 2026). A month's boundaries were its 1st minus 24 hours: in
// a year whose DST starts on 31 March that is 30 March 23:00, so what moved
// on 31 March was booked in April. Both count calendar days now. The
// expectations hold in any time zone; run under TZ=Europe/Rome to exercise
// the change itself.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/providers/providers.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// The year buckets the Cash Flow tab charts, read from the yearly bar
  /// chart that receives them (their type is private to the dashboard).
  Map<int, dynamic> years(WidgetTester tester) {
    final chart = tester.widget(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_YearlyBarChart').first) as dynamic;
    return {for (final y in chart.data.years as List<dynamic>) y.year as int: y};
  }

  Future<void> bankRow(int account, DateTime day, double amount, double balance) => h.db
      .into(h.db.transactions)
      .insert(
        TransactionsCompanion.insert(accountId: account, operationDate: day, valueDate: day, amount: amount, balanceAfter: Value(balance)),
      );

  Future<void> pumpAsOf(WidgetTester tester, DateTime asOf) async {
    await h.pump(tester, overrides: [waybackDateProvider.overrideWith((ref) => asOf)]);
    await h.openTab(tester, 'Cash Flow');
  }

  testWidgets('the current year counts its calendar days, summer time or not', (tester) async {
    final main = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await bankRow(main, DateTime(2026, 1, 2), 1000, 1000);
    await h.db.into(h.db.incomes).insert(IncomesCompanion.insert(date: DateTime(2026, 1, 15), valueDate: DateTime(2026, 1, 15), amount: 2710));
    await pumpAsOf(tester, DateTime(2026, 9, 28));
    try {
      final y2026 = years(tester)[2026];
      expect(y2026.days, 271, reason: '1 January to 28 September, both included');
      expect(y2026.dailyIncome, closeTo(10, 1e-9));
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a flow on 31 March stays in March when DST starts that day', (tester) async {
    final main = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await bankRow(main, DateTime(2024, 2, 1), 1000, 1000);
    await bankRow(main, DateTime(2024, 3, 31), 500, 1500);
    await pumpAsOf(tester, DateTime(2024, 6, 30));
    try {
      final months = {for (final m in years(tester)[2024].months as List<dynamic>) m.month as int: m.navChange as double};
      expect(months[3], 500, reason: 'saved on 31 March');
      expect(months[4], 0, reason: 'nothing moved in April');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a completed year keeps its 365 or 366 days', (tester) async {
    final main = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await bankRow(main, DateTime(2024, 2, 1), 1000, 1000);
    await pumpAsOf(tester, DateTime(2026, 1, 10));
    try {
      final all = years(tester);
      expect(all[2024].days, 366);
      expect(all[2025].days, 365);
      expect(all[2026].days, 10);
    } finally {
      await h.unmount(tester);
    }
  });
}
