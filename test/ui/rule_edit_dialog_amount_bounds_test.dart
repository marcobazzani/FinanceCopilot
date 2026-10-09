// The rule dialog's amount bounds are read in the active locale, strictly: a
// bound the locale cannot read ("10.50" in it_IT) is flagged on its field and
// Save stays off. It used to be read as "no bound", so the rule was saved
// without it and silently matched every amount.
//
// A stored bound the user leaves alone saves unchanged: it was pre-filled
// with two decimals, so saving a rule rewrote a 10.555 bound as 10.56.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/rule_edit_dialog.dart';

/// Opens the dialog [open] shows once the locale has loaded, as in the app
/// (the shell watches it): the dialog reads it when it opens.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.open);
  final Future<bool> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready ? TextButton(key: const Key('open'), onPressed: () => open(context), child: const Text('open')) : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late int groceries;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openDialog(WidgetTester tester, Future<bool> Function(BuildContext context) open) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: _Launcher(open)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));
  FilledButton save(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('ruleSave')));

  Future<List<AutoCategorizationRule>> rules() => db.select(db.autoCategorizationRules).get();

  testWidgets('an unreadable minimum is flagged, Save stays off and no unbounded rule is saved', (tester) async {
    await openDialog(
      tester,
      (context) =>
          showRuleEditDialog(context, initialMatchType: RuleMatchType.contains, initialPattern: 'esselunga', initialCategoryId: groceries),
    );
    try {
      expect(save(tester).onPressed, isNotNull, reason: 'pattern and category are set');
      expect(find.textContaining('Matches'), findsOneWidget, reason: 'the live match count');
      // "10.50" is not a number in it_IT (the dot groups thousands).
      await tester.enterText(field('Min amount'), '10.50');
      await settle(tester);

      expect(find.descendant(of: field('Min amount'), matching: find.text('Invalid number')), findsOneWidget);
      expect(save(tester).onPressed, isNull, reason: 'the rule would be saved with no minimum and match every amount');
      expect(find.textContaining('Matches'), findsNothing, reason: 'a count without the unreadable bound is the count of every amount');
      await tester.tap(find.byKey(const Key('ruleSave')), warnIfMissed: false);
      await settle(tester);
      expect(await rules(), isEmpty);

      await tester.enterText(field('Min amount'), '10,50');
      await settle(tester);
      expect(find.text('Invalid number'), findsNothing);
      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);

      final saved = (await rules()).single;
      expect(saved.amountMin, 10.5);
      expect(saved.amountMax, isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('an unreadable maximum is flagged and keeps the stored bound', (tester) async {
    final id = await RuleService(db).create(matchType: RuleMatchType.contains, pattern: 'esselunga', categoryId: groceries, amountMax: 1500);
    final rule = (await rules()).single;
    await openDialog(tester, (context) => showRuleEditDialog(context, rule: rule));
    try {
      expect(tester.widget<TextField>(field('Max amount')).controller!.text, '1.500,00');
      await tester.enterText(field('Max amount'), '1500.5');
      await settle(tester);

      expect(find.descendant(of: field('Max amount'), matching: find.text('Invalid number')), findsOneWidget);
      expect(save(tester).onPressed, isNull);
      expect((await rules()).single.amountMax, 1500);

      await tester.enterText(field('Max amount'), '1.500,5');
      await settle(tester);
      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);
      final saved = (await rules()).single;
      expect(saved.id, id);
      expect(saved.amountMax, 1500.5);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('empty bounds are no bound, and a readable one is saved as typed', (tester) async {
    await openDialog(
      tester,
      (context) => showRuleEditDialog(context, initialMatchType: RuleMatchType.contains, initialPattern: 'coop', initialCategoryId: groceries),
    );
    try {
      await tester.enterText(field('Max amount'), '2.000');
      await settle(tester);
      expect(find.text('Invalid number'), findsNothing);
      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);

      final saved = (await rules()).single;
      expect(saved.amountMin, isNull);
      expect(saved.amountMax, 2000, reason: 'it_IT groups thousands with the dot');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a pattern-only edit keeps every digit of the stored bounds', (tester) async {
    await RuleService(
      db,
    ).create(matchType: RuleMatchType.contains, pattern: 'esselunga', categoryId: groceries, amountMin: 10.555, amountMax: 1500);
    final rule = (await rules()).single;
    await openDialog(tester, (context) => showRuleEditDialog(context, rule: rule));
    try {
      expect(tester.widget<TextField>(field('Min amount')).controller!.text, '10,555', reason: 'it used to be pre-filled as 10,56');
      expect(tester.widget<TextField>(field('Max amount')).controller!.text, '1.500,00', reason: 'the usual spelling when it is exact');
      await tester.enterText(field('Pattern'), 'esselunga spa');
      await settle(tester);
      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);

      final saved = (await rules()).single;
      expect(saved.pattern, 'esselunga spa');
      expect(saved.amountMin, 10.555);
      expect(saved.amountMax, 1500);
    } finally {
      await unmount(tester);
    }
  });
}
