// The import wizard's number-format picker:
//  * the formats it offers, each named in its own language, after "Auto";
//  * "Auto" is no choice: importing with it never clears the number format the
//    account already has saved (the wizard's config save used to overwrite it
//    with null — also right after the import itself had stored the format it
//    resolved for a new account).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

void main() {
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

  Future<void> saveConfig({String? numberLocale}) => ImportConfigService(h.db).save(
    accountId: acct,
    skipRows: 0,
    mappings: {'date': 'Date', 'amount': 'Amount', 'description': 'Description', '__balanceMode': 'cumulative'},
    formula: const [],
    hashColumns: const [],
    numberLocale: numberLocale,
  );

  Future<String?> savedNumberLocale() async => (await ImportConfigService(h.db).getByAccount(acct))?.numberLocale;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  /// From the quick confirm (a saved config covers the mapping) to the full
  /// confirm step, where the number-format picker is.
  Future<void> openConfirmStep(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(OutlinedButton, 'Let me edit'));
    await tap(tester, find.widgetWithText(FilledButton, 'Next'));
    expect(find.byKey(const Key('numberLocaleDropdown')), findsOneWidget);
  }

  List<(String?, String?)> pickerItems(WidgetTester tester) => [
    for (final item in tester.widget<DropdownButton<String?>>(find.byKey(const Key('numberLocaleDropdown'))).items!)
      (item.value, (item.child as Text).data),
  ];

  testWidgets('the formats offered: Auto (the app locale), then each format named in its own language', (tester) async {
    await saveConfig(numberLocale: 'en_US');
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await openConfirmStep(tester);
      expect(pickerItems(tester), [
        (null, 'Auto (en_US)'),
        ('it_IT', 'Italiano (it_IT)'),
        ('en_US', 'English / US (en_US)'),
        ('en_GB', 'English / UK (en_GB)'),
        ('de_DE', 'Deutsch (de_DE)'),
        ('fr_FR', 'Français (fr_FR)'),
        ('es_ES', 'Español (es_ES)'),
      ]);
    } finally {
      await h.unmount(tester);
    }
  });

  // The app runs en_GB; the account's statements are en_US (the saved format).
  testWidgets('importing with "Auto" picked keeps the account\'s saved number format', (tester) async {
    await saveConfig(numberLocale: 'en_US');
    await h.pump(
      tester,
      ImportScreen(preselectedAccountId: acct, testPreview: statement),
      locale: 'en_GB',
    );
    try {
      await openConfirmStep(tester);
      await tap(tester, find.byKey(const Key('numberLocaleDropdown')));
      await tap(tester, find.text('Auto (en_GB)').last);
      await tap(tester, find.widgetWithText(FilledButton, 'Import'));
      expect(find.text('Import Complete'), findsOneWidget);

      expect(await savedNumberLocale(), 'en_US');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('a format picked explicitly replaces the saved one', (tester) async {
    await saveConfig(numberLocale: 'en_US');
    await h.pump(
      tester,
      ImportScreen(preselectedAccountId: acct, testPreview: statement),
      locale: 'en_GB',
    );
    try {
      await openConfirmStep(tester);
      await tap(tester, find.byKey(const Key('numberLocaleDropdown')));
      await tap(tester, find.text('English / UK (en_GB)').last);
      await tap(tester, find.widgetWithText(FilledButton, 'Import'));
      expect(find.text('Import Complete'), findsOneWidget);

      expect(await savedNumberLocale(), 'en_GB');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('an account without a saved format keeps the one its first "Auto" import stored', (tester) async {
    await saveConfig();
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await tap(tester, find.widgetWithText(FilledButton, 'Import'));
      expect(find.text('Import Complete'), findsOneWidget);

      expect(await savedNumberLocale(), 'en_US', reason: 'the import stores the format it read the file with');
    } finally {
      await h.unmount(tester);
    }
  });
}
