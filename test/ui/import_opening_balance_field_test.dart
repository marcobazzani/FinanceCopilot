// The import preview's "Balance on <date>" field (opening balance — see
// TransactionService.planOpeningBalance) is offered only when the account
// holds nothing but the imported file afterwards: it is empty, or the file
// replaces every row it has. On an account with earlier rows, or when the
// import is re-run from the account's stored rows, it is absent: a
// difference from the bank there is a gap in the history, not an opening.
// It is also offered only where a balance is a running sum from 0
// (cumulative, filtered). An unreadable number blocks Import; the amount it
// implies is masked in privacy mode while the row counts and the date stay
// readable.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  // The file starts on 2026-03-01.
  const statement = FilePreview(
    columns: ['Date', 'Amount'],
    rows: [
      {'Date': '2026-03-01', 'Amount': '100'},
      {'Date': '2026-03-05', 'Amount': '-40'},
    ],
    totalRows: 2,
    numberLocale: 'en_US',
  );
  const mappings = [
    ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
  ];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<void> saveConfig(String balanceMode) => ImportConfigService(db).save(
    accountId: acct,
    skipRows: 0,
    mappings: {'date': 'Date', 'amount': 'Amount', '__balanceMode': balanceMode},
    formula: const [],
    hashColumns: const [],
    numberLocale: 'en_US',
  );

  /// A row already in the account, hand-entered.
  Future<void> existingRow(DateTime day, double amount) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: day,
          valueDate: day,
          amount: amount,
          description: const Value('Earlier row'),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// The quick confirm of importing [statement] into the account, as after
  /// picking the file; [fromStoredRows]: of re-running the import from the
  /// account's stored rows instead.
  Future<ProviderContainer> pumpConfirm(WidgetTester tester, {bool private = false, bool fromStoredRows = false}) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = fromStoredRows
        ? ImportScreen(
            preselectedAccountId: acct,
            storedPreview: (await importer.previewFromStoredRows(acct, numberLocale: 'en_US'))!,
          )
        : ImportScreen(preselectedAccountId: acct, testPreview: statement);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => private),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget, reason: 'the quick confirm is shown');
    return ProviderScope.containerOf(tester.element(find.byWidget(screen)));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Pumps through the import's own async chain (recalculate, the opening
  /// balance, classify) to the result screen.
  Future<void> settleImport(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapImport(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await settleImport(tester);
  }

  final field = find.byKey(const Key('actualBalanceField'));

  group('field visibility by mode, on an empty account', () {
    for (final mode in ['cumulative', 'filtered']) {
      testWidgets('$mode: the field shows', (tester) async {
        await saveConfig(mode);
        await pumpConfirm(tester);
        try {
          expect(field, findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });
    }

    for (final mode in ['column', 'none']) {
      testWidgets('$mode: the field is absent', (tester) async {
        await saveConfig(mode);
        await pumpConfirm(tester);
        try {
          expect(field, findsNothing);
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  group('offered only when the file is the account\'s whole history', () {
    testWidgets('an account with a row before the file starts: the field is absent', (tester) async {
      await existingRow(DateTime(2026, 2, 15), 500);
      await saveConfig('cumulative');
      await pumpConfirm(tester);
      try {
        expect(field, findsNothing, reason: 'it used to be offered on any account');
        expect(find.text('Predicted balance'), findsOneWidget, reason: 'the rest of the preview is unchanged');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a file that replaces every row: the field shows, and the typed balance becomes the opening', (tester) async {
      await existingRow(DateTime(2026, 3, 2), 300);
      await existingRow(DateTime(2026, 3, 4), -20);
      await saveConfig('cumulative');
      await pumpConfirm(tester);
      try {
        final replaced = find.ancestor(of: find.text('Rows to replace'), matching: find.byType(Row)).first;
        expect(
          find.descendant(of: replaced, matching: find.text('2')),
          findsOneWidget,
          reason: 'both earlier rows are replaced',
        );
        await tester.enterText(field, '560');
        await tester.pump();
        await tapImport(tester);

        final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
        expect(rows.where((t) => t.description == 'Earlier row'), isEmpty, reason: 'the file replaced them');
        final opening = rows.singleWhere((t) => t.description == 'Opening balance');
        expect(opening.amount, 500, reason: '560 typed − 60 from the file');
        expect(opening.operationDate, DateTime(2026, 2, 28));
        expect(rows.last.balanceAfter, 560);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('re-running the import from the account\'s stored rows: the field is absent', (tester) async {
      await importer.importTransactions(
        preview: statement,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await saveConfig('cumulative');
      await pumpConfirm(tester, fromStoredRows: true);
      try {
        expect(field, findsNothing, reason: "the account's own history, not a first statement");
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('a number the locale cannot read disables Import', (tester) async {
    await saveConfig('cumulative');
    await pumpConfirm(tester);
    try {
      final importButton = find.widgetWithText(FilledButton, 'Import');
      expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull, reason: 'enabled before anything is typed');

      await tester.enterText(field, 'not a number');
      await tester.pump();

      expect(find.text('Invalid number'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(importButton).onPressed,
        isNull,
        reason: 'an unreadable balance blocks the import, never dropped silently',
      );
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the opening amount it implies is masked in privacy mode; the label and the date stay readable', (tester) async {
    await saveConfig('cumulative');
    final container = await pumpConfirm(tester);
    try {
      // The file alone: 100 − 40 = 60. Typing 560 implies +500.
      await tester.enterText(field, '560');
      await tester.pump();

      final openingRow = find.ancestor(of: find.text('Opening balance'), matching: find.byType(Row)).first;
      final value = find.descendant(of: openingRow, matching: find.byWidgetPredicate((w) => w is Text && w.data == '+500.00'));
      expect(value, findsOneWidget, reason: 'the typed balance minus what the file adds up to');
      expect(masked(value), isFalse, reason: 'nothing is masked before privacy is on');
      expect(masked(find.text('Opening balance')), isFalse, reason: 'a label is no figure');

      container.read(privacyModeProvider.notifier).state = true;
      await tester.pump();

      expect(masked(value), isTrue, reason: 'the opening amount is a position size');
      expect(masked(find.text('Opening balance')), isFalse, reason: 'the label stays readable');
      // The field's own label names the date, not an amount, and stays
      // readable throughout.
      expect(masked(find.textContaining('Balance on')), isFalse);
    } finally {
      await unmount(tester);
    }
  });

  group('tapping Import with a typed balance', () {
    testWidgets('adds the opening-balance transaction and reports it, masked, on the result screen', (tester) async {
      await saveConfig('cumulative');
      await pumpConfirm(tester, private: true);
      try {
        await tester.enterText(field, '560');
        await tester.pump();
        await tapImport(tester);

        final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
        final opening = rows.firstWhere((t) => t.description == 'Opening balance');
        expect(opening.amount, 500, reason: '560 typed − 60 the two imported rows show');
        expect(opening.operationDate, DateTime(2026, 2, 28), reason: 'the day before the earliest imported row');
        expect(opening.currency, 'EUR');
        expect(opening.status, TransactionStatus.settled);
        expect(opening.rawMetadata, isNull, reason: 'an ordinary row, not one the next re-import would delete');
        final cat = await CategoryService(db).getByKey(CategoryService.openingBalanceIncomeKey);
        expect(opening.categoryId, cat!.id);
        expect(rows.last.balanceAfter, 560);

        final addedLine = find.text('Opening balance');
        expect(addedLine, findsOneWidget, reason: 'the result screen names what it added');
        final addedValue = find.text('+500.00');
        expect(addedValue, findsOneWidget);
        expect(masked(addedValue), isTrue, reason: 'privacy mode was already on for this test');
        expect(masked(addedLine), isFalse, reason: 'the label stays readable');

        // "Import Another" resets the wizard, including the typed balance
        // and the amount just added — nothing from this import leaks into
        // the next one.
        await tester.tap(find.widgetWithText(OutlinedButton, 'Import Another'));
        await settle(tester);
        expect(find.text('Opening balance'), findsNothing);
        expect(find.text('Import Preview'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('typing the balance the file already adds up to adds nothing, and the result screen says nothing about it', (tester) async {
      await saveConfig('cumulative');
      await pumpConfirm(tester);
      try {
        await tester.enterText(field, '60');
        await tester.pump();
        await tapImport(tester);

        final rows = await db.select(db.transactions).get();
        expect(rows.any((t) => t.description == 'Opening balance'), isFalse);
        expect(find.text('Opening balance'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}
