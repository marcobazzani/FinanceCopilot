// Amounts an import computes (a balance difference, a formula, a sum of
// columns, quantity x price, a computed fee) carried the noise of binary
// arithmetic: `1100.15 − 1000.10` is 100.05000000000007, and the edit forms
// pre-filled "100,05000000000007". The noise is stripped before the amount is
// stored — including a difference of large figures, whose noise is that of
// its terms (12345.62 − 12345.67 is −0.049999999999272404) — and an edit form
// no longer spells a noisy stored figure with every digit.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/utils/amount_parser.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

void main() {
  group('stripFloatNoise', () {
    test('the noise of a computation is dropped', () {
      expect(stripFloatNoise(1100.15 - 1000.10), 100.05);
      expect(stripFloatNoise(100.05000000000007), 100.05);
      expect(stripFloatNoise(0.1 + 0.2), 0.3);
      expect(stripFloatNoise(0.3 - 0.1), 0.2);
      expect(stripFloatNoise(-(0.1 + 0.2)), -0.3);
    });

    test('a real figure comes back exactly', () {
      for (final v in [0.0, 1.0, -258.35, 7707.97, 0.123456, 12345678.123456, 123456789012.34, 1e-7, 0.00012345, 1e21, 42.0]) {
        expect(stripFloatNoise(v), v, reason: '$v');
      }
    });

    test('is the 15-significant-digit round-trip the settings forms use', () {
      for (final v in [0.07 * 100, 0.29 * 100, 1 / 3, 2 / 3 * 1e6, -1e-9 / 3]) {
        expect(stripFloatNoise(v), double.parse(v.toStringAsPrecision(15)), reason: '$v');
      }
    });

    test('a difference of large figures: the digits are counted from the larger term', () {
      expect(stripFloatNoise(12345.62 - 12345.67, magnitude: 12345.67), -0.05);
      expect(stripFloatNoise(2500.00 - 2499.99, magnitude: 2500.00), 0.01);
      expect(stripFloatNoise(3454.28 - 3456.78, magnitude: 3456.78), -2.5);
      expect(stripFloatNoise(1234567.89 - 1234567.84, magnitude: 1234567.89), 0.05);
      expect(stripFloatNoise(99999999.99 - 99999999.98, magnitude: 99999999.99), 0.01);
      // Real digits of the result that fit in 15 of the larger term survive.
      expect(stripFloatNoise(1000.123456 - 1000, magnitude: 1000.123456), 0.123456);
      // A magnitude no larger than the result changes nothing.
      expect(stripFloatNoise(1100.15 - 1000.10, magnitude: 1.0), 100.05);
      expect(stripFloatNoise(1 / 3, magnitude: 0.1), double.parse((1 / 3).toStringAsPrecision(15)));
    });
  });

  group('editableFigure', () {
    test('a noisy stored figure pre-fills the locale spelling', () {
      expect(fmt.editableFigure(100.05000000000007, fmt.amountFormat('it_IT'), locale: 'it_IT'), '100,05');
      expect(fmt.editableFigure(100.05000000000007, fmt.amountFormat('en_US'), locale: 'en_US'), '100.05');
      expect(fmt.editableFigure(-(0.1 + 0.2), fmt.amountFormat('it_IT'), locale: 'it_IT'), '-0,30');
    });

    test('real digits beyond the display precision are still all kept', () {
      expect(fmt.editableFigure(0.123456, NumberFormat.decimalPattern('it_IT'), locale: 'it_IT'), '0,123456');
      expect(fmt.editableFigure(1234.5678, fmt.amountFormat('it_IT'), locale: 'it_IT'), '1234,5678');
      expect(fmt.editableFigure(1500, fmt.amountFormat('it_IT'), locale: 'it_IT'), '1.500,00');
    });
  });

  group('amounts computed by an import are stored without noise', () {
    late AppDatabase db;
    late ImportService importer;
    late int acct;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      importer = ImportService(db);
      acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    });
    tearDown(() => db.close());

    Future<List<double>> importAmounts(List<String> columns, List<Map<String, String>> rows, ColumnMapping amount) async {
      final r = await importer.importTransactions(
        preview: FilePreview(columns: columns, rows: rows, totalRows: rows.length, numberLocale: 'en_US'),
        mappings: [
          const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          amount,
        ],
        accountId: acct,
        numberLocaleOverride: 'en_US',
      );
      expect(r.errors, isEmpty);
      final txs = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      return [for (final t in txs) t.amount];
    }

    test('balance difference 1000.10 → 1100.15 stores exactly 100.05', () async {
      final amounts = await importAmounts(
        ['Date', 'Balance'],
        [
          {'Date': '2025-01-01', 'Balance': '1000.10'},
          {'Date': '2025-01-02', 'Balance': '1100.15'},
        ],
        const ColumnMapping(targetField: 'amount', balanceDiffColumn: 'Balance'),
      );
      expect(amounts, [0, 100.05]);
    });

    test('a small movement on a large balance: 12345.67 → 12345.62 stores exactly -0.05', () async {
      final amounts = await importAmounts(
        ['Date', 'Balance'],
        [
          {'Date': '2025-01-01', 'Balance': '12345.67'},
          {'Date': '2025-01-02', 'Balance': '12345.62'},
          {'Date': '2025-01-03', 'Balance': '12343.12'},
        ],
        const ColumnMapping(targetField: 'amount', balanceDiffColumn: 'Balance'),
      );
      expect(amounts, [0, -0.05, -2.5]);
    });

    test('a formula: 1000.10 − 1000.05 stores exactly 0.05', () async {
      final amounts = await importAmounts(
        ['Date', 'In', 'Out'],
        [
          {'Date': '2025-01-01', 'In': '1000.10', 'Out': '1000.05'},
          {'Date': '2025-01-02', 'In': '0.3', 'Out': '0.1'},
        ],
        const ColumnMapping(
          targetField: 'amount',
          formulaTerms: [
            FormulaTerm(operator: '+', sourceColumn: 'In'),
            FormulaTerm(operator: '-', sourceColumn: 'Out'),
          ],
        ),
      );
      expect(amounts, [0.05, 0.2]);
    });

    test('a sum of columns: 0.1 + 0.2 stores exactly 0.3', () async {
      final amounts = await importAmounts(
        ['Date', 'A', 'B'],
        [
          {'Date': '2025-01-01', 'A': '0.1', 'B': '0.2'},
          {'Date': '2025-01-02', 'A': '-1000.10', 'B': '1000.05'},
        ],
        const ColumnMapping(targetField: 'amount', multiColumns: ['A', 'B']),
      );
      expect(amounts, [0.3, -0.05]);
    });

    test('an income formula stores exactly 0.05', () async {
      final r = await importer.importIncomes(
        preview: const FilePreview(
          columns: ['Date', 'Gross', 'Tax'],
          rows: [
            {'Date': '2025-01-01', 'Gross': '1000.10', 'Tax': '1000.05'},
          ],
          totalRows: 1,
        ),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(
            targetField: 'amount',
            formulaTerms: [
              FormulaTerm(operator: '+', sourceColumn: 'Gross'),
              FormulaTerm(operator: '-', sourceColumn: 'Tax'),
            ],
          ),
        ],
        defaultCurrency: 'EUR',
        numberLocaleOverride: 'en_US',
      );
      expect(r.errors, isEmpty);
      expect((await db.select(db.incomes).getSingle()).amount, 0.05);
    });

    group('asset events', () {
      late int broker;
      setUp(() async => broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker')));

      Future<AssetEvent> importEvent(Map<String, String> row, List<ColumnMapping> mappings, {bool computeFee = false}) async {
        final r = await importer.importAssetEventsGrouped(
          preview: FilePreview(columns: row.keys.toList(), rows: [row], totalRows: 1),
          mappings: mappings,
          baseCurrency: 'EUR',
          intermediaryId: broker,
          computeFee: computeFee,
          numberLocaleOverride: 'en_US',
        );
        expect(r.result.errors, isEmpty);
        return db.select(db.assetEvents).getSingle();
      }

      test('the auto-calculated amount: 3 × 0.1 stores exactly 0.3', () async {
        final e = await importEvent(
          {'date': '2025-01-01', 'isin': 'IE00B4L5Y983', 'quantity': '3', 'price': '0.1'},
          const [
            ColumnMapping(sourceColumn: 'date', targetField: 'date'),
            ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
            ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
            ColumnMapping(sourceColumn: 'price', targetField: 'price'),
          ],
        );
        expect(e.amount, 0.3);
      });

      test('the computed fee: |1005.10| − 10 × 100.45 stores exactly 0.6', () async {
        final e = await importEvent(
          {'date': '2025-01-01', 'isin': 'IE00B4L5Y983', 'quantity': '10', 'price': '100.45', 'amount': '-1005.10'},
          const [
            ColumnMapping(sourceColumn: 'date', targetField: 'date'),
            ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
            ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
            ColumnMapping(sourceColumn: 'price', targetField: 'price'),
            ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
          ],
          computeFee: true,
        );
        expect(e.commission, 0.6);
      });

      test('fee rows folded into one trade: 0.1 + 0.2 stores exactly 0.3', () async {
        final r = await importer.importAssetEventsGrouped(
          preview: const FilePreview(
            columns: ['date', 'isin', 'type', 'amount', 'orderRef'],
            rows: [
              {'date': '2025-01-01', 'isin': 'IE00B4L5Y983', 'type': 'Buy', 'amount': '-100', 'orderRef': 'A1'},
              {'date': '2025-01-01', 'isin': 'IE00B4L5Y983', 'type': 'Fee', 'amount': '-0.1', 'orderRef': 'A1'},
              {'date': '2025-01-01', 'isin': 'IE00B4L5Y983', 'type': 'Fee', 'amount': '-0.2', 'orderRef': 'A1'},
            ],
            totalRows: 3,
          ),
          mappings: const [
            ColumnMapping(sourceColumn: 'date', targetField: 'date'),
            ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
            ColumnMapping(sourceColumn: 'type', targetField: 'type'),
            ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
            ColumnMapping(sourceColumn: 'orderRef', targetField: 'orderRef'),
          ],
          baseCurrency: 'EUR',
          intermediaryId: broker,
          buyValues: {'Buy'},
          feeValues: {'Fee'},
          numberLocaleOverride: 'en_US',
        );
        expect(r.result.errors, isEmpty);
        expect((await db.select(db.assetEvents).getSingle()).commission, 0.3);
      });
    });
  });
}
