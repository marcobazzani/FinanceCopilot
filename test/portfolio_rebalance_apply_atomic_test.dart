// Applying a rebalance draft writes several rows per trade (auto-created
// asset, its price, the event, the pillar assignment). A failure half-way
// through must leave NOTHING written: a partially applied draft is a
// portfolio nobody asked for — some trades booked, the rest missing, and no
// way to tell which from the UI.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';

/// Writes the first `failOn - 1` events for real, then fails.
class _FailingEventService extends AssetEventService {
  final int failOn;
  var _calls = 0;

  _FailingEventService(super.db, {required this.failOn});

  @override
  Future<int> create({
    required int assetId,
    required DateTime date,
    required EventType type,
    required double amount,
    double? quantity,
    double? price,
    required String currency,
    double? exchangeRate,
    String? exchangeRateBase,
    double? commission,
    String? notes,
  }) async {
    if (++_calls == failOn) throw StateError('write failed');
    return super.create(
      assetId: assetId,
      date: date,
      type: type,
      amount: amount,
      quantity: quantity,
      price: price,
      currency: currency,
      exchangeRate: exchangeRate,
      exchangeRateBase: exchangeRateBase,
      commission: commission,
      notes: notes,
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  PortfolioRebalanceDraftRow buyRow({
    required String pillarId,
    required int? assetId,
    required String isin,
    PortfolioRebalanceAutoCreateSpec? autoCreateSpec,
  }) => PortfolioRebalanceDraftRow(
    pillarId: pillarId,
    pillarName: 'Retirement',
    assetId: assetId,
    assetName: isin,
    isin: isin,
    type: EventType.buy,
    amount: 100,
    baseAmount: 100,
    estimatedQuantity: 1,
    price: 100,
    currency: 'EUR',
    fxRate: 1,
    estimatedTax: 0,
    currentBaseValue: 0,
    projectedBaseValue: 100,
    autoCreateSpec: autoCreateSpec,
    notes: 'rebalance',
  );

  test('a failure while applying a draft rolls back every row the draft already wrote', () async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final held = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Held',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
            isin: const Value('IE00B4L5Y983'),
          ),
        );
    final pillarId = await PillarService(db).create(name: 'Retirement');

    final draft = PortfolioRebalanceDraft(
      mode: PortfolioRebalanceMode.buyOnly,
      scope: PortfolioRebalanceScope.currentPillar(pillarId),
      baseCurrency: 'EUR',
      rows: [
        buyRow(pillarId: pillarId, assetId: held, isin: 'IE00B4L5Y983'),
        buyRow(
          pillarId: pillarId,
          assetId: null,
          isin: 'IE0006WW1TQ4',
          autoCreateSpec: const PortfolioRebalanceAutoCreateSpec(
            isin: 'IE0006WW1TQ4',
            ticker: 'EXUS',
            exchange: 'Xetra',
            currency: 'EUR',
            instrumentType: InstrumentType.etf,
            assetClass: AssetClass.equity,
            assetType: AssetType.stockEtf,
          ),
        ),
        buyRow(pillarId: pillarId, assetId: held, isin: 'IE00B4L5Y983'),
      ],
      unresolved: const [],
      availableCashBase: 300,
      targetBuyBase: 300,
      executedBuyBase: 300,
      buyShortfallBase: 0,
      leftoverCashBase: 0,
      currentPortfolioValueBase: 0,
      projectedPortfolioValueBase: 300,
    );

    await expectLater(
      PortfolioRebalanceService(db).applyDraft(draft, _FailingEventService(db, failOn: 3), date: DateTime(2026, 1, 3)),
      throwsStateError,
    );

    expect(await db.select(db.assetEvents).get(), isEmpty, reason: 'the two events written before the failure are rolled back');
    expect((await db.select(db.assets).get()).map((a) => a.id), [held], reason: 'no auto-created asset survives');
    expect(await db.select(db.marketPrices).get(), isEmpty, reason: "nor the auto-created asset's price");
    expect(await db.select(db.pillarAssets).get(), isEmpty, reason: 'nor its pillar assignment');
  });
}
