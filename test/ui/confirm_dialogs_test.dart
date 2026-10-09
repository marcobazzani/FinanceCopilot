// Confirmation dialogs that used to be hand-rolled AlertDialogs and now go
// through the shared showConfirmDialog. Each test pins the title, message,
// button labels, confirm colour and outcome of Cancel / confirm.
//
// Pinned bug: the composition "Refresh from market" confirmation popped with
// the section's (outer) context instead of the dialog's. Under a nested
// Navigator that popped the screen's route instead of the dialog, which then
// never closed.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

/// Records refresh requests instead of fetching composition data.
class _RecordingCompositionService extends CompositionService {
  _RecordingCompositionService(super.db);

  final refreshed = <int>[];

  @override
  Future<void> clearAndResync(int assetId) async => refreshed.add(assetId);

  @override
  Future<void> syncCompositions() async {}
}

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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  void useView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// The open dialog's confirm button (a FilledButton labelled [label]).
  FilledButton confirmButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, label)));

  void expectDialog(WidgetTester tester, {required String title, required String content, required String confirm}) {
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final alert = tester.widget<AlertDialog>(dialog);
    expect((alert.title! as Text).data, title);
    expect((alert.content! as Text).data, content);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, s.cancel)), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, confirm)), findsOneWidget);
  }

  group('SelectionActionBar bulk delete', () {
    Future<(SelectionController<int>, List<Set<int>>)> pumpBar(WidgetTester tester) async {
      final controller = SelectionController<int>()..selectAll([1, 2]);
      addTearDown(controller.dispose);
      final deleted = <Set<int>>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: SelectionActionBar<int>(
                controller: controller,
                visibleIds: const [1, 2, 3],
                onDelete: (ids) async => deleted.add(ids),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip(s.delete));
      await settle(tester);
      return (controller, deleted);
    }

    testWidgets('asks with the item count and a destructive confirm; Cancel keeps the selection', (tester) async {
      final (controller, deleted) = await pumpBar(tester);
      expectDialog(tester, title: s.bulkDeleteTitle, content: s.bulkDeleteBody(2), confirm: s.delete);
      final errorColor = Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error;
      expect(confirmButton(tester, s.delete).style?.backgroundColor?.resolve({}), errorColor);

      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(deleted, isEmpty);
      expect(controller.ids, {1, 2});
    });

    testWidgets('Delete deletes the selected ids and clears the selection', (tester) async {
      final (controller, deleted) = await pumpBar(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(deleted, [
        {1, 2},
      ]);
      expect(controller.active, isFalse);
    });
  });

  group('Pillar detail delete', () {
    Future<void> openDetail(WidgetTester tester, Pillar pillar) async {
      useView(tester, const Size(1200, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appLocaleProvider.overrideWith((ref) => Stream.value('en')),
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
      await tester.tap(find.byTooltip(s.delete));
      await settle(tester);
    }

    for (final kind in PillarKind.values) {
      testWidgets('${kind.name}: kind-specific message; Cancel keeps it, Delete removes it and leaves the screen', (tester) async {
        final id = await PillarService(db).create(name: 'Retirement', kind: kind);
        final pillar = (await PillarService(db).getById(id))!;
        await openDetail(tester, pillar);
        try {
          final message = kind == PillarKind.virtual ? s.virtualPortfolioDeleteConfirm : s.pillarDeleteConfirm;
          expectDialog(tester, title: s.delete, content: message, confirm: s.delete);
          expect(confirmButton(tester, s.delete).style?.backgroundColor?.resolve({}), Colors.red, reason: 'red, as every other delete asks');

          await tester.tap(find.widgetWithText(TextButton, s.cancel));
          await settle(tester);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(PillarDetailScreen), findsOneWidget);
          expect(await PillarService(db).getAll(), hasLength(1));

          await tester.tap(find.byTooltip(s.delete));
          await settle(tester);
          await tester.tap(find.widgetWithText(FilledButton, s.delete));
          await settle(tester);
          expect(await PillarService(db).getAll(), isEmpty);
          expect(find.byType(PillarDetailScreen), findsNothing);
          expect(find.text('open'), findsOneWidget);
        } finally {
          await unmount(tester);
        }
      });
    }
  });

  testWidgets('custom portfolio model delete: Cancel keeps it, Delete removes it', (tester) async {
    final service = PortfolioModelService(db);
    final modelId = await service.createCustomModel(
      name: 'My model',
      items: const [PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100, description: 'World')],
    );
    // Wide enough for the built-in model labels in the test font.
    useView(tester, const Size(2400, 1200));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: PillarsScreen()),
      ),
    );
    await settle(tester);
    try {
      await tester.tap(find.widgetWithText(Tab, s.pillarTabPortfolioModels));
      await settle(tester);
      // The row swipes to delete (it used to have a trash button).
      await tester.drag(find.text('My model'), const Offset(-1500, 0));
      await settle(tester);
      expectDialog(tester, title: s.delete, content: s.portfolioModelDeleteConfirm, confirm: s.delete);
      expect(confirmButton(tester, s.delete).style?.backgroundColor?.resolve({}), Colors.red, reason: 'red, like every other delete');

      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await service.getById(modelId), isNotNull);

      await tester.drag(find.text('My model'), const Offset(-1500, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.delete));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await service.getById(modelId), isNull);
    } finally {
      await unmount(tester);
    }
  });

  group('Composition refresh', () {
    late _RecordingCompositionService compositions;
    late Asset asset;

    setUp(() async {
      compositions = _RecordingCompositionService(db);
      final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      final id = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'World fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
            ),
          );
      await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'USA', weight: 60));
      asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    });

    /// The detail screen lives in a nested Navigator (as in a split layout):
    /// the dialog opens on the root one.
    Future<void> openRefresh(WidgetTester tester) async {
      useView(tester, const Size(1200, 1600));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => DateTime(2026, 3, 10, 12)),
            marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
            compositionServiceProvider.overrideWithValue(compositions),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip(s.compositionRefreshTooltip));
      await settle(tester);
    }

    testWidgets('Cancel closes the confirmation and keeps the screen and its data', (tester) async {
      await openRefresh(tester);
      try {
        expectDialog(tester, title: s.compositionRefreshTooltip, content: s.cannotBeUndone, confirm: s.update);
        expect(confirmButton(tester, s.update).style, isNull, reason: 'the confirm button keeps the default colour');

        await tester.tap(find.widgetWithText(TextButton, s.cancel));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AssetDetailScreen), findsOneWidget);
        expect(compositions.refreshed, isEmpty);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('Update closes the confirmation and refreshes this asset once', (tester) async {
      await openRefresh(tester);
      try {
        await tester.tap(find.widgetWithText(FilledButton, s.update));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(AssetDetailScreen), findsOneWidget);
        expect(compositions.refreshed, [asset.id]);
      } finally {
        await unmount(tester);
      }
    });
  });
}
