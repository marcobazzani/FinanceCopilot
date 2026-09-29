// Health tab: KPI texts in the display language and locale, the FIRE dialog
// closing while its field still has focus, and the KPI details sliding open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/providers/providers.dart';

import 'dashboard_harness.dart';

Asset _asset(int id, String name, {InstrumentType type = InstrumentType.etf, double? ter}) => Asset(
  id: id,
  name: name,
  ticker: name,
  assetType: AssetType.stockEtf,
  instrumentType: type,
  assetClass: AssetClass.equity,
  intermediaryId: 1,
  assetGroup: '',
  currency: 'EUR',
  valuationMethod: ValuationMethod.marketPrice,
  ter: ter,
  isActive: true,
  includeInSavings: true,
  sortOrder: 0,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
);

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  group('Italian display locale', () {
    testWidgets('Savings Rate projection: Italian month names and decimal commas', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, 'Tasso di risparmio');
        final text = h.dialogText(tester);
        expect(text, contains('Risparmi / Entrate x 100'));
        expect(text, contains('Nel 2026 (gen–feb) finora: 6.000,00 € (100,0% rispetto al 2025).'));
        expect(text, contains('Tasso%: ~0,0%'));
        expect(text, isNot(contains('Jan')));
        expect(text, isNot(contains('0.0%')));
        await h.tapDialogButton(tester, 'Chiudi');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('HHI and TER formulas are Italian', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, 'HHI');
        expect(h.dialogText(tester), contains('Indice di Herfindahl-Hirschman\n< 1500 = Ben diversificato'));
        await h.tapDialogButton(tester, 'Chiudi');

        await h.openInfo(tester, 'TER');
        expect(h.dialogText(tester), contains('TER medio ponderato\n0,20%'));
        await h.tapDialogButton(tester, 'Chiudi');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('FIRE dialog: the months behind the projection are spelled out', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, 'Progresso verso target FI');
        expect(find.text('  Proiezione anno corrente (2 mesi)'), findsOneWidget);
        await h.tapDialogButton(tester, 'Annulla');
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('English keeps its wording', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openInfo(tester, 'HHI');
      expect(h.dialogText(tester), contains('Herfindahl-Hirschman Index\n< 1500 = Well diversified'));
      await h.tapDialogButton(tester, 'Close');
      await h.openInfo(tester, 'TER');
      expect(h.dialogText(tester), contains('Weighted Avg TER\n0.20%'));
      await h.tapDialogButton(tester, 'Close');
      await h.openInfo(tester, 'FI Target Progress');
      expect(find.text('  Current-year projection (2m)'), findsOneWidget);
      await h.tapDialogButton(tester, 'Cancel');
    } finally {
      await h.unmount(tester);
    }
  });

  // The SWR field kept focus while the dialog closed: its controller used to
  // be disposed as soon as the dialog returned, while the closing animation
  // was still rebuilding the field.
  group('FIRE dialog closes cleanly with the SWR field focused', () {
    Finder swrField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

    testWidgets('Cancel', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openInfo(tester, 'FI Target Progress');
        await tester.enterText(swrField(), '3');
        await h.tapDialogButton(tester, 'Cancel');
        expect(find.byType(AlertDialog), findsNothing);
        final stored = await (h.db.select(h.db.appConfigs)..where((c) => c.key.equals('FIRE_SWR'))).getSingleOrNull();
        expect(stored, isNull, reason: 'cancel stores nothing');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Save stores the rate', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openInfo(tester, 'FI Target Progress');
        await tester.enterText(swrField(), '3');
        await h.tapDialogButton(tester, 'Save');
        expect(find.byType(AlertDialog), findsNothing);
        final stored = await (h.db.select(h.db.appConfigs)..where((c) => c.key.equals('FIRE_SWR'))).getSingle();
        expect(stored.value, '3.0');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Reset keeps the dialog open with the default rate', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openInfo(tester, 'FI Target Progress');
        await tester.enterText(swrField(), '3');
        await h.tapDialogButton(tester, 'Reset default');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.descendant(of: swrField(), matching: find.text('2.75')), findsOneWidget);
        await h.tapDialogButton(tester, 'Cancel');
        expect(find.byType(AlertDialog), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('KPI details slide open and closed; the card header does not move', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      final card = h.kpiCard('Savings Rate');
      final details = find.descendant(of: card, matching: find.text('Details'));
      final name = find.descendant(of: card, matching: find.text('Savings Rate'));
      await tester.ensureVisible(details);
      await h.settle(tester);
      final collapsed = tester.getSize(card).height;
      final nameTop = tester.getTopLeft(name).dy;

      await tester.tap(details);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opening = tester.getSize(card).height;
      await h.settle(tester);
      final expanded = tester.getSize(card).height;
      expect(expanded, greaterThan(collapsed));
      expect(opening, allOf(greaterThan(collapsed), lessThan(expanded)), reason: 'the details grow in, they do not snap');
      expect(tester.getTopLeft(name).dy, nameTop);
      expect(
        find.descendant(of: card, matching: find.textContaining('savings rate')),
        findsOneWidget,
        reason: 'the description is shown',
      );

      await tester.tap(details);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final closing = tester.getSize(card).height;
      await h.settle(tester);
      expect(closing, allOf(greaterThan(collapsed), lessThan(expanded)));
      expect(tester.getSize(card).height, collapsed);
      expect(tester.getTopLeft(name).dy, nameTop);
    } finally {
      await h.unmount(tester);
    }
  });

  // 6,000 at 0.20% + 3,000 at 0.50% + a 1,000 stock (no TER, none expected):
  // 27 a year on 10,000 → 0.27%, rated Good.
  group('TER KPI', () {
    final known = [_asset(1, 'EMKT', ter: 0.2), _asset(2, 'BOND', ter: 0.5), _asset(3, 'ACME', type: InstrumentType.stock)];
    const knownValues = {1: 6000.0, 2: 3000.0, 3: 1000.0};

    Future<void> pumpWith(WidgetTester tester, List<Asset> assets, Map<int, double> values) => h.pump(
      tester,
      overrides: [activeAssetsProvider.overrideWithValue(AsyncData(assets)), assetMarketValuesProvider.overrideWithValue(AsyncData(values))],
    );

    Finder inTerCard(String text) => find.descendant(of: h.kpiCard('TER'), matching: find.text(text));

    testWidgets('every fund with a TER', (tester) async {
      await h.seed();
      await pumpWith(tester, known, knownValues);
      try {
        expect(inTerCard('0.27%'), findsOneWidget);
        expect(inTerCard('Good'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a fund with an unknown TER is left out, not counted as free, and the formula says so', (tester) async {
      await h.seed();
      await pumpWith(tester, [...known, _asset(4, 'MYST')], {...knownValues, 4: 5000.0});
      try {
        expect(inTerCard('0.27%'), findsOneWidget, reason: 'counted as free it would read 27 / 15,000 = 0.18%');
        await h.openInfo(tester, 'TER');
        expect(h.dialogText(tester), contains('Weighted Avg TER\n0.27%\n1 fund without a TER excluded from the average'));
        await h.tapDialogButton(tester, 'Close');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('nothing to weigh: no TER, no rating', (tester) async {
      await h.seed();
      await pumpWith(tester, [_asset(4, 'MYST')], {4: 5000.0});
      try {
        expect(inTerCard('-'), findsOneWidget);
        expect(inTerCard('N/A'), findsOneWidget, reason: 'an unknown cost is not an excellent one');
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
