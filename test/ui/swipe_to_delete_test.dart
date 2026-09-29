// The canonical list delete: a row swipes away end to start over a red
// background with a trash icon and asks first; the delete runs on confirm,
// before the row collapses, so a dismissed row is never left in the tree.
//
// The pins record the swipe of the lists that had one before it was shared
// (categories, rules): background, confirmation and outcome. The widget tests
// drive the shared SwipeToDelete in a plain list.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';
import 'package:finance_copilot/ui/widgets/swipe_to_delete.dart';
import 'package:finance_copilot/utils/dialogs.dart';

/// A list of [rows]; each row swipes away through [row].
class _Rows extends StatefulWidget {
  const _Rows({required this.rows, required this.row});

  final List<String> rows;
  final Widget Function(String label, List<String> rows, VoidCallback changed) row;

  @override
  State<_Rows> createState() => _RowsState();
}

class _RowsState extends State<_Rows> {
  late final _rows = [...widget.rows];

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final label in _rows) widget.row(label, _rows, () => setState(() {})),
    ],
  );
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Drags [row] a little to the left and holds it: the background shows.
  Future<TestGesture> holdDragged(WidgetTester tester, Finder row) async {
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    return gesture;
  }

  /// The red background under a row held half-swiped.
  void expectTrashBackground(WidgetTester tester) {
    final icon = find.descendant(of: find.byType(Dismissible), matching: find.byIcon(Icons.delete));
    expect(icon, findsOneWidget, reason: 'the trash icon shows under the swiped row');
    final scheme = Theme.of(tester.element(icon)).colorScheme;
    expect(tester.widget<Icon>(icon).color, scheme.onErrorContainer);
    final background = tester.widget<Container>(find.ancestor(of: icon, matching: find.byType(Container)).first);
    expect(background.color, scheme.errorContainer);
    expect(background.alignment, Alignment.centerRight);
    expect(tester.widget<Dismissible>(find.byType(Dismissible).first).direction, DismissDirection.endToStart);
  }

  void expectConfirm(WidgetTester tester, {required String title, required String content}) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final alert = tester.widget<AlertDialog>(dialog);
    expect((alert.title! as Text).data, title);
    expect((alert.content! as Text).data, content);
    final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)));
    expect(confirm.style?.backgroundColor?.resolve({}), Colors.red, reason: 'a destructive confirm');
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
  }

  group('categories & rules (pins of the swipe they had)', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: CategoriesRulesScreen()),
        ),
      );
      await settle(tester);
    }

    Future<Category> groceries() => (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle();

    testWidgets('a category swipes over the trash background, asks first; Cancel keeps it, Delete removes it', (tester) async {
      final category = await groceries();
      await pumpScreen(tester);
      try {
        await tester.tap(find.byKey(const Key('tabCategories')));
        await settle(tester);

        final gesture = await holdDragged(tester, find.text('Groceries'));
        expectTrashBackground(tester);
        await gesture.up();
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing, reason: 'a short drag slides back without asking');

        await tester.drag(find.text('Groceries'), const Offset(-800, 0));
        await settle(tester);
        expectConfirm(tester, title: s.deleteCategoryTitle, content: s.cannotBeUndone);
        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.text('Groceries'), findsOneWidget, reason: 'the row comes back');
        expect(await (db.select(db.categories)..where((c) => c.id.equals(category.id))).getSingleOrNull(), isNotNull);

        await tester.drag(find.text('Groceries'), const Offset(-800, 0));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await (db.select(db.categories)..where((c) => c.id.equals(category.id))).getSingleOrNull(), isNull);
        expect(find.text('Groceries'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a rule swipes over the same background and asks the same way', (tester) async {
      await RuleService(db).create(matchType: RuleMatchType.contains, pattern: 'esselunga', categoryId: (await groceries()).id);
      await pumpScreen(tester);
      try {
        final row = find.textContaining('esselunga', findRichText: true);
        final gesture = await holdDragged(tester, row);
        expectTrashBackground(tester);
        await gesture.up();
        await settle(tester);

        await tester.drag(row, const Offset(-800, 0));
        await settle(tester);
        expectConfirm(tester, title: s.delete, content: s.cannotBeUndone);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await db.select(db.autoCategorizationRules).get(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('SwipeToDelete', () {
    Future<void> pumpRows(WidgetTester tester, Widget Function(String label, List<String> rows, VoidCallback changed) row) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _Rows(rows: const ['Alpha', 'Beta'], row: row),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('the entity\'s confirmation asks; Cancel slides the row back, Delete runs the delete before the collapse', (tester) async {
      final deleted = <String>[];
      var deletedAtCollapse = <String>[];
      await pumpRows(
        tester,
        (label, rows, changed) => SwipeToDelete.custom(
          key: ValueKey(label),
          // As an entity's confirmAndDelete does: its own confirmation, then
          // the delete.
          confirmAndDelete: () async {
            final confirmed = await showConfirmDialog(
              tester.element(find.byType(ListView)),
              title: 'Delete $label?',
              content: 'Gone for good.',
              confirmLabel: s.delete,
              cancelLabel: s.cancel,
              confirmColor: Colors.red,
            );
            if (!confirmed) return false;
            deleted.add(label);
            rows.remove(label);
            changed();
            return true;
          },
          child: ListTile(title: Text(label)),
        ),
      );
      await tester.drag(find.text('Alpha'), const Offset(-600, 0));
      await settle(tester);
      expectConfirm(tester, title: 'Delete Alpha?', content: 'Gone for good.');
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(deleted, isEmpty);
      expect(tester.getTopLeft(find.text('Alpha')).dx, lessThan(100), reason: 'the row slid back');

      await tester.drag(find.text('Alpha'), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      // Well within the 300 ms collapse: the delete already ran.
      await tester.pump(const Duration(milliseconds: 50));
      deletedAtCollapse = [...deleted];
      await settle(tester);
      expect(deletedAtCollapse, ['Alpha']);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no dismissed row is left in the tree');
    });

    testWidgets('custom: the entity\'s own confirm-and-delete decides; a refusal slides the row back', (tester) async {
      var answer = false;
      final asked = <String>[];
      await pumpRows(
        tester,
        (label, rows, changed) => SwipeToDelete.custom(
          key: ValueKey(label),
          confirmAndDelete: () async {
            asked.add(label);
            if (answer) {
              rows.remove(label);
              changed();
            }
            return answer;
          },
          child: ListTile(title: Text(label)),
        ),
      );
      await tester.drag(find.text('Beta'), const Offset(-600, 0));
      await settle(tester);
      expect(asked, ['Beta']);
      expect(find.byType(AlertDialog), findsNothing, reason: 'no confirmation of its own');
      expect(tester.getTopLeft(find.text('Beta')).dx, lessThan(100), reason: 'refused: the row slid back');

      answer = true;
      await tester.drag(find.text('Beta'), const Offset(-600, 0));
      await settle(tester);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only swipes end to start', (tester) async {
      var asked = 0;
      await pumpRows(
        tester,
        (label, rows, changed) => SwipeToDelete.custom(
          key: ValueKey(label),
          confirmAndDelete: () async {
            asked++;
            return false;
          },
          child: ListTile(title: Text(label)),
        ),
      );
      await tester.drag(find.text('Alpha'), const Offset(600, 0));
      await settle(tester);
      expect(asked, 0);
    });
  });
}
