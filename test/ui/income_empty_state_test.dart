// Income tab with no income yet: the app's one empty state — a muted
// payments icon, the explanation and an "Add Income" action that opens the
// Add form.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
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

  testWidgets('no income: icon, message and an Add Income action that opens the form', (tester) async {
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
      final context = tester.element(find.byType(IncomeScreen));
      final icon = tester.widget<Icon>(find.byIcon(Icons.payments));
      expect(icon.size, 48);
      expect(icon.color, Theme.of(context).colorScheme.onSurfaceVariant);
      expect(find.text(AppStrings.en.noIncomeYet), findsOneWidget);

      final action = find.widgetWithText(FilledButton, 'Add Income');
      expect(action, findsOneWidget);
      expect(find.descendant(of: action, matching: find.byIcon(Icons.add)), findsOneWidget);
      await tester.tap(action);
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, 'Add Income'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
