// The manual "Add Income" dialog. The integration walkthrough reaches it only
// when its FAB tap is not intercepted by a page still in transition, so
// whether these lines ran used to depend on timing. Pinned here directly.
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

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('adding an income stores the typed date, amount, type and currency', (tester) async {
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
    try {
      await tester.tap(find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add'));
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, 'Add Income'), findsOneWidget);

      final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '2026-03-10');
      await tester.enterText(fields.at(1), '1,234.50');
      await tester.tap(find.byType(DropdownButtonFormField<IncomeType>));
      await settle(tester);
      await tester.tap(find.text('Refund').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final income = (await db.select(db.incomes).get()).single;
      expect(income.amount, 1234.5, reason: 'parsed with the en_US grouping separator');
      expect(income.type, IncomeType.refund);
      expect(income.currency, 'EUR', reason: 'defaults to the base currency');
      expect(income.valueDate, DateTime(2026, 3, 10), reason: 'value date = the date the money moved');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
