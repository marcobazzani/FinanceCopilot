// The import wizard's preview tables show the file's raw rows. The cells of
// the columns mapped to position-size fields — amount (also a formula term or
// the balance-difference column), balance, quantity, commission — blur in
// privacy mode; unmapped columns, dates, descriptions, prices and exchange
// rates stay readable. The inline previews of the amounts (formula, balance
// difference) and fees the import will compute blur their figures and keep
// their labels readable. Each test asserts a masked figure and a readable one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
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
    columns: ['Date', 'Description', 'Amount', 'Balance', 'Memo'],
    rows: [
      {'Date': '11/05/2022', 'Description': 'Salary', 'Amount': '2500.00', 'Balance': '3500.00', 'Memo': 'M-1'},
      {'Date': '12/05/2022', 'Description': 'Rent', 'Amount': '-1234.56', 'Balance': '2265.44', 'Memo': 'M-2'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> setPrivate(WidgetTester tester, bool value) async {
    ProviderScope.containerOf(tester.element(find.byType(ImportScreen))).read(privacyModeProvider.notifier).state = value;
    await h.settle(tester, frames: 4);
  }

  /// The table cell showing [text] (a preview table is the only place it shows).
  Finder cell(String text) => find.descendant(of: find.byType(DataTable), matching: find.text(text));
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('mapper: the amount and balance columns blur once mapped; dates, descriptions and unmapped columns do not', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await setPrivate(tester, true);
      expect(masked(cell('-1234.56')), isFalse, reason: 'an unmapped column is just file text');

      await h.mapColumn(tester, 'Operation Date *', 'Date');
      await h.mapColumn(tester, 'amount *', 'Amount');
      await h.mapColumn(tester, 'Description *', 'Description');
      await tap(tester, find.text(s.balanceFromColumn).first);
      await h.mapColumn(tester, s.fieldLabel('balanceAfter'), 'Balance');

      expect(cell('-1234.56'), findsOneWidget);
      expect(masked(cell('-1234.56')), isTrue, reason: 'an amount is position size');
      expect(masked(cell('2265.44')), isTrue, reason: 'a balance is position size');
      expect(masked(cell('Rent')), isFalse, reason: 'a description is not');
      expect(masked(cell('12/05/2022')), isFalse, reason: 'a date is not');
      expect(masked(cell('M-2')), isFalse, reason: 'an unmapped column is not');
      expect(
        masked(find.descendant(of: find.byType(DataTable), matching: find.text('Amount'))),
        isFalse,
        reason: 'column names stay readable',
      );

      await setPrivate(tester, false);
      expect(masked(cell('-1234.56')), isFalse, reason: 'nothing blurs outside privacy mode');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('mapper: formula and balance-difference amount columns blur', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await setPrivate(tester, true);
      await tap(tester, find.widgetWithText(OutlinedButton, s.amountModeBalance));
      // Balance Δ starts on the first column; point it at the balances.
      final balanceColumn = find.ancestor(of: find.text(s.balanceColumn), matching: find.byType(Row)).first;
      await tap(tester, find.descendant(of: balanceColumn, matching: find.byType(DropdownButtonFormField<String>)));
      await tap(tester, find.text('Balance').last);
      expect(masked(cell('2265.44')), isTrue, reason: 'the balance the amounts are derived from');
      expect(masked(cell('-1234.56')), isFalse, reason: 'the Amount column is not mapped in this mode');

      await tap(tester, find.widgetWithText(OutlinedButton, s.amountModeFormula));
      // The formula starts with a term on the first column: point it at Amount.
      final term = find.ancestor(of: find.text('+'), matching: find.byType(Row)).first;
      await tap(tester, find.descendant(of: term, matching: find.byType(DropdownButtonFormField<String>)));
      await tap(tester, find.text('Amount').last);
      expect(masked(cell('-1234.56')), isTrue, reason: 'a formula term is an amount');
      expect(masked(cell('Rent')), isFalse);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('mapper: quantity and commission blur; price and exchange rate stay readable', (tester) async {
    const trades = FilePreview(
      columns: ['Day', 'Code', 'Units', 'Unit price', 'FX', 'Fee'],
      rows: [
        {'Day': '11/05/2022', 'Code': 'IE00B4L5Y983', 'Units': '12', 'Unit price': '81.25', 'FX': '1.0850', 'Fee': '2.95'},
      ],
      totalRows: 1,
      numberLocale: 'en_US',
    );
    await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: trades));
    try {
      await setPrivate(tester, true);
      await h.mapColumn(tester, 'Operation Date *', 'Day');
      await h.mapColumn(tester, 'ISIN *', 'Code');
      await h.mapColumn(tester, 'Quantity', 'Units');
      await h.mapColumn(tester, 'Price', 'Unit price');
      await h.mapColumn(tester, 'Exchange Rate', 'FX');
      await h.mapColumn(tester, 'Commission *', 'Fee');

      expect(masked(cell('12')), isTrue, reason: 'units held are position size');
      expect(masked(cell('2.95')), isTrue, reason: 'a commission paid is position size');
      expect(masked(cell('81.25')), isFalse, reason: 'a unit price is market data');
      expect(masked(cell('1.0850')), isFalse, reason: 'an exchange rate is market data');
      expect(masked(cell('IE00B4L5Y983')), isFalse);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('quick confirm: the header preview blurs the mapped amount, not the description', (tester) async {
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {'date': 'Date', 'amount': 'Amount', 'description': 'Description', '__balanceMode': 'cumulative'},
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      expect(find.text(s.headerPreviewTitle), findsOneWidget, reason: 'the quick confirm');
      await setPrivate(tester, true);
      expect(masked(cell('-1234.56')), isTrue, reason: 'the mapped amount');
      expect(masked(cell('Rent')), isFalse, reason: 'a description');
      expect(masked(cell('2265.44')), isFalse, reason: 'the balance column is not mapped in cumulative mode');
    } finally {
      await h.unmount(tester);
    }
  });

  group('inline previews: the computed amounts blur, their labels do not', () {
    bool readable(Finder f) => f.evaluate().isNotEmpty && !masked(f);

    testWidgets('formula amounts', (tester) async {
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await tap(tester, find.widgetWithText(OutlinedButton, s.amountModeFormula));
        final term = find.ancestor(of: find.text('+'), matching: find.byType(Row)).first;
        await tap(tester, find.descendant(of: term, matching: find.byType(DropdownButtonFormField<String>)));
        await tap(tester, find.text('Amount').last);
        expect(find.text('${s.previewLabel}: 2,500.00  ·  -1,234.56'), findsOneWidget, reason: 'the plain sentence outside privacy mode');

        await setPrivate(tester, true);
        expect(masked(find.text('-1,234.56')), isTrue, reason: 'a computed amount is position size');
        expect(masked(find.text('2,500.00')), isTrue);
        expect(readable(find.textContaining('${s.previewLabel}: ')), isTrue, reason: 'the label stays readable');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('balance-difference amounts', (tester) async {
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
      try {
        await tap(tester, find.widgetWithText(OutlinedButton, s.amountModeBalance));
        final balanceColumn = find.ancestor(of: find.text(s.balanceColumn), matching: find.byType(Row)).first;
        await tap(tester, find.descendant(of: balanceColumn, matching: find.byType(DropdownButtonFormField<String>)));
        await tap(tester, find.text('Balance').last);
        expect(find.text('${s.previewLabel}: ${s.balanceDiffFormula} → 3,500.00 ${s.firstRowLabel}  ·  -1,234.56'), findsOneWidget);

        await setPrivate(tester, true);
        expect(masked(find.text('-1,234.56')), isTrue, reason: 'a derived amount is position size');
        expect(masked(find.text('3,500.00')), isTrue, reason: 'the first balance is position size');
        expect(readable(find.textContaining(s.balanceDiffFormula)), isTrue, reason: 'the formula stays readable');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('computed fees', (tester) async {
      const trades = FilePreview(
        columns: ['Gross', 'Units', 'Unit price', 'FX', 'Day', 'Code'],
        rows: [
          {'Gross': '1012.50', 'Units': '10', 'Unit price': '100', 'FX': '1', 'Day': '11/05/2022', 'Code': 'IE00B4L5Y983'},
        ],
        totalRows: 1,
        numberLocale: 'en_US',
      );
      await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: trades));
      try {
        await tap(tester, find.text(s.computedLabel).first);
        expect(readable(find.text('${s.previewLabel}: ${s.notApplicable}')), isTrue, reason: 'nothing to compute yet');
        await h.mapColumn(tester, 'Amount', 'Gross');
        await h.mapColumn(tester, 'Quantity', 'Units');
        await h.mapColumn(tester, 'Price', 'Unit price');
        await h.mapColumn(tester, 'Exchange Rate', 'FX');
        expect(find.text('${s.previewLabel}: 12.50'), findsOneWidget);

        await setPrivate(tester, true);
        expect(masked(find.text('12.50')), isTrue, reason: 'a commission paid is position size');
        expect(readable(find.textContaining('${s.previewLabel}: ')), isTrue);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
