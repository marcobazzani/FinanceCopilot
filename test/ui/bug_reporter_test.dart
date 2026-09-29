// Bug reporter dialogs.
//
// Pinned bugs:
//  * The description/steps controllers were created outside the first dialog
//    and disposed as soon as it returned — while its closing animation was
//    still running — and never disposed at all when the dialog was cancelled.
//    The dialog now owns them.
//  * The result dialog put its primary action (Open GitHub Issue) before Close;
//    every other dialog in the app puts the secondary action first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/bug_reporter.dart';

void main() {
  const s = AppStrings.en;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openReporter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(onPressed: () => openBugReporter(context, ref), child: const Text('report')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('report'));
    await settle(tester);
    expect(find.widgetWithText(TextField, s.ticketerDescriptionLabel), findsOneWidget);
  }

  Future<void> fillFields(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, s.ticketerDescriptionLabel), 'Totals are off');
    await tester.enterText(find.widgetWithText(TextField, s.ticketerStepsLabel), '1. Open the dashboard');
    await tester.pump();
  }

  testWidgets('Continue with a field still focused opens the result dialog', (tester) async {
    await openReporter(tester);
    await fillFields(tester);
    await tester.tap(find.widgetWithText(FilledButton, s.ticketerContinue));
    await settle(tester);

    expect(find.byType(TextField), findsNothing, reason: 'the form dialog is gone');
    expect(find.widgetWithText(TextButton, s.ticketerClose), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, s.ticketerClose));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancel with a field still focused closes without a result dialog', (tester) async {
    await openReporter(tester);
    await fillFields(tester);
    await tester.tap(find.widgetWithText(TextButton, s.cancel));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('result dialog: Close (secondary) comes before Open GitHub Issue (primary)', (tester) async {
    await openReporter(tester);
    await fillFields(tester);
    await tester.tap(find.widgetWithText(FilledButton, s.ticketerContinue));
    await settle(tester);

    final close = find.widgetWithText(TextButton, s.ticketerClose);
    final openIssue = find.widgetWithText(FilledButton, s.ticketerOpenIssue);
    expect(close, findsOneWidget);
    expect(openIssue, findsOneWidget);
    expect(tester.getCenter(close).dx, lessThan(tester.getCenter(openIssue).dx));

    await tester.tap(close);
    await settle(tester);
  });
}
