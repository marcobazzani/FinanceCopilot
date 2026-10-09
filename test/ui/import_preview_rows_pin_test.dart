// Import preview rows: every value is 12 px; a colour or bold weight is the
// row's own (the predicted balance is bold, in the primary colour; rows to
// replace are orange); position-size values (the amount sum, the predicted
// balance) blur in privacy mode, counts never do — and the value is plain
// text either way.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  const statement = FilePreview(
    columns: ['Date', 'Description', 'Amount', 'Balance'],
    rows: [
      {'Date': '11 May 2022', 'Description': 'Salary', 'Amount': '2500.00', 'Balance': '3500.00'},
      {'Date': '12 May 2022', 'Description': 'Rent', 'Amount': '-1234.56', 'Balance': '2265.44'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await importer.importTransactions(
      preview: statement,
      mappings: const [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ColumnMapping(sourceColumn: 'Balance', targetField: 'balanceAfter'),
      ],
      accountId: acct,
      numberLocaleOverride: 'en_US',
    );
    await ImportConfigService(db).save(
      accountId: acct,
      skipRows: 0,
      mappings: {'date': 'Date', 'valueDate': 'Date', 'amount': 'Amount', 'description': 'Description', '__balanceMode': 'cumulative'},
      formula: const [],
      hashColumns: const [],
      numberLocale: 'en_US',
    );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// The value of the preview row labelled [label]: its one text besides the label.
  Text valueOf(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return tester.widget<Text>(find.descendant(of: row, matching: find.byWidgetPredicate((w) => w is Text && w.data != label)));
  }

  Finder valueFinder(String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return find.descendant(of: row, matching: find.byWidgetPredicate((w) => w is Text && w.data != label));
  }

  testWidgets('values: 12 px, the row\'s own colour and weight; only position size blurs in privacy mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final preview = (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!;
    final screen = ImportScreen(preselectedAccountId: acct, storedPreview: preview);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    try {
      final primary = Theme.of(tester.element(find.text(s.predictedBalance))).colorScheme.primary;
      void expectStyles() {
        final parsed = valueOf(tester, s.parsedRowsLabel);
        expect(parsed.data, '2');
        expect((parsed.style?.fontSize, parsed.style?.fontWeight, parsed.style?.color), (12, null, null));
        final replace = valueOf(tester, s.rowsToReplace);
        expect((replace.style?.fontSize, replace.style?.fontWeight, replace.style?.color), (12, null, Colors.orange));
        final sum = valueOf(tester, s.importAmountSum);
        expect(sum.data, '1,265.44');
        expect((sum.style?.fontSize, sum.style?.fontWeight, sum.style?.color), (12, null, null));
        final balance = valueOf(tester, s.predictedBalance);
        expect((balance.style?.fontSize, balance.style?.fontWeight, balance.style?.color), (12, FontWeight.bold, primary));
      }

      expectStyles();
      for (final label in [s.parsedRowsLabel, s.rowsToReplace, s.importAmountSum, s.predictedBalance]) {
        expect(masked(valueFinder(label)), isFalse, reason: '$label: nothing is masked before privacy is on');
      }

      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);
      expectStyles();
      expect(masked(valueFinder(s.importAmountSum)), isTrue);
      expect(masked(valueFinder(s.predictedBalance)), isTrue);
      expect(masked(valueFinder(s.parsedRowsLabel)), isFalse);
      expect(masked(valueFinder(s.rowsToReplace)), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
