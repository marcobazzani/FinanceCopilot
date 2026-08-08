// The dry-run preview and the real import must agree about every row, because
// the preview is what the user checks before committing.
//
// They did not: `previewAssetEventImport` never looked at the price mapping, so
// with the wizard's "Auto calc" (amount = quantity x price) it saw a null
// amount and inferred buy/sell from the quantity sign alone, while the import
// it was previewing inferred it from the computed amount. Both paths now share
// `autoCalcAmountFor`.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  /// No amount column at all — the shape that triggers the wizard's Auto-calc.
  FilePreview autoCalcPreview(List<List<String>> rows) => FilePreview(
    columns: ['date', 'isin', 'quantity', 'price', 'currency'],
    rows: rows.map((r) => {'date': r[0], 'isin': r[1], 'quantity': r[2], 'price': r[3], 'currency': r[4]}).toList(),
    totalRows: rows.length,
  );

  const autoCalcMappings = [
    ColumnMapping(sourceColumn: 'date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
    ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
    ColumnMapping(sourceColumn: 'price', targetField: 'price'),
    ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
  ];

  group('autoCalcAmountFor', () {
    test('multiplies quantity by price, dividing by 100 for bonds', () {
      expect(autoCalcAmountFor(qty: 10, price: 100.5, isBond: false), closeTo(1005, 0.0001));
      expect(autoCalcAmountFor(qty: 10, price: 98.5, isBond: true), closeTo(9.85, 0.0001));
    });

    test('returns 0 rather than guessing when an input is missing', () {
      expect(autoCalcAmountFor(qty: null, price: 100, isBond: false), 0);
      expect(autoCalcAmountFor(qty: 10, price: null, isBond: false), 0);
    });

    test('keeps the sign of the product', () {
      expect(autoCalcAmountFor(qty: -5, price: 100, isBond: false), -500);
      expect(autoCalcAmountFor(qty: 5, price: -100, isBond: false), -500);
    });
  });

  group('preview matches the real import under Auto-calc', () {
    /// buy/sell tallies from the dry run and from the committed events, for the
    /// same file and the same mappings.
    Future<({Map<String, int> preview, Map<String, int> real})> countsFor(
      FilePreview file, {
      bool negativeIsBuy = false,
    }) async {
      final dryRun = await importer.previewAssetEventImport(
        preview: file,
        mappings: autoCalcMappings,
        negativeIsBuy: negativeIsBuy,
      );
      final previewCounts = {
        'buy': dryRun.assetSummary.values.fold(0, (a, s) => a + s.buyCount),
        'sell': dryRun.assetSummary.values.fold(0, (a, s) => a + s.sellCount),
      };

      await importer.importAssetEventsGrouped(
        preview: file,
        mappings: autoCalcMappings,
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
        negativeIsBuy: negativeIsBuy,
      );
      final events = await db.select(db.assetEvents).get();
      final realCounts = {
        'buy': events.where((e) => e.type == EventType.buy).length,
        'sell': events.where((e) => e.type == EventType.sell).length,
      };
      return (preview: previewCounts, real: realCounts);
    }

    test('a negative price makes the row a sell in BOTH paths', () async {
      // The divergence made concrete: quantity is positive, so quantity-only
      // inference says "buy", while the computed amount (10 x -100) is negative
      // and the import says "sell".
      final file = autoCalcPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '-100', 'EUR'],
      ]);
      final c = await countsFor(file);
      expect(c.real, {'buy': 0, 'sell': 1});
      expect(c.preview, c.real, reason: 'preview must classify the row exactly as the import does');
    });

    test('agrees on a mixed file', () async {
      final file = autoCalcPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100', 'EUR'], // buy
        ['2024-02-15', 'IE00B4L5Y983', '-4', '110', 'EUR'], // sell (negative qty)
        ['2024-03-15', 'IE00B4L5Y983', '3', '-90', 'EUR'], // sell (negative price)
      ]);
      final c = await countsFor(file);
      expect(c.preview, c.real);
      expect(c.real, {'buy': 1, 'sell': 2});
    });

    test('agrees under the cash-flow convention (negative amount = buy)', () async {
      final file = autoCalcPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '-100', 'EUR'], // amount < 0 → buy
        ['2024-02-15', 'IE00B4L5Y983', '5', '100', 'EUR'], // amount > 0 → sell
      ]);
      final c = await countsFor(file, negativeIsBuy: true);
      expect(c.preview, c.real);
      expect(c.real, {'buy': 1, 'sell': 1});
    });

    test('agrees when price is unmapped so no amount can be derived', () async {
      // Neither amount nor price: the import writes amount 0, and both paths
      // must still land on the same type rather than one of them guessing.
      final file = autoCalcPreview([
        ['2024-01-15', 'IE00B4L5Y983', '10', '100', 'EUR'],
      ]);
      const noPrice = [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'currency', targetField: 'currency'),
      ];
      final dryRun = await importer.previewAssetEventImport(preview: file, mappings: noPrice);
      await importer.importAssetEventsGrouped(
        preview: file,
        mappings: noPrice,
        baseCurrency: 'EUR',
        intermediaryId: intermediaryId,
      );
      final events = await db.select(db.assetEvents).get();
      expect(dryRun.assetSummary.values.single.buyCount, events.where((e) => e.type == EventType.buy).length);
      expect(events.single.amount, 0, reason: 'no amount and no price derivable → 0, not a guess');
    });
  });
}
