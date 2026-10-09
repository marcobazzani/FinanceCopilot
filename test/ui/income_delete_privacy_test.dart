// Deleting an income asks with its amount, currency and date. In privacy mode
// the amount is position size and must be masked, while the date (and the
// rest of the question) stays readable — the confirmation used to print the
// amount in clear. Same confirmation from the edit form's delete and from a
// swipe on the row.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/income_screen.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
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
          privacyModeProvider.overrideWith((ref) => true),
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

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// In the open confirmation: the amount masked, the date and the currency
  /// readable, in the same sentence.
  void expectMaskedAmountReadableDate(WidgetTester tester) {
    final dialog = find.widgetWithText(AlertDialog, s.deleteIncomeTitle);
    expect(dialog, findsOneWidget);
    final amount = find.descendant(of: dialog, matching: find.text('500.00'));
    expect(amount, findsOneWidget, reason: 'the amount is quoted as its own masked figure');
    expect(masked(amount), isTrue, reason: 'the amount is position size');
    final sentence = find.descendant(of: dialog, matching: find.textContaining('3/1/2026'));
    expect(sentence, findsOneWidget);
    expect(masked(sentence), isFalse, reason: 'the date is not position size');
    expect(tester.widget<Text>(sentence).textSpan!.toPlainText(), contains('EUR'), reason: 'the currency stays readable too');
    expect(tester.widget<Text>(sentence).textSpan!.toPlainText(), isNot(contains('500')), reason: 'no clear copy of the amount');
  }

  testWidgets('the edit form\'s delete masks the amount and keeps the date readable', (tester) async {
    await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
    await pumpScreen(tester);
    try {
      await tester.tap(find.text('500.00 €'));
      await settle(tester);
      await tester.tap(find.byTooltip(s.delete));
      await settle(tester);
      expectMaskedAmountReadableDate(tester);

      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect(await db.select(db.incomes).get(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a swipe asks the same masked question', (tester) async {
    await IncomeService(db).create(date: DateTime(2026, 3, 1), amount: 500, currency: 'EUR');
    await pumpScreen(tester);
    try {
      await tester.drag(find.text('500.00 €'), const Offset(-900, 0));
      await settle(tester);
      expectMaskedAmountReadableDate(tester);

      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(await db.select(db.incomes).get(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });
}
