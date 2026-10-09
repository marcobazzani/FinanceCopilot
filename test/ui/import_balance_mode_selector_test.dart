// Pins the import wizard's "Balance per row" selector before it binds the
// balance mode itself instead of its stored name: which segment is selected,
// what each mode shows, what switching modes clears, and the mode that is
// imported and saved.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';
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
    columns: ['Date', 'Description', 'Amount', 'Balance', 'State'],
    rows: [
      {'Date': '11/05/2022', 'Description': 'Salary', 'Amount': '100', 'Balance': '100', 'State': 'DONE'},
      {'Date': '12/05/2022', 'Description': 'Rent', 'Amount': '-30', 'Balance': '100', 'State': 'FAILED'},
      {'Date': '13/05/2022', 'Description': 'Refund', 'Amount': '10', 'Balance': '110', 'State': 'DONE'},
    ],
    totalRows: 3,
    numberLocale: 'en_US',
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> tapSegment(WidgetTester tester, String label) => tap(tester, find.text(label).first);

  /// The selected segment carries the selection check.
  bool selected(String label) => find
      .descendant(
        of: find.ancestor(of: find.text(label).first, matching: find.byType(TextButton)).first,
        matching: find.byIcon(Icons.check),
      )
      .evaluate()
      .isNotEmpty;

  Finder balanceAfterRow() => find.text(s.fieldLabel('balanceAfter'));
  String? mappedBalanceColumn(WidgetTester tester) {
    final row = find.ancestor(of: balanceAfterRow(), matching: find.byType(Row)).first;
    return tester
        .widget<DropdownButtonFormField<String>>(find.descendant(of: row, matching: find.byType(DropdownButtonFormField<String>)))
        .initialValue;
  }

  testWidgets('pin: modes, what each shows and what switching clears', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      expect(find.byType(SegmentedButton<BalanceMode>), findsOneWidget, reason: 'the selector binds the mode itself');
      expect(selected(s.recalcCumulative), isTrue, reason: 'no saved config: the default mode');
      expect(selected(s.balanceFromColumn), isFalse);
      expect(selected(s.recalcFiltered), isFalse);
      expect(find.text(s.balanceCumulativeHelp), findsOneWidget);
      expect(balanceAfterRow(), findsNothing);
      expect(find.text(s.filterColumn), findsNothing);

      await tapSegment(tester, s.balanceFromColumn);
      expect(selected(s.balanceFromColumn), isTrue);
      expect(find.text(s.balanceCumulativeHelp), findsNothing);
      expect(balanceAfterRow(), findsOneWidget);
      await h.mapColumn(tester, s.fieldLabel('balanceAfter'), 'Balance');
      expect(mappedBalanceColumn(tester), 'Balance');

      await tapSegment(tester, s.recalcCumulative);
      expect(balanceAfterRow(), findsNothing);
      await tapSegment(tester, s.balanceFromColumn);
      expect(mappedBalanceColumn(tester), isNull, reason: 'leaving column mode drops the balance column');

      await tapSegment(tester, s.recalcFiltered);
      expect(selected(s.recalcFiltered), isTrue);
      expect(balanceAfterRow(), findsNothing);
      expect(find.text(s.filterColumn), findsOneWidget);
      await h.mapColumn(tester, s.filterColumn, 'State');
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'DONE')).selected, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'FAILED')).selected, isTrue);

      await tapSegment(tester, s.recalcCumulative);
      await tapSegment(tester, s.recalcFiltered);
      expect(find.widgetWithText(FilterChip, 'DONE'), findsNothing, reason: 'leaving filtered mode drops the filter column');
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('pin: the filtered mode picked is the one imported and saved', (tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await h.mapColumn(tester, 'Operation Date *', 'Date');
      await h.mapColumn(tester, 'amount *', 'Amount');
      await h.mapColumn(tester, 'Description *', 'Description');
      await tapSegment(tester, s.recalcFiltered);
      await h.mapColumn(tester, s.filterColumn, 'State');
      await tap(tester, find.widgetWithText(FilterChip, 'FAILED'));
      await tap(tester, find.widgetWithText(FilledButton, s.next));
      await tap(tester, find.widgetWithText(FilledButton, s.importButton));
      expect(find.text(s.importComplete), findsOneWidget);

      final saved = jsonDecode((await ImportConfigService(h.db).getByAccount(acct))!.mappingsJson) as Map<String, dynamic>;
      expect(saved['__balanceMode'], 'filtered');
      expect(saved['__balanceFilterColumn'], 'State');
      expect(jsonDecode(saved['__balanceFilterInclude'] as String), ['DONE']);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('pin: a saved column mode is selected with its balance column', (tester) async {
    await ImportConfigService(h.db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {'date': 'Date', 'amount': 'Amount', 'description': 'Description', 'balanceAfter': 'Balance', '__balanceMode': 'column'},
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, s.letMeEdit));
      expect(selected(s.balanceFromColumn), isTrue);
      expect(selected(s.recalcCumulative), isFalse);
      expect(mappedBalanceColumn(tester), 'Balance');
    } finally {
      await h.unmount(tester);
    }
  });
}
