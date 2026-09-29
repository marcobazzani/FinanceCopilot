// The income split dialog quotes the inflow being split and what is left to
// allocate: both are money the user received — position size — and privacy
// mode masks them. The labels, the hint and the per-type captions around them
// stay readable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/income_split_dialog.dart';

void main() {
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Finder fieldFor(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('total and remaining / over-allocated amounts are masked, their labels are not', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(appLocaleProvider);
                return ElevatedButton(
                  onPressed: () => showIncomeSplitDialog(context, title: 'Flag as Income', total: 2000, currency: 'EUR'),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(text));

    expect(masked(inDialog('2,000.00')), isFalse, reason: 'nothing is masked before privacy is on');

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();

    final total = inDialog('EUR2,000.00');
    expect(total, findsOneWidget);
    expect(masked(total), isTrue, reason: 'the inflow being split is position size');
    expect(masked(inDialog('Total')), isFalse, reason: 'the label stays readable');

    // Balanced: "Remaining: EUR0.00".
    expect(masked(inDialog('EUR0.00')), isTrue);
    expect(masked(inDialog('Remaining: ')), isFalse);

    // Under-allocated: 500 left.
    await tester.enterText(fieldFor('Income'), '1500');
    await tester.pump();
    expect(masked(inDialog('EUR500.00')), isTrue, reason: 'what is left of the inflow is position size');
    expect(masked(inDialog('Remaining: ')), isFalse);

    // Over-allocated by 100.
    await tester.enterText(fieldFor('Income'), '2000');
    await tester.enterText(fieldFor('Refund'), '100');
    await tester.pump();
    expect(masked(inDialog('EUR100.00')), isTrue, reason: 'the excess is position size');
    expect(masked(inDialog('Over by: ')), isFalse, reason: 'the warning stays readable');
    expect(masked(find.text('Refund')), isFalse, reason: 'income types are labels');
  });
}
