// The income Edit form never rewrites an amount the user did not touch: it is
// pre-filled with every digit (in the locale spelling the save parses back),
// so changing only the type keeps 1234.5678 at 1234.5678. The form used to
// pre-fill two decimals, and the save wrote back 1234.57.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
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

  Future<void> insertIncome(double amount) => db
      .into(db.incomes)
      .insert(
        IncomesCompanion.insert(date: DateTime(2026, 3, 1), valueDate: DateTime(2026, 3, 1), amount: amount, currency: const Value('EUR')),
      );

  Future<void> openAndPickRefund(WidgetTester tester, String listText) async {
    await tester.tap(find.textContaining(listText));
    await settle(tester);
    expect(find.widgetWithText(AlertDialog, 'Edit Income'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<IncomeType>));
    await settle(tester);
    await tester.tap(find.text('Refund').last);
    await settle(tester);
  }

  for (final (locale, listText, prefill) in [('it_IT', '1.234,57', '1234,5678'), ('en_US', '1,234.57', '1234.5678')]) {
    testWidgets('$locale: a type-only edit keeps an amount with more than two decimals', (tester) async {
      await insertIncome(1234.5678);
      await pumpScreen(tester, locale);
      try {
        await openAndPickRefund(tester, listText);
        expect(tester.widget<TextField>(dialogField(1)).controller!.text, prefill, reason: 'every digit, in the locale spelling');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final income = (await db.select(db.incomes).get()).single;
        expect(income.type, IncomeType.refund);
        expect(income.amount, 1234.5678);
      } finally {
        await unmount(tester);
      }
    });
  }
}
