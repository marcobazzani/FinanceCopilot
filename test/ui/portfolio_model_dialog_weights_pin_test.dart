// Pin: an existing model's weights pre-fill in the locale's spelling with
// every digit the save reads back exactly — unchanged when the pre-fill moved
// onto the shared editableFigure.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';

/// Opens [dialog] once the locale is loaded (the dialog reads it in initState).
class _Launcher extends ConsumerWidget {
  const _Launcher(this.dialog);
  final Widget Function() dialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                onPressed: () => showDialog<void>(context: context, builder: (_) => dialog()),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late PortfolioModelService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PortfolioModelService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  for (final (locale, expected) in [
    ('en_US', ['50', '33.333333', '16.666667']),
    ('it_IT', ['50', '33,333333', '16,666667']),
  ]) {
    testWidgets('$locale: weights pre-fill with every digit, in the locale', (tester) async {
      final id = await service.createCustomModel(
        name: 'Thirds',
        items: const [
          PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50, description: 'World'),
          PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 33.333333, description: 'Gold'),
          PortfolioModelInputItem(isin: 'IE00BK5BQT80', targetWeight: 16.666667, description: 'EM'),
        ],
      );
      final model = (await service.getById(id))!;
      final items = await service.getItems(id);
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          ],
          child: MaterialApp(
            home: _Launcher(() => PortfolioModelDialog(existing: model, existingItems: items)),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);
      try {
        final fields = find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byType(TextField));
        final weights = [
          for (final isin in ['IE00B4L5Y983', 'IE00B579F325', 'IE00BK5BQT80'])
            tester.widget<TextField>(fields.at(1 + items.indexWhere((i) => i.isin == isin) * 3 + 1)).controller!.text,
        ];
        expect(weights, expected);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  }
}
