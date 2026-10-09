// Pins for the portfolio clean-up (dead fields, one helper for the rebalance
// "cannot draft" entries, one parser for the stored default tax rate):
// - a pillar's divergence from its model: matched and extra holdings, the
//   holdings without a value or a quantity in neither;
// - every "cannot draft" entry of a rebalance draft, field by field;
// - the default tax rate read by the dashboard and by the rebalance: unset
//   or unreadable is 26%, anything else is clamped to [0, 1].
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/utils/asset_value_math.dart' show parseStoredTaxRate;
import 'package:finance_copilot/services/providers/providers.dart';

void main() {
  const world = 'IE00B4L5Y983';
  const bonds = 'IE00B579F325';
  const usa = 'IE00BK5BQT80';
  final asOf = DateTime(2026, 2, 2);

  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> asset(String name, {String? isin, String currency = 'EUR'}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          isin: Value(isin),
          currency: Value(currency),
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: broker,
        ),
      );

  Future<void> trade(int assetId, EventType type, double qty, double price, {DateTime? on, String currency = 'EUR'}) => AssetEventService(
    db,
  ).create(assetId: assetId, date: on ?? DateTime(2026, 1, 5), type: type, quantity: qty, price: price, amount: qty * price, currency: currency);

  Future<void> close(int assetId, double price, {String currency = 'EUR'}) => db
      .into(db.marketPrices)
      .insert(MarketPricesCompanion.insert(assetId: assetId, date: DateTime(2026, 2, 1), closePrice: price, currency: currency));

  Future<void> usdRate(DateTime on) async {
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: on, rate: 0.9));
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: on, rate: 1 / 0.9));
  }

  Future<String> model(List<(String, double)> items) =>
      PortfolioModelService(
        db,
      ).createCustomModel(
        name: 'Model',
        items: [for (final (isin, weight) in items) PortfolioModelInputItem(isin: isin, targetWeight: weight)],
      );

  test('pinned: divergence — matched and extra holdings; no value or no quantity, neither', () async {
    final matched = await asset('World', isin: world);
    final extra = await asset('Extra', isin: usa);
    final unvalued = await asset('Unvalued', isin: bonds);
    final sold = await asset('Sold', isin: bonds);
    for (final id in [matched, extra, unvalued, sold]) {
      await trade(id, EventType.buy, 10, 100);
    }
    final modelId = await model([(world, 50), (bonds, 50)]);
    final pillarId = await PillarService(db).create(name: 'Retirement', portfolioModelId: modelId);
    for (final id in [matched, extra, unvalued, sold]) {
      await PillarService(db).assign(pillarId: pillarId, assetId: id, qty: 10);
    }
    await trade(sold, EventType.sell, 10, 100);

    final divergence = (await PortfolioModelService(db).computeDivergenceForPillar(
      pillarId: pillarId,
      marketValuesByAssetId: {matched: 1000, extra: 1000, sold: 0},
    ))!;
    expect(
      [for (final r in divergence.rows) (r.target.isin, r.assetIds.join(','), r.currentValue, r.currentWeight)],
      [
        (world, '$matched', 1000.0, 50.0),
        (bonds, '', 0.0, 0.0),
      ],
    );
    expect(
      [for (final e in divergence.extraHoldings) (e.assetId, e.assetName, e.isin, e.currentValue, e.currentWeight)],
      [
        (extra, 'Extra', usa, 1000.0, 50.0),
      ],
    );
  });

  group('pinned: the entries a rebalance draft cannot draft, field by field', () {
    Future<List<(String?, String?, int?, String?, String?, PortfolioRebalanceUnresolvedReason)>> unresolved(String pillarId) async {
      final draft = await PortfolioRebalanceService(
        db,
      ).buildDraft(scope: PortfolioRebalanceScope.currentPillar(pillarId), mode: PortfolioRebalanceMode.sellAndBuy, asOf: asOf);
      return [for (final u in draft.unresolved) (u.pillarId, u.pillarName, u.assetId, u.assetName, u.isin, u.reason)];
    }

    test('a pillar without a model', () async {
      final pillarId = await PillarService(db).create(name: 'Loose');
      expect(await unresolved(pillarId), [(pillarId, 'Loose', null, null, null, PortfolioRebalanceUnresolvedReason.missingModel)]);
    });

    test('drafted around: no quantity yet, no ISIN, a target without a price or a rate', () async {
      final held = await asset('World', isin: world);
      await trade(held, EventType.buy, 10, 100);
      await close(held, 110);
      final noIsin = await asset('No ISIN');
      await trade(noIsin, EventType.buy, 5, 100);
      await close(noIsin, 100);
      final later = await asset('Later', isin: world);
      await trade(later, EventType.buy, 3, 100, on: DateTime(2026, 3, 1));
      // Targets already on file, outside the pillar: one never priced, one
      // priced in a currency without a rate.
      final unpricedTarget = await asset('Bonds', isin: ' ie00b579f325 ');
      final dollarTarget = await asset('USA', isin: usa, currency: 'USD');
      await close(dollarTarget, 50, currency: 'USD');

      final pillarId = await PillarService(db).create(name: 'Retirement', portfolioModelId: await model([(world, 40), (bonds, 30), (usa, 30)]));
      for (final (id, qty) in [(held, 10.0), (noIsin, 5.0), (later, 3.0)]) {
        await PillarService(db).assign(pillarId: pillarId, assetId: id, qty: qty);
      }

      expect(await unresolved(pillarId), [
        (pillarId, 'Retirement', later, 'Later', null, PortfolioRebalanceUnresolvedReason.missingCurrentQuantity),
        (pillarId, 'Retirement', noIsin, 'No ISIN', null, PortfolioRebalanceUnresolvedReason.missingIsin),
        (pillarId, 'Retirement', unpricedTarget, 'Bonds', ' ie00b579f325 ', PortfolioRebalanceUnresolvedReason.missingMarketPrice),
        (pillarId, 'Retirement', dollarTarget, 'USA', usa, PortfolioRebalanceUnresolvedReason.missingFxRate),
      ]);
    });

    test('blocking: a held asset without a price, a rate or a convertible cost', () async {
      final modelId = await model([(world, 100)]);
      final unpriced = await asset('Unpriced', isin: world);
      await trade(unpriced, EventType.buy, 10, 100);
      final noRate = await asset('No rate', isin: world, currency: 'USD');
      await trade(noRate, EventType.buy, 10, 100, currency: 'USD');
      await close(noRate, 100, currency: 'USD');
      final noCostRate = await asset('No cost rate', isin: world, currency: 'USD');
      await trade(noCostRate, EventType.buy, 10, 100, currency: 'USD');

      final expected = <String, (int, PortfolioRebalanceUnresolvedReason)>{
        'A': (unpriced, PortfolioRebalanceUnresolvedReason.missingMarketPrice),
        'B': (noRate, PortfolioRebalanceUnresolvedReason.missingFxRate),
      };
      final pillarIds = <String, String>{};
      for (final MapEntry(key: name, value: (id, _)) in expected.entries) {
        pillarIds[name] = await PillarService(db).create(name: name, portfolioModelId: modelId);
        await PillarService(db).assign(pillarId: pillarIds[name]!, assetId: id, qty: 10);
      }
      for (final MapEntry(key: name, value: (id, reason)) in expected.entries) {
        final assetName = (await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle()).name;
        expect(await unresolved(pillarIds[name]!), [(pillarIds[name], name, id, assetName, world, reason)]);
      }

      // Priced, with a rate today but none on the day it was bought.
      await close(noCostRate, 100, currency: 'USD');
      await usdRate(DateTime(2026, 2, 1));
      final c = await PillarService(db).create(name: 'C', portfolioModelId: modelId);
      await PillarService(db).assign(pillarId: c, assetId: noCostRate, qty: 10);
      expect(await unresolved(c), [(c, 'C', noCostRate, 'No cost rate', world, PortfolioRebalanceUnresolvedReason.missingCostBasisFx)]);
    });
  });

  group('pinned: the default tax rate', () {
    Future<void> store(String? value) async {
      await (db.delete(db.appConfigs)..where((c) => c.key.equals('TAX_RATE'))).go();
      if (value != null) await db.into(db.appConfigs).insert(AppConfigsCompanion.insert(key: 'TAX_RATE', value: value));
    }

    Future<double> dashboardRate() async {
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      // Listened to: a provider nobody listens to is paused, its stream too.
      container.listen(defaultTaxRateProvider, (_, _) {});
      return container.read(defaultTaxRateProvider.future);
    }

    /// The tax the rebalance estimates on selling 3 of 10 units bought at
    /// 100 and now at 150 (a third of the value is gain): 150 × the rate.
    Future<double> rebalanceTax() async {
      final draft = await PortfolioRebalanceService(
        db,
      ).buildDraft(scope: PortfolioRebalanceScope.currentPillar(_pillar), mode: PortfolioRebalanceMode.sellAndBuy, asOf: asOf);
      return draft.estimatedTax;
    }

    setUp(() async {
      final gaining = await asset('World', isin: world);
      await trade(gaining, EventType.buy, 10, 100);
      await close(gaining, 150);
      final other = await asset('Bonds', isin: bonds);
      await trade(other, EventType.buy, 5, 100);
      await close(other, 100);
      _pillar = await PillarService(db).create(name: 'Retirement', portfolioModelId: await model([(world, 50), (bonds, 50)]));
      await PillarService(db).assign(pillarId: _pillar, assetId: gaining, qty: 10);
      await PillarService(db).assign(pillarId: _pillar, assetId: other, qty: 5);
    });

    for (final (stored, rate) in [(null, 0.26), ('0.3', 0.3), ('1.5', 1.0), ('-0.2', 0.0), ('abc', 0.26), ('', 0.26)]) {
      test('stored ${stored == null ? 'nothing' : '"$stored"'}: $rate', () async {
        await store(stored);
        expect(await dashboardRate(), rate);
        expect(await rebalanceTax(), closeTo(150 * rate, 1e-9));
      });
    }
  });

  group('parseStoredTaxRate: the one reading of the stored default tax rate', () {
    late List<LogRecord> warnings;

    setUp(() {
      warnings = [];
      final sub = Logger.root.onRecord.where((r) => r.level == Level.WARNING).listen(warnings.add);
      addTearDown(sub.cancel);
    });

    test('nothing stored: the default, silently', () async {
      expect(parseStoredTaxRate(null), 0.26);
      await pumpEventQueue();
      expect(warnings, isEmpty);
    });

    test('a number: clamped to [0, 1], silently', () async {
      expect(parseStoredTaxRate('0.3'), 0.3);
      expect(parseStoredTaxRate('1.5'), 1.0);
      expect(parseStoredTaxRate('-0.2'), 0.0);
      await pumpEventQueue();
      expect(warnings, isEmpty);
    });

    test('an unreadable value: the default, and a warning that names it', () async {
      expect(parseStoredTaxRate('26%'), 0.26);
      await pumpEventQueue();
      expect(warnings.map((r) => r.message), [contains('"26%"')]);
    });
  });
}

late String _pillar;
