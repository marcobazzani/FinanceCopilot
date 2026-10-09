// The wizard's progress header: money when the ledger is valued, rows when it
// is not. Pins both paths (the row path only shows when the progress carries
// no money figures) so the figures can be read as one value instead of three
// fields checked apart and then force-unwrapped.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/classification_wizard_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpWizard(WidgetTester tester, ClassificationProgress progress, {bool isPrivate = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privacyModeProvider.overrideWith((ref) => isPrivate),
          classificationProgressProvider.overrideWith((ref, accountId) => Stream.value(progress)),
          uncategorizedGroupsProvider.overrideWith((ref, accountId) => Stream.value(const <MerchantGroup>[])),
        ],
        child: const MaterialApp(home: ClassificationWizardScreen()),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('without money figures the header counts rows, with no secondary row line', (tester) async {
    await pumpWizard(tester, const ClassificationProgress(total: 4, categorized: 1, excluded: 2));

    final header = find.byKey(const Key('wizardProgress'));
    expect(tester.widget<Text>(header).data, '1 of 4 classified (25%)');
    expect(find.byKey(const Key('wizardProgressRows')), findsNothing);
    expect(find.byKey(const Key('wizardExcludedNote')), findsOneWidget);
    expect(find.byKey(const Key('wizardFxExcludedNote')), findsNothing);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.25);
    await unmount(tester);
  });

  testWidgets('the row header is not masked in privacy mode: counts are shape, not size', (tester) async {
    await pumpWizard(tester, const ClassificationProgress(total: 4, categorized: 1), isPrivate: true);

    expect(find.descendant(of: find.byKey(const Key('wizardProgress')), matching: find.byType(ImageFiltered)), findsNothing);
    expect(find.text('1 of 4 classified (25%)'), findsOneWidget);
    await unmount(tester);
  });
}
