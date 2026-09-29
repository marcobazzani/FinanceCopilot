// Pins for the provider clean-up:
// - a pillar's allocation counts the held assets it leaves out for want of a
//   value — the same count as the allocation tab's (one helper): an asset of
//   the pillar with a quantity held and no market value; not one outside the
//   pillar, nor one not held on the viewed date.
// - the converted event amounts of an asset are released with the asset
//   screen: they used to stay alive for the whole session, and kept the
//   asset's event stream alive with them.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
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

  Future<int> asset(String name, {double? close}) async {
    final id = await AssetService(db).create(name: name, currency: 'EUR', intermediaryId: broker);
    await AssetEventService(
      db,
    ).create(assetId: id, date: DateTime(2025, 1, 10), type: EventType.buy, quantity: 10, amount: 1000, currency: 'EUR');
    if (close != null) {
      await db
          .into(db.marketPrices)
          .insert(MarketPricesCompanion.insert(assetId: id, date: DateTime(2025, 6, 9), closePrice: close, currency: 'EUR'));
    }
    return id;
  }

  test('pinned: a pillar counts its held assets without a value, and only those', () async {
    final priced = await asset('Priced', close: 120);
    final unpriced = await asset('Unpriced');
    final outside = await asset('Outside');
    final notHeldYet = await asset('Not held yet');
    final pillarId = await PillarService(db).create(name: 'Retirement');
    for (final id in [priced, unpriced, notHeldYet]) {
      await PillarService(db).assign(pillarId: pillarId, assetId: id, qty: 5);
    }
    // [outside] is in no pillar; [notHeldYet] is not held on the viewed date.
    final stats = await AssetService(db).getStatsForAll();
    stats[notHeldYet] = const AssetStats(eventCount: 0);
    final assets = await AssetService(db).getAll();

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(assets)),
        activeAssetsProvider.overrideWithValue(AsyncData(assets)),
        assetStatsProvider.overrideWithValue(AsyncData(stats)),
        pillarAssetsProvider.overrideWithValue(AsyncData(await db.select(db.pillarAssets).get())),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(pillarAllocationDataProvider(pillarId).future);
    expect(data.assets.map((a) => a.id), [priced]);
    expect(data.marketValues, {priced: 10 * 120 * 0.5});
    expect(data.unvaluedAssetCount, 1, reason: 'only the unpriced asset of the pillar; not $outside, not $notHeldYet');
  });

  test("an asset's converted event amounts are released once nothing shows the asset", () async {
    final id = await asset('World');
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
      ],
    );
    addTearDown(container.dispose);

    final delivered = <Map<int, double>>[];
    final sub = container.listen<AsyncValue<Map<int, double>>>(convertedEventAmountsProvider(id), (_, next) {
      if (next case AsyncData(:final value)) delivered.add(value);
    }, fireImmediately: true);
    for (var i = 0; i < 50 && delivered.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(delivered.last.values, [1000], reason: 'delivers while listened to');

    sub.close();
    await container.pump();
    expect(container.exists(convertedEventAmountsProvider(id)), isFalse);
    expect(container.exists(assetEventsProvider(id)), isFalse, reason: 'and no longer keeps the event stream alive');
  });
}
