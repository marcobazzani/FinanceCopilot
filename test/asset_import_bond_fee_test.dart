// The asset import's computed fee ("Computed" in the wizard): what a row paid
// beyond the value of its units, |amount| − |quantity| × price [/ rate]. The
// value of a bond's units is quoted per 100 of face value, so it divides by
// the bond price divisor — as the amount auto-calc (quantity x price) does.
//
// Pinned bug: the fee ignored the divisor. A BTP bought at 98.50 for a face
// value of 10,000 (9,850 plus a 10 commission, 9,860 paid) got a "fee" of
// |9,860 − 10,000 × 98.50| = 975,140 instead of 10.
//
// Figures are pinned in the same operation order as the code and chosen so
// that they carry no float noise.
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

  const byIsin = [
    ColumnMapping(sourceColumn: 'date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
    ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
    ColumnMapping(sourceColumn: 'price', targetField: 'price'),
    ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
  ];

  Future<void> importFees(
    List<Map<String, String>> rows, {
    List<ColumnMapping> mappings = byIsin,
    Map<String, IsinExchangeOption>? selectedExchanges,
    int? targetAssetId,
  }) async {
    final r = await importer.importAssetEventsGrouped(
      preview: FilePreview(columns: rows.first.keys.toList(), rows: rows, totalRows: rows.length),
      mappings: mappings,
      baseCurrency: 'EUR',
      intermediaryId: broker,
      numberLocaleOverride: 'en_US',
      computeFee: true,
      selectedExchanges: selectedExchanges,
      targetAssetId: targetAssetId,
    );
    expect(r.result.errors, isEmpty);
  }

  group('computedFeeFor', () {
    test('a bond\'s units are worth quantity x price / 100, a fund\'s quantity x price', () {
      expect(computedFeeFor(amount: -9860, qty: 10000, price: 98.5, isBond: true, rateMapped: false), (-9860.0).abs() - 10000 * 98.5 / 100);
      expect(computedFeeFor(amount: -1010, qty: 10, price: 100, isBond: false, rateMapped: false), (-1010.0).abs() - 10 * 100);
    });

    test('the value is converted by the rate when an exchange-rate column is mapped', () {
      expect(
        computedFeeFor(amount: -7890, qty: 10000, price: 98.5, isBond: true, rateMapped: true, rate: 1.25),
        (-7890.0).abs() - 10000 * 98.5 / 100 / 1.25,
      );
    });

    test('a sell\'s negative quantity counts as units, not as a negative value', () {
      expect(computedFeeFor(amount: 9840, qty: -10000, price: 98.5, isBond: true, rateMapped: false), 9850 - 9840.0);
    });

    test('no fee is invented: a missing quantity or price, or a missing or non-positive mapped rate', () {
      expect(computedFeeFor(amount: -1010, qty: null, price: 100, isBond: false, rateMapped: false), isNull);
      expect(computedFeeFor(amount: -1010, qty: 10, price: null, isBond: false, rateMapped: false), isNull);
      for (final rate in [null, 0.0, -1.1]) {
        expect(computedFeeFor(amount: -1010, qty: 10, price: 100, isBond: false, rateMapped: true, rate: rate), isNull, reason: 'rate $rate');
      }
    });
  });

  group('the import', () {
    test('a bond fee row: the value of the units divides by 100, a fund\'s does not', () async {
      await asset('IT0005383309', InstrumentType.bond);
      await asset('IE00B4L5Y983', InstrumentType.etf);
      await importFees([
        {'date': '2025-01-10', 'isin': 'IT0005383309', 'quantity': '10000', 'price': '98.5', 'amount': '-9860'},
        {'date': '2025-01-11', 'isin': 'IE00B4L5Y983', 'quantity': '10', 'price': '100', 'amount': '-1010'},
      ]);
      expect([for (final e in await events()) e.commission], [9860 - 10000 * 98.5 / 100, 1010 - 10 * 100.0]);
    });

    test('a bond fee row with a mapped exchange rate: the value divides by 100, then by the rate', () async {
      await asset('US912810SX72', InstrumentType.bond);
      await importFees(
        [
          {'date': '2025-01-10', 'isin': 'US912810SX72', 'quantity': '10000', 'price': '98.5', 'amount': '-7890', 'rate': '1.25'},
        ],
        mappings: [
          ...byIsin,
          const ColumnMapping(sourceColumn: 'rate', targetField: 'exchangeRate'),
        ],
      );
      expect((await events()).single.commission, 7890 - 10000 * 98.5 / 100 / 1.25);
    });

    test('a bond the import creates from the picked listing', () async {
      await importFees(
        [
          {'date': '2025-01-10', 'isin': 'IT0005383309', 'quantity': '10000', 'price': '98.5', 'amount': '-9860'},
        ],
        selectedExchanges: const {
          'IT0005383309': IsinExchangeOption(cid: 1, ticker: 'BTP', name: 'BTP 2030', exchange: 'Milan', typeName: 'Bonds'),
        },
      );
      expect((await db.select(db.assets).getSingle()).instrumentType, InstrumentType.bond);
      expect((await events()).single.commission, 9860 - 10000 * 98.5 / 100);
    });

    test('a bond target asset of a single-asset import', () async {
      final btp = await asset('IT0005383309', InstrumentType.bond, valuation: ValuationMethod.eventDriven);
      await importFees(
        [
          {'date': '2025-01-10', 'quantity': '10000', 'price': '98.5', 'amount': '-9860'},
        ],
        mappings: [
          for (final m in byIsin)
            if (m.targetField != 'isin') m,
        ],
        targetAssetId: btp,
      );
      expect((await events()).single.commission, 9860 - 10000 * 98.5 / 100);
    });
  });
}
