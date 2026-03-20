import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings dialog opens and shows currency/locale dropdowns', (tester) async {
    final db = await pumpApp(tester);

    // Tap settings icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Dialog opens
    expect(find.text('Settings'), findsOneWidget);

    // Currency and locale dropdowns
    expect(find.text('Default Currency'), findsOneWidget);
    expect(find.text('Number/Date Format'), findsOneWidget);

    // Save and Cancel buttons
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Save → dialog closes
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Dialog is gone
    expect(find.text('Settings'), findsNothing);

    await db.close();
  });
}
