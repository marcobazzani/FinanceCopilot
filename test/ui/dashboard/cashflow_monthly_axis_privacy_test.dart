// Privacy mode on the Cash Flow tab's monthly charts: their value-axis amounts
// are blurred (PrivacyMask, like the yearly chart, pinned in
// cashflow_tab_test.dart, and the History charts); the month names stay
// readable.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// The month-by-month chart (income, the section's first view) and the
  /// texts it draws.
  Finder chartOf(Finder tile) => find.descendant(of: tile, matching: find.byWidgetPredicate((w) => w is BarChart || w is LineChart));
  List<String?> labelsOf(WidgetTester tester, Finder tile) =>
      tester.widgetList<Text>(find.descendant(of: chartOf(tile), matching: find.byType(Text))).map((t) => t.data).toList();

  testWidgets('monthly income chart: privacy blurs the value-axis amounts, the months stay readable', (tester) async {
    await h.seed();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openTab(tester, 'Cash Flow');
      final tile = await h.cashFlowSection(tester, 'cfMonthByMonthTile');
      final labels = labelsOf(tester, tile);
      bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
      Finder label(String text) => find.descendant(of: chartOf(tile), matching: find.text(text));
      final amounts = labels.whereType<String>().where((l) => l.contains('€')).toList();
      expect(amounts, isNotEmpty);
      for (final amount in amounts) {
        expect(masked(label(amount)), isTrue, reason: '$amount is position size');
      }
      expect(labels, contains('Jun'), reason: 'the month names carry no magnitude');
      expect(masked(label('Jun')), isFalse);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('monthly income chart: without privacy the value axis shows the amounts', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'Cash Flow');
      final labels = labelsOf(tester, await h.cashFlowSection(tester, 'cfMonthByMonthTile'));
      expect(labels, isNot(contains('\u2022\u2022\u2022\u2022')));
      expect(labels.where((l) => l != null && l.contains('€')), isNotEmpty);
    } finally {
      await h.unmount(tester);
    }
  });
}
