import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Adjustments screen shows two tabs', (tester) async {
    final db = await pumpApp(tester);

    // Navigate to Adjustments
    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    // Two tabs
    expect(find.text('Saving Spent'), findsOneWidget);
    expect(find.text('Donation Spent'), findsOneWidget);

    // Default tab shows empty state
    expect(find.textContaining('No spread adjustments yet'), findsOneWidget);

    // Tap second tab
    await tester.tap(find.text('Donation Spent'));
    await settle(tester);

    expect(find.textContaining('No income adjustments yet'), findsOneWidget);

    // Tap back to first tab
    await tester.tap(find.text('Saving Spent'));
    await settle(tester);

    expect(find.textContaining('No spread adjustments yet'), findsOneWidget);

  });
}
