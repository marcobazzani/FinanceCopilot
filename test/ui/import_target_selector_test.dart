// "Import as": the choice between transactions, asset events and income. The
// import wizard and the share-to-app sheet show the same selector; these tests
// pin its segments (value, icon, label and their sizes), its density and what
// picking a target does in the wizard.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/import/import_service.dart' show ImportTarget;
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/ui/widgets/import_target_selector.dart';

import 'import_wizard_harness.dart';

void main() {
  final h = ImportHarness();

  setUpAll(ImportHarness.initLocales);
  setUp(h.open);
  tearDown(h.close);

  final selector = find.byType(SegmentedButton<ImportTarget>);
  SegmentedButton<ImportTarget> button(WidgetTester tester) => tester.widget<SegmentedButton<ImportTarget>>(selector);

  /// Each segment as (value, icon, icon size, label, label font size).
  List<(ImportTarget, IconData?, double?, String?, double?)> segments(WidgetTester tester) => [
    for (final segment in button(tester).segments)
      (
        segment.value,
        (segment.icon! as Icon).icon,
        (segment.icon! as Icon).size,
        (segment.label! as Text).data,
        (segment.label! as Text).style?.fontSize,
      ),
  ];

  testWidgets('the wizard offers the three targets, transactions first, at the regular density', (tester) async {
    await h.pump(tester, const ImportScreen());
    try {
      expect(find.text('Import as: '), findsOneWidget);
      expect(segments(tester), [
        (ImportTarget.transaction, Icons.receipt_long, 18.0, 'Transaction', 12.0),
        (ImportTarget.assetEvent, Icons.trending_up, 18.0, 'Asset Event', 12.0),
        (ImportTarget.income, Icons.payments, 18.0, 'Income', 12.0),
      ]);
      expect(button(tester).selected, {ImportTarget.transaction});
      expect(button(tester).showSelectedIcon, isFalse);
      expect(button(tester).style, isNull, reason: 'the wizard keeps the default density');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('the Italian wizard names the targets in Italian', (tester) async {
    await h.pump(tester, const ImportScreen(), language: 'it', locale: 'it_IT');
    try {
      expect(segments(tester).map((s) => s.$4), ['Transazione', 'Evento attività', 'Reddito']);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('picking a target switches the wizard to it', (tester) async {
    await h.pump(tester, const ImportScreen());
    try {
      expect(find.text('No accounts yet. Create one first.'), findsOneWidget, reason: 'transactions go into an account');

      await tester.tap(find.text('Asset Event'));
      await h.settle(tester);
      expect(button(tester).selected, {ImportTarget.assetEvent});
      expect(find.text('Mode: '), findsOneWidget, reason: 'asset events pick their import mode');
      expect(find.text('No accounts yet. Create one first.'), findsNothing);

      await tester.tap(find.text('Income'));
      await h.settle(tester);
      expect(button(tester).selected, {ImportTarget.income});
      expect(find.text('Mode: '), findsNothing);
      expect(find.text('No accounts yet. Create one first.'), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a wizard opened on a preselected target shows no selector', (tester) async {
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.income));
    try {
      expect(selector, findsNothing);
      expect(find.text('Import as: '), findsNothing);
    } finally {
      await h.unmount(tester);
    }
  });

  // The share-to-app sheet only opens on Android, from a file shared to the
  // app; it shows the compact selector.
  testWidgets('the compact selector of the share sheet: the same segments, compact density, reports the pick', (tester) async {
    final picked = <ImportTarget>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ImportTargetSelector(selected: ImportTarget.transaction, onChanged: picked.add, compact: true),
          ),
        ),
      ),
    );
    expect(segments(tester), [
      (ImportTarget.transaction, Icons.receipt_long, 18.0, 'Transaction', 12.0),
      (ImportTarget.assetEvent, Icons.trending_up, 18.0, 'Asset Event', 12.0),
      (ImportTarget.income, Icons.payments, 18.0, 'Income', 12.0),
    ]);
    expect(button(tester).selected, {ImportTarget.transaction});
    expect(button(tester).showSelectedIcon, isFalse);
    expect(button(tester).style?.visualDensity, VisualDensity.compact);

    await tester.tap(find.text('Income'));
    await tester.pump();
    expect(picked, [ImportTarget.income]);
  });
}
