// Price Changes card: the period chips and the "default period" confirmation
// show localized unit labels, never the internal unit keys.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// Chip labels of the Price Changes card titled [title], in order.
  List<String> chipLabels(WidgetTester tester, String title) => [
    for (final chip in tester.widgetList<ChoiceChip>(
      find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card)).first,
        matching: find.byType(ChoiceChip),
      ),
    ))
      ((chip.label as Row).children.first as Text).data!,
  ];

  testWidgets('Italian: localized period chips and confirmation', (tester) async {
    await h.seed();
    await h.pump(tester, language: 'it', locale: 'it_IT');
    try {
      await h.openTab(tester, 'Storico');
      expect(chipLabels(tester, 'Variazioni prezzo'), ['g', 's', 'm', 'a', 'WTD', 'MTD', 'YTD', 'Tutto']);

      await tester.longPress(find.widgetWithText(ChoiceChip, 'Tutto'));
      await h.settle(tester);
      expect(find.text('Periodo predefinito impostato su Tutto'), findsOneWidget);
      final stored = await (h.db.select(h.db.appConfigs)..where((c) => c.key.equals('DEFAULT_PRICE_CHANGE_UNIT'))).getSingle();
      expect(stored.value, 'All', reason: 'the stored unit stays the internal key');

      // The value-change column header is Italian too.
      final header = find.text('Valore \u0394 (€)');
      for (var i = 0; i < 100 && header.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(header, findsOneWidget);
      expect(find.text('Value \u0394 (€)'), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('English chips read as before', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openTab(tester, 'History');
      expect(chipLabels(tester, 'Price Changes'), ['d', 'w', 'm', 'y', 'WTD', 'MTD', 'YTD', 'All']);
      await tester.longPress(find.widgetWithText(ChoiceChip, 'w'));
      await h.settle(tester);
      expect(find.text('Default period set to w'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
