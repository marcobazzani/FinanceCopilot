// PortfolioModelDialog under a comma-decimal locale: the weights of an
// existing model are pre-filled in the locale spelling the save parses back
// exactly (it used to pre-fill "50.00", which it_IT does not read as 50), and
// a double tap on the save button creates one model.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';

/// Opens [dialog] once the locale is loaded, as in the app (the shell
/// watches it): the dialog reads the locale in initState.
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
                key: const Key('open'),
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

  Future<void> open(WidgetTester tester, Widget Function() dialog) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
        ],
        child: MaterialApp(home: _Launcher(dialog)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(PortfolioModelDialog), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder dialogField(int index) => find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byType(TextField)).at(index);

  testWidgets('open-and-save without edits keeps the weights (50 stays 50)', (tester) async {
    final id = await service.createCustomModel(
      name: 'Core',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50, description: 'World'),
        PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 37.5, description: 'Gold'),
        PortfolioModelInputItem(isin: 'IE00BK5BQT80', targetWeight: 12.5, description: 'EM'),
      ],
    );
    final model = (await service.getById(id))!;
    final items = await service.getItems(id);
    await open(tester, () => PortfolioModelDialog(existing: model, existingItems: items));
    try {
      final weights = [
        for (final isin in ['IE00B4L5Y983', 'IE00B579F325', 'IE00BK5BQT80'])
          tester.widget<TextField>(dialogField(items.indexWhere((i) => i.isin == isin) * 3 + 2)).controller!.text,
      ];
      expect(weights, ['50', '37,5', '12,5'], reason: 'pre-filled in the it_IT spelling');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.byType(PortfolioModelDialog), findsNothing, reason: 'saved without a validation error');
      final saved = {for (final i in await service.getItems(id)) i.isin: i.targetWeight};
      expect(saved, {'IE00B4L5Y983': 50, 'IE00B579F325': 37.5, 'IE00BK5BQT80': 12.5});
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('two rapid taps on Create create one model', (tester) async {
    await open(tester, () => const PortfolioModelDialog());
    try {
      await tester.enterText(dialogField(0), 'Core');
      await tester.enterText(dialogField(1), 'IE00B4L5Y983');
      await tester.enterText(dialogField(2), '100');
      await tester.enterText(dialogField(3), 'World');
      await settle(tester);
      // Hold the database so the first save is still in flight when the
      // second tap lands, as with the app's background database isolate.
      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      final create = find.widgetWithText(FilledButton, 'Create');
      await tester.tap(create);
      await tester.tap(create, warnIfMissed: false);
      release.complete();
      await held;
      await settle(tester);

      expect(await service.getAll(), hasLength(1));
    } finally {
      await unmount(tester);
    }
  });
}
