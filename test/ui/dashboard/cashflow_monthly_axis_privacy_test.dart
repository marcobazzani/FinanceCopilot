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

  Future<void> expand(WidgetTester tester, String title) async {
    final tile = find.text(title);
    await tester.ensureVisible(tile);
    await h.settle(tester);
    await tester.tap(tile);
    await h.settle(tester);
  }

  /// The texts drawn by the chart of the section titled [title].
  List<String?> labelsOf(WidgetTester tester, String title) {
    final tile = find.ancestor(of: find.text(title), matching: find.byType(ExpansionTile)).first;
    final chart = find.descendant(of: tile, matching: find.byType(BarChart));
    return tester.widgetList<Text>(find.descendant(of: chart, matching: find.byType(Text))).map((t) => t.data).toList();
  }

  testWidgets('monthly income chart: privacy blurs the value-axis amounts, the months stay readable', (tester) async {
    await h.seed();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openTab(tester, 'Cash Flow');
      await expand(tester, 'Income by Month (per Year)');
      final labels = labelsOf(tester, 'Income by Month (per Year)');
      bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
      final tile = find.ancestor(of: find.text('Income by Month (per Year)'), matching: find.byType(ExpansionTile)).first;
      Finder label(String text) => find.descendant(
        of: find.descendant(of: tile, matching: find.byType(BarChart)),
        matching: find.text(text),
      );
      final amounts = labels.whereType<String>().where((l) => l.endsWith(' €')).toList();
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
      await expand(tester, 'Income by Month (per Year)');
      final labels = labelsOf(tester, 'Income by Month (per Year)');
      expect(labels, isNot(contains('\u2022\u2022\u2022\u2022')));
      expect(labels.where((l) => l != null && l.endsWith(' €')), isNotEmpty);
    } finally {
      await h.unmount(tester);
    }
  });
}
