// History tab, Totals table: a figure keeps to one line, whatever its size.
// The "vs ATH" and "Value" columns had fixed widths, so a total above a
// million wrapped its currency symbol onto a second line. They are now as
// wide as their widest figure, header and rows alike, so the columns stay
// aligned; when a narrow screen cannot give them that much, the figures
// shrink to fit rather than wrap or overflow.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

import 'dashboard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();
  final euro = fmt.currencyFormat('it_IT', '€', decimalDigits: 2);
  // 1.108.341,51 € at its high, then 100.016,28 € spent.
  final total = '+${euro.format(1008325.23)}';
  final belowHigh = euro.format(-100016.28);

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Future<void> seedMillion() async {
    final db = h.db;
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    for (final (day, amount, balance) in [(DateTime(2025, 1, 10), 1108341.51, 1108341.51), (DateTime(2025, 6, 10), -100016.28, 1008325.23)]) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: day,
              valueDate: day,
              amount: amount,
              balanceAfter: Value(balance),
            ),
          );
    }
  }

  Finder totalsCard() => find.ancestor(of: find.text(s.vsATH), matching: find.byType(Card)).first;
  Finder inTotals(Finder f) => find.descendant(of: totalsCard(), matching: f);
  Finder rowOf(String label) => find.ancestor(of: inTotals(find.text(label)), matching: find.byType(Row)).first;
  Finder cellOf(String label, String text) => find.descendant(of: rowOf(label), matching: find.text(text));

  /// The lines [f]'s text is laid out on.
  int lines(WidgetTester tester, Finder f) {
    final paragraph = tester.renderObject<RenderParagraph>(f);
    final text = paragraph.text.toPlainText();
    return paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)).map((b) => b.top).toSet().length;
  }

  /// How much [f] is scaled on screen: 1 when drawn at its own size.
  double scaleOf(WidgetTester tester, Finder f) => tester.getRect(f).height / tester.getSize(f).height;

  Future<void> openTotals(WidgetTester tester) async {
    await h.openTab(tester, 'History');
    await tester.ensureVisible(find.text(s.vsATH));
    await h.settle(tester);
  }

  testWidgets('a total above a million stays on one line, at the size of the others; the columns stay aligned', (tester) async {
    await seedMillion();
    await h.pump(tester, locale: 'it_IT');
    try {
      await openTotals(tester);
      final value = cellOf('Total Assets', total);
      final delta = cellOf('Total Assets', belowHigh);
      expect(value, findsOneWidget);
      expect(delta, findsOneWidget);
      expect(lines(tester, value), 1, reason: 'the currency symbol used to wrap onto a second line');
      expect(lines(tester, delta), 1);
      expect(scaleOf(tester, value), 1.0, reason: 'the column made room for it: not shrunk');
      expect(scaleOf(tester, delta), 1.0);

      // The header and every row share the two columns.
      final valueEdge = tester.getTopRight(inTotals(find.text(s.value))).dx;
      final deltaEdge = tester.getTopRight(inTotals(find.text(s.vsATH))).dx;
      expect(tester.getTopRight(value).dx, closeTo(valueEdge, 0.01));
      expect(tester.getTopRight(delta).dx, closeTo(deltaEdge, 0.01));
      expect(tester.getTopRight(cellOf('Cash', total)).dx, closeTo(valueEdge, 0.01));
      expect(tester.getTopRight(cellOf('Invested', '—')).dx, closeTo(valueEdge, 0.01), reason: 'a total with nothing to add up');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a phone-wide screen: the figures shrink to fit, never wrap nor overflow', (tester) async {
    await seedMillion();
    await h.pump(tester, locale: 'it_IT');
    try {
      tester.view.physicalSize = const Size(412, 2400);
      await h.settle(tester);
      await openTotals(tester);
      expect(tester.takeException(), isNull, reason: 'no row overflows');
      final value = cellOf('Total Assets', total);
      final delta = cellOf('Total Assets', belowHigh);
      expect(lines(tester, value), 1);
      expect(lines(tester, delta), 1);
      expect(scaleOf(tester, value), lessThan(1.0), reason: 'the card is too narrow for it at full size');
      final label = inTotals(find.text('Total Assets'));
      expect(tester.getSize(label).width, greaterThanOrEqualTo(80), reason: 'the label keeps its room');
      expect(tester.getTopRight(value).dx, closeTo(tester.getTopRight(inTotals(find.text(s.value))).dx, 0.01));
    } finally {
      await h.unmount(tester);
    }
  });
}
