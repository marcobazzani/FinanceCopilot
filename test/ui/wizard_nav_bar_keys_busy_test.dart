// The shared wizard navbar's buttons can carry a key each, and a running
// primary action shows a progress indicator in place of its icon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/widgets/wizard_nav_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, WizardNavBar bar) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar]),
        ),
      ),
    );
  }

  testWidgets('each button carries its key', (tester) async {
    await pumpBar(
      tester,
      WizardNavBar(
        primaryKey: const Key('go'),
        primaryLabel: 'Apply',
        onPrimary: () {},
        secondaryKey: const Key('skip'),
        secondaryLabel: 'Skip',
        onSecondary: () {},
      ),
    );
    expect(tester.widget(find.byKey(const Key('go'))), isA<FilledButton>());
    expect(find.descendant(of: find.byKey(const Key('go')), matching: find.text('Apply')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('skip'))), isA<OutlinedButton>());
    expect(find.descendant(of: find.byKey(const Key('skip')), matching: find.text('Skip')), findsOneWidget);
  });

  testWidgets('a busy primary action shows a progress indicator instead of its icon', (tester) async {
    await pumpBar(tester, const WizardNavBar(primaryLabel: 'Apply', primaryIcon: Icons.check, primaryBusy: true, onPrimary: null));
    final apply = find.widgetWithText(FilledButton, 'Apply');
    expect(find.descendant(of: apply, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.descendant(of: apply, matching: find.byIcon(Icons.check)), findsNothing);

    await pumpBar(tester, const WizardNavBar(primaryLabel: 'Apply', primaryIcon: Icons.check, onPrimary: null));
    expect(find.descendant(of: apply, matching: find.byType(CircularProgressIndicator)), findsNothing);
    expect(find.descendant(of: apply, matching: find.byIcon(Icons.check)), findsOneWidget);
  });
}
