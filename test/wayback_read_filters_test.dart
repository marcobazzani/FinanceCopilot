import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/account_service.dart';
import 'package:finance_copilot/services/asset_service.dart';
import 'package:finance_copilot/services/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart'
    show allSeriesDataProvider;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        defaultTaxRateProvider.overrideWithValue(const AsyncData(0.26)),
        marketPriceServiceProvider.overrideWithValue(
          _TestMarketPriceService(db),
        ),
        accountsProvider.overrideWithValue(const AsyncData(<Account>[])),
        accountStatsProvider.overrideWithValue(
          const AsyncData(<int, AccountStats>{}),
        ),
        assetsProvider.overrideWithValue(const AsyncData(<Asset>[])),
        assetStatsProvider.overrideWithValue(
          const AsyncData(<int, AssetStats>{}),
        ),
        extraordinaryEventsProvider.overrideWithValue(
          const AsyncData(<ExtraordinaryEvent>[]),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('wayback date filters date-bearing reads only', () async {
    container.read(waybackDateProvider.notifier).state = DateTime(2024, 2, 29);
    final through = container.read(waybackDateProvider);

    final accountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Checking'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 6, 1),
            valueDate: DateTime(2024, 2, 29, 12),
            amount: 100,
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 3, 1),
            amount: 200,
          ),
        );

    final intermediaryId = await db
        .into(db.intermediaries)
        .insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: intermediaryId,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 6, 1),
            valueDate: DateTime(2024, 2, 29, 12),
            type: EventType.buy,
            amount: 300,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 3, 1),
            type: EventType.buy,
            amount: 400,
          ),
        );

    await db
        .into(db.incomes)
        .insert(
          IncomesCompanion.insert(
            date: DateTime(2024, 6, 1),
            valueDate: DateTime(2024, 2, 29, 12),
            amount: 500,
          ),
        );
    await db
        .into(db.incomes)
        .insert(
          IncomesCompanion.insert(
            date: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 3, 1),
            amount: 600,
          ),
        );

    final bufferId = await db
        .into(db.buffers)
        .insert(BuffersCompanion.insert(name: 'Buffer'));
    await db
        .into(db.bufferTransactions)
        .insert(
          BufferTransactionsCompanion.insert(
            bufferId: bufferId,
            operationDate: DateTime(2024, 6, 1),
            valueDate: DateTime(2024, 2, 29, 12),
            amount: 700,
            balanceAfter: 700,
          ),
        );
    await db
        .into(db.bufferTransactions)
        .insert(
          BufferTransactionsCompanion.insert(
            bufferId: bufferId,
            operationDate: DateTime(2024, 1, 1),
            valueDate: DateTime(2024, 3, 1),
            amount: 800,
            balanceAfter: 1500,
          ),
        );

    final eventId = await db
        .into(db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: 'Event',
            direction: EventDirection.outflow,
            treatment: EventTreatment.instant,
            totalAmount: 900,
            eventDate: DateTime(2024, 1, 1),
          ),
        );
    await db
        .into(db.extraordinaryEvents)
        .insert(
          ExtraordinaryEventsCompanion.insert(
            name: 'Future event',
            direction: EventDirection.outflow,
            treatment: EventTreatment.instant,
            totalAmount: 1000,
            eventDate: DateTime(2024, 3, 1),
          ),
        );
    await db
        .into(db.extraordinaryEventEntries)
        .insert(
          ExtraordinaryEventEntriesCompanion.insert(
            eventId: eventId,
            date: DateTime(2024, 2, 29, 12),
            amount: -90,
            entryKind: EventEntryKind.manual,
          ),
        );
    await db
        .into(db.extraordinaryEventEntries)
        .insert(
          ExtraordinaryEventEntriesCompanion.insert(
            eventId: eventId,
            date: DateTime(2024, 3, 1),
            amount: -100,
            entryKind: EventEntryKind.manual,
          ),
        );

    final txs = await container
        .read(transactionServiceProvider)
        .getByAccount(accountId, through: through);
    expect(txs.map((t) => t.amount), [100]);
    final allTxs = await container
        .read(transactionServiceProvider)
        .watchAll(through: through)
        .first;
    expect(allTxs.map((t) => t.amount), [100]);

    final assetEvents = await container
        .read(assetEventServiceProvider)
        .getByAsset(assetId, through: through);
    expect(assetEvents.map((e) => e.amount), [300]);

    final incomes = await container
        .read(incomeServiceProvider)
        .getAll(through: through);
    expect(incomes.map((i) => i.amount), [500]);

    final bufferTxs = await container
        .read(bufferServiceProvider)
        .getByBuffer(bufferId, through: through);
    expect(bufferTxs.map((t) => t.amount), [700]);

    final events = await container
        .read(extraordinaryEventServiceProvider)
        .getAll(through: through);
    expect(events.map((e) => e.name), ['Event']);

    final entries = await container
        .read(extraordinaryEventServiceProvider)
        .getEntries(eventId, through: through);
    expect(entries.map((e) => e.amount), [-90]);

    expect(await db.select(db.transactions).get(), hasLength(2));
    expect(await db.select(db.assetEvents).get(), hasLength(2));
    expect(await db.select(db.incomes).get(), hasLength(2));
    expect(await db.select(db.bufferTransactions).get(), hasLength(2));
    expect(await db.select(db.extraordinaryEventEntries).get(), hasLength(2));
  });

  test(
    'wayback chart data uses valueDate and clips every rendered source series',
    () async {
      container.read(waybackDateProvider.notifier).state = DateTime(
        2024,
        2,
        29,
      );
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(key: 'BASE_CURRENCY', value: 'EUR'),
          );
      await db
          .into(db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(key: 'TAX_RATE', value: '0.26'),
          );

      final intermediaryId = await db
          .into(db.intermediaries)
          .insert(IntermediariesCompanion.insert(name: 'Broker'));
      final assetId = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.eventDriven,
              intermediaryId: intermediaryId,
            ),
          );
      await db
          .into(db.assetEvents)
          .insert(
            AssetEventsCompanion.insert(
              assetId: assetId,
              date: DateTime(2024, 6, 1),
              valueDate: DateTime(2024, 1, 15),
              type: EventType.buy,
              amount: 1000,
              quantity: const Value(10),
            ),
          );

      final visibleEventId = await db
          .into(db.extraordinaryEvents)
          .insert(
            ExtraordinaryEventsCompanion.insert(
              name: 'Visible event',
              direction: EventDirection.outflow,
              treatment: EventTreatment.instant,
              totalAmount: 500,
              eventDate: DateTime(2024, 1, 20),
            ),
          );
      final futureEventId = await db
          .into(db.extraordinaryEvents)
          .insert(
            ExtraordinaryEventsCompanion.insert(
              name: 'Future event',
              direction: EventDirection.outflow,
              treatment: EventTreatment.instant,
              totalAmount: 900,
              eventDate: DateTime(2024, 3, 1),
            ),
          );

      final data = await container.read(allSeriesDataProvider.future);
      expect(data, isNotNull);
      expect(data!.firstDate, DateTime(2024, 1, 15));

      final endX = DateTime(
        2024,
        2,
        29,
      ).difference(data.firstDate).inDays.toDouble();
      for (final series in data.allSeries) {
        expect(
          series.spots.every((spot) => spot.x >= 0 && spot.x <= endX),
          isTrue,
          reason: '${series.key} must stay inside the Wayback chart domain',
        );
      }

      expect(data.assetInvested.single.spots.first.y, 1000);
      expect(
        data.adjustments.map((s) => s.key),
        contains('adjustment_value:$visibleEventId'),
      );
      expect(
        data.adjustments.map((s) => s.key),
        isNot(contains('adjustment_value:$futureEventId')),
      );
    },
  );
}

class _TestMarketPriceService extends MarketPriceService {
  _TestMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(
    String ticker,
    String currency,
    DateTime from,
  ) async => const {};
}
