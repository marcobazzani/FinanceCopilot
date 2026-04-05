import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Settings: open, verify controls, save currency, clear cache', (tester) async {
    final db = await pumpApp(tester);

    // Open settings
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);

    // Verify controls present
    expect(find.text('Default Currency'), findsOneWidget);
    expect(find.text('Number/Date Format'), findsOneWidget);
    expect(find.text('Interface Language'), findsOneWidget);
    expect(find.text('Clear cached data'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Save with defaults
    await tester.tap(find.text('Save'));
    await settle(tester);

    // Dialog closed
    expect(find.text('Settings'), findsNothing);

    // Verify currency in DB
    final row = await db.customSelect(
      "SELECT value FROM app_configs WHERE key = 'BASE_CURRENCY'",
    ).getSingle();
    expect(row.read<String>('value'), 'EUR');

    // Reopen settings and clear cache
    await tester.tap(find.byIcon(Icons.settings));
    await settle(tester);

    await tester.tap(find.text('Clear'));
    await settle(tester);

    // Snackbar appears
    expect(find.text('Cached data cleared'), findsOneWidget);
  });
}
