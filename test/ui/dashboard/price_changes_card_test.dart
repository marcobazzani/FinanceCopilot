// Price Changes card: the period chips and the "default period" confirmation
// show localized unit labels, never the internal unit keys; the column
// headers sort the rows; the stepper and the field set how many units back.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

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

  group('sorting and the period', () {
    /// A second listed asset, cheaper but moving more: 20 units, 48 yesterday,
    /// 50 today (+4.17%, +40); the harness fund moves from 120 to 121 (+0.83%,
    /// +10).
    Future<void> addZeta() async {
      final broker = (await h.db.select(h.db.intermediaries).get()).first.id;
      final zeta = await h.db
          .into(h.db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Zeta',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
            ),
          );
      await h.db
          .into(h.db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: zeta,
              date: DateTime(2025, 1, 2),
              valueDate: DateTime(2025, 1, 2),
              type: EventType.buy,
              amount: 800,
              quantity: const Value(20),
              price: const Value(40),
            ),
          );
      for (final (day, close) in [(DateTime(2025, 1, 2), 40.0), (DateTime(2026, 3, 9), 48.0), (DashboardHarness.today, 50.0)]) {
        await h.db.into(h.db.marketPrices).insert(MarketPricesCompanion.insert(assetId: zeta, date: day, closePrice: close, currency: 'EUR'));
      }
    }

    Finder card() => find.ancestor(of: find.text('Price Changes'), matching: find.byType(Card)).first;

    /// The rows, top to bottom.
    List<String> rows(WidgetTester tester) {
      final names = [
        for (final name in ['Fund', 'Zeta'])
          if (find.descendant(of: card(), matching: find.text(name)).evaluate().isNotEmpty)
            (name, tester.getTopLeft(find.descendant(of: card(), matching: find.text(name)).first).dy),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      return [for (final (name, _) in names) name];
    }

    Future<void> tapIn(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await h.settle(tester);
      await tester.tap(f);
      await h.settle(tester);
    }

    Future<void> waitForRows(WidgetTester tester) async {
      for (var i = 0; i < 100 && rows(tester).length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('a header sorts by its column, again the other way, a third time back to by name', (tester) async {
      await h.seed();
      await addZeta();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'History');
        await waitForRows(tester);
        expect(rows(tester), ['Fund', 'Zeta'], reason: 'by name');
        // A header reads its label, and an arrow while it sorts the rows.
        Finder header(String label) => find.descendant(
          of: card(),
          matching: find.byWidgetPredicate((w) => w is Text && RegExp('^${RegExp.escape(label)}( [▲▼])?\$').hasMatch(w.data ?? '')),
        );
        for (final (label, ascending) in [
          ('Price', ['Zeta', 'Fund']),
          ('%', ['Fund', 'Zeta']),
          ('Value \u0394 (€)', ['Fund', 'Zeta']),
        ]) {
          await tapIn(tester, header(label));
          expect(rows(tester), ascending, reason: '$label, ascending');
          await tapIn(tester, header(label));
          expect(rows(tester), ascending.reversed.toList(), reason: '$label, descending');
          await tapIn(tester, header(label));
          expect(rows(tester), ['Fund', 'Zeta'], reason: '$label a third time: by name again');
        }
        // Already by name: the name header turns it the other way, then back.
        await tapIn(tester, header('Asset'));
        expect(rows(tester), ['Zeta', 'Fund'], reason: 'by name, descending');
        await tapIn(tester, header('Asset'));
        expect(rows(tester), ['Fund', 'Zeta'], reason: 'by name, ascending again');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the stepper and the field set how many units back; to-date periods take no number', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'History');
        final field = find.descendant(of: card(), matching: find.byType(TextField));
        String number() => tester.widget<TextField>(field).controller!.text;
        expect(number(), '1');
        await tapIn(tester, find.descendant(of: card(), matching: find.byIcon(Icons.arrow_drop_up)));
        expect(number(), '2');
        await tapIn(tester, find.descendant(of: card(), matching: find.byIcon(Icons.arrow_drop_down)));
        expect(number(), '1');
        await tester.enterText(field, '3');
        await h.settle(tester);
        await tapIn(tester, find.widgetWithText(ChoiceChip, 'YTD'));
        expect(number(), '', reason: 'year to date counts no units');
        await tapIn(tester, find.widgetWithText(ChoiceChip, 'w'));
        expect(number(), '1', reason: 'back to one unit, of weeks');
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
