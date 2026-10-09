// The income Add/Edit form round-trip under the active locale:
// - the amount is pre-filled in the locale's own spelling, so open-and-save
//   under it_IT keeps 1500 (it used to pre-fill Dart's "1500.0", which the
//   comma-decimal locale does not read back);
// - the date field is pre-filled with the locale's short date and read back
//   in that order first, so under en_US "3/7/2026" stays March 7 and a typed
//   "9/27/2026" is accepted;
// - the booking date (incomes.date, only used by the import dedup) is left
//   alone unless the user moved the date of a row whose booking date was in
//   sync with its value date.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/income_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, String locale) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: IncomeScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder dialogField(int index) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(index);

  String fieldText(WidgetTester tester, int index) => tester.widget<TextField>(dialogField(index)).controller!.text;

  Future<Income> onlyIncome() async => (await db.select(db.incomes).get()).single;

  /// An imported income: the bank booked it on [booked], the money moved on [moved].
  Future<void> insertImported({required DateTime booked, required DateTime moved, required double amount}) => db
      .into(db.incomes)
      .insert(
        IncomesCompanion.insert(date: booked, valueDate: moved, amount: amount, currency: const Value('EUR')),
      );

  Future<void> openEdit(WidgetTester tester, String listText) async {
    await tester.tap(find.textContaining(listText));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Edit Income'), findsOneWidget);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
  }

  group('it_IT (comma decimal, day-first dates)', () {
    testWidgets('open-and-save without edits keeps a 1500 income at 1500', (tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 1500, currency: 'EUR');
      await pumpScreen(tester, 'it_IT');
      try {
        await openEdit(tester, '1.500,00');
        expect(fieldText(tester, 1), '1.500,00', reason: 'pre-filled in the locale spelling');

        await tapSave(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Invalid date or amount'), findsNothing);
        final income = await onlyIncome();
        expect(income.amount, 1500);
        expect(income.valueDate, DateTime(2026, 3, 1));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a typed 3/7/2026 is 3 July', (tester) async {
      await pumpScreen(tester, 'it_IT');
      try {
        await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add'));
        await settle(tester);
        await tester.enterText(dialogField(0), '3/7/2026');
        await tester.enterText(dialogField(1), '100');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await settle(tester);

        expect((await onlyIncome()).valueDate, DateTime(2026, 7, 3));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('editing only the amount leaves the booking date alone', (tester) async {
      await insertImported(booked: DateTime(2026, 2, 27), moved: DateTime(2026, 3, 1), amount: 500);
      await pumpScreen(tester, 'it_IT');
      try {
        await openEdit(tester, '500,00');
        await tester.enterText(dialogField(1), '750');
        await tapSave(tester);

        final income = await onlyIncome();
        expect(income.amount, 750);
        expect(income.valueDate, DateTime(2026, 3, 1));
        expect(income.date, DateTime(2026, 2, 27), reason: 'the import dedup keys on the booking date');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an in-sync income moves the booking date too', (tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
      await pumpScreen(tester, 'it_IT');
      try {
        await openEdit(tester, '500,00');
        await tester.enterText(dialogField(0), '15/03/2026');
        await tester.enterText(dialogField(1), '500');
        await tapSave(tester);

        final income = await onlyIncome();
        expect(income.valueDate, DateTime(2026, 3, 15));
        expect(income.date, DateTime(2026, 3, 15));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('moving the date of an imported income moves only the value date', (tester) async {
      await insertImported(booked: DateTime(2026, 2, 27), moved: DateTime(2026, 3, 1), amount: 500);
      await pumpScreen(tester, 'it_IT');
      try {
        await openEdit(tester, '500,00');
        await tester.enterText(dialogField(0), '15/03/2026');
        await tester.enterText(dialogField(1), '500');
        await tapSave(tester);

        final income = await onlyIncome();
        expect(income.valueDate, DateTime(2026, 3, 15));
        expect(income.date, DateTime(2026, 2, 27), reason: 'a booking date distinct from the value date is the bank\'s');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('en_US (month-first dates)', () {
    testWidgets('open-and-save without edits keeps March 7 (pre-filled 3/7/2026)', (tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 7), amount: 500, currency: 'EUR');
      await pumpScreen(tester, 'en_US');
      try {
        await openEdit(tester, '500.00');
        expect(fieldText(tester, 0), '3/7/2026');

        await tapSave(tester);

        final income = await onlyIncome();
        expect(income.valueDate, DateTime(2026, 3, 7));
        expect(income.date, DateTime(2026, 3, 7));
        expect(income.amount, 500);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a typed 9/27/2026 is accepted as September 27', (tester) async {
      await pumpScreen(tester, 'en_US');
      try {
        await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add'));
        await settle(tester);
        await tester.enterText(dialogField(0), '9/27/2026');
        await tester.enterText(dialogField(1), '100');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await settle(tester);

        expect(find.text('Invalid date or amount'), findsNothing);
        expect((await onlyIncome()).valueDate, DateTime(2026, 9, 27));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the date label shows an example in the locale order, not a fixed dd/MM/yyyy', (tester) async {
      await pumpScreen(tester, 'en_US');
      try {
        await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add'));
        await settle(tester);

        expect(find.text('Date (e.g. 12/31/${DateTime.now().year})'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
