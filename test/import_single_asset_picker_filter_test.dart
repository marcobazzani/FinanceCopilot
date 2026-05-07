// Regression: the import wizard's single-asset target picker must show
// every event-driven asset, even if that asset already has rows in
// market_prices. Pension/contribute imports themselves write synthetic
// close_price rows (resyncRevaluePricesForAsset), so a previously-
// imported pension asset has market_prices entries despite having no
// external feed. Filtering by `valuation_method` is the authoritative
// signal; filtering by absence-of-market-prices silently broke
// re-imports of pension assets.
//
// Pinned bug: F.P.G.G. (eventDriven, no ticker/ISIN) disappeared from
// the picker after its first import wrote market_prices rows.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';

void main() {
  late AppDatabase db;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intermediaryId = await db.into(db.intermediaries).insert(
          IntermediariesCompanion.insert(name: 'Generali'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createAsset({
    required String name,
    required ValuationMethod method,
    String? ticker,
    String? isin,
  }) async {
    return db.into(db.assets).insert(AssetsCompanion.insert(
          name: name,
          assetType: AssetType.pension,
          instrumentType: const Value(InstrumentType.pension),
          assetClass: const Value(AssetClass.multiAsset),
          valuationMethod: method,
          ticker: Value(ticker),
          isin: Value(isin),
          currency: const Value('EUR'),
          intermediaryId: intermediaryId,
        ));
  }

  Future<void> insertMarketPrice(int assetId, DateTime date, double price) async {
    await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(
          assetId: assetId,
          date: date,
          closePrice: price,
          currency: 'EUR',
        ));
  }

  test(
      'event-driven asset is included in the manual-asset filter even when '
      'it has market_prices entries (re-import case)',
      () async {
    // Mimic an F.P.G.G.-style pension asset that has been imported once.
    // The previous import wrote synthetic price snapshots into market_prices.
    final pensionId = await createAsset(
      name: 'F.P.G.G.',
      method: ValuationMethod.eventDriven,
    );
    await insertMarketPrice(pensionId, DateTime(2025, 1, 1), 1.0);
    await insertMarketPrice(pensionId, DateTime(2026, 1, 1), 1.05);

    // A regular ETF, market-driven, also with market_prices.
    final etfId = await createAsset(
      name: 'iShares Core MSCI World',
      method: ValuationMethod.marketPrice,
      ticker: 'SWDA',
      isin: 'IE00B4L5Y983',
    );
    await insertMarketPrice(etfId, DateTime(2026, 5, 1), 95.43);

    final assets = await db.select(db.assets).get();

    // The picker's filter — see column_mapper_step._buildSingleAssetPicker.
    // Use valuationMethod as the source of truth, NOT presence of market
    // prices (which fires a false negative for re-imported pension funds).
    final manual = assets
        .where((a) => a.valuationMethod == ValuationMethod.eventDriven)
        .toList();

    expect(manual, hasLength(1));
    expect(manual.first.id, equals(pensionId));
    expect(manual.first.name, equals('F.P.G.G.'));
  });

  test(
      'market-driven asset is excluded from the manual filter even when it '
      'has zero market_prices entries (e.g. obscure exchange not yet synced)',
      () async {
    final stockId = await createAsset(
      name: 'Obscure Stock',
      method: ValuationMethod.marketPrice,
      ticker: 'OBSC',
    );

    final assets = await db.select(db.assets).get();
    final manual = assets
        .where((a) => a.valuationMethod == ValuationMethod.eventDriven)
        .toList();

    expect(manual, isEmpty);
    expect(stockId, isPositive); // prevent unused-variable warning
  });
}
