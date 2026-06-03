import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  testWidgets('custom model create dialog persists rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PortfolioModelDialog()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'Core');
    await tester.enterText(find.byType(TextField).at(1), 'IE00B4L5Y983');
    await tester.enterText(find.byType(TextField).at(2), '60');
    await tester.enterText(find.byType(TextField).at(3), 'World');
    await tester.tap(find.text('Add row'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(4), 'IE00B579F325');
    await tester.enterText(find.byType(TextField).at(5), '40');
    await tester.enterText(find.byType(TextField).at(6), 'Gold');
    await tester.tap(find.text('Create'));
    await tester.pump();

    final service = PortfolioModelService(db);
    final models = await service.getAll();
    expect(models, hasLength(1));
    expect(models.single.name, 'Core');
    expect(await service.getItems(models.single.id), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
