// The import wizard's small create dialogs (account, intermediary, empty
// asset) own their text controllers: closing them — cancel or create — while
// the name field still has focus must not use a disposed controller during
// the closing animation ("A TextEditingController was used after being
// disposed").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
  final h = ImportHarness();

  setUpAll(ImportHarness.initLocales);
  setUp(h.open);
  tearDown(() => h.close());

  Finder dialogField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  /// Types [name] into the open dialog's name field (which takes the focus)
  /// and leaves through [button]; the dialog must close without an error.
  Future<void> typeAndLeave(WidgetTester tester, String name, Finder button) async {
    await tester.enterText(dialogField(), name);
    await tester.pump();
    await tester.tap(button);
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  }

  Finder inDialog(Type type, String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(type, label));

  testWidgets('new account: cancel and create with the name field focused', (tester) async {
    await h.pump(tester, const ImportScreen());
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, 'Create Account'));
      await typeAndLeave(tester, 'Savings', inDialog(TextButton, 'Cancel'));
      expect(await h.db.select(h.db.accounts).get(), isEmpty);

      await tap(tester, find.widgetWithText(OutlinedButton, 'Create Account'));
      await typeAndLeave(tester, 'Savings', inDialog(FilledButton, 'Create'));
      expect((await h.db.select(h.db.accounts).get()).map((a) => a.name), ['Savings']);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('new intermediary on the confirm step: cancel and create with the name field focused', (tester) async {
    const trades = FilePreview(
      columns: ['Day', 'Code'],
      rows: [
        {'Day': '11/05/2022', 'Code': 'IE00B4L5Y983'},
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: trades));
    try {
      await h.mapColumn(tester, 'Operation Date *', 'Day');
      await h.mapColumn(tester, 'ISIN *', 'Code');
      final autoCalc = find.descendant(
        of: find.ancestor(of: find.text('Auto calc'), matching: find.byType(Row)).first,
        matching: find.byType(Checkbox),
      );
      await tap(tester, autoCalc);
      await tap(tester, find.widgetWithText(FilledButton, 'Next'));

      await tap(tester, find.widgetWithText(OutlinedButton, 'Add Intermediary'));
      await typeAndLeave(tester, 'Broker', inDialog(TextButton, 'Cancel'));
      expect(await h.db.select(h.db.intermediaries).get(), isEmpty);

      await tap(tester, find.widgetWithText(OutlinedButton, 'Add Intermediary'));
      await typeAndLeave(tester, 'Broker', inDialog(FilledButton, 'Create'));
      expect((await h.db.select(h.db.intermediaries).get()).map((i) => i.name), ['Broker']);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('new empty asset: cancel and create with the name field focused', (tester) async {
    await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Pension fund'));
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent));
    try {
      await tap(tester, find.text('Import into single asset'));

      await tap(tester, find.widgetWithText(OutlinedButton, 'Create empty asset'));
      await typeAndLeave(tester, 'My pension', inDialog(TextButton, 'Cancel'));
      expect(await h.db.select(h.db.assets).get(), isEmpty);

      await tap(tester, find.widgetWithText(OutlinedButton, 'Create empty asset'));
      await typeAndLeave(tester, 'My pension', inDialog(FilledButton, 'Create'));
      final asset = (await h.db.select(h.db.assets).get()).single;
      expect(asset.name, 'My pension');
      expect(asset.valuationMethod, ValuationMethod.eventDriven);
    } finally {
      await h.unmount(tester);
    }
  });
}
