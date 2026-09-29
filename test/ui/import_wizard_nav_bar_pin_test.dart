// Pins the bottom buttons of the import wizard's steps before they move into
// the shared wizard navbar: their labels, button types, icons and when they
// are enabled.
//
//  * Mapper: a filled "Next" without an icon, off until date and amount are
//    mapped; it opens the confirm step.
//  * Confirm step: a filled "Import" with a check icon; when the import is
//    blocked, the reason sits on the same row, before the button.
//  * Quick confirm: an outlined "Let me edit" (edit icon) before a filled
//    "Import" (check icon); "Let me edit" opens the mapper.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
  const s = AppStrings.en;
  final h = ImportHarness();
  late int acct;

  setUpAll(ImportHarness.initLocales);
  setUp(() async {
    h.open();
    acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => h.close());

  const statement = FilePreview(
    columns: ['Date', 'Description', 'Amount'],
    rows: [
      {'Date': '11/05/2022', 'Description': 'Salary', 'Amount': '100'},
      {'Date': '12/05/2022', 'Description': 'Refund', 'Amount': '50'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );

  Future<void> saveConfig({String? numberLocale = 'en_US'}) => ImportConfigService(h.db).save(
    accountId: acct,
    skipRows: 0,
    mappings: {'date': 'Date', 'amount': 'Amount', 'description': 'Description', '__balanceMode': 'cumulative'},
    formula: const [],
    hashColumns: const [],
    numberLocale: numberLocale,
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Finder filled(String label) => find.widgetWithText(FilledButton, label);
  Finder outlined(String label) => find.widgetWithText(OutlinedButton, label);
  bool enabled(WidgetTester tester, Finder button) => tester.widget<ButtonStyleButton>(button).onPressed != null;
  Finder iconIn(Finder button, IconData icon) => find.descendant(of: button, matching: find.byIcon(icon));

  testWidgets('mapper: a filled Next without an icon, off until date and amount are mapped', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      expect(filled(s.next), findsOneWidget);
      expect(find.descendant(of: filled(s.next), matching: find.byType(Icon)), findsNothing);
      expect(enabled(tester, filled(s.next)), isFalse, reason: 'nothing is mapped yet');
      expect(outlined(s.letMeEdit), findsNothing, reason: 'the mapper has no secondary action');

      await h.mapColumn(tester, 'Operation Date *', 'Date');
      expect(enabled(tester, filled(s.next)), isFalse, reason: 'the amount is still missing');
      await h.mapColumn(tester, 'amount *', 'Amount');
      expect(enabled(tester, filled(s.next)), isTrue, reason: 'date and amount are what the step enforces');
      await h.mapColumn(tester, 'Description *', 'Description');
      expect(enabled(tester, filled(s.next)), isTrue);

      await tap(tester, filled(s.next));
      expect(find.text(s.importSummary), findsOneWidget, reason: 'the confirm step');
      expect(filled(s.importButton), findsOneWidget);
      expect(iconIn(filled(s.importButton), Icons.check), findsOneWidget);
      expect(enabled(tester, filled(s.importButton)), isTrue);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('confirm step: a blocked import says why on the row of its disabled Import button', (tester) async {
    await h.importer.importTransactions(
      preview: statement,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
      ],
      accountId: acct,
      numberLocaleOverride: 'en_US',
    );
    await saveConfig();
    // Imported under "Auto": no number format saved for the stored text.
    await (h.db.update(
      h.db.importConfigs,
    )..where((c) => c.accountId.equals(acct))).write(const ImportConfigsCompanion(numberLocale: Value(null)));
    final stored = (await h.importer.previewFromStoredRows(acct))!;
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, storedPreview: stored));
    try {
      await tap(tester, filled(s.next));
      final import = filled(s.importButton);
      expect(import, findsOneWidget);
      expect(iconIn(import, Icons.check), findsOneWidget);
      expect(enabled(tester, import), isFalse);
      final bar = find.ancestor(of: import, matching: find.byType(Row)).first;
      expect(
        find.descendant(of: bar, matching: find.text(s.numberFormatRequiredForRerun)),
        findsOneWidget,
        reason: 'the reason, before the button',
      );
      expect(find.descendant(of: bar, matching: find.byIcon(Icons.error_outline)), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('quick confirm: an outlined Let me edit before a filled Import', (tester) async {
    await saveConfig();
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      final edit = outlined(s.letMeEdit);
      final import = filled(s.importButton);
      expect(edit, findsOneWidget);
      expect(import, findsOneWidget);
      expect(iconIn(edit, Icons.edit), findsOneWidget);
      expect(iconIn(import, Icons.check), findsOneWidget);
      expect(enabled(tester, edit), isTrue);
      expect(enabled(tester, import), isTrue);
      expect(tester.getTopLeft(edit).dx, lessThan(tester.getTopLeft(import).dx), reason: 'the secondary action comes first');

      await tap(tester, edit);
      expect(filled(s.next), findsOneWidget, reason: 'the mapper');
      expect(enabled(tester, filled(s.next)), isTrue, reason: 'the saved config maps every required field');
    } finally {
      await h.unmount(tester);
    }
  });
}
