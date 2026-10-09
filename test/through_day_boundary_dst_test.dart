// "As of day D" filters must end exactly at the next local midnight, on the
// two daylight-saving change days as well as on ordinary days.
//
// The exclusive end of day D used to be computed as
// `DateTime(y, m, d).add(const Duration(days: 1))`. `Duration(days: 1)` is 24
// hours of elapsed time, not one calendar day: in a zone with daylight saving
// the spring-forward day is 23 hours long and the fall-back day 25. In
// Europe/Rome that bound landed on 2026-03-30 01:00 (letting the first hour of
// the next day in) and on 2026-10-25 23:00 (dropping the last hour of the day
// itself), so wayback / as-of views counted or lost rows around the change.
//
// The DST cases only bite when the suite runs in a zone with daylight saving
// (e.g. Europe/Rome); in UTC all three cases are ordinary days and must pass
// all the same.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/domain/buffer_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/domain/income_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_rebalance_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show allSeriesDataProvider;

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// A day, an instant late on that day (must be included "as of" the day) and
/// an instant early on the next day (must not be).
typedef _Boundary = ({String label, DateTime day, DateTime lateSameDay, DateTime earlyNextDay});

final _boundaries = <_Boundary>[
  (
    label: 'an ordinary day',
    day: DateTime(2026, 6, 10),
    lateSameDay: DateTime(2026, 6, 10, 23, 30),
    earlyNextDay: DateTime(2026, 6, 11, 0, 30),
  ),
  (
    label: 'the spring-forward day (23 h in Europe/Rome)',
    day: DateTime(2026, 3, 29),
    lateSameDay: DateTime(2026, 3, 29, 23, 30),
    earlyNextDay: DateTime(2026, 3, 30, 0, 30),
  ),
  (
    label: 'the fall-back day (25 h in Europe/Rome)',
    day: DateTime(2026, 10, 25),
    lateSameDay: DateTime(2026, 10, 25, 23, 30),
    earlyNextDay: DateTime(2026, 10, 26, 0, 30),
  ),
];

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> asset({String? isin}) async {
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    return db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: intermediaryId,
            isin: Value(isin),
          ),
        );
  }

  Future<int> assetEvent(int assetId, DateTime on, EventType type, {required double amount, double? qty, double? price}) => db
      .into(db.assetEvents)
      .insert(
        AssetEventsCompanion.insert(
          assetId: assetId,
          date: on,
          valueDate: on,
          type: type,
          amount: amount,
          quantity: Value(qty),
          price: Value(price),
        ),
      );

  Future<void> price(int assetId, DateTime on, double close) =>
      db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: assetId, date: on, closePrice: close, currency: 'EUR'));

  for (final b in _boundaries) {
    group('as of ${b.label}', () {
      test('asset events: reads, average buy price and latest revalue', () async {
        final svc = AssetEventService(db);
        final a = await asset();
        await assetEvent(a, b.lateSameDay, EventType.buy, amount: 10, qty: 1, price: 10);
        await assetEvent(a, b.earlyNextDay, EventType.buy, amount: 30, qty: 1, price: 30);
        await assetEvent(a, b.lateSameDay, EventType.revalue, amount: 111);
        await assetEvent(a, b.earlyNextDay, EventType.revalue, amount: 222);

        List<DateTime> dates(List<AssetEvent> events) => events.map((e) => e.valueDate).toList();
        expect(dates(await svc.getByAsset(a, through: b.day)), [b.lateSameDay, b.lateSameDay]);
        expect(dates((await svc.getByAssets([a], through: b.day))[a]!), [b.lateSameDay, b.lateSameDay]);
        expect(dates(await svc.watchByAsset(a, through: b.day).first), [b.lateSameDay, b.lateSameDay]);
        expect(await svc.getAverageBuyPrice(a, through: b.day), 10);
        expect(await svc.getLatestRevalueAmount(a, through: b.day), 111);
      });

      test('adjustments: events, entries, stats and the same-day duplicate count', () async {
        final svc = ExtraordinaryEventService(db);
        final bufferId = await db.into(db.buffers).insert(BuffersCompanion.insert(name: 'Refunds'));
        Future<int> event(DateTime on, {int? buffer}) => db
            .into(db.extraordinaryEvents)
            .insert(
              ExtraordinaryEventsCompanion.insert(
                name: 'Repair',
                direction: EventDirection.outflow,
                treatment: EventTreatment.instant,
                totalAmount: 500,
                eventDate: on,
                bufferId: Value(buffer),
              ),
            );
        final inside = await event(b.lateSameDay, buffer: bufferId);
        await event(b.earlyNextDay);
        for (final (on, reimbursed) in [(b.lateSameDay, 20.0), (b.earlyNextDay, 70.0)]) {
          await db
              .into(db.extraordinaryEventEntries)
              .insert(ExtraordinaryEventEntriesCompanion.insert(eventId: inside, date: on, amount: -50, entryKind: EventEntryKind.manual));
          await db
              .into(db.bufferTransactions)
              .insert(
                BufferTransactionsCompanion.insert(
                  bufferId: bufferId,
                  operationDate: on,
                  valueDate: on,
                  amount: reimbursed,
                  balanceAfter: 0,
                  isReimbursement: const Value(true),
                ),
              );
        }

        expect((await svc.getAll(through: b.day)).map((e) => e.id), [inside]);
        expect((await svc.watchAll(through: b.day).first).map((e) => e.id), [inside]);
        expect((await svc.getEntries(inside, through: b.day)).map((e) => e.date), [b.lateSameDay]);
        expect((await svc.watchEntries(inside, through: b.day).first).map((e) => e.date), [b.lateSameDay]);
        final stats = await svc.watchStatsForAll(through: b.day).first;
        expect(stats.keys, [inside]);
        expect(stats[inside]!.entryCount, 1);
        expect(stats[inside]!.totalAllocated, 50);
        expect(stats[inside]!.totalReimbursed, 20);
        expect(await svc.countIdenticalManualEntries(eventId: inside, date: b.day, amount: 50), 1);
      });

      test('buffer transactions and balance', () async {
        final svc = BufferService(db);
        final bufferId = await svc.create(name: 'Holiday');
        await svc.createTransaction(bufferId: bufferId, operationDate: b.lateSameDay, amount: 10, currency: 'EUR');
        await svc.createTransaction(bufferId: bufferId, operationDate: b.earlyNextDay, amount: 20, currency: 'EUR');

        expect((await svc.getByBuffer(bufferId, through: b.day)).map((t) => t.valueDate), [b.lateSameDay]);
        expect((await svc.watchByBuffer(bufferId, through: b.day).first).map((t) => t.valueDate), [b.lateSameDay]);
        expect(await svc.computeBalance(bufferId, through: b.day), 10);
      });

      test('incomes', () async {
        final svc = IncomeService(db);
        await svc.create(date: b.lateSameDay, amount: 10, currency: 'EUR');
        await svc.create(date: b.earlyNextDay, amount: 20, currency: 'EUR');

        expect((await svc.getAll(through: b.day)).map((i) => i.amount), [10]);
        expect((await svc.watchAll(through: b.day).first).map((i) => i.amount), [10]);
      });

      test('transactions and account stats', () async {
        final txs = TransactionService(db);
        final accounts = AccountService(db);
        final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Checking'));
        await txs.create(accountId: accountId, operationDate: b.lateSameDay, amount: 10, balanceAfter: 110, currency: 'EUR');
        await txs.create(accountId: accountId, operationDate: b.earlyNextDay, amount: 20, balanceAfter: 130, currency: 'EUR');

        expect((await txs.getByAccount(accountId, through: b.day)).map((t) => t.amount), [10]);
        expect((await txs.watchByAccount(accountId, through: b.day).first).map((t) => t.amount), [10]);
        expect((await txs.watchAll(through: b.day).first).map((t) => t.amount), [10]);

        final stats = await accounts.getStatsForAll(through: b.day);
        expect(stats.keys, [accountId]);
        expect(stats[accountId]!.count, 1);
        expect(stats[accountId]!.lastDate, b.lateSameDay);
        expect(stats[accountId]!.balance, 110);
        expect((await accounts.watchStatsForAll(through: b.day).first)[accountId]?.balance, 110);
      });

      test('asset stats', () async {
        final svc = AssetService(db);
        final a = await asset();
        await assetEvent(a, b.lateSameDay, EventType.buy, amount: 10, qty: 1, price: 10);
        await assetEvent(a, b.earlyNextDay, EventType.buy, amount: 60, qty: 2, price: 30);

        final stats = (await svc.getStatsForAll(through: b.day))[a];
        expect(stats?.totalQuantity, 1);
        expect(stats?.totalInvested, 10);
        expect(stats?.lastDate, b.lateSameDay);
        expect((await svc.watchStatsForAll(through: b.day).first)[a]?.totalQuantity, 1);
      });

      test('price on or before the day, and its last-buy fallback', () async {
        final prices = _OfflineMarketPriceService(db);
        final priced = await asset();
        await price(priced, b.lateSameDay, 100);
        await price(priced, b.earlyNextDay, 200);
        expect(await prices.getPrice(priced, b.day), 100);

        final unpriced = await asset();
        await assetEvent(unpriced, b.lateSameDay, EventType.buy, amount: 10, qty: 1, price: 10);
        await assetEvent(unpriced, b.earlyNextDay, EventType.buy, amount: 30, qty: 1, price: 30);
        expect(await prices.getPrice(unpriced, b.day), 10);
      });

      test('rebalance draft values the holding as of the day', () async {
        const isin = 'IE00B4L5Y983';
        final a = await asset(isin: isin);
        await assetEvent(a, b.lateSameDay, EventType.buy, amount: 1000, qty: 10, price: 100);
        await price(a, b.lateSameDay, 100);
        await price(a, b.earlyNextDay, 999);
        final modelId = await PortfolioModelService(db).createCustomModel(
          name: 'Model',
          items: const [PortfolioModelInputItem(isin: isin, targetWeight: 100)],
        );
        final pillars = PillarService(db);
        final pillarId = await pillars.create(name: 'Retirement', portfolioModelId: modelId);
        await pillars.assign(pillarId: pillarId, assetId: a, qty: 10);

        final draft = await PortfolioRebalanceService(db).buildDraft(
          scope: PortfolioRebalanceScope.currentPillar(pillarId),
          mode: PortfolioRebalanceMode.sellAndBuy,
          asOf: b.day,
        );
        expect(draft.unresolved, isEmpty, reason: 'the buy late on the day is held as of that day');
        expect(draft.currentPortfolioValueBase, closeTo(1000, 1e-9), reason: 'priced with the close of the day, not of the next one');
      });

      test('dashboard series in the wayback view of the day', () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
            defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
            marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
            accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
            accountStatsProvider.overrideWithValue(const AsyncData(<int, AccountStats>{})),
            assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
            assetStatsProvider.overrideWithValue(const AsyncData(<int, AssetStats>{})),
            extraordinaryEventsProvider.overrideWithValue(const AsyncData(<ExtraordinaryEvent>[])),
          ],
        );
        addTearDown(container.dispose);
        container.read(waybackDateProvider.notifier).state = b.day;

        final a = await asset();
        await assetEvent(a, b.lateSameDay, EventType.buy, amount: 100, qty: 1, price: 100);
        await assetEvent(a, b.earlyNextDay, EventType.buy, amount: 1000, qty: 10, price: 100);
        final eventId = await db
            .into(db.extraordinaryEvents)
            .insert(
              ExtraordinaryEventsCompanion.insert(
                name: 'Repair',
                direction: EventDirection.outflow,
                treatment: EventTreatment.instant,
                totalAmount: 500,
                eventDate: b.lateSameDay,
              ),
            );

        final data = await container.read(allSeriesDataProvider.future);
        final invested = data!.assetInvested.where((s) => s.key == 'asset_invested:$a');
        expect(invested.map((s) => s.spots.last.y), [100], reason: 'the buy late on the day counts, the next day one does not');
        expect(data.adjustments.map((s) => s.key), contains('adjustment_value:$eventId'));
      });
    });
  }
}
