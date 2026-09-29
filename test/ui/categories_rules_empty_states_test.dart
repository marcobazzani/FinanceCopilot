// Settings → Categories & rules: an empty tab shows the shared empty state
// (icon above the centred tagline), inside the tab's pull-to-refresh list.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/classification/categories_rules_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectEmptyState(WidgetTester tester, IconData icon, String message) {
    final empty = find.widgetWithText(EmptyState, message);
    expect(empty, findsOneWidget);
    final iconFinder = find.descendant(of: empty, matching: find.byIcon(icon));
    expect(iconFinder, findsOneWidget);
    expect(tester.getCenter(iconFinder).dy, lessThan(tester.getCenter(find.text(message)).dy));
    expect(tester.widget<Text>(find.text(message)).textAlign, TextAlign.center);
    expect(find.ancestor(of: empty, matching: find.byType(MobilePullToRefresh)), findsOneWidget);
    expect(
      tester.widget<ListView>(find.ancestor(of: empty, matching: find.byType(ListView)).first).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
  }

  testWidgets('no rules: the shared empty state', (tester) async {
    await pumpScreen(tester);
    try {
      expectEmptyState(tester, Icons.rule, s.noRulesYet);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('no category to show: the shared empty state', (tester) async {
    await db.update(db.categories).write(const CategoriesCompanion(isArchived: Value(true)));
    await pumpScreen(tester);
    try {
      await tester.tap(find.byKey(const Key('tabCategories')));
      await settle(tester);
      expectEmptyState(tester, Icons.label_outline, s.noCategoriesYet);
    } finally {
      await unmount(tester);
    }
  });
}
