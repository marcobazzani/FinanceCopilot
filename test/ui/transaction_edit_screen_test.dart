// TransactionEditScreen under the active locale and the ledger's date
// convention:
// - the amount hint is an example the locale parser reads back;
// - editing a row writes the booking date (operationDate, the import dedup's
//   key) only when the user moved the day of a row whose booking date was in
//   sync with its value date — never on a category-only edit and never over
//   an imported booking date;
// - a double tap on the save button inserts one row;
// - the status dropdown shows localized labels, not enum names;
// - privacy mode masks the raw import values but keeps the column names.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';

/// Opens [screen] on a push once the locale is loaded, as in the app (the
/// shell watches it): the screen reads the locale once in initState.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.screen);
  final Widget Function() screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late Account account;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<Transaction> insertTx({required DateTime booked, required DateTime moved, String? rawMetadata}) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            operationDate: booked,
            valueDate: moved,
            amount: -20,
            description: const Value('Esselunga'),
            rawMetadata: Value(rawMetadata),
          ),
        );
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<Transaction>> rows() => db.select(db.transactions).get();

  Future<void> open(WidgetTester tester, {Transaction? tx, String language = 'en'}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          portableLanguageProvider.overrideWith((ref) => language),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: _Launcher(() => TransactionEditScreen(transaction: tx, account: account)),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(TransactionEditScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pickDay(WidgetTester tester, int day) async {
    await tester.tap(find.byType(TextFormField).first);
    await settle(tester);
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await settle(tester);
  }

  testWidgets('the amount hint is spelled in the active locale', (tester) async {
    await open(tester);
    try {
      final amount = tester.widget<TextField>(find.descendant(of: find.byType(TextFormField).at(1), matching: find.byType(TextField)));
      expect(amount.decoration!.hintText, '-123,45', reason: 'it_IT reads "-123.45" as -12345');
    } finally {
      await unmount(tester);
    }
  });

  group('booking date on edit', () {
    testWidgets('a category-only edit keeps the imported booking date', (tester) async {
      final tx = await insertTx(booked: DateTime(2024, 3, 8), moved: DateTime(2024, 3, 10));
      final groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
      await open(tester, tx: tx);
      try {
        await tester.tap(find.byType(CategoryField));
        await settle(tester);
        await tester.enterText(find.byKey(const Key('categoryPickerSearch')), 'Grocer');
        await settle(tester);
        await tester.tap(find.text('Groceries').last);
        await settle(tester);
        await tapSave(tester);

        final saved = (await rows()).single;
        expect(saved.categoryId, groceries);
        expect(saved.valueDate, DateTime(2024, 3, 10));
        expect(saved.operationDate, DateTime(2024, 3, 8), reason: 'the import dedup keys on the booking date');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an in-sync row moves the booking date too', (tester) async {
      final tx = await insertTx(booked: DateTime(2024, 3, 10), moved: DateTime(2024, 3, 10));
      await open(tester, tx: tx);
      try {
        await pickDay(tester, 15);
        await tapSave(tester);

        final saved = (await rows()).single;
        expect(saved.valueDate, DateTime(2024, 3, 15));
        expect(saved.operationDate, DateTime(2024, 3, 15));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an imported row moves only the value date', (tester) async {
      final tx = await insertTx(booked: DateTime(2024, 3, 8), moved: DateTime(2024, 3, 10));
      await open(tester, tx: tx);
      try {
        await pickDay(tester, 15);
        await tapSave(tester);

        final saved = (await rows()).single;
        expect(saved.valueDate, DateTime(2024, 3, 15));
        expect(saved.operationDate, DateTime(2024, 3, 8), reason: 'a booking date distinct from the value date is the bank\'s');
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('two rapid taps on Create insert one transaction', (tester) async {
    await open(tester);
    try {
      await tester.enterText(find.byType(TextFormField).at(1), '-12,50');
      await settle(tester);
      // Hold the database so the first save is still in flight when the
      // second tap lands, as with the app's background database isolate.
      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      final create = find.widgetWithText(FilledButton, 'Create Transaction');
      await tester.tap(create);
      await tester.tap(create, warnIfMissed: false);
      release.complete();
      await held;
      await settle(tester);

      final saved = await rows();
      expect(saved, hasLength(1));
      expect(saved.single.amount, -12.5);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a typed balance the locale cannot read is flagged, not silently dropped', (tester) async {
    await open(tester);
    try {
      await tester.enterText(find.byType(TextFormField).at(1), '-12,50');
      await tester.enterText(find.byType(TextFormField).at(4), '1500.5');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create Transaction'));
      await settle(tester);

      expect(find.text('Invalid number'), findsOneWidget, reason: 'it_IT does not read "1500.5"');
      expect(await rows(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the status dropdown shows the Italian label, not the enum name', (tester) async {
    final tx = await insertTx(booked: DateTime(2024, 3, 10), moved: DateTime(2024, 3, 10));
    await open(tester, tx: tx, language: 'it');
    try {
      expect(find.text('Contabilizzata'), findsOneWidget);
      expect(find.text('settled'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('privacy mode masks the raw import values and keeps the column names readable', (tester) async {
    final raw = jsonEncode({'Data': '08/03/2024', 'Importo': '-1.234,56', 'Saldo': '5.000,00', 'Descrizione': 'ESSELUNGA'});
    final tx = await insertTx(booked: DateTime(2024, 3, 8), moved: DateTime(2024, 3, 10), rawMetadata: raw);
    await open(tester, tx: tx);
    try {
      final panel = find.byKey(const Key('rawImportData'));
      Finder inPanel(String text) => find.descendant(of: panel, matching: find.text(text));
      bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

      expect(inPanel('-1.234,56'), findsOneWidget);
      expect(masked(inPanel('-1.234,56')), isFalse, reason: 'privacy mode is off');

      final container = ProviderScope.containerOf(tester.element(find.byType(TransactionEditScreen)));
      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);

      expect(masked(inPanel('-1.234,56')), isTrue, reason: 'a raw amount reveals the position size');
      expect(masked(inPanel('5.000,00')), isTrue, reason: 'a raw balance reveals the position size');
      expect(inPanel('Importo: '), findsOneWidget);
      expect(masked(inPanel('Importo: ')), isFalse, reason: 'column names are not position sizes');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('raw import data that is not a column object is masked as a whole', (tester) async {
    final tx = await insertTx(booked: DateTime(2024, 3, 8), moved: DateTime(2024, 3, 10), rawMetadata: 'ESSELUNGA;-1.234,56');
    await open(tester, tx: tx);
    try {
      final container = ProviderScope.containerOf(tester.element(find.byType(TransactionEditScreen)));
      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);

      final raw = find.descendant(of: find.byKey(const Key('rawImportData')), matching: find.text('ESSELUNGA;-1.234,56'));
      expect(raw, findsOneWidget);
      expect(find.ancestor(of: raw, matching: find.byType(ImageFiltered)), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
