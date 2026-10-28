// The jobs that write without a person asking for that change (seeding,
// startup maintenance, provider sync, derived rates) must never move the
// manual-edit stamp the sync indicator compares; a person's edit through a
// service must. A new background writer that is not marked automatic shows up
// here as a moved stamp.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/manual_edit_tracker.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/domain/account_service.dart';
import 'package:finance_copilot/services/import/stored_metadata_repair.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// A provider answering one price per fetch.
class _OnePricePerFetch extends MarketPriceService {
  _OnePricePerFetch(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => {DateTime(2026, 10, 1): 42.0};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(), manualEdits: ManualEditTracker()));
  tearDown(() => db.close());

  /// Data as an import or a restore left it: written outside any edit.
  Future<({int assetId})> seedData() => automaticWrites(() async {
    final brokerId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Current account'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: accountId,
            operationDate: DateTime(2026, 10, 1),
            valueDate: DateTime(2026, 10, 1),
            amount: -12.5,
            description: const Value('POS GROCERY STORE 1234'),
          ),
        );
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Fund',
            ticker: const Value('USF'),
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: brokerId,
            currency: const Value('USD'),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2026, 10, 1),
            valueDate: DateTime(2026, 10, 1),
            type: EventType.buy,
            amount: 100,
            quantity: const Value(1),
            currency: const Value('USD'),
          ),
        );
    await db
        .into(db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: DateTime(2026, 10, 1), rate: 1.25));
    return (assetId: assetId);
  });

  test('seeding, startup maintenance, provider sync and derived rates are no manual edits', () async {
    final (:assetId) = await seedData();

    await PortfolioModelService(db).seedBuiltInModels();
    await TransactionClassifierService(db).recomputeKeysIfStale(force: true);
    await StoredMetadataRepair(db).runIfNeeded(appLocale: 'en_US');
    final prices = _OnePricePerFetch(db);
    await prices.syncPrices();
    expect(await db.select(db.marketPrices).get(), isNotEmpty, reason: 'the sync wrote its prices');

    // Computing converted amounts fills the event's missing exchange rate.
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(prices),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(convertedEventAmountsProvider(assetId), (_, _) {});
    addTearDown(sub.close);
    await container.read(convertedEventAmountsProvider(assetId).future);
    expect((await db.select(db.assetEvents).getSingle()).exchangeRate, 1.25, reason: 'the rate was filled');

    await prices.clearCache();

    expect(await db.lastManualEdit(), isNull);
  });

  test('an edit through a service is a manual edit', () async {
    await seedData();
    await AccountService(db).create(name: 'Savings', currency: 'EUR');
    expect(await db.lastManualEdit(), isNotNull);
  });
}
