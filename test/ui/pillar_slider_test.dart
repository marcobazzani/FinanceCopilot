// Two things pinned here, both reported from the running app.
//
// 1. Dragging a slider reordered the list. `visibleRows` was re-sorted on every
//    build by each row's slice value, which is derived from `row.current` — the
//    value the slider mutates on every drag frame. Because each row carries a
//    ValueKey, Flutter RELOCATED the widget mid-gesture, so the drag continued
//    on whatever asset had taken that position. Order is now decided when the
//    screen opens and stays put.
//
// 2. "max 97%" looked like a broken slider. Standard pillars partition a
//    holding, so units already assigned to another standard pillar cannot be
//    assigned here. The label now says how many units are elsewhere.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, allSeriesDataProvider;
import 'package:finance_copilot/ui/screens/pillars/pillar_detail_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seedAsset({required String ticker, required double qty}) async {
    final interId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker $ticker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: '$ticker fund',
            ticker: Value(ticker),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: interId,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: DateTime(2025, 1, 1),
            valueDate: DateTime(2025, 1, 1),
            type: EventType.buy,
            amount: qty * 10,
            quantity: Value(qty),
            price: const Value(10),
          ),
        );
    return id;
  }

  Widget harness({
    required String pillarId,
    required Map<int, double> marketValues,
    required List<Asset> assets,
    required List<Pillar> pillars,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appLocaleProvider.overrideWith((ref) => Stream.value('en')),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        pillarsProvider.overrideWithValue(AsyncData(pillars)),
        standardPillarsProvider.overrideWithValue(AsyncData(pillars)),
        virtualPortfoliosProvider.overrideWithValue(const AsyncData([])),
        activeAssetsProvider.overrideWithValue(AsyncData(assets)),
        assetsProvider.overrideWithValue(AsyncData(assets)),
        pillarAssetsProvider.overrideWithValue(const AsyncData([])),
        assetMarketValuesProvider.overrideWithValue(AsyncData(marketValues)),
        unassignedFractionProvider.overrideWithValue(const AsyncData({})),
        allSeriesDataProvider.overrideWithValue(const AsyncData<AllSeriesData?>(null)),
        pillarPerformanceSnapshotsProvider.overrideWithValue(const AsyncData({})),
      ],
      child: MaterialApp(home: PillarDetailScreen(pillarId: pillarId)),
    );
  }

  /// Asset tickers in the order their rows are laid out on screen.
  List<String> rowOrder(WidgetTester tester, List<String> tickers) {
    final positions = <String, double>{};
    for (final t in tickers) {
      final f = find.textContaining('$t  ·  ');
      if (f.evaluate().isEmpty) continue;
      positions[t] = tester.getTopLeft(f.first).dy;
    }
    final sorted = positions.keys.toList()..sort((a, b) => positions[a]!.compareTo(positions[b]!));
    return sorted;
  }

  testWidgets('dragging a slider does not reorder the rows', (tester) async {
    // BIG is worth far more than SMALL, so the old slice-value sort put BIG
    // first. Dragging SMALL to 100% would have made its slice the larger one
    // and swapped the rows mid-gesture.
    final big = await seedAsset(ticker: 'BIG', qty: 100);
    final small = await seedAsset(ticker: 'SMALL', qty: 100);
    final pillarId = await PillarService(db).create(name: 'Retirement');
    final pillar = (await PillarService(db).getById(pillarId))!;
    final assets = await db.select(db.assets).get();

    await tester.pumpWidget(
      harness(
        pillarId: pillarId,
        marketValues: {big: 100000, small: 10},
        assets: assets,
        pillars: [pillar],
      ),
    );
    await tester.pumpAndSettle();

    final before = rowOrder(tester, ['BIG', 'SMALL']);
    expect(before, ['BIG', 'SMALL'], reason: 'rows open ordered by holding value');

    // Drag SMALL's slider all the way right.
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(2));
    await tester.drag(sliders.at(1), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(
      rowOrder(tester, ['BIG', 'SMALL']),
      before,
      reason: 'the list must not reorder while (or after) a slider is dragged',
    );
    // And the drag landed on SMALL, not on whatever row moved into its place.
    final assigned = await PillarService(db).qtyFor(pillarId, small);
    expect(assigned, greaterThan(0), reason: 'SMALL should have received the assignment');
    expect(await PillarService(db).qtyFor(pillarId, big), 0, reason: 'BIG must not have been touched');
  });

  testWidgets('a cap below 100% says how many units sit in other pillars', (tester) async {
    // Mirrors the real report: 129 units held, 3.87 assigned to another
    // standard pillar, so this pillar caps at 97%.
    final assetId = await seedAsset(ticker: 'EM13', qty: 129);
    final other = await PillarService(db).create(name: 'FIRE');
    await PillarService(db).assign(pillarId: other, assetId: assetId, qty: 3.87);
    final pillarId = await PillarService(db).create(name: 'Lombard');
    final pillars = [(await PillarService(db).getById(pillarId))!, (await PillarService(db).getById(other))!];
    final assets = await db.select(db.assets).get();

    await tester.pumpWidget(
      harness(pillarId: pillarId, marketValues: {assetId: 16496}, assets: assets, pillars: pillars),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('max 97%'), findsOneWidget);
    expect(
      find.textContaining('units in other pillars'),
      findsOneWidget,
      reason: 'a cap under 100% must explain itself, otherwise the slider reads as broken',
    );
  });

  testWidgets('a full cap stays the short label', (tester) async {
    final assetId = await seedAsset(ticker: 'XEON', qty: 2371);
    final pillarId = await PillarService(db).create(name: 'Retirement');
    final pillar = (await PillarService(db).getById(pillarId))!;
    final assets = await db.select(db.assets).get();

    await tester.pumpWidget(
      harness(pillarId: pillarId, marketValues: {assetId: 355493}, assets: assets, pillars: [pillar]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('max 100%'), findsOneWidget);
    expect(find.textContaining('other pillars'), findsNothing, reason: 'nothing to explain when the whole holding is available');
  });
}
