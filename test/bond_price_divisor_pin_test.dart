// A bond is quoted per 100 of face value: every valuation from a quoted price
// divides it by 100 for a bond and by 1 for anything else. Pinned at every
// place that applies that divisor, with the expected figure written in the
// same operation order as the code, so a shared divisor changes nothing.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_charts_provider.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show AllSeriesData, ChartSeries, allSeriesDataProvider;
import 'package:finance_copilot/utils/asset_value_math.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

class _FakeMarketDataService extends WebMarketDataService {
  final Map<String, List<ProviderSearchResult>> searchResults;
  final Map<String, Map<DateTime, double>> pricesByTicker;

  _FakeMarketDataService(super.db, {required this.searchResults, required this.pricesByTicker});

  @override
  Future<List<ProviderSearchResult>> search(String query) async => searchResults[query] ?? const [];

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => pricesByTicker[ticker] ?? const {};

  @override
  Future<Map<DateTime, double>> fetchHistoricalPricesForListing(ProviderSearchResult listing, DateTime from) async =>
      pricesByTicker[listing.symbol] ?? const {};
}

void main() {
  final d0 = DateTime(2025, 3, 3);
  DateTime day(int n) => d0.add(Duration(days: n));
  const usdEur = 0.9123;

  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  test('bondPriceDivisor: 100 for a bond, 1 for every other instrument', () {
    for (final type in InstrumentType.values) {
      expect(bondPriceDivisor(type), type == InstrumentType.bond ? 100.0 : 1.0, reason: type.name);
    }
  });

  Future<int> asset(String name, InstrumentType type, {String currency = 'EUR', String? isin}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          ticker: Value(name),
          isin: Value(isin),
          assetType: AssetType.stockEtf,
          instrumentType: Value(type),
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: broker,
          currency: Value(currency),
        ),
      );

  Future<void> buy(int assetId, double qty, double price, {String currency = 'EUR', bool bond = false}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: d0,
          valueDate: d0,
          type: EventType.buy,
          amount: qty * price / (bond ? 100 : 1),
          quantity: Value(qty),
          price: Value(price),
          currency: Value(currency),
        ),
      );

  Future<void> close(int assetId, DateTime date, double price, {String currency = 'EUR'}) =>
      db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: date, closePrice: price, currency: currency));

  Future<void> usdRate() async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: d0, rate: usdEur));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: d0, rate: 1 / usdEur));
  }

  group('valuation providers', () {
    late int btp;
    late int world;
    late int tNote;
    late ProviderContainer container;

    setUp(() async {
      btp = await asset('BTP', InstrumentType.bond);
      world = await asset('WORLD', InstrumentType.etf);
      tNote = await asset('TNOTE', InstrumentType.bond, currency: 'USD');
      await buy(btp, 2000, 98.37, bond: true);
      await buy(world, 3, 101.25);
      await buy(tNote, 1000, 97.5, currency: 'USD', bond: true);
      for (final (id, first, second, ccy) in [(btp, 98.37, 99.13, 'EUR'), (world, 101.25, 102.5, 'EUR'), (tNote, 97.5, 96.8, 'USD')]) {
        await close(id, day(0), first, currency: ccy);
        await close(id, day(1), second, currency: ccy);
      }
      await usdRate();
      final assets = await AssetService(db).getAll();
      final stats = await AssetService(db).getStatsForAll();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
          nowProvider.overrideWithValue(() => day(1).add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
          accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
          assetsProvider.overrideWithValue(AsyncData(assets)),
          assetStatsProvider.overrideWithValue(AsyncData(stats)),
          extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('market value per asset: quantity × price ÷ divisor × rate', () async {
      final values = await container.read(assetMarketValuesProvider.future);
      expect(values[btp], 2000 * 99.13 / 100.0 * 1.0);
      expect(values[world], 3 * 102.5 / 1.0 * 1.0);
      expect(values[tNote], 1000 * 96.8 / 100.0 * usdEur);
    });

    test('price changes carry the divisor', () async {
      final changes = await container.read(assetDailyChangesProvider(day(0)).future);
      final byName = {for (final c in changes) c.name: c};
      expect(byName['BTP']!.priceDivisor, 100.0);
      expect(byName['WORLD']!.priceDivisor, 1.0);
      expect(byName['TNOTE']!.priceDivisor, 100.0);
      expect(byName['BTP']!.valueDiff, (99.13 * 2000 / 100.0 * 1.0) - (98.37 * 2000 / 100.0 * 1.0));
    });

    test('dashboard market series', () async {
      final data = await container.read(allSeriesDataProvider.future);
      double at(int id, int x) => data!.assetMarket.singleWhere((s) => s.key == 'asset_market:$id').spots.singleWhere((p) => p.x == x).y;
      expect(at(btp, 0), 2000 * 98.37 / 100.0 * 1.0);
      expect(at(btp, 1), 2000 * 99.13 / 100.0 * 1.0);
      expect(at(world, 1), 3 * 102.5 / 1.0 * 1.0);
      expect(at(tNote, 1), 1000 * 96.8 / 100.0 * usdEur);
    });

    test('asset detail price series', () async {
      final chartContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          allSeriesDataProvider.overrideWith(
            (ref) async => AllSeriesData(
              firstDate: d0,
              accounts: const [],
              assetInvested: const [],
              assetMarket: [
                for (final id in [btp, world])
                  ChartSeries(key: 'asset_market:$id', name: '$id', color: Colors.blue, spots: const [FlSpot(0, 1), FlSpot(1, 1)]),
              ],
              assetGain: const [],
              assetNet: const [],
              adjustments: const [],
              incomeAdjustments: const [],
              ephemeralInflows: const [],
              baseCurrency: 'EUR',
            ),
          ),
        ],
      );
      addTearDown(chartContainer.dispose);
      final bond = await chartContainer.read(singleAssetChartDataProvider(btp).future);
      expect(bond!.priceSeries.spots.map((p) => p.y), [98.37 / 100.0, 99.13 / 100.0]);
      final fund = await chartContainer.read(singleAssetChartDataProvider(world).future);
      expect(fund!.priceSeries.spots.map((p) => p.y), [101.25 / 1.0, 102.5 / 1.0]);
    });
  });

  test('a bond revalue is stored as a price per 100 of face value', () async {
    final btp = await asset('BTP', InstrumentType.bond);
    await buy(btp, 2000, 98.37, bond: true);
    await AssetEventService(db).create(assetId: btp, date: day(2), type: EventType.revalue, amount: 2010.5, currency: 'EUR');
    final prices = await db.select(db.marketPrices).get();
    expect(prices.single.closePrice, 2010.5 / 2000 * 100.0);
  });

  test('rebalance: a held bond and a bond target are valued per 100 of face value', () async {
    const heldIsin = 'IT0005383309';
    const targetIsin = 'IT0005436693';
    final btp = await asset('BTP', InstrumentType.bond, isin: heldIsin);
    await buy(btp, 2000, 98.37, bond: true);
    await close(btp, day(1), 99.13);
    final modelId = await PortfolioModelService(db).createCustomModel(
      name: 'Bonds',
      items: const [
        PortfolioModelInputItem(isin: heldIsin, targetWeight: 50),
        PortfolioModelInputItem(isin: targetIsin, targetWeight: 50),
      ],
    );
    final pillarId = await PillarService(db).create(name: 'Income', portfolioModelId: modelId);
    await PillarService(db).assign(pillarId: pillarId, assetId: btp, qty: 2000);

    final rebalance = PortfolioRebalanceService(
      db,
      marketDataService: _FakeMarketDataService(
        db,
        searchResults: {
          targetIsin: const [
            ProviderSearchResult(cid: 3001, description: 'BTP 2031', symbol: 'BTP31', exchange: 'Xetra', flag: 'DE', type: 'Bonds - Xetra'),
          ],
        },
        pricesByTicker: {
          'BTP31': {day(1): 101.4},
        },
      ),
    );
    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: day(1),
    );

    final sale = draft.rows.singleWhere((r) => r.assetId == btp && r.type == EventType.sell);
    expect(sale.currentBaseValue, 2000 * 99.13 / 100.0 * 1.0);
    expect(sale.baseAmount, sale.estimatedQuantity * (99.13 / 100.0 * 1.0));
    final targetBuy = draft.rows.singleWhere((r) => r.isin == targetIsin && r.type == EventType.buy);
    expect(targetBuy.autoCreateSpec!.instrumentType, InstrumentType.bond);
    expect(targetBuy.estimatedQuantity, greaterThan(0));
    expect(targetBuy.baseAmount, targetBuy.estimatedQuantity * (101.4 / 100.0 * 1.0));
  });
}
