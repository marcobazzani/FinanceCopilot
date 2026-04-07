import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import CSV: income', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'income.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.income);
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final incomes = await db.select(db.incomes).get();
    expect(incomes.length, 3);
    expect(incomes.where((i) => i.amount == 3500.00).length, 2);
    expect(incomes.where((i) => i.amount == 3600.00).length, 1);
  });

  testWidgets('Import XLSX: income with typed cells', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'income.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.income);
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final incomes = await db.select(db.incomes).get();
    expect(incomes.length, 3);
  });
}
