import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

/// Pins the financial-correctness rule: a foreign-currency asset's daily
/// change must use the closest *real* previous-day FX rate we have — never a
/// fabricated 1:1 and never today's live rate stamped onto yesterday. When the
/// reference date predates all stored FX history, we fall back to the nearest
/// rate after it (the earliest one we actually have). The asset is skipped only
/// when there is genuinely no FX rate for the pair at all.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('foreign asset with reference predating FX history falls back to nearest rate, not skipped', () async {
    final now = DateTime.now();
    final referenceDate = DateTime(now.year - 1, 6, 9);

    final iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Stock',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: const Value('USD'),
          ),
        );
    // One buy so stats has a non-zero quantity.
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(now.year - 2, 1, 1),
            valueDate: DateTime(now.year - 2, 1, 1),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            currency: const Value('USD'),
          ),
        );
    // Prices: today + reference date both present (so price is not the blocker).
    for (final d in [referenceDate, now]) {
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(
              assetId: assetId,
              date: d,
              closePrice: 110.0,
              currency: 'USD',
            ),
          );
    }
    // FX: only a single rate exists, dated *after* the reference date. The
    // on-or-before lookup misses; the nearest-after fallback must supply it.
    await db
        .into(db.exchangeRates)
        .insert(
          ExchangeRatesCompanion.insert(
            fromCurrency: 'USD',
            toCurrency: 'EUR',
            date: now,
            rate: 0.9,
          ),
        );

    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(<Asset>[asset])),
        assetStatsProvider.overrideWithValue(
          AsyncData(<int, AssetStats>{
            assetId: AssetStats(
              eventCount: 1,
              firstDate: DateTime(now.year - 2, 1, 1),
              lastDate: DateTime(now.year - 2, 1, 1),
              totalInvested: 1000,
              totalQuantity: 10,
            ),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final changes = await container.read(assetDailyChangesProvider(referenceDate).future);
    final reported = changes.where((c) => c.name == 'US Stock').toList();

    // No rate on/before the reference date, but one exists after it -> use it.
    expect(reported, hasLength(1), reason: 'asset must be reported using the nearest available rate, not skipped');
    expect(reported.single.previousFxRate, closeTo(0.9, 1e-9), reason: 'previous FX must fall back to the nearest stored rate');
  });

  test('foreign asset with no FX rate at all is skipped', () async {
    final now = DateTime.now();
    final referenceDate = DateTime(now.year - 1, 6, 9);

    final iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'JP Stock',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: const Value('JPY'),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(now.year - 2, 1, 1),
            valueDate: DateTime(now.year - 2, 1, 1),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            currency: const Value('JPY'),
          ),
        );
    for (final d in [referenceDate, now]) {
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(assetId: assetId, date: d, closePrice: 110.0, currency: 'JPY'),
          );
    }
    // No JPY/EUR rate anywhere -> the asset cannot be valued and must be skipped.

    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(<Asset>[asset])),
        assetStatsProvider.overrideWithValue(
          AsyncData(<int, AssetStats>{
            assetId: AssetStats(
              eventCount: 1,
              firstDate: DateTime(now.year - 2, 1, 1),
              lastDate: DateTime(now.year - 2, 1, 1),
              totalInvested: 1000,
              totalQuantity: 10,
            ),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final changes = await container.read(assetDailyChangesProvider(referenceDate).future);
    expect(
      changes.where((c) => c.name == 'JP Stock'),
      isEmpty,
      reason: 'no FX rate for the pair at all -> skip rather than fabricate',
    );
  });

  test('foreign asset with a real previous-day FX is reported with that rate', () async {
    final now = DateTime.now();
    final referenceDate = DateTime(now.year - 1, 6, 9);

    final iid = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'US Stock',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: iid,
            currency: const Value('USD'),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(now.year - 2, 1, 1),
            valueDate: DateTime(now.year - 2, 1, 1),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            currency: const Value('USD'),
          ),
        );
    for (final d in [referenceDate, now]) {
      await db
          .into(db.marketPrices)
          .insert(
            MarketPricesCompanion.insert(assetId: assetId, date: d, closePrice: 110.0, currency: 'USD'),
          );
    }
    // Both a today-resolvable rate AND a reference-date rate exist.
    await db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: now, rate: 0.9));
    await db
        .into(db.exchangeRates)
        .insert(ExchangeRatesCompanion.insert(fromCurrency: 'USD', toCurrency: 'EUR', date: referenceDate, rate: 0.8));

    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
        marketPriceServiceProvider.overrideWithValue(_TestMarketPriceService(db)),
        assetsProvider.overrideWithValue(AsyncData(<Asset>[asset])),
        assetStatsProvider.overrideWithValue(
          AsyncData(<int, AssetStats>{
            assetId: AssetStats(
              eventCount: 1,
              firstDate: DateTime(now.year - 2, 1, 1),
              lastDate: DateTime(now.year - 2, 1, 1),
              totalInvested: 1000,
              totalQuantity: 10,
            ),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final changes = await container.read(assetDailyChangesProvider(referenceDate).future);
    final reported = changes.where((c) => c.name == 'US Stock').toList();
    expect(reported, hasLength(1), reason: 'asset with full FX data must be reported');
    expect(reported.single.previousFxRate, closeTo(0.8, 1e-9), reason: 'previous FX must be the reference-date rate, not today\'s');
    expect(reported.single.todayFxRate, closeTo(0.9, 1e-9));
  });
}

class _TestMarketPriceService extends MarketPriceService {
  _TestMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}
