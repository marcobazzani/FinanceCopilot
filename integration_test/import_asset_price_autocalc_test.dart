// Issue #96 — "Campi obbligatori non presenti su Directa".
//
// A broker export carried Quantity + Amount but no Price and no Exchange
// Rate column. The mapper labelled both fields with a bold `*` and a
// "Required" hint, so the reporter believed they had to edit the source
// spreadsheet — even though `_canProceedToConfirm()` only ever enforced
// date / amount / ISIN and the import ran fine without them.
//
// This pins both halves of the fix:
//   1. Price / Exchange Rate / Quantity / Currency are rendered WITHOUT a
//      `*`, and Next really is reachable with neither of them mapped.
//   2. The new "Auto calc from amount" toggle on the Price row derives the
//      per-unit price as amount / quantity, so the position stops being
//      excluded from the weighted average buy price.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('asset mapper: price/FX are not required and price can be derived from amount', (tester) async {
    late AppDatabase db;
    db = await pumpApp(
      tester,
      seed: (database) async {
        await database.into(database.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker Directa'));
      },
    );
    await longSettle(tester);

    // assets_multi_isin.csv: date,isin,quantity,price,currency,amount.
    // We deliberately leave `price` unmapped to reproduce the reporter's
    // file shape, then assert the derived value matches the price the
    // fixture itself reports (950.00 / 10 = 95.00).
    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_multi_isin.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent, db: db);
    await longSettle(tester);
    await setSegmentMode(tester, 'Historic');

    // ── 1. No false `*` on the fields the gate never checks ───────────────
    // Assert on each row's EXACT rendered label via mapperLabelText, which
    // scrolls the row into view first. A bare `expect(find.text('Price *'),
    // findsNothing)` would pass vacuously on any window short enough to leave
    // the row unbuilt — the mapper is a ListView.
    for (final field in ['Quantity', 'Price', 'Currency', 'Exchange Rate']) {
      expect(
        await mapperLabelText(tester, field),
        field,
        reason: '"$field" must not be starred — _canProceedToConfirm() does not enforce it (issue #96)',
      );
    }
    // The genuinely enforced ones keep their `*`.
    for (final field in ['Operation Date', 'ISIN']) {
      expect(await mapperLabelText(tester, field), '$field *', reason: '$field IS enforced by the gate');
    }

    // ── 2. Next is reachable without price / exchange rate ────────────────
    await setMapping(tester, 'Operation Date', 'date');
    await setMapping(tester, 'ISIN', 'isin');
    await setMapping(tester, 'Quantity', 'quantity');
    await setMapping(tester, 'Amount', 'amount');
    await setMapping(tester, 'Currency', 'currency');

    final next = find.widgetWithText(FilledButton, 'Next');
    await tester.ensureVisible(next);
    await settle(tester);
    expect(
      tester.widget<FilledButton>(next).onPressed,
      isNotNull,
      reason: 'Next must be enabled with price and exchange rate unmapped (issue #96)',
    );

    // ── 3. Derive the price from amount / quantity ────────────────────────
    final toggleLabel = find.text('Auto calc from amount');
    await scrollMapperTo(tester, toggleLabel);
    expect(toggleLabel, findsOneWidget, reason: 'price auto-calc toggle should sit on the Price row');
    await tester.ensureVisible(toggleLabel);
    await settle(tester);
    final toggle = find.descendant(
      of: find.ancestor(of: toggleLabel, matching: find.byType(Row)).first,
      matching: find.byType(Checkbox),
    );
    await tester.tap(toggle.first);
    await longSettle(tester);
    // The dropdown is replaced by the formula label while derived.
    final formula = find.text('amount / quantity');
    await scrollMapperTo(tester, formula);
    expect(formula, findsOneWidget, reason: 'derived Price row should show its formula');

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await longSettle(tester);
    await selectIntermediary(tester, 'Broker Directa');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await pumpFor(tester, const Duration(seconds: 60));

    final events = await db.select(db.assetEvents).get();
    expect(events, isNotEmpty, reason: 'import should have created events');
    expect(
      events.every((e) => e.price != null),
      isTrue,
      reason: 'every imported row should carry a derived price',
    );
    // The fixture's own (never-mapped) Price column is the oracle:
    // IE00B4L5Y983 buys 10 @ 950.00 → 95.00 and 5 @ 480.00 → 96.00.
    final swda = await (db.select(db.assets)..where((a) => a.isin.equals('IE00B4L5Y983'))).getSingle();
    final swdaEvents = await (db.select(db.assetEvents)..where((e) => e.assetId.equals(swda.id))).get();
    expect(
      swdaEvents.map((e) => e.price!.toStringAsFixed(2)).toSet(),
      {'95.00', '96.00'},
      reason: 'derived prices must reproduce the price column we never mapped',
    );
    final avg = await AssetEventService(db).getAverageBuyPrice(swda.id);
    // (10 * 95 + 5 * 96) / 15 = 95.333…
    expect(avg, closeTo(95.3333, 0.001), reason: 'derived price should restore the weighted average buy price');
  });
}
