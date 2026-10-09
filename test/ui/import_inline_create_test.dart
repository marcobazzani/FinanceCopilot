// The import wizard's inline create dialogs are the app's own: the New
// Account form of the Accounts screen and the Add Intermediary form of the
// intermediary list (titles, field labels and buttons as there). What the
// confirm step creates is selected at once — the new intermediary's radio is
// on and Import comes on with it; a new account joins the account picker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = ImportHarness();

  setUpAll(ImportHarness.initLocales);
  setUp(h.open);
  tearDown(() => h.close());

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  /// The dialog's title, its field's label and hint, and its buttons.
  void expectForm(WidgetTester tester, {required String title, required String label, String? hint}) {
    final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(find.descendant(of: find.byWidget(alert.title!), matching: find.text(title), matchRoot: true), findsOneWidget);
    final field = tester.widget<TextField>(inDialog(find.byType(TextField)));
    expect(field.decoration!.labelText, label);
    expect(field.decoration!.hintText, hint);
    expect(inDialog(find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
    expect(inDialog(find.widgetWithText(FilledButton, s.create)), findsOneWidget);
  }

  const trades = FilePreview(
    columns: ['Day', 'Code'],
    rows: [
      {'Day': '11/05/2022', 'Code': 'IE00B4L5Y983'},
    ],
    totalRows: 1,
    numberLocale: 'en_US',
  );

  /// The asset import's confirm step, with date and ISIN mapped.
  Future<void> openConfirmStep(WidgetTester tester) async {
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: trades));
    await h.mapColumn(tester, 'Operation Date *', 'Day');
    await h.mapColumn(tester, 'ISIN *', 'Code');
    final autoCalc = find.descendant(
      of: find.ancestor(of: find.text('Auto calc'), matching: find.byType(Row)).first,
      matching: find.byType(Checkbox),
    );
    await tap(tester, autoCalc);
    await tap(tester, find.widgetWithText(FilledButton, s.next));
    expect(find.text(s.importSummary), findsOneWidget, reason: 'the confirm step');
  }

  int? selectedIntermediary(WidgetTester tester) => tester.widget<RadioGroup<int?>>(find.byType(RadioGroup<int?>)).groupValue;
  bool importEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, s.importButton)).onPressed != null;

  Future<int> intermediaryId(String name) async => (await h.db.select(h.db.intermediaries).get()).singleWhere((i) => i.name == name).id;

  testWidgets('no intermediary yet: the one created on the confirm step is selected and Import comes on', (tester) async {
    await openConfirmStep(tester);
    try {
      expect(importEnabled(tester), isFalse, reason: 'no intermediary to import into');
      await tap(tester, find.widgetWithText(OutlinedButton, s.addIntermediary));
      expectForm(tester, title: s.addIntermediary, label: s.intermediaryName);
      await tester.enterText(inDialog(find.byType(TextField)), '  Broker  ');
      await tap(tester, inDialog(find.widgetWithText(FilledButton, s.create)));

      expect(find.byType(AlertDialog), findsNothing);
      expect(selectedIntermediary(tester), await intermediaryId('Broker'), reason: 'created trimmed, and selected');
      expect(importEnabled(tester), isTrue);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('another intermediary selected: the one created next to the list takes the selection', (tester) async {
    await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Old broker'));
    await openConfirmStep(tester);
    try {
      await tap(tester, find.widgetWithText(RadioListTile<int?>, 'Old broker'));
      expect(selectedIntermediary(tester), await intermediaryId('Old broker'));

      await tap(tester, find.widgetWithText(TextButton, s.addIntermediary));
      expectForm(tester, title: s.addIntermediary, label: s.intermediaryName);
      await tester.enterText(inDialog(find.byType(TextField)), 'New broker');
      await tap(tester, inDialog(find.widgetWithText(FilledButton, s.create)));

      expect(selectedIntermediary(tester), await intermediaryId('New broker'));
      expect(find.widgetWithText(RadioListTile<int?>, 'New broker'), findsOneWidget);
      expect(importEnabled(tester), isTrue);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('no account yet: the New Account form creates one, which the account picker then lists', (tester) async {
    await h.pump(tester, const ImportScreen());
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, s.createAccount));
      expectForm(tester, title: s.newAccountTitle, label: s.name, hint: s.accountNameHint);
      await tester.enterText(inDialog(find.byType(TextField)), '  Savings  ');
      await tap(tester, inDialog(find.widgetWithText(FilledButton, s.create)));

      expect(find.byType(AlertDialog), findsNothing);
      expect((await h.db.select(h.db.accounts).get()).map((a) => a.name), ['Savings']);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget, reason: 'the account picker replaces the create prompt');
      await tap(tester, find.byType(DropdownButtonFormField<int>));
      expect(find.text('Savings'), findsWidgets);
    } finally {
      await h.unmount(tester);
    }
  });
}
