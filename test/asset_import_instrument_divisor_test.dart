// The asset import's quantity x price conversions use the price divisor of the
// instrument each row goes to (a bond is quoted per 100 of face value, see
// bondPriceDivisor). Pinned in the same operation order as the code, with
// figures whose products carry no float noise.
//
// The divisor used to come from a set of bond ISINs looked up across every
// broker, and a single-asset import has no ISIN at all: a bond target asset
// got the divisor of a fund (amounts 100 times too big, prices 100 times too
// small).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/isin_lookup_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int broker;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> asset(String isin, InstrumentType type, {ValuationMethod valuation = ValuationMethod.marketPrice}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: isin,
          assetType: AssetType.stockEtf,
          instrumentType: Value(type),
          valuationMethod: valuation,
          isin: Value(isin),
          intermediaryId: broker,
        ),
      );

  Future<List<AssetEvent>> events() => (db.select(db.assetEvents)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();

  const qtyPrice = [
    ColumnMapping(sourceColumn: 'date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
    ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
    ColumnMapping(sourceColumn: 'price', targetField: 'price'),
  ];

  test('autoCalcAmountFor: quantity x price, divided by 100 for a bond', () {
    expect(autoCalcAmountFor(qty: 10, price: 98.5, isBond: true), 10 * 98.5 / 100);
    expect(autoCalcAmountFor(qty: 2000, price: 98.37, isBond: true), 2000 * 98.37 / 100);
    expect(autoCalcAmountFor(qty: 3, price: 101.25, isBond: false), 3 * 101.25);
  });

  group('by ISIN', () {
    test('the auto-calculated amount of a bond and of a fund', () async {
      await asset('XS1234567890', InstrumentType.bond);
      await asset('IE00B4L5Y983', InstrumentType.etf);
      final r = await importer.importAssetEventsGrouped(
        preview: const FilePreview(
          columns: ['date', 'isin', 'quantity', 'price'],
          rows: [
            {'date': '2025-01-10', 'isin': 'XS1234567890', 'quantity': '10', 'price': '98.5'},
            {'date': '2025-01-11', 'isin': 'IE00B4L5Y983', 'quantity': '3', 'price': '101.25'},
          ],
          totalRows: 2,
        ),
        mappings: qtyPrice,
        baseCurrency: 'EUR',
        intermediaryId: broker,
      );
      expect(r.result.errors, isEmpty);
      expect([for (final e in await events()) e.amount], [10 * 98.5 / 100, 3 * 101.25]);
    });

    test('a bond the import creates from the picked listing', () async {
      await importer.importAssetEventsGrouped(
        preview: const FilePreview(
          columns: ['date', 'isin', 'quantity', 'price'],
          rows: [
            {'date': '2025-01-10', 'isin': 'IT0005383309', 'quantity': '2000', 'price': '98.37'},
          ],
          totalRows: 1,
        ),
        mappings: qtyPrice,
        baseCurrency: 'EUR',
        intermediaryId: broker,
        selectedExchanges: const {
          'IT0005383309': IsinExchangeOption(cid: 1, ticker: 'BTP', name: 'BTP 2030', exchange: 'Milan', typeName: 'Bonds'),
        },
      );
      final created = await db.select(db.assets).getSingle();
      expect(created.instrumentType, InstrumentType.bond);
      expect((await events()).single.amount, 2000 * 98.37 / 100);
    });

    test('the derived price of a bond and of a fund', () async {
      await asset('XS1234567890', InstrumentType.bond);
      await asset('IE00B4L5Y983', InstrumentType.etf);
      await importer.importAssetEventsGrouped(
        preview: const FilePreview(
          columns: ['date', 'isin', 'quantity', 'amount'],
          rows: [
            {'date': '2025-01-10', 'isin': 'XS1234567890', 'quantity': '10', 'amount': '-9.85'},
            {'date': '2025-01-11', 'isin': 'IE00B4L5Y983', 'quantity': '3', 'amount': '-303.75'},
          ],
          totalRows: 2,
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
      expect([for (final e in await events()) e.price], [(-9.85).abs() / 10.0.abs() * 100, (-303.75).abs() / 3.0.abs() * 1]);
    });
  });

  group('into a single asset: the target asset\'s instrument', () {
    Future<void> importInto(int target, Map<String, String> row, List<ColumnMapping> mappings, {bool autoCalcPrice = false}) async {
      final r = await importer.importAssetEventsGrouped(
        preview: FilePreview(columns: row.keys.toList(), rows: [row], totalRows: 1),
        mappings: mappings,
        baseCurrency: 'EUR',
        intermediaryId: broker,
        targetAssetId: target,
        autoCalcPrice: autoCalcPrice,
      );
      expect(r.result.errors, isEmpty);
    }

    const noIsinQtyPrice = [
      ColumnMapping(sourceColumn: 'date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
      ColumnMapping(sourceColumn: 'price', targetField: 'price'),
    ];

    test('a bond: the auto-calculated amount divides by 100', () async {
      final btp = await asset('IT0005383309', InstrumentType.bond);
      await importInto(btp, {'date': '2025-01-10', 'quantity': '10', 'price': '98.5'}, noIsinQtyPrice);
      expect((await events()).single.amount, 10 * 98.5 / 100);
    });

    test('a fund: the auto-calculated amount is quantity x price', () async {
      final fund = await asset('IE00B4L5Y983', InstrumentType.etf);
      await importInto(fund, {'date': '2025-01-10', 'quantity': '3', 'price': '101.25'}, noIsinQtyPrice);
      expect((await events()).single.amount, 3 * 101.25);
    });

    test('a bond: the derived price multiplies by 100', () async {
      final btp = await asset('IT0005383309', InstrumentType.bond);
      await importInto(
        btp,
        {'date': '2025-01-10', 'quantity': '10', 'amount': '-9.85'},
        const [
          ColumnMapping(sourceColumn: 'date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
          ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
        ],
        autoCalcPrice: true,
      );
      expect((await events()).single.price, (-9.85).abs() / 10.0.abs() * 100);
    });
  });
}
