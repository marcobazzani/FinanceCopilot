import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Adjustments tab inside Accounts opens the ExtraordinaryEvents view',
      (tester) async {
    await pumpApp(tester);

    // Navigate Accounts -> Adjustments tab.
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    await tester.tap(find.text('Adjustments'));
    await settle(tester);

    // The unified view replaces the old Spread Expenses / Donations tabs.
    // With no events seeded, the empty-state text or info box should be visible.
    expect(find.textContaining('events'), findsWidgets);
  });
}
