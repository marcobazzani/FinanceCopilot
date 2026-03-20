import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import screen shows toolbar and target selector', (tester) async {
    final db = await pumpApp(tester);

    // Open ImportScreen via AppBar import icon
    await tester.tap(find.byIcon(Icons.file_upload));
    await tester.pumpAndSettle();

    // "Open File" and "Paste from Clipboard" buttons
    expect(find.text('Open File'), findsOneWidget);
    expect(find.text('Paste from Clipboard'), findsOneWidget);

    // Target selector with 3 segments
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Asset Event'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);

    await db.close();
  });
}
