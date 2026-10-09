// The tax a rebalance sale is estimated to cost comes from the cost basis of
// the shares still held. It used to be the LIFETIME average buy price (every
// buy ever made, divided by every unit ever bought): after a full sale and a
// re-buy, the disposed lot's price was blended into the new position. The
// cost basis is the moving-average pool the asset screens use: a full sale
// empties it and the re-buy starts afresh.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/utils/asset_value_math.dart' show kDefaultTaxRate;

void main() {
  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Default'));
  });
  tearDown(() => db.close());

  const overweightIsin = 'IE00B4L5Y983';
  const otherIsin = 'IE00B579F325';

  Future<int> held(String name, String isin, List<(int, EventType, double, double)> events, double close) async {
    final id = await AssetService(db).create(name: name, isin: isin, currency: 'EUR', intermediaryId: broker);
    for (final (day, type, qty, price) in events) {
      await AssetEventService(db).create(
        assetId: id,
        date: DateTime(2026, 1, day),
        type: type,
        quantity: qty,
        price: price,
        amount: qty * price,
        currency: 'EUR',
      );
    }
    await db
        .into(db.marketPrices)
        .insert(MarketPricesCompanion.insert(assetId: id, date: DateTime(2026, 1, 9), closePrice: close, currency: 'EUR'));
    return id;
  }

  /// 50/50 model: the first asset (3,000) is overweight against the second
  /// (500), so the draft sells 4 units of it at 300.
  Future<PortfolioRebalanceDraftRow> saleOf(int overweight, int other) async {
    final modelId = await PortfolioModelService(db).createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: overweightIsin, targetWeight: 50),
        PortfolioModelInputItem(isin: otherIsin, targetWeight: 50),
      ],
    );
    final pillarId = await PillarService(db).create(name: 'Retirement', portfolioModelId: modelId);
    await PillarService(db).assign(pillarId: pillarId, assetId: overweight, qty: 10);
    await PillarService(db).assign(pillarId: pillarId, assetId: other, qty: 5);
    final draft = await PortfolioRebalanceService(db).buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 9),
    );
    final sale = draft.rows.singleWhere((r) => r.assetId == overweight && r.type == EventType.sell);
    expect(sale.estimatedQuantity, 4);
    expect(sale.baseAmount, closeTo(1200, 1e-9));
    expect(sale.currentBaseValue, closeTo(3000, 1e-9));
    return sale;
  }

  test('a full sale then a re-buy: the tax is on the gain over the re-buy price only', () async {
    final a = await held('A', overweightIsin, [
      (1, EventType.buy, 10, 100),
      (2, EventType.sell, 10, 150),
      (3, EventType.buy, 10, 200),
    ], 300);
    final b = await held('B', otherIsin, [(1, EventType.buy, 5, 100)], 100);

    final sale = await saleOf(a, b);
    // Cost of the 10 held = 2,000 (the re-buy): a third of the 3,000 value is
    // gain → 1,200 × 1/3 × 26% = 104. The lifetime average (3,000 / 20 × 10 =
    // 1,500) read half of it as gain: 156.
    expect(sale.estimatedTax, closeTo(1200 * (1000 / 3000) * 0.26, 1e-9));
  });

  test('a partial sale keeps the average cost of what is left', () async {
    final a = await held('A', overweightIsin, [
      (1, EventType.buy, 10, 100),
      (2, EventType.buy, 10, 200),
      (3, EventType.sell, 10, 250),
    ], 300);
    final b = await held('B', otherIsin, [(1, EventType.buy, 5, 100)], 100);

    final sale = await saleOf(a, b);
    // 10 left at the 150 average: cost 1,500, gain 1,500 of 3,000.
    expect(sale.estimatedTax, closeTo(1200 * 0.5 * 0.26, 1e-9));
  });

  group('default tax rate', () {
    Future<void> storeTaxRate(String value) =>
        (db.update(db.appConfigs)..where((c) => c.key.equals('TAX_RATE'))).write(AppConfigsCompanion(value: Value(value)));

    test('the stored rate applies', () async {
      await storeTaxRate('0.12');
      final a = await held('A', overweightIsin, [(1, EventType.buy, 10, 150)], 300);
      final b = await held('B', otherIsin, [(1, EventType.buy, 5, 100)], 100);

      final sale = await saleOf(a, b);
      expect(sale.estimatedTax, closeTo(1200 * 0.5 * 0.12, 1e-9));
    });

    test('an unreadable stored rate falls back to the shared default', () async {
      await storeTaxRate('n/a');
      final a = await held('A', overweightIsin, [(1, EventType.buy, 10, 150)], 300);
      final b = await held('B', otherIsin, [(1, EventType.buy, 5, 100)], 100);

      final sale = await saleOf(a, b);
      expect(sale.estimatedTax, closeTo(1200 * 0.5 * kDefaultTaxRate, 1e-9));
    });
  });
}
