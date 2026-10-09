// An asset import never writes half of itself:
//
//  * a mapped currency column with a blank cell — or a value the database
//    does not accept — refuses that row with a structured issue (`rejected`,
//    field `currency`), like the transaction and income imports: the other
//    rows still import, an asset is created in the currency of the first row
//    it holds, and an ISIN none of whose rows can be stored gets no asset.
//    The dry run reports the same rows. It used to throw while creating the
//    assets, leaving the assets created before the bad row behind;
//  * everything the import writes — the assets it creates, the replaced
//    events, the pension-income mirror, the price resync and the rate fill —
//    is written in one transaction: a failure leaves nothing written.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';

/// A rate lookup that fails: the import's last write step (the rate fill).
class _FailingRates extends ExchangeRateService {
  _FailingRates(super.db);

  @override
  Future<double?> getRate(String from, String to, DateTime date) async => throw StateError('rates unavailable');
}

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

  const mappings = [
    ColumnMapping(sourceColumn: 'date', targetField: 'date'),
    ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
    ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
    ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
    ColumnMapping(sourceColumn: 'ccy', targetField: 'currency'),
  ];

  FilePreview file(List<(String, String, String, String, String)> rows) => FilePreview(
    columns: const ['date', 'isin', 'quantity', 'amount', 'ccy'],
    rows: [
      for (final (date, isin, qty, amount, ccy) in rows) {'date': date, 'isin': isin, 'quantity': qty, 'amount': amount, 'ccy': ccy},
    ],
    totalRows: rows.length,
  );

  Future<AssetImportResult> import(
    FilePreview preview, {
    List<ColumnMapping> mappings = mappings,
    int? targetAssetId,
    ExchangeRateService? rates,
  }) => importer.importAssetEventsGrouped(
    preview: preview,
    mappings: mappings,
    baseCurrency: 'EUR',
    intermediaryId: broker,
    numberLocaleOverride: 'en_US',
    targetAssetId: targetAssetId,
    rateService: rates,
  );

  List<(ImportIssueKind, int, String)> shape(List<ImportIssue> issues) => [for (final i in issues) (i.kind, i.line, i.fields.join(','))];

  Future<Map<String, String>> assetCurrencies() async => {for (final a in await db.select(db.assets).get()) a.isin ?? a.name: a.currency};

  Future<Map<double, String>> eventCurrencies() async => {for (final e in await db.select(db.assetEvents).get()) e.amount: e.currency};

  // Row 2 is the only row of its ISIN; row 3 is the first of its ISIN.
  final blanks = file([
    ('2025-01-10', 'IE00B4L5Y983', '1', '-100', 'USD'),
    ('2025-01-11', 'LU0908500753', '2', '-200', ''),
    ('2025-01-12', 'DE000A0H0744', '3', '-300', '   '),
    ('2025-01-13', 'DE000A0H0744', '4', '-400', 'CHF'),
  ]);

  group('a blank cell in the mapped currency column', () {
    test('refuses its row, never imports it in the base currency; the other rows import', () async {
      final r = await import(blanks);
      expect(r.result.importedRows, 2);
      expect(r.result.errorRows, 2);
      expect(shape(r.result.issues), [(ImportIssueKind.rejected, 2, 'currency'), (ImportIssueKind.rejected, 3, 'currency')]);
      expect(r.result.errors.first, startsWith('Skipped line 2'), reason: 'English text for the logs');
      expect(await eventCurrencies(), {-100.0: 'USD', -400.0: 'CHF'});
    });

    test('an asset takes the currency of the first row it holds; an ISIN with no row to hold gets none', () async {
      final r = await import(blanks);
      expect(await assetCurrencies(), {'IE00B4L5Y983': 'USD', 'DE000A0H0744': 'CHF'});
      expect(r.assetsByIsin.keys.toSet(), {'IE00B4L5Y983', 'DE000A0H0744'});
    });

    test('the dry run reports the same rows', () async {
      final p = await importer.previewAssetEventImport(preview: blanks, mappings: mappings, numberLocale: 'en_US');
      expect((p.parsedRows, p.errorRows), (2, 2));
      expect(shape(p.issues), [(ImportIssueKind.rejected, 2, 'currency'), (ImportIssueKind.rejected, 3, 'currency')]);
      expect({for (final s in p.assetSummary.values) s.isin: s.currency}, {'IE00B4L5Y983': 'USD', 'DE000A0H0744': 'CHF'});
    });

    test('into a single asset: the row is refused, the others go to the target', () async {
      final target = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'Pension',
              assetType: AssetType.pension,
              valuationMethod: ValuationMethod.eventDriven,
              intermediaryId: broker,
              currency: const Value('USD'),
            ),
          );
      final r = await import(
        file([('2025-01-10', '', '1', '-100', 'USD'), ('2025-01-11', '', '2', '-200', '')]),
        mappings: [
          for (final m in mappings)
            if (m.targetField != 'isin') m,
        ],
        targetAssetId: target,
      );
      expect(shape(r.result.issues), [(ImportIssueKind.rejected, 2, 'currency')]);
      expect(await eventCurrencies(), {-100.0: 'USD'});
    });
  });

  test('a currency the database does not accept refuses its row too', () async {
    final r = await import(file([('2025-01-10', 'IE00B4L5Y983', '1', '-100', 'EURO'), ('2025-01-11', 'IE00B4L5Y983', '2', '-200', 'USD')]));
    expect(shape(r.result.issues), [(ImportIssueKind.rejected, 1, 'currency')]);
    expect(await eventCurrencies(), {-200.0: 'USD'});
    expect(await assetCurrencies(), {'IE00B4L5Y983': 'USD'});
  });

  test('when no row can be stored nothing is written: no asset', () async {
    final r = await import(file([('2025-01-10', 'IE00B4L5Y983', '1', '-100', '')]));
    expect(r.result.importedRows, 0);
    expect(shape(r.result.issues), [(ImportIssueKind.rejected, 1, 'currency')]);
    expect(await db.select(db.assets).get(), isEmpty);
  });

  test('a failure while writing leaves nothing written: no new asset, the replaced events intact', () async {
    final held = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            isin: const Value('IE00B4L5Y983'),
            intermediaryId: broker,
            currency: const Value('USD'),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: held,
            date: DateTime(2025, 1, 15),
            valueDate: DateTime(2025, 1, 15),
            type: EventType.buy,
            amount: -50,
            quantity: const Value(0.5),
            currency: const Value('USD'),
          ),
        );

    // Both rows are USD without a rate: the fill after the events are written
    // looks their rates up, and fails.
    await expectLater(
      import(
        file([('2025-01-10', 'IE00B4L5Y983', '1', '-100', 'USD'), ('2025-01-11', 'LU0908500753', '2', '-200', 'USD')]),
        rates: _FailingRates(db),
      ),
      throwsStateError,
    );
    expect(await assetCurrencies(), {'IE00B4L5Y983': 'USD'}, reason: 'the asset of the new ISIN was not left behind');
    expect(await eventCurrencies(), {-50.0: 'USD'}, reason: 'the replaced event is still there, and no new one');
  });
}
