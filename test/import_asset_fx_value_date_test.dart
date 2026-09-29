// The FX-rate fill after an asset-event import resolves the rate on the day
// the money moved (value date), like every other conversion in the app.
//
// It used to look the rate up on the trade (booking) date. When a broker
// settles a USD trade two days after booking, the stored rate — and so the
// cost basis in base currency — came from the wrong day.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';

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

  Future<void> eurUsd(DateTime on, double rate) =>
      db.into(db.exchangeRates).insert(ExchangeRatesCompanion.insert(fromCurrency: 'EUR', toCurrency: 'USD', date: on, rate: rate));

  test('a missing rate is filled with the rate of the value date, not of the trade date', () async {
    await eurUsd(DateTime(2024, 1, 10), 1.10); // trade (booking) day
    await eurUsd(DateTime(2024, 1, 12), 1.20); // settlement: the money moved

    final result = await importer.importAssetEventsGrouped(
      preview: const FilePreview(
        columns: ['Trade', 'Settle', 'ISIN', 'Type', 'Qty', 'Price', 'Amount', 'Ccy'],
        rows: [
          {
            'Trade': '2024-01-10',
            'Settle': '2024-01-12',
            'ISIN': 'US0000000001',
            'Type': 'buy',
            'Qty': '10',
            'Price': '100',
            'Amount': '1000',
            'Ccy': 'USD',
          },
        ],
        totalRows: 1,
      ),
      mappings: const [
        ColumnMapping(sourceColumn: 'Trade', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Settle', targetField: 'valueDate'),
        ColumnMapping(sourceColumn: 'ISIN', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'Type', targetField: 'type'),
        ColumnMapping(sourceColumn: 'Qty', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'Price', targetField: 'price'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'Ccy', targetField: 'currency'),
      ],
      rateService: ExchangeRateService(db),
      baseCurrency: 'EUR',
      intermediaryId: intermediaryId,
    );
    expect(result.result.errorRows, 0, reason: 'errors: ${result.result.errors}');

    final event = (await db.select(db.assetEvents).get()).single;
    expect(event.date, DateTime(2024, 1, 10));
    expect(event.valueDate, DateTime(2024, 1, 12));
    expect(event.exchangeRate, 1.20, reason: 'the rate of the value date');
    expect(event.exchangeRateBase, 'EUR');
  });
}
