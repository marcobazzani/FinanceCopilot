// A rule's delete asks one confirmation wherever it starts: the rule dialog's
// trashcan (pinned here) and the rules list's swipe (swipe_to_delete_test.dart,
// categories_rules_screen_fixes_test.dart). "Delete" / "This cannot be undone"
// with a red Delete. Cancel keeps the rule and its dialog; Delete removes the
// rule, closes the dialog and marks the rules changed.
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

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
    await RuleService(db).create(matchType: RuleMatchType.contains, pattern: 'esselunga', categoryId: groceries);
  });
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

  /// The rules tab with the rule's edit dialog open.
  Future<void> openRuleDialog(WidgetTester tester) async {
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
    container = ProviderScope.containerOf(tester.element(find.byType(CategoriesRulesScreen)));
    await settle(tester);
    await tester.tap(find.textContaining('esselunga', findRichText: true));
    await settle(tester);
    expect(find.text(s.editRule), findsOneWidget);
  }

  Finder confirmDialog() => find.ancestor(of: find.text(s.cannotBeUndone), matching: find.byType(AlertDialog));

  Future<void> tapTrashcan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ruleDeleteButton')));
    await settle(tester);
  }

  testWidgets('the trashcan asks with a red Delete; Cancel keeps the rule and its dialog', (tester) async {
    await openRuleDialog(tester);
    try {
      await tapTrashcan(tester);
      final dialog = confirmDialog();
      expect(dialog, findsOneWidget, reason: 'the trashcan asks first');
      final alert = tester.widget<AlertDialog>(dialog);
      expect((alert.title! as Text).data, s.delete);
      expect((alert.content! as Text).data, s.cannotBeUndone);
      final confirm = tester.widget<FilledButton>(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, s.delete)));
      expect(confirm.style?.backgroundColor?.resolve({}), Colors.red);

      await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, s.cancel)));
      await settle(tester);
      expect(confirmDialog(), findsNothing);
      expect(find.text(s.editRule), findsOneWidget, reason: 'the rule dialog stays open');
      expect(await db.select(db.autoCategorizationRules).get(), hasLength(1));
      expect(container.read(rulesDirtyProvider), isFalse);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Delete removes the rule, closes its dialog and marks the rules changed', (tester) async {
    await openRuleDialog(tester);
    try {
      await tapTrashcan(tester);
      await tester.tap(find.descendant(of: confirmDialog(), matching: find.widgetWithText(FilledButton, s.delete)));
      await settle(tester);

      expect(await db.select(db.autoCategorizationRules).get(), isEmpty);
      expect(find.byType(AlertDialog), findsNothing, reason: 'the rule dialog closes with it');
      expect(container.read(rulesDirtyProvider), isTrue);
      expect(find.byKey(const Key('rulesDirtyBanner')), findsOneWidget);
      expect(find.textContaining('esselunga', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await unmount(tester);
    }
  });
}
