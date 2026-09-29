// Import preview: the sum of the amounts about to be imported and the
// predicted balance are position size and privacy mode masks them; the row
// counts next to them (parsed, skipped, replaced) are shape and stay readable.
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
      mappings: {
        'date': 'Date',
        'valueDate': 'Date',
        'amount': 'Amount',
        'description': 'Description',
        // Column mode reads the balance from the file and predicts none.
        '__balanceMode': 'cumulative',
      },
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

  /// The value cell of the preview row labelled [label].
  Finder valueOf(String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return find.descendant(of: row, matching: find.byWidgetPredicate((w) => w is Text && w.data != null && w.data != label));
  }

  testWidgets('import preview: the amount sum and predicted balance are masked, the row count stays readable', (tester) async {
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
      expect(find.text('Import Preview'), findsOneWidget, reason: 'the saved config leads straight to the quick confirm with its preview');
      expect(masked(valueOf('Import amount sum')), isFalse, reason: 'nothing is masked before privacy is on');

      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);

      final sum = valueOf('Import amount sum');
      expect(sum, findsOneWidget);
      expect(tester.widget<Text>(sum).data, '1,265.44');
      expect(masked(sum), isTrue, reason: 'the money being imported is position size');
      final balance = valueOf('Predicted balance');
      expect(balance, findsOneWidget);
      expect(masked(balance), isTrue, reason: 'a balance is position size');
      final parsed = valueOf('Parsed rows');
      expect(tester.widget<Text>(parsed).data, '2');
      expect(masked(parsed), isFalse, reason: 'a count of rows is shape, not magnitude');
      expect(masked(find.text('Import amount sum')), isFalse, reason: 'labels stay readable');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
