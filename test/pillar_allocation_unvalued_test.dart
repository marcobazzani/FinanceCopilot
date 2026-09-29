// A pillar's allocation view values each held asset at its market value. An
// asset held without a price, or without an exchange rate to the base
// currency, has no value: it used to be listed as worth 0 — shrinking the
// pillar and every weight computed from it. It is left out and counted.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final today = DateTime(2025, 6, 10);
  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  /// The pillar's allocation data, read over the seeded database.
  Future<PillarAllocationData> allocation(String pillarId) async {
    final assets = await AssetService(db).getAll();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(assets)),
        activeAssetsProvider.overrideWithValue(AsyncData(assets.where((a) => a.isActive).toList())),
        assetStatsProvider.overrideWithValue(AsyncData(await AssetService(db).getStatsForAll())),
        pillarAssetsProvider.overrideWithValue(AsyncData(await db.select(db.pillarAssets).get())),
      ],
    );
    addTearDown(container.dispose);
    return container.read(pillarAllocationDataProvider(pillarId).future);
  }

  Future<int> asset(String name, {String currency = 'EUR', double? buyPrice, double? close}) async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: Value(currency),
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
            price: Value(buyPrice),
            currency: Value(currency),
          ),
        );
    if (close != null) {
      await db
          .into(db.marketPrices)
          .insert(MarketPricesCompanion.insert(assetId: id, date: DateTime(2025, 6, 9), closePrice: close, currency: currency));
    }
    return id;
  }

  test('an asset without a price or an exchange rate is left out of the pillar and counted', () async {
    final priced = await asset('Priced', buyPrice: 100, close: 120);
    final unpriced = await asset('Unpriced');
    final noRate = await asset('No rate', currency: 'USD', buyPrice: 100, close: 110);
    final pillarId = await PillarService(db).create(name: 'Retirement');
    for (final id in [priced, unpriced, noRate]) {
      await PillarService(db).assign(pillarId: pillarId, assetId: id, qty: 5);
    }

    final data = await allocation(pillarId);
    expect(data.assets.map((a) => a.id), [priced]);
    expect(data.marketValues, {priced: 10 * 120 * 0.5}, reason: 'half of the priced holding is in the pillar');
    expect(data.unvaluedAssetCount, 2);
  });

  test('every held asset valued: nothing left out', () async {
    final a = await asset('A', buyPrice: 100, close: 120);
    final b = await asset('B', buyPrice: 50, close: 40);
    final pillarId = await PillarService(db).create(name: 'Retirement');
    await PillarService(db).assign(pillarId: pillarId, assetId: a, qty: 10);
    await PillarService(db).assign(pillarId: pillarId, assetId: b, qty: 10);

    final data = await allocation(pillarId);
    expect(data.marketValues, {a: 1200.0, b: 400.0});
    expect(data.unvaluedAssetCount, 0);
  });
}
