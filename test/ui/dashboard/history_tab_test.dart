// History tab: the Totals drill-down slides open instead of snapping, and the
// collapsible source charts keep the standard ExpansionTile chevron (it
// rotates on expand) with any chart actions in the title row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/build_flags.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  testWidgets('Totals: a row\'s drill-down slides open and closed; the row itself does not move', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      final card = find.ancestor(of: find.text('Totals'), matching: find.byType(Card)).first;
      final row = find.descendant(of: card, matching: find.text('Cash'));
      await tester.ensureVisible(row);
      await h.settle(tester);
      final collapsed = tester.getSize(card).height;
      final rowTop = tester.getTopLeft(row).dy;

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opening = tester.getSize(card).height;
      await h.settle(tester);
      final expanded = tester.getSize(card).height;
      expect(
        find.descendant(of: card, matching: find.text('Main')),
        findsOneWidget,
        reason: 'the account behind the Cash total',
      );
      expect(expanded, greaterThan(collapsed));
      expect(opening, allOf(greaterThan(collapsed), lessThan(expanded)), reason: 'the drill-down grows in, it does not snap');
      expect(tester.getTopLeft(row).dy, rowTop);

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final closing = tester.getSize(card).height;
      await h.settle(tester);
      expect(closing, allOf(greaterThan(collapsed), lessThan(expanded)));
      expect(tester.getSize(card).height, collapsed);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('collapsible charts use the rotating ExpansionTile chevron; actions sit in the title', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      final tiles = find.byType(ExpansionTile);
      expect(tiles, findsWidgets);
      for (final tile in tester.widgetList<ExpansionTile>(tiles)) {
        expect(tile.trailing, isNull, reason: 'a custom trailing widget replaces the rotating chevron');
      }
      final first = tiles.first;
      if (debugChartsEnabled) {
        expect(find.descendant(of: first, matching: find.byTooltip('Edit')), findsOneWidget);
        expect(find.descendant(of: first, matching: find.byTooltip('Delete')), findsOneWidget);
      }
      final chevron = find.descendant(of: first, matching: find.byIcon(Icons.expand_more));
      expect(chevron, findsOneWidget);
      RotationTransition rotation() =>
          tester.widget<RotationTransition>(find.ancestor(of: chevron, matching: find.byType(RotationTransition)).first);
      expect(rotation().turns.value, 0);

      await tester.ensureVisible(first);
      await h.settle(tester);
      await tester.tap(find.descendant(of: first, matching: find.text('Total Assets')).first);
      await h.settle(tester);
      expect(rotation().turns.value, 0.5, reason: 'the chevron turns to point up once the tile is open');
    } finally {
      await h.unmount(tester);
    }
  });
}
