// The wizard's amount-formula preview shows the amount the import stores:
// the sum of the terms without the noise of binary arithmetic, as the import
// computes it (float_noise_test.dart). 0.005 + 0.030 adds up to
// 0.034999999999999996 in binary: previewed as that, it read 0.03, while the
// import stores 0.035 — 0.04 — for the same row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

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
    columns: ['Fee', 'Tax', 'Date', 'Description'],
    rows: [
      {'Fee': '0.005', 'Tax': '0.030', 'Date': '01/03/2024', 'Description': 'Charges'},
    ],
    totalRows: 1,
    numberLocale: 'en_US',
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  testWidgets('a sum with float noise previews the amount the import stores', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, s.amountModeFormula));
      await tap(tester, find.widgetWithText(OutlinedButton, s.addColumn));
      // Both terms start on the first column: point the second at Tax.
      final second = find.ancestor(of: find.text('+').at(1), matching: find.byType(Row)).first;
      await tap(tester, find.descendant(of: second, matching: find.byType(DropdownButtonFormField<String>)));
      await tap(tester, find.text('Tax').last);
      expect(find.text('${s.previewLabel}: 0.04'), findsOneWidget, reason: 'Fee + Tax = 0.035');
    } finally {
      await h.unmount(tester);
    }

    await ImportService(h.db).importTransactions(
      preview: statement,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(
          targetField: 'amount',
          formulaTerms: [
            FormulaTerm(operator: '+', sourceColumn: 'Fee'),
            FormulaTerm(operator: '+', sourceColumn: 'Tax'),
          ],
        ),
      ],
      accountId: acct,
      numberLocaleOverride: 'en_US',
    );
    final stored = (await h.db.select(h.db.transactions).getSingle()).amount;
    expect(stored, 0.035);
    expect(fmt.amountFormat('en_US').format(stored), '0.04', reason: 'what the preview shows');
  });

  test('the evaluator the preview and the import share', () {
    const terms = [
      FormulaTerm(operator: '+', sourceColumn: 'In'),
      FormulaTerm(operator: '-', sourceColumn: 'Out'),
    ];
    expect(formulaAmount(terms, const {'In': '1000.10', 'Out': '1000.05'}, locale: 'en_US'), 0.05);
    expect(formulaAmount(terms, const {'In': '1.000,10', 'Out': ''}, locale: 'it_IT'), 1000.1, reason: 'a blank cell adds 0');
    expect(formulaAmount(terms, const {'In': '', 'Out': ' '}, locale: 'en_US'), 0);
    expect(formulaAmount(terms, const {'In': '12', 'Out': 'n/a'}, locale: 'en_US'), isNull, reason: 'an unreadable cell: no amount');
    expect(formulaAmount(terms, const {'Out': '2'}, locale: 'en_US'), -2, reason: 'a column the row lacks adds 0');
  });
}
