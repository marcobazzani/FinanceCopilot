import 'dart:convert';
// Import wizard in "re-run from stored data" mode and the value-date-from-text
// mapping option.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  FilePreview kbcPreview() => FilePreview(
    columns: const ['Column 1', 'Column 2', 'Column 3'],
    rows: const [
      {'Column 1': '11 May 2022', 'Column 2': 'POS Revolut1946 20220509', 'Column 3': '-2500.00'},
      {'Column 1': '11 May 2022', 'Column 2': 'POS Revolut1946 20220510', 'Column 3': '-134.33'},
      {'Column 1': '12 May 2022', 'Column 2': 'Non-Euro Point Of Sales Fee', 'Column 3': '-0.46'},
    ],
    totalRows: 3,
    numberLocale: 'en_US',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'KBC'));
    // Original import: plain column mappings, saved config as the wizard would.
    await importer.importTransactions(
      preview: kbcPreview(),
      mappings: const [
        ColumnMapping(sourceColumn: 'Column 1', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Column 1', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'Column 3', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Column 2', targetField: 'description'),
      ],
      accountId: acct,
      numberLocaleOverride: 'en_US',
    );
    await ImportConfigService(db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {
        'date': 'Column 1',
        'valueDate': 'Column 1',
        'amount': 'Column 3',
        'description': 'Column 2',
        '__balanceMode': 'none',
        // A filter that shaped the original import (every stored row passed it).
        '__rowFilters': '[{"column":"Column 2","op":"notContains","value":"ZZZ"}]',
        '__filterCombine': 'all',
      },
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    // A manual row that must survive a re-run.
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2022, 5, 12),
            valueDate: DateTime(2022, 5, 12),
            amount: -7,
            description: const Value('Coffee (manual)'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('stored-rows wizard: banner, no file toolbar, quick-confirm from saved config', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final preview = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: ImportScreen(preselectedAccountId: acct, storedPreview: preview),
        ),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('rerunImportBanner')), findsOneWidget);
    expect(find.text('Open file'), findsNothing);
    // Saved config covers everything → quick confirm with an Import button.
    expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('re-run with a saved split (regex + fallback) as value date fixes dates and keeps the manual row', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The user has configured: TxDate = 8 digits at the end of the description, else the booking date.
    await ImportConfigService(db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {
        'date': 'Column 1',
        'valueDate': 'TxDate',
        'amount': 'Column 3',
        'description': 'Column 2',
        '__balanceMode': 'none',
        '__columnSplits':
            '[{"sourceColumn":"Column 2","newColumns":["TxDate"],"byRegex":true,"delimiter":"","pattern":"(\\\\d{8})\$","fallbackColumn":"Column 1"}]',
      },
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    final preview = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: ImportScreen(preselectedAccountId: acct, storedPreview: preview),
        ),
      ),
    );
    await settle(tester);
    // Saved config covers everything → quick confirm; the derived column is visible in the summary.
    expect(find.textContaining('valueDate ← TxDate'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.operationDate), (t) => OrderingTerm.asc(t.id)])).get();
    expect(rows, hasLength(4), reason: '3 regenerated + 1 manual');
    expect(rows.any((t) => t.description == 'Coffee (manual)'), isTrue);
    final regenerated = rows.where((t) => t.rawMetadata != null).toList();
    expect(regenerated.map((t) => t.valueDate), [DateTime(2022, 5, 9), DateTime(2022, 5, 10), DateTime(2022, 5, 12)]);
    expect(regenerated.every((t) => t.operationDate.day >= 11), isTrue, reason: 'booking dates unchanged');
    // The derived column is computed, not statement data: it is NOT persisted;
    // a later re-run recomputes it from the saved split.
    expect(regenerated.first.rawMetadata, isNot(contains('TxDate')));
    expect(regenerated.first.rawMetadata, contains('"Column 2":"POS Revolut1946 20220509"'));

    // The re-run configuration is persisted for the next import (file or re-run).
    final cfg = (await ImportConfigService(db).getByAccount(acct))!;
    final saved = jsonDecode(cfg.mappingsJson) as Map<String, dynamic>;
    expect(saved['valueDate'], 'TxDate');
    expect(saved['__columnSplits'], contains('"fallbackColumn":"Column 1"'));
    expect(saved['__columnSplits'], contains('"newColumns":["TxDate"]'));
    expect(saved['__balanceMode'], 'none');
    expect(cfg.numberLocale, 'en_US');
    await teardownTree(tester);
  });

  testWidgets('a derived split column is never offered as the operation date; a saved mapping pointing to one is dropped', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A config saved by a version that allowed it: Date ← derived column (the
    // mistake that rewrote an account's booking dates with a loose regex).
    await ImportConfigService(db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {
        'date': 'TxDate',
        'valueDate': 'Column 1',
        'amount': 'Column 3',
        'description': 'Column 2',
        '__balanceMode': 'none',
        '__columnSplits':
            '[{"sourceColumn":"Column 2","newColumns":["TxDate"],"byRegex":true,"delimiter":"","pattern":"(\\\\d{8})\$","fallbackColumn":"Column 1"}]',
      },
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
    final preview = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: ImportScreen(preselectedAccountId: acct, storedPreview: preview),
        ),
      ),
    );
    await settle(tester);
    // The date mapping was dropped → the config is incomplete → no quick confirm, the mapping step is shown.
    expect(find.textContaining('date ← TxDate'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Import'), findsNothing);
    // Open the Date dropdown: bank columns only, the derived column is absent.
    final dateDropdown = find.byWidgetPredicate((w) => w is DropdownButtonFormField<String> && w.initialValue == null).first;
    await tester.scrollUntilVisible(dateDropdown, 200, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    expect(find.textContaining('must be a statement column'), findsOneWidget);
    await tester.tap(dateDropdown);
    await settle(tester);
    expect(find.text('Column 1').hitTestable(), findsWidgets);
    expect(find.text('TxDate').hitTestable(), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('stored-rows wizard: saved row filters are shown read-only, splits stay editable', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final preview = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: ImportScreen(preselectedAccountId: acct, storedPreview: preview),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Let me edit'));
    await settle(tester);
    await tester.ensureVisible(find.text('Refine rows & columns'));
    await tester.tap(find.text('Refine rows & columns'));
    await settle(tester);

    // Skip rows / no header: not applicable to stored rows.
    expect(find.text('Skip rows'), findsNothing);
    // Filters: content visible (the saved filter row + its value), controls disabled.
    expect(find.byKey(const Key('rowFiltersReadOnlyNote')), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ZZZ'), findsOneWidget, reason: 'saved filter is displayed');
    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'ZZZ')).enabled, isFalse);
    expect(tester.widget<TextButton>(find.byKey(const Key('addFilterButton'))).onPressed, isNull);
    final deleteIcons = find.descendant(of: find.byKey(const Key('rowFiltersSection')), matching: find.byIcon(Icons.delete_outline));
    expect(deleteIcons, findsOneWidget);
    expect(tester.widget<IconButton>(find.ancestor(of: deleteIcons, matching: find.byType(IconButton))).onPressed, isNull);
    // Splits: still editable.
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Add split')).onPressed, isNotNull);
    await teardownTree(tester);
  });

  testWidgets('no saved number format: no quick-confirm, no Auto, Import blocked until a format is chosen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Wipe the saved locale (an account imported under "Auto").
    await (db.update(db.importConfigs)..where((c) => c.accountId.equals(acct))).write(const ImportConfigsCompanion(numberLocale: Value(null)));
    final preview = (await importer.previewFromStoredRows(acct))!;
    expect(preview.numberLocale, isNull);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(
          home: ImportScreen(preselectedAccountId: acct, storedPreview: preview),
        ),
      ),
    );
    await settle(tester);
    // Not quick-confirm: the mapper is shown (Next, not Import).
    expect(find.widgetWithText(FilledButton, 'Import'), findsNothing);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await settle(tester);

    expect(find.byKey(const Key('numberLocaleMissingNote')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Import')).onPressed, isNull);
    expect(find.text('Import amount sum'), findsNothing, reason: 'no figures computed with a guessed locale');

    await tester.tap(find.byKey(const Key('numberLocaleDropdown')));
    await settle(tester);
    expect(find.textContaining('Auto'), findsNothing, reason: 'stored text has one format: Auto is not offered');
    await tester.tap(find.text('English / US (en_US)').last);
    await settle(tester);
    expect(find.byKey(const Key('numberLocaleMissingNote')), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Import')).onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The choice is saved for the account.
    expect((await ImportConfigService(db).getByAccount(acct))!.numberLocale, 'en_US');
    await teardownTree(tester);
  });
}
