// A pillar (or virtual portfolio) is deleted like every other entity: the
// confirmation's Delete is red. The detail view's trashcan asks through
// confirmAndDeletePillar, the one confirmation a list swipe can share.
//
// Pinned bug: the pillar detail's delete confirmation kept the default button
// colour, unlike the other deletes (assets, adjustments, transactions, …).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Pillar> createPillar(PillarKind kind) async {
    final id = await PillarService(db).create(name: 'Retirement', kind: kind);
    return (await PillarService(db).getById(id))!;
  }

  /// A page with an "open" button that pushes the detail view of [pillar].
  Future<void> pumpHost(WidgetTester tester, Pillar pillar, {String language = 'en'}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(language == 'it' ? 'it_IT' : 'en')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          pillarsProvider.overrideWith((ref) => ref.watch(pillarServiceProvider).watchAll()),
          standardPillarsProvider.overrideWithValue(AsyncData([pillar])),
          virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
          activeAssetsProvider.overrideWithValue(const AsyncData([])),
          assetsProvider.overrideWithValue(const AsyncData([])),
          pillarAssetsProvider.overrideWithValue(const AsyncData([])),
          assetMarketValuesProvider.overrideWithValue(const AsyncData({})),
          unassignedFractionProvider.overrideWithValue(const AsyncData({})),
          allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
          pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PillarDetailScreen(pillarId: pillar.id))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  /// The open confirmation's Delete button.
  FilledButton deleteButton(WidgetTester tester, AppStrings s) =>
      tester.widget<FilledButton>(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, s.delete)));

  for (final kind in PillarKind.values) {
    testWidgets('${kind.name}: the detail trashcan asks with a red Delete; Cancel keeps it, Delete removes it and leaves', (tester) async {
      const s = AppStrings.en;
      final pillar = await createPillar(kind);
      await pumpHost(tester, pillar);
      try {
        await tester.tap(find.byTooltip(s.delete));
        await settle(tester);
        final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect((alert.title! as Text).data, s.delete);
        expect((alert.content! as Text).data, kind == PillarKind.virtual ? s.virtualPortfolioDeleteConfirm : s.pillarDeleteConfirm);
        expect(deleteButton(tester, s).style?.backgroundColor?.resolve({}), Colors.red, reason: 'as every other delete asks');

        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.byType(PillarDetailScreen), findsOneWidget);
        expect(await PillarService(db).getAll(), hasLength(1));

        await tester.tap(find.byTooltip(s.delete));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.delete));
        await settle(tester);
        expect(await PillarService(db).getAll(), isEmpty);
        expect(find.byType(PillarDetailScreen), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  }

  group('confirmAndDeletePillar, as a list swipe calls it', () {
    const s = AppStrings.it;

    /// A button that asks for [pillar] and records each answer.
    Future<List<bool>> pumpCaller(WidgetTester tester, Pillar pillar) async {
      final answers = <bool>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            portableLanguageProvider.overrideWith((ref) => 'it'),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => answers.add(await confirmAndDeletePillar(context, ref, pillar)),
                  child: const Text('delete'),
                ),
              ),
            ),
          ),
        ),
      );
      return answers;
    }

    for (final kind in PillarKind.values) {
      testWidgets('${kind.name}: its own message and a red Delete, in the UI language; says whether it deleted', (tester) async {
        final pillar = await createPillar(kind);
        final answers = await pumpCaller(tester, pillar);
        try {
          await tester.tap(find.text('delete'));
          await settle(tester);
          final alert = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect((alert.title! as Text).data, s.delete);
          expect((alert.content! as Text).data, kind == PillarKind.virtual ? s.virtualPortfolioDeleteConfirm : s.pillarDeleteConfirm);
          expect(deleteButton(tester, s).style?.backgroundColor?.resolve({}), Colors.red);

          await tester.tap(find.widgetWithText(TextButton, s.cancel));
          await settle(tester);
          expect(answers, [false]);
          expect(await PillarService(db).getAll(), hasLength(1));

          await tester.tap(find.text('delete'));
          await settle(tester);
          await tester.tap(find.widgetWithText(FilledButton, s.delete));
          await settle(tester);
          expect(answers, [false, true]);
          expect(await PillarService(db).getAll(), isEmpty);
        } finally {
          await unmount(tester);
        }
      });
    }
  });
}
