// PortfolioModelDialog: each row's fields stay with their row. Removing a
// row used to leave the fields in place and shift the rows' texts up by one,
// so the field the user was typing in suddenly held the next row's weight.
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

  Finder dialogField(int index) => find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byType(TextField)).at(index);

  /// The text of the field that has the keyboard focus.
  String focusedText(WidgetTester tester) =>
      tester.widgetList<EditableText>(find.byType(EditableText)).firstWhere((e) => e.focusNode.hasFocus).controller.text;

  testWidgets('removing a row keeps the focused field, and every field, with its own row', (tester) async {
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
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
        ],
        child: MaterialApp(
          home: _Launcher(() => PortfolioModelDialog(existing: model, existingItems: items)),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    try {
      String weightOf(int row) => tester.widget<TextField>(dialogField(row * 3 + 2)).controller!.text;
      String descriptionOf(int row) => tester.widget<TextField>(dialogField(row * 3 + 3)).controller!.text;
      final second = (weightOf(1), descriptionOf(1));
      final third = (weightOf(2), descriptionOf(2));

      // The user is in the second row's weight field...
      await tester.tap(dialogField(1 * 3 + 2));
      await settle(tester);
      expect(focusedText(tester), second.$1);

      // ...and removes the first row.
      await tester.tap(find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byIcon(Icons.delete_outline)).first);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(focusedText(tester), second.$1, reason: 'the focused field went on to show the next row');
      expect((weightOf(0), descriptionOf(0)), second);
      expect((weightOf(1), descriptionOf(1)), third);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
