// showInfoSnack is the app's one snack-bar helper; optional duration/action
// cover the one snack that used to be built by hand (Drive re-auth).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/dialogs.dart';

void main() {
  Future<void> show(WidgetTester tester, void Function(BuildContext context) onPressed) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(onPressed: () => onPressed(context), child: const Text('show')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
  }

  testWidgets('without options it is a plain snack bar with the default timing', (tester) async {
    await show(tester, (context) => showInfoSnack(context, 'Saved'));
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(find.text('Saved'), findsOneWidget);
    expect(bar.duration, const SnackBar(content: SizedBox()).duration);
    expect(bar.action, isNull);
  });

  testWidgets('duration and action are passed through; the action runs when tapped', (tester) async {
    var taps = 0;
    await show(
      tester,
      (context) => showInfoSnack(
        context,
        'Sign in again',
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Sign in', onPressed: () => taps++),
      ),
    );
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.duration, const Duration(seconds: 8));
    expect(bar.action?.label, 'Sign in');

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    expect(taps, 1);
  });
}
