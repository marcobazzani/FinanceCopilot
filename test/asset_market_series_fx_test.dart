// A foreign-currency position on the dashboard's market-value series is
// converted day by day with the latest stored FX rate on or before that day.
//
// This path used to run only in the live-data integration walkthrough, and
// only when the provider happened to return a non-base-currency listing for
// one of the fixture assets. Pinned here on fixed data.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider;

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final d0 = DateTime(2026, 1, 1);
  DateTime day(int n) => d0.add(Duration(days: n));

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
        nowProvider.overrideWithValue(() => day(5)),
        marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
        accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
        accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
        assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
        assetStatsProvider.overrideWithValue(const AsyncData(<int, AssetStats>{})),
        extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> rate(String from, String to, DateTime date, double rate) =>
      db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: from, toCurrency: to, date: date, rate: rate));

  test('USD position is valued with the latest rate on or before each day; no rate yet means no point', () async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
            currency: const Value('USD'),
          ),
        );
    // Cost basis carries its own stamped rate; the market value does not.
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: d0,
            valueDate: d0,
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
            currency: const Value('USD'),
            exchangeRate: const Value(1.25),
          ),
        );
    for (var n = 0; n <= 5; n++) {
      await db
          .into(db.marketPrices)
          .insert(MarketPricesCompanion.insert(assetId: assetId, date: day(n), closePrice: n < 5 ? 100 : 110, currency: 'USD'));
    }
    await rate('USD', 'EUR', day(1), 0.9); // direct
    await rate('EUR', 'USD', day(2), 1.6); // inverse only → 1 / 1.6
    // day 3: no row — carries day 2's rate
    await rate('USD', 'EUR', day(4), 0.8); // direct and inverse on the same day:
    await rate('EUR', 'USD', day(4), 2.0); //   the direct quote wins

    final data = await container.read(allSeriesDataProvider.future);
    final market = data!.assetMarket.singleWhere((s) => s.key == 'asset_market:$assetId');
    final byX = {for (final s in market.spots) s.x.toInt(): s.y};

    expect(byX.containsKey(0), isFalse, reason: 'no USD/EUR rate on or before day 0: skip the point, never assume 1.0');
    expect(byX[1], closeTo(900, 1e-9)); // 10 × 100 × 0.9
    expect(byX[2], closeTo(625, 1e-9)); // 10 × 100 / 1.6
    expect(byX[3], closeTo(625, 1e-9)); // latest rate on or before day 3
    expect(byX[4], closeTo(800, 1e-9)); // direct 0.8, not 1 / 2.0
    expect(byX[5], closeTo(880, 1e-9)); // 10 × 110 × 0.8

    final invested = data.assetInvested.singleWhere((s) => s.key == 'asset_invested:$assetId');
    expect(invested.spots.first.y, closeTo(800, 1e-9), reason: 'cost basis uses the rate stamped on the buy: 1000 / 1.25');
  });
}
