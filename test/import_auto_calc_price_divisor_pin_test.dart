// Pin: the price the asset import derives from amount and quantity (issue #96)
// applies the bond divisor — 100 for a bond, quoted per 100 of face value, 1
// otherwise — in this operation order, to the last bit.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<double?> derivedPrice({required String isin, required InstrumentType type}) async {
    await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: isin,
            assetType: AssetType.stockEtf,
            instrumentType: Value(type),
            valuationMethod: ValuationMethod.marketPrice,
            isin: Value(isin),
            intermediaryId: broker,
          ),
        );
    final r = await ImportService(db).importAssetEventsGrouped(
      preview: FilePreview(
        columns: const ['date', 'isin', 'quantity', 'amount'],
        rows: [
          {'date': '2024-06-15', 'isin': isin, 'quantity': '3', 'amount': '-9.87'},
        ],
        totalRows: 1,
      ),
      mappings: const [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: broker,
      autoCalcPrice: true,
    );
    expect(r.result.errors, isEmpty);
    return (await db.select(db.assetEvents).getSingle()).price;
  }

  test('bond: |amount| / |quantity| x 100', () async {
    expect(await derivedPrice(isin: 'XS1234567890', type: InstrumentType.bond), (-9.87).abs() / 3.0.abs() * 100);
  });

  test('any other instrument: |amount| / |quantity| x 1', () async {
    expect(await derivedPrice(isin: 'IE00B4L5Y983', type: InstrumentType.etf), (-9.87).abs() / 3.0.abs() * 1);
  });
}
