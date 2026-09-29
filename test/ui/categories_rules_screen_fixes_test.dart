// Settings → Categories & rules:
// - swiping a rule away deletes it on confirm, before the row collapses (in
//   confirmDismiss, like the categories tab): it used to delete in
//   onDismissed and then flip the "rules changed" flag, whose rebuild could
//   land before the database dropped the row — "A dismissed Dismissible
//   widget is still part of the tree";
// - a dragged rule or category stays where it was dropped while the new order
//   is saved (the list used to snap back until the database answered);
// - a classification run that ends after the screen was closed still clears
//   the "rules changed" flag, without touching the closed screen's ref;
// - a rule's amount bounds read in the locale ("≥ 1.500,00"), not as raw
//   doubles ("≥ 1500.0").
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';

/// Holds classifyAll until [hold] completes, when set.
class _HeldClassifier extends TransactionClassifierService {
  _HeldClassifier(super.db);

  /// Created by the test body, so that completing it wakes the held run in
  /// the test's own (fake-async) zone.
  Completer<void>? hold;

  @override
  Future<ClassifyResult> classifyAll({int? accountId, bool overwrite = false}) async {
    final held = hold;
    if (held != null) await held.future;
    return super.classifyAll(accountId: accountId, overwrite: overwrite);
  }
}

void main() {
  late AppDatabase db;
  late int groceries;
  late int dining;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
    dining = (await (db.select(db.categories)..where((c) => c.key.equals('restaurants'))).getSingleOrNull())?.id ?? groceries;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester, {
    String locale = 'en_US',
    TransactionClassifierService? classifier,
    Stream<List<AutoCategorizationRule>>? rules,
  }) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          privacyModeProvider.overrideWith((ref) => false),
          if (classifier != null) transactionClassifierServiceProvider.overrideWithValue(classifier),
          if (rules != null) categorizationRulesProvider.overrideWith((ref) => rules),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CategoriesRulesScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.text('open')));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(CategoriesRulesScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> rule(String pattern, {double? min, double? max}) =>
      RuleService(db).create(matchType: RuleMatchType.contains, pattern: pattern, categoryId: groceries, amountMin: min, amountMax: max);

  /// Rule patterns top to bottom, as rendered.
  List<String> renderedPatterns(WidgetTester tester, List<String> patterns) {
    final shown = [for (final p in patterns) (p, tester.getTopLeft(find.textContaining(p, findRichText: true)).dy)];
    shown.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final s in shown) s.$1];
  }

  Future<void> dragHandle(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, dy / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('swiping a rule away deletes it on confirm, before the row collapses', (tester) async {
    await rule('esselunga');
    await rule('coop');
    await pumpScreen(tester);
    try {
      await tester.drag(find.textContaining('esselunga', findRichText: true), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      // Well before the row's 300 ms collapse is over, the rule is gone and
      // the rules are marked changed: no rebuild can meet a dismissed row
      // the list still holds (it used to delete only once dismissed).
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect((await db.select(db.autoCategorizationRules).get()).map((r) => r.pattern), ['coop']);
      expect(container.read(rulesDirtyProvider), isTrue);

      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('esselunga', findRichText: true), findsNothing);
      expect(find.byKey(const Key('rulesDirtyBanner')), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a swiped rule stays when the delete is cancelled', (tester) async {
    await rule('esselunga');
    await pumpScreen(tester);
    try {
      await tester.drag(find.textContaining('esselunga', findRichText: true), const Offset(-600, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
      expect(find.textContaining('esselunga', findRichText: true), findsOneWidget);
      expect(await db.select(db.autoCategorizationRules).get(), hasLength(1));
      expect(container.read(rulesDirtyProvider), isFalse);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a dragged rule stays where it was dropped while the order is saved', (tester) async {
    await rule('alpha');
    await rule('bravo');
    await rule('charlie');
    await pumpScreen(tester);
    try {
      expect(renderedPatterns(tester, ['alpha', 'bravo', 'charlie']), ['alpha', 'bravo', 'charlie']);
      // Hold the database: the new order is not saved (nor streamed back) yet.
      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      final alphaRow = find.ancestor(of: find.textContaining('alpha', findRichText: true), matching: find.byType(ListTile));
      await dragHandle(tester, find.descendant(of: alphaRow, matching: find.byIcon(Icons.drag_handle)), 150);
      await settle(tester);

      expect(renderedPatterns(tester, ['alpha', 'bravo', 'charlie']), isNot(['alpha', 'bravo', 'charlie']), reason: 'the list snapped back');
      final dropped = renderedPatterns(tester, ['alpha', 'bravo', 'charlie']);

      release.complete();
      await held;
      await settle(tester);
      expect(renderedPatterns(tester, ['alpha', 'bravo', 'charlie']), dropped, reason: 'the saved order is the dropped one');
      expect((await RuleService(db).getAll()).map((r) => r.pattern), dropped);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a dragged category stays where it was dropped while the order is saved', (tester) async {
    await pumpScreen(tester);
    try {
      await tester.tap(find.byKey(const Key('tabCategories')));
      await settle(tester);
      final visible =
          (await (db.select(db.categories)
                    ..where((c) => c.isArchived.equals(false))
                    ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.id)]))
                  .get())
              .take(3)
              .map((c) => c.id)
              .toList();
      double top(int id) => tester.getTopLeft(find.byKey(ValueKey('cat_$id'))).dy;
      expect(top(visible[0]) < top(visible[1]) && top(visible[1]) < top(visible[2]), isTrue);

      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      await dragHandle(tester, find.descendant(of: find.byKey(ValueKey('cat_${visible[0]}')), matching: find.byIcon(Icons.drag_handle)), 150);
      await settle(tester);
      expect(top(visible[0]) > top(visible[1]), isTrue, reason: 'the list snapped back');

      release.complete();
      await held;
      await settle(tester);
      expect(top(visible[0]) > top(visible[1]), isTrue);
      final saved = await (db.select(db.categories)..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
      expect(saved.indexWhere((c) => c.id == visible[0]) > saved.indexWhere((c) => c.id == visible[1]), isTrue);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a classification run that ends after the screen closed still clears the flag', (tester) async {
    final classifier = _HeldClassifier(db);
    await pumpScreen(tester, classifier: classifier);
    try {
      container.read(rulesDirtyProvider.notifier).state = true;
      final release = classifier.hold = Completer<void>();
      await tester.tap(find.byKey(const Key('classifyUncategorized')));
      await settle(tester);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      expect(find.byType(CategoriesRulesScreen), findsNothing);

      release.complete();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(container.read(rulesDirtyProvider), isFalse, reason: 'the rules were applied');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a rule\'s amount bounds read in the locale', (tester) async {
    await rule('esselunga', min: 1500, max: 2500.5);
    await RuleService(db).create(matchType: RuleMatchType.contains, pattern: 'pizza', categoryId: dining);
    await pumpScreen(tester, locale: 'it_IT');
    try {
      expect(find.textContaining('≥ 1.500,00'), findsOneWidget);
      expect(find.textContaining('≤ 2.500,50'), findsOneWidget);
      expect(find.textContaining('1500.0'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
