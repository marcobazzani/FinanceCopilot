import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

class _FakeMarketDataService extends WebMarketDataService {
  final Map<String, List<ProviderSearchResult>> searchResults;
  final Map<String, Map<DateTime, double>> pricesByTicker;

  _FakeMarketDataService(
    super.db, {
    required this.searchResults,
    required this.pricesByTicker,
  });

  @override
  Future<List<ProviderSearchResult>> search(String query) async => searchResults[query] ?? const [];

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(
    String ticker,
    String currency,
    DateTime from,
  ) async => pricesByTicker[ticker] ?? const {};

  @override
  Future<Map<DateTime, double>> fetchHistoricalPricesForListing(
    ProviderSearchResult listing,
    DateTime from,
  ) async => pricesByTicker[listing.symbol] ?? const {};
}

void main() {
  late AppDatabase db;
  late AssetService assets;
  late AssetEventService events;
  late PillarService pillars;
  late PortfolioModelService models;
  late PortfolioRebalanceService rebalance;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assets = AssetService(db);
    events = AssetEventService(db);
    pillars = PillarService(db);
    models = PortfolioModelService(db);
    rebalance = PortfolioRebalanceService(db);
    intermediaryId = await db
        .into(db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
  });

  tearDown(() async => db.close());

  Future<int> assetPosition({
    required String name,
    required String isin,
    required double quantity,
    required double buyPrice,
    required double marketPrice,
    double? taxRate,
  }) async {
    final assetId = await assets.create(
      name: name,
      isin: isin,
      currency: 'EUR',
      intermediaryId: intermediaryId,
      taxRate: taxRate,
    );
    await events.create(
      assetId: assetId,
      date: DateTime(2026, 1, 1),
      type: EventType.buy,
      quantity: quantity,
      price: buyPrice,
      amount: quantity * buyPrice,
      currency: 'EUR',
    );
    await db
        .into(db.marketPrices)
        .insert(
          MarketPricesCompanion.insert(
            assetId: assetId,
            date: DateTime(2026, 1, 2),
            closePrice: marketPrice,
            currency: 'EUR',
          ),
        );
    return assetId;
  }

  Future<String> twoAssetPillar({
    required int firstAsset,
    required int secondAsset,
    required double firstQty,
    required double secondQty,
    double firstWeight = 50,
    double secondWeight = 50,
  }) async {
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: firstWeight),
        PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: secondWeight),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: firstAsset, qty: firstQty);
    await pillars.assign(pillarId: pillarId, assetId: secondAsset, qty: secondQty);
    return pillarId;
  }

  test('exact target portfolio produces no trades', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 10, secondQty: 10);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.rows, isEmpty);
  });

  test('overweight asset creates sell draft and underweight asset creates buy draft', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 15,
      buyPrice: 100,
      marketPrice: 100,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 5,
      buyPrice: 100,
      marketPrice: 100,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 15, secondQty: 5);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.rows.where((row) => row.assetId == a && row.type == EventType.sell), hasLength(1));
    expect(draft.rows.where((row) => row.assetId == b && row.type == EventType.buy), hasLength(1));
  });

  test('buy-only allocates contribution to underweight matched assets', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 8,
      buyPrice: 100,
      marketPrice: 100,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 2,
      buyPrice: 100,
      marketPrice: 100,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 8, secondQty: 2);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 1000,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.rows.where((row) => row.type == EventType.buy), isNotEmpty);
    expect(draft.rows.any((row) => row.assetId == b), isTrue);
  });

  test('buy-only includes target assets that are not currently held when the asset exists', () async {
    final held = await assetPosition(
      name: 'Held',
      isin: 'IE00B4L5Y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final targetOnlyAssetId = await assetPosition(
      name: 'Target only',
      isin: 'IE00B579F325',
      quantity: 1,
      buyPrice: 50,
      marketPrice: 50,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50),
        PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 50),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: held, qty: 10);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 1000,
      asOf: DateTime(2026, 1, 2),
    );

    expect(draft.unresolved.where((row) => row.reason == PortfolioRebalanceUnresolvedReason.unmatchedModelItem), isEmpty);
    expect(draft.rows.any((row) => row.assetId == targetOnlyAssetId && row.type == EventType.buy), isTrue);
  });

  test('buy-only matches stored assets by normalized ISIN case', () async {
    final held = await assetPosition(
      name: 'Held',
      isin: 'ie00b4l5y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    await assetPosition(
      name: 'Target only',
      isin: 'ie00b579f325',
      quantity: 1,
      buyPrice: 50,
      marketPrice: 50,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50),
        PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 50),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: held, qty: 10);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 1000,
      asOf: DateTime(2026, 1, 2),
    );

    expect(draft.unresolved.where((row) => row.reason == PortfolioRebalanceUnresolvedReason.unmatchedModelItem), isEmpty);
    expect(draft.rows.where((row) => row.type == EventType.buy), isNotEmpty);
  });

  test('buy-only spends remaining cash across whole units in one pass', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 1,
      buyPrice: 10,
      marketPrice: 10,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 1,
      buyPrice: 11,
      marketPrice: 11,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 1, secondQty: 1);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 21,
      asOf: DateTime(2026, 1, 2),
    );

    expect(draft.availableCashBase, closeTo(21, 1e-9));
    expect(draft.targetBuyBase, closeTo(21, 1e-9));
    expect(draft.executedBuyBase, closeTo(21, 1e-9));
    expect(draft.leftoverCashBase, closeTo(0, 1e-9));
    expect(draft.rows.where((row) => row.type == EventType.buy), hasLength(2));
  });

  test('tax-aware net proceeds reduce available buy cash', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 15,
      buyPrice: 50,
      marketPrice: 100,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 5,
      buyPrice: 100,
      marketPrice: 100,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 15, secondQty: 5);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.estimatedTax, closeTo(65, 1e-9));
    expect(draft.availableCashBase, closeTo(435, 1e-9));
    final buy = draft.rows.singleWhere((row) => row.type == EventType.buy);
    expect(buy.baseAmount, closeTo(400, 1e-9));
    expect(draft.leftoverCashBase, closeTo(35, 1e-9));
  });

  test('sell-and-buy rounds to whole units and reports the cash gap', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 5,
      buyPrice: 30,
      marketPrice: 30,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 1,
      buyPrice: 30,
      marketPrice: 30,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 60),
        PortfolioModelInputItem(isin: 'IE00B579F325', targetWeight: 40),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: a, qty: 5);
    await pillars.assign(pillarId: pillarId, assetId: b, qty: 1);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );

    expect(draft.availableCashBase, closeTo(30, 1e-9));
    expect(draft.targetBuyBase, closeTo(42, 1e-9));
    expect(draft.executedBuyBase, closeTo(30, 1e-9));
    expect(draft.buyShortfallBase, closeTo(12, 1e-9));
    expect(draft.leftoverCashBase, closeTo(0, 1e-9));
    expect(draft.rows.where((row) => row.type == EventType.sell).single.estimatedQuantity, 1);
    expect(draft.rows.where((row) => row.type == EventType.buy).single.estimatedQuantity, 1);
  });

  test('per-asset tax override beats global tax', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 15,
      buyPrice: 50,
      marketPrice: 100,
      taxRate: 0.10,
    );
    final b = await assetPosition(
      name: 'B',
      isin: 'IE00B579F325',
      quantity: 5,
      buyPrice: 100,
      marketPrice: 100,
    );
    final pillarId = await twoAssetPillar(firstAsset: a, secondAsset: b, firstQty: 15, secondQty: 5);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.estimatedTax, closeTo(25, 1e-9));
  });

  test('missing price excludes affected rows with an unresolved reason', () async {
    final assetId = await assets.create(
      name: 'A',
      isin: 'IE00B4L5Y983',
      currency: 'EUR',
      intermediaryId: intermediaryId,
    );
    await events.create(
      assetId: assetId,
      date: DateTime(2026, 1, 1),
      type: EventType.buy,
      quantity: 10,
      price: 100,
      amount: 1000,
      currency: 'EUR',
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: assetId, qty: 10);

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.sellAndBuy,
      asOf: DateTime(2026, 1, 2),
    );
    expect(draft.rows, isEmpty);
    expect(draft.unresolved.single.reason, PortfolioRebalanceUnresolvedReason.missingMarketPrice);
  });

  test('applying a draft creates asset event rows only after explicit apply', () async {
    final a = await assetPosition(
      name: 'A',
      isin: 'IE00B4L5Y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 100),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: a, qty: 10);
    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 100,
      asOf: DateTime(2026, 1, 2),
    );
    expect(await events.getByAsset(a), hasLength(1));
    final inserted = await rebalance.applyDraft(draft, events, date: DateTime(2026, 1, 3));
    expect(inserted, hasLength(1));
    expect(await events.getByAsset(a), hasLength(2));
  });

  test('missing target asset becomes executable from market data and apply auto-creates it', () async {
    final held = await assetPosition(
      name: 'Held',
      isin: 'IE00B4L5Y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50),
        PortfolioModelInputItem(
          isin: 'IE0006WW1TQ4',
          targetWeight: 50,
          description: 'Xtrackers MSCI World ex USA UCITS ETF 1C',
        ),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: held, qty: 10);

    rebalance = PortfolioRebalanceService(
      db,
      marketDataService: _FakeMarketDataService(
        db,
        searchResults: {
          'IE0006WW1TQ4': const [
            ProviderSearchResult(
              cid: 2001,
              description: 'Xtrackers MSCI World ex USA UCITS ETF 1C USD',
              symbol: 'EXUS',
              exchange: 'Xetra',
              flag: 'DE',
              type: 'ETFs - Xetra',
              url: '/etfs/exus-xetra',
            ),
          ],
        },
        pricesByTicker: {
          'EXUS': {
            DateTime(2026, 1, 2): 100,
          },
        },
      ),
    );

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 1000,
      asOf: DateTime(2026, 1, 2),
    );

    final targetBuy = draft.rows.singleWhere(
      (row) => row.type == EventType.buy && row.isin == 'IE0006WW1TQ4',
    );
    expect(targetBuy.isPlaceholder, isFalse);
    expect(targetBuy.assetId, isNull);
    expect(targetBuy.autoCreateSpec, isNotNull);
    expect(targetBuy.currency, 'EUR');
    expect(targetBuy.price, 100);
    expect(targetBuy.estimatedQuantity, greaterThan(0));
    expect(draft.hasExecutableTrades, isTrue);

    final inserted = await rebalance.applyDraft(
      draft,
      events,
      date: DateTime(2026, 1, 3),
    );
    expect(inserted, isNotEmpty);

    final createdAsset = await (db.select(db.assets)..where((a) => a.isin.equals('IE0006WW1TQ4'))).getSingleOrNull();
    expect(createdAsset, isNotNull);
    expect(createdAsset!.ticker, 'EXUS');
    expect(createdAsset.exchange, 'Xetra');

    final createdEvents = await events.getByAsset(createdAsset.id);
    expect(createdEvents, hasLength(1));
    expect(createdEvents.single.type, EventType.buy);
    expect(createdEvents.single.quantity, targetBuy.estimatedQuantity);

    final assignmentQuery = db.select(db.pillarAssets)
      ..where((pa) => pa.pillarId.equals(pillarId))
      ..where((pa) => pa.assetId.equals(createdAsset.id));
    final assignment = await assignmentQuery.getSingleOrNull();
    expect(assignment, isNotNull);
    expect(assignment!.quantity, targetBuy.estimatedQuantity);
  });

  test('progressive draft emits placeholders before resolving missing target assets', () async {
    final held = await assetPosition(
      name: 'Held',
      isin: 'IE00B4L5Y983',
      quantity: 10,
      buyPrice: 100,
      marketPrice: 100,
    );
    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(isin: 'IE00B4L5Y983', targetWeight: 50),
        PortfolioModelInputItem(
          isin: 'IE0006WW1TQ4',
          targetWeight: 50,
          description: 'Xtrackers MSCI World ex USA UCITS ETF 1C',
        ),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
    await pillars.assign(pillarId: pillarId, assetId: held, qty: 10);

    rebalance = PortfolioRebalanceService(
      db,
      marketDataService: _FakeMarketDataService(
        db,
        searchResults: {
          'IE0006WW1TQ4': const [
            ProviderSearchResult(
              cid: 2001,
              description: 'Xtrackers MSCI World ex USA UCITS ETF 1C USD',
              symbol: 'EXUS',
              exchange: 'Xetra',
              flag: 'DE',
              type: 'ETFs - Xetra',
              url: '/etfs/exus-xetra',
            ),
          ],
        },
        pricesByTicker: {
          'EXUS': {
            DateTime(2026, 1, 2): 100,
          },
        },
      ),
    );

    final drafts = await rebalance
        .buildDraftStream(
          scope: PortfolioRebalanceScope.currentPillar(pillarId),
          mode: PortfolioRebalanceMode.buyOnly,
          contributionAmount: 1000,
          asOf: DateTime(2026, 1, 2),
        )
        .toList();

    expect(drafts, hasLength(2));
    expect(drafts.first.rows.any((row) => row.isin == 'IE0006WW1TQ4' && row.isPlaceholder), isTrue);
    final resolvedBuy = drafts.last.rows.singleWhere((row) => row.isin == 'IE0006WW1TQ4');
    expect(resolvedBuy.isPlaceholder, isFalse);
    expect(resolvedBuy.autoCreateSpec?.ticker, 'EXUS');
  });

  test('applyDraft auto-creates a default intermediary when the database has none', () async {
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assets = AssetService(db);
    events = AssetEventService(db);
    pillars = PillarService(db);
    models = PortfolioModelService(db);

    final modelId = await models.createCustomModel(
      name: 'Model',
      items: const [
        PortfolioModelInputItem(
          isin: 'IE0006WW1TQ4',
          targetWeight: 100,
          description: 'Xtrackers MSCI World ex USA UCITS ETF 1C',
          preferredTicker: 'EXUS',
          preferredExchange: 'Xetra',
        ),
      ],
    );
    final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);

    rebalance = PortfolioRebalanceService(
      db,
      marketDataService: _FakeMarketDataService(
        db,
        searchResults: {
          'IE0006WW1TQ4': const [
            ProviderSearchResult(
              cid: 2001,
              description: 'Xtrackers MSCI World ex USA UCITS ETF 1C USD',
              symbol: 'EXUS',
              exchange: 'Xetra',
              flag: 'DE',
              type: 'ETFs - Xetra',
              url: '/etfs/exus-xetra',
            ),
          ],
        },
        pricesByTicker: {
          'EXUS': {DateTime(2026, 1, 2): 100},
        },
      ),
    );

    final draft = await rebalance.buildDraft(
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      mode: PortfolioRebalanceMode.buyOnly,
      contributionAmount: 1000,
      asOf: DateTime(2026, 1, 2),
    );

    final inserted = await rebalance.applyDraft(
      draft,
      events,
      date: DateTime(2026, 1, 3),
    );
    expect(inserted, hasLength(1));

    final allIntermediaries = await db.select(db.intermediaries).get();
    expect(allIntermediaries, hasLength(1));
    expect(allIntermediaries.single.name, 'Default');

    final createdAsset = await (db.select(db.assets)..where((a) => a.isin.equals('IE0006WW1TQ4'))).getSingle();
    expect(createdAsset.intermediaryId, allIntermediaries.single.id);
  });
}
