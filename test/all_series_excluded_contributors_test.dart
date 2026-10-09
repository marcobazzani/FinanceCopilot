// Totals leave out a contributor they cannot convert to the base currency —
// and now say so. Assets without a price were already counted
// ([unpricedAssetIds]); these were dropped without a count:
// - an account whose balance is in a currency without any rate: its series
//   has no spots;
// - an adjustment in such a currency: its series were not even kept;
// - an asset with a buy or sell amount without a rate: the amount is missing
//   from its invested line, so a total built from that line (Saving) misses
//   it, and its gain series has no spots.
// [AllSeriesData] names the accounts and adjustments, and [totalExclusions]
// reports every contributor a total leaves out, each once, with one
// aggregated count for the footnote.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show AllSeriesData, ChartSeries, TotalExclusions, allSeriesDataProvider, buildSmartTotalSpots, totalExclusions;

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final d0 = DateTime(2026, 1, 5);
  DateTime day(int n) => DateTime(d0.year, d0.month, d0.day + n);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
        nowProvider.overrideWithValue(() => day(3)),
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

  Future<int> account(String name, {String currency = 'EUR', required double balance}) async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: name, currency: Value(currency)));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(accountId: id, operationDate: day(0), valueDate: day(0), amount: balance, balanceAfter: Value(balance)),
        );
    return id;
  }

  Future<int> adjustment(String name, {String currency = 'EUR', double amount = 500}) => db
      .into(db.extraordinaryEvents)
      .insert(
        ExtraordinaryEventsCompanion.insert(
          name: name,
          direction: EventDirection.outflow,
          treatment: EventTreatment.instant,
          totalAmount: amount,
          currency: Value(currency),
          eventDate: day(1),
        ),
      );

  Future<int> fund(String name) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    for (var n = 0; n <= 3; n++) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: day(n), closePrice: 100, currency: 'EUR'));
    }
    return id;
  }

  Future<void> buy(int assetId, DateTime on, {required double amount, required double qty, String currency = 'EUR'}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: EventType.buy,
          amount: amount,
          quantity: Value(qty),
          price: Value(amount / qty),
          currency: Value(currency),
        ),
      );

  Future<AllSeriesData> data() async {
    final d = await container.read(allSeriesDataProvider.future);
    return d!;
  }

  ChartSeries? series(AllSeriesData d, String key) => d.allSeries.where((s) => s.key == key).firstOrNull;

  group('an account in a currency without any rate', () {
    test('is named on the data and counted under a total that holds it', () async {
      final eur = await account('Main', balance: 1000);
      final usd = await account('Dollars', currency: 'USD', balance: 400);

      final d = await data();
      expect(series(d, 'account:$usd')!.spots, isEmpty, reason: 'no rate, no value');
      expect(d.excludedAccountIds, {usd});
      final cash = totalExclusions(d.cashSeries, d);
      expect(cash.accountIds, {usd});
      expect(cash.excludedFromTotalCount, 1);
      expect(buildSmartTotalSpots(d.cashSeries).last.y, 1000, reason: 'the total itself is unchanged: the EUR account only');
      expect(d.excludedAccountIds.contains(eur), isFalse);
    });

    test('a total without it counts nothing', () async {
      await account('Main', balance: 1000);
      final usd = await account('Dollars', currency: 'USD', balance: 400);

      final d = await data();
      final withoutIt = d.accounts.where((s) => s.key != 'account:$usd').toList();
      expect(totalExclusions(withoutIt, d).excludedFromTotalCount, 0);
    });
  });

  group('an adjustment in a currency without any rate', () {
    test('keeps its series without spots, is named on the data and counted', () async {
      await account('Main', balance: 1000);
      final eurEvent = await adjustment('Roof');
      final usdEvent = await adjustment('Car', currency: 'USD');

      final d = await data();
      expect(series(d, 'adjustment_value:$usdEvent'), isNotNull, reason: 'kept, so a total built from it can count it');
      expect(series(d, 'adjustment_value:$usdEvent')!.spots, isEmpty, reason: 'no rate, no value');
      expect(series(d, 'adjustment_value:$eurEvent')!.spots, isNotEmpty);
      expect(d.excludedAdjustmentIds, {usdEvent});

      final saving = totalExclusions(d.savingSeries, d);
      expect(saving.adjustmentIds, {usdEvent});
      expect(saving.excludedFromTotalCount, 1);
      expect(buildSmartTotalSpots(d.savingSeries).last.y, 1000 + 500, reason: 'the EUR adjustment only');
    });

    test('with a rate it is converted and nothing is counted', () async {
      await account('Main', balance: 1000);
      final usdEvent = await adjustment('Car', currency: 'USD');
      await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: d0, rate: 0.9));

      final d = await data();
      expect(series(d, 'adjustment_value:$usdEvent')!.spots.last.y, closeTo(450, 1e-9));
      expect(d.excludedAdjustmentIds, isEmpty);
      expect(totalExclusions(d.savingSeries, d).excludedFromTotalCount, 0);
    });
  });

  group('an asset with a buy amount without a rate', () {
    test('is counted under a total its invested line stands in, not under its market value', () async {
      final a = await fund('Fund');
      await buy(a, day(0), amount: 1100, qty: 10, currency: 'USD');
      await buy(a, day(2), amount: 100, qty: 1);

      final d = await data();
      final invested = d.assetInvested.where((s) => s.key == 'asset_invested:$a').toList();
      final saving = totalExclusions(invested, d);
      expect(saving.costBasisIncompleteAssetIds, {a}, reason: 'the 1,100 USD is missing from the invested line');
      expect(saving.excludedFromTotalCount, 1);

      final gain = totalExclusions(d.assetGain, d);
      expect(gain.costBasisIncompleteAssetIds, {a}, reason: 'no gain drawn against a partial cost basis');

      expect(totalExclusions(d.assetMarket, d).excludedFromTotalCount, 0, reason: 'the units are held: the market value is whole');
      expect(totalExclusions([...invested, ...d.assetMarket], d).excludedFromTotalCount, 0, reason: 'the market value stands for it');
    });

    test('a complete cost basis counts nothing', () async {
      final a = await fund('Fund');
      await buy(a, day(0), amount: 1000, qty: 10);

      final d = await data();
      expect(totalExclusions([...d.assetInvested, ...d.assetGain], d).excludedFromTotalCount, 0);
    });

    test('every amount without a rate: the invested line is kept without spots, and counted', () async {
      final a = await fund('Fund');
      await buy(a, day(0), amount: 1100, qty: 10, currency: 'USD');

      final d = await data();
      final invested = d.assetInvested.where((s) => s.key == 'asset_invested:$a').toList();
      expect(invested, hasLength(1), reason: 'kept, so a Saving total built from it can count it');
      expect(invested.single.spots, isEmpty, reason: 'no amount converts: no invested figure');
      expect(totalExclusions(invested, d).costBasisIncompleteAssetIds, {a});
      expect(totalExclusions(invested, d).excludedFromTotalCount, 1);
    });
  });

  test('each contributor is counted once, alongside the unpriced assets', () async {
    await account('Main', balance: 1000);
    final usd = await account('Dollars', currency: 'USD', balance: 400);
    final usdEvent = await adjustment('Car', currency: 'USD');
    final a = await fund('Fund');
    await buy(a, day(0), amount: 1100, qty: 10, currency: 'USD');
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other'));
    final unpriced = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Unpriced',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: unpriced,
            date: day(0),
            valueDate: day(0),
            type: EventType.buy,
            amount: 50,
            quantity: const Value(1),
            currency: const Value('EUR'),
          ),
        );

    final d = await data();
    final nav = totalExclusions([...d.accounts, ...d.assetNet, ...d.adjustments], d);
    expect(nav.accountIds, {usd});
    expect(nav.adjustmentIds, {usdEvent});
    expect(nav.unpricedAssetIds, {a, unpriced}, reason: 'the net value of the fund is not drawn either');

    final all = nav.union(totalExclusions(d.cashSeries, d)).union(totalExclusions(d.savingSeries, d)).union(totalExclusions(d.assetGain, d));
    expect(all.excludedFromTotalCount, 4, reason: 'the dollar account, the dollar adjustment, the fund and the unpriced asset');
  });

  test('nothing to count: an empty set of exclusions', () {
    final d = AllSeriesData(
      firstDate: d0,
      accounts: [
        const ChartSeries(key: 'account:1', name: 'Main', color: Color(0xFF2196F3), spots: [FlSpot(0, 1)]),
      ],
      assetInvested: const [],
      assetMarket: const [],
      assetGain: const [],
      assetNet: const [],
      adjustments: const [],
      incomeAdjustments: const [],
      ephemeralInflows: const [],
      baseCurrency: 'EUR',
    );
    expect(d.excludedAccountIds, isEmpty);
    expect(d.excludedAdjustmentIds, isEmpty);
    expect(totalExclusions(d.accounts, d).excludedFromTotalCount, 0);
    expect(const TotalExclusions().excludedFromTotalCount, 0);
  });
}
