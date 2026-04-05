import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Adjustments screen shows tabs and navigates', (tester) async {
    await pumpApp(tester);

    // Navigate to Adjustments
    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    // Two tabs should be visible
    expect(find.text('Spread Expenses'), findsOneWidget);
    expect(find.text('Donations / Inheritance'), findsOneWidget);

    // Tap second tab
    await tester.tap(find.text('Donations / Inheritance'));
    await settle(tester);

    // Tap back to first tab
    await tester.tap(find.text('Spread Expenses'));
    await settle(tester);
  });
}
