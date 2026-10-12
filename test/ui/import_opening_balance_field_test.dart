// The "Actual balance" field (opening balance — see
// TransactionService.planOpeningBalance): visible only where a balance is a
// running sum from 0 (cumulative, filtered); an unreadable number blocks
// Import; the amount it implies is masked in privacy mode while the row
// counts and the date stay readable.
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<ProviderContainer> pumpQuickConfirm(WidgetTester tester, {bool private = false}) async {
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
          privacyModeProvider.overrideWith((ref) => private),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
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

  group('field visibility by mode', () {
    for (final mode in ['cumulative', 'filtered']) {
      testWidgets('$mode: the field shows', (tester) async {
        await importer.importTransactions(
          preview: statement,
          mappings: mappings,
          accountId: acct,
          balanceMode: mode,
          numberLocaleOverride: 'en_US',
        );
        await saveConfig(mode);
        await pumpQuickConfirm(tester);
        try {
          expect(find.byKey(const Key('actualBalanceField')), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });
    }

    for (final mode in ['column', 'none']) {
      testWidgets('$mode: the field is absent', (tester) async {
        await importer.importTransactions(
          preview: statement,
          mappings: mappings,
          accountId: acct,
          balanceMode: mode,
          numberLocaleOverride: 'en_US',
        );
        await saveConfig(mode);
        await pumpQuickConfirm(tester);
        try {
          expect(find.byKey(const Key('actualBalanceField')), findsNothing);
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  testWidgets('a number the locale cannot read disables Import', (tester) async {
    await importer.importTransactions(
      preview: statement,
      mappings: mappings,
      accountId: acct,
      balanceMode: 'cumulative',
      numberLocaleOverride: 'en_US',
    );
    await saveConfig('cumulative');
    await pumpQuickConfirm(tester);
    try {
      final importButton = find.widgetWithText(FilledButton, 'Import');
      expect(tester.widget<FilledButton>(importButton).onPressed, isNotNull, reason: 'enabled before anything is typed');

      await tester.enterText(find.byKey(const Key('actualBalanceField')), 'not a number');
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
    await importer.importTransactions(
      preview: statement,
      mappings: mappings,
      accountId: acct,
      balanceMode: 'cumulative',
      numberLocaleOverride: 'en_US',
    );
    await saveConfig('cumulative');
    final container = await pumpQuickConfirm(tester);
    try {
      // App history alone: 100 − 40 = 60. Typing 560 implies +500.
      await tester.enterText(find.byKey(const Key('actualBalanceField')), '560');
      await tester.pump();

      final openingRow = find.ancestor(of: find.text('Opening balance'), matching: find.byType(Row)).first;
      final value = find.descendant(of: openingRow, matching: find.byWidgetPredicate((w) => w is Text && w.data == '+500.00'));
      expect(value, findsOneWidget, reason: 'the typed balance minus what the app shows');
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
      await importer.importTransactions(
        preview: statement,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await saveConfig('cumulative');
      await pumpQuickConfirm(tester, private: true);
      try {
        await tester.enterText(find.byKey(const Key('actualBalanceField')), '560');
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
        await tester.tap(find.widgetWithText(FilledButton, 'Import'));
        await settleImport(tester);

        final rows = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate)])).get();
        final opening = rows.firstWhere((t) => t.description == 'Opening balance');
        expect(opening.amount, 500, reason: "560 typed − 60 the app's own two rows show");
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

    testWidgets('typing the balance the app already shows adds nothing, and the result screen says nothing about it', (tester) async {
      await importer.importTransactions(
        preview: statement,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await saveConfig('cumulative');
      await pumpQuickConfirm(tester);
      try {
        await tester.enterText(find.byKey(const Key('actualBalanceField')), '60');
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
        await tester.tap(find.widgetWithText(FilledButton, 'Import'));
        await settleImport(tester);

        final rows = await db.select(db.transactions).get();
        expect(rows.any((t) => t.description == 'Opening balance'), isFalse);
        expect(find.text('Opening balance'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });
}
