// Every way out of the income Add/Edit dialogs — confirm, Enter in the amount
// field, cancel, unreadable input, delete — taken while a text field still has
// focus. The dialogs used to dispose their text controllers as soon as they
// returned, while the closing animation was still rebuilding the focused
// field, so these exits raised "A TextEditingController was used after being
// disposed".
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/income_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
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

  Future<List<Income>> incomes() => db.select(db.incomes).get();

  group('Add Income', () {
    Future<void> openAdd(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add'));
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, 'Add Income'), findsOneWidget);
    }

    testWidgets('Enter in the amount field adds the income', (tester) async {
      await openAdd(tester);
      try {
        await tester.enterText(dialogField(0), '2026-03-10');
        await tester.enterText(dialogField(1), '200');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final income = (await incomes()).single;
        expect(income.amount, 200);
        expect(income.type, IncomeType.income);
        expect(income.valueDate, DateTime(2026, 3, 10));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an unreadable amount is rejected with a message and nothing is stored', (tester) async {
      await openAdd(tester);
      try {
        await tester.enterText(dialogField(1), 'abc');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await settle(tester);

        expect(find.text('Invalid date or amount'), findsOneWidget);
        expect(await incomes(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('cancel stores nothing', (tester) async {
      await openAdd(tester);
      try {
        await tester.enterText(dialogField(1), '200');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(await incomes(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('Edit Income', () {
    Future<void> openEdit(WidgetTester tester) async {
      await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
      await pumpScreen(tester);
      await tester.tap(find.textContaining('500.00'));
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, 'Edit Income'), findsOneWidget);
    }

    testWidgets('save writes the new values; date and value date move together', (tester) async {
      await openEdit(tester);
      try {
        await tester.enterText(dialogField(0), '2026-03-15');
        await tester.enterText(dialogField(1), '750.5');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final income = (await incomes()).single;
        expect(income.amount, 750.5);
        expect(income.date, DateTime(2026, 3, 15));
        expect(income.valueDate, DateTime(2026, 3, 15));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an unreadable date is rejected with a message and the income is unchanged', (tester) async {
      await openEdit(tester);
      try {
        await tester.enterText(dialogField(0), 'not a date');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(find.text('Invalid date or amount'), findsOneWidget);
        final income = (await incomes()).single;
        expect(income.amount, 500);
        expect(income.valueDate, DateTime(2026, 3, 1));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('delete asks for confirmation, then removes the income', (tester) async {
      await openEdit(tester);
      try {
        await tester.enterText(dialogField(1), '1');
        await tester.tap(find.byTooltip('Delete'));
        await settle(tester);
        expect(find.widgetWithText(AlertDialog, 'Delete Income?'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await settle(tester);
        expect(await incomes(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('cancel leaves the income untouched', (tester) async {
      await openEdit(tester);
      try {
        await tester.enterText(dialogField(1), '999');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect((await incomes()).single.amount, 500);
      } finally {
        await unmount(tester);
      }
    });
  });
}
