// Deleting an asset from its detail screen removes its events and the asset
// in one transaction: nobody (another screen, the dashboard) ever reads the
// half-deleted state of an asset without events. The two deletes used to be
// separate writes, so an interruption between them left exactly that.
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
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// Holds the asset delete until [release] completes: the moment between the
/// two writes, made long enough to look at.
class _HeldAssetService extends AssetService {
  _HeldAssetService(super.db);

  final release = Completer<void>();

  @override
  Future<int> delete(int id) async {
    await release.future;
    return super.delete(id);
  }
}

void main() {
  late AppDatabase db;
  late Asset asset;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 10),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Events and assets counted in one statement: a consistent snapshot.
  Future<(int, int)> counts() async {
    final row = await db.customSelect('SELECT (SELECT COUNT(*) FROM asset_events) AS e, (SELECT COUNT(*) FROM assets) AS a').getSingle();
    return (row.read<int>('e'), row.read<int>('a'));
  }

  testWidgets('the events and the asset go in one transaction', (tester) async {
    final assets = _HeldAssetService(db);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          assetServiceProvider.overrideWithValue(assets),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AssetDetailScreen(asset: asset))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    try {
      await tester.tap(find.byTooltip('Delete Asset'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      // The events are gone, the asset delete is held: what does a reader see?
      final seen = counts();
      assets.release.complete();
      await settle(tester);
      expect(await seen, isNot((0, 1)), reason: 'a reader saw the asset without its events');
      expect(await counts(), (0, 0));
      expect(find.byType(AssetDetailScreen), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
