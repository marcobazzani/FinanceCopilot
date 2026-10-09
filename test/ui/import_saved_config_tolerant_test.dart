// The import wizard reads a saved config with the shared tolerant reader. A
// saved setting of an unexpected shape used to throw inside the saved-config
// load (a microtask: nobody caught it) and left the wizard half-restored.
//
//  * A filter set stored as a JSON list is read as the list.
//  * Mappings that are not JSON, an unknown balance mode, a row filter or an
//    amount formula that cannot be read: nothing unreadable is restored, and
//    the wizard opens on the mapper instead of the quick confirm, so nothing
//    is imported in a setting the user did not save without being shown.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
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
    columns: ['Date', 'Description', 'Amount', 'State'],
    rows: [
      {'Date': '01/03/2024', 'Description': 'Salary', 'Amount': '100', 'State': 'DONE'},
      {'Date': '02/03/2024', 'Description': 'Card', 'Amount': '-30', 'State': 'FAILED'},
      {'Date': '03/03/2024', 'Description': 'Refund', 'Amount': '10', 'State': 'DONE'},
    ],
    totalRows: 3,
    numberLocale: 'en_US',
  );

  Future<void> config(String mappingsJson, {String formulaJson = '[]'}) => h.db
      .into(h.db.importConfigs)
      .insert(
        ImportConfigsCompanion.insert(
          accountId: Value(acct),
          mappingsJson: Value(mappingsJson),
          formulaJson: Value(formulaJson),
          numberLocale: const Value('en_US'),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await h.pump(tester, ImportScreen(preselectedAccountId: acct, testPreview: statement));
    expect(tester.takeException(), isNull);
  }

  void expectMapper() {
    expect(find.widgetWithText(OutlinedButton, 'Let me edit'), findsNothing, reason: 'not the quick confirm');
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget, reason: 'the mapper');
  }

  testWidgets('a filter set stored as a JSON list is restored and applied', (tester) async {
    await config(
      jsonEncode({
        'date': 'Date',
        'amount': 'Amount',
        'description': 'Description',
        '__balanceMode': 'filtered',
        '__balanceFilterColumn': 'State',
        '__balanceFilterInclude': ['DONE'],
      }),
    );
    try {
      await open(tester);
      final import = find.widgetWithText(FilledButton, 'Import');
      expect(import, findsOneWidget, reason: 'every setting read: quick confirm');
      await tester.ensureVisible(import);
      await tester.tap(import);
      await h.settle(tester, frames: 30);
      expect(find.text('Import Complete'), findsOneWidget);
      final rows = await (h.db.select(h.db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
      expect(rows.map((t) => t.balanceAfter), [100, 100, 110]);
      expect(rows.map((t) => t.status), [TransactionStatus.settled, TransactionStatus.cancelled, TransactionStatus.settled]);
      final saved = jsonDecode((await ImportConfigService(h.db).getByAccount(acct))!.mappingsJson) as Map<String, dynamic>;
      expect(saved['__balanceFilterInclude'], '["DONE"]', reason: 'written back in the stored format');
    } finally {
      await h.unmount(tester);
    }
  });

  for (final (what, mappings, formula) in [
    ('mappings that are not JSON', '{"date": ', '[]'),
    ('an unknown balance mode', '{"date":"Date","amount":"Amount","description":"Description","__balanceMode":"cumulativ"}', '[]'),
    ('a balance mode that is not text', '{"date":"Date","amount":"Amount","description":"Description","__balanceMode":1}', '[]'),
    ('a row filter that is not JSON', '{"date":"Date","amount":"Amount","description":"Description","__rowFilters":"garbage"}', '[]'),
    ('a combined column list of objects', '{"date":"Date","amount":"Amount","description":"Description","__multi_description":"[{}]"}', '[]'),
    ('an amount formula that is not JSON', '{"date":"Date","description":"Description"}', 'garbage'),
  ]) {
    testWidgets('$what: no error, the mapper instead of the quick confirm', (tester) async {
      await config(mappings, formulaJson: formula);
      try {
        await open(tester);
        expectMapper();
      } finally {
        await h.unmount(tester);
      }
    });
  }

  testWidgets('pin: a complete, readable config still opens on the quick confirm', (tester) async {
    await config('{"date":"Date","amount":"Amount","description":"Description","__balanceMode":"cumulative"}');
    try {
      await open(tester);
      expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });
}
