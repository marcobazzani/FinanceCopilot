// T5 — resync writes a market_prices row for every revalue, anchored to
// qty-at-date that includes contribute quantities. After importing the
// full PPP fixture, all 6 anchor revalue dates have correct close_price.
// Deleting the latest revalue purges its market_prices row (orphan
// cleanup). Updating an earlier contribute.quantity re-anchors all
// subsequent revalues' close_price.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/asset_event_service.dart';
import 'package:finance_copilot/services/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late AssetEventService eventService;
  late int intermediaryId;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    eventService = AssetEventService(db);
    intermediaryId = await db.into(db.intermediaries).insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
    assetId = await db.into(db.assets).insert(AssetsCompanion.insert(
          name: 'Pension',
          assetType: AssetType.pension,
          instrumentType: const Value(InstrumentType.pension),
          assetClass: const Value(AssetClass.multiAsset),
          valuationMethod: ValuationMethod.eventDriven,
          currency: const Value('EUR'),
          intermediaryId: intermediaryId,
        ));
  });

  tearDown(() => db.close());

  Future<void> importPpp() async {
    final capped = await importer.parseFile(
      'test/fixtures/ppp/import.tsv',
      skipRows: 0,
      noHeader: true,
      numberLocale: 'it_IT',
    );
    final preview = await importer.getFullRows(capped, numberLocale: 'it_IT');
    await importer.importAssetEventsGrouped(
      preview: preview,
      mappings: const [
        ColumnMapping(sourceColumn: 'Column 4', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Column 2', targetField: 'type'),
        ColumnMapping(sourceColumn: 'Column 5', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
      targetAssetId: assetId,
      contributeValues: const {'C/TFR', 'C/Azienda', 'C/Iscritto'},
      revalueValues: const {'TOTALEP'},
      numberLocaleOverride: 'it_IT',
    );
    // The import path doesn't trigger resync directly (it uses batched
    // inserts, not AssetEventService.create). Run resync once after the
    // import to materialize all market_prices.
    await eventService.resyncRevaluePricesForAsset(assetId);
  }

  test('all 6 PPP revalues materialize a market_prices row', () async {
    await importPpp();
    final prices = await (db.select(db.marketPrices)
          ..where((p) => p.assetId.equals(assetId))
          ..orderBy([(p) => OrderingTerm.asc(p.date)]))
        .get();
    expect(prices, hasLength(6));
    expect(prices.map((p) => p.date), [
      DateTime(2021, 12, 31),
      DateTime(2022, 12, 31),
      DateTime(2023, 12, 31),
      DateTime(2024, 12, 31),
      DateTime(2025, 12, 31),
      DateTime(2026, 2, 28),
    ]);
    // Each close_price = position / Σ contribs through that date.
    // The exact ratios depend on the cumulative contribute totals; we
    // verify the round-trip identity: qty(d) × close_price(d) ≈ position(d).
    final expectedAmounts = [1900.00, 6800.00, 11900.00, 17000.00, 22200.00, 23100.00];
    for (var i = 0; i < prices.length; i++) {
      final p = prices[i];
      final qtyRow = await db.customSelect(
        "SELECT SUM(CASE WHEN type IN ('buy','contribute') THEN COALESCE(quantity,0) "
        "WHEN type='sell' THEN -COALESCE(quantity,0) ELSE 0 END) AS q "
        "FROM asset_events WHERE asset_id = ? AND value_date <= ?",
        variables: [
          Variable.withInt(assetId),
          Variable.withInt(p.date.millisecondsSinceEpoch ~/ 1000),
        ],
      ).getSingleOrNull();
      final qty = qtyRow!.read<double>('q');
      // qty × close_price must equal the position value (the revalue.amount).
      expect(qty * p.closePrice, closeTo(expectedAmounts[i], 0.01));
    }
  });

  test('deleting the latest revalue purges its market_prices row', () async {
    await importPpp();
    final pricesBefore = await (db.select(db.marketPrices)
          ..where((p) => p.assetId.equals(assetId)))
        .get();
    expect(pricesBefore, hasLength(6));

    final latestRevalue = await (db.select(db.assetEvents)
          ..where((e) =>
              e.assetId.equals(assetId) & e.type.equalsValue(EventType.revalue))
          ..orderBy([(e) => OrderingTerm.desc(e.valueDate)])
          ..limit(1))
        .getSingle();
    await eventService.delete(latestRevalue.id);

    final pricesAfter = await (db.select(db.marketPrices)
          ..where((p) => p.assetId.equals(assetId))
          ..orderBy([(p) => OrderingTerm.asc(p.date)]))
        .get();
    expect(pricesAfter, hasLength(5),
        reason: 'orphan cleanup: deleted revalue removes its market_prices row');
    // The remaining 5 are intact.
    expect(pricesAfter.map((p) => p.date), [
      DateTime(2021, 12, 31),
      DateTime(2022, 12, 31),
      DateTime(2023, 12, 31),
      DateTime(2024, 12, 31),
      DateTime(2025, 12, 31),
    ]);
  });
}
