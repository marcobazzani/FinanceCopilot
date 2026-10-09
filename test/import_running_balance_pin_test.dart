// Pins, before the import service and the ledger share one running-balance
// loop (running_balance.dart), one exception for a refused cell and one query
// for the filtered-mode seed: every figure, status and issue below is what
// the code produced before those refactors.
//
//  * a row refused for its currency cell — blank, or not accepted by the
//    database — in the income and asset imports and the asset dry run;
//  * the filtered-mode seed of an import: the stored balance of the
//    value-date last row booked before it, 0 with no row before, unknown
//    when that row has none — counting only hand-entered rows on a re-run;
//  * the running balance an import stores (cumulative, filtered, column) and
//    the one the ledger recalculates, in value-date order with the row's
//    order breaking ties, in integer cents.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<int> stored(DateTime booked, double amount, {DateTime? value, double? balance, String? raw}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: booked,
          valueDate: value ?? booked,
          amount: amount,
          description: Value('$booked $amount'),
          balanceAfter: Value(balance),
          rawMetadata: Value(raw),
        ),
      );

  Future<List<(double, double?, TransactionStatus)>> ledger({DateTime? from}) async => [
    for (final t
        in await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(acct) & t.operationDate.isBiggerOrEqualValue(from ?? DateTime(1970)))
              ..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)]))
            .get())
      (t.amount, t.balanceAfter, t.status),
  ];

  group('a row refused for its currency cell', () {
    List<(ImportIssueKind, int, String, String, String, String)> shape(List<ImportIssue> issues) => [
      for (final i in issues) (i.kind, i.line, i.value, i.locale, i.fields.join(','), i.message),
    ];

    test('income import: a blank cell', () async {
      final r = await importer.importIncomes(
        preview: const FilePreview(
          columns: ['Date', 'Amount', 'Currency'],
          rows: [
            {'Date': '2026-01-01', 'Amount': '100', 'Currency': 'USD'},
            {'Date': '2026-01-02', 'Amount': '200', 'Currency': ' '},
          ],
          totalRows: 2,
        ),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Currency', targetField: 'currency'),
        ],
        defaultCurrency: 'EUR',
        numberLocaleOverride: 'en_US',
      );
      expect(shape(r.issues), [
        (ImportIssueKind.rejected, 2, '', '', 'currency', 'Skipped line 2: FormatException: Empty currency'),
      ]);
    });

    group('asset import and its dry run: a blank cell, a value the database does not accept', () {
      late int broker;
      setUp(() async => broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker')));

      const trades = FilePreview(
        columns: ['date', 'isin', 'quantity', 'amount', 'ccy'],
        rows: [
          {'date': '2025-01-10', 'isin': 'IE00B4L5Y983', 'quantity': '1', 'amount': '-100', 'ccy': 'USD'},
          {'date': '2025-01-11', 'isin': 'IE00B4L5Y983', 'quantity': '2', 'amount': '-200', 'ccy': ''},
          {'date': '2025-01-12', 'isin': 'IE00B4L5Y983', 'quantity': '3', 'amount': '-300', 'ccy': 'EURO'},
        ],
        totalRows: 3,
      );
      const mappings = [
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'isin', targetField: 'isin'),
        ColumnMapping(sourceColumn: 'quantity', targetField: 'quantity'),
        ColumnMapping(sourceColumn: 'amount', targetField: 'amount'),
        ColumnMapping(sourceColumn: 'ccy', targetField: 'currency'),
      ];

      test('import', () async {
        final r = await importer.importAssetEventsGrouped(
          preview: trades,
          mappings: mappings,
          baseCurrency: 'EUR',
          intermediaryId: broker,
          numberLocaleOverride: 'en_US',
        );
        expect(shape(r.result.issues), [
          (ImportIssueKind.rejected, 2, '', '', 'currency', 'Skipped line 2: FormatException: Empty currency'),
          (ImportIssueKind.rejected, 3, '', '', 'currency', 'Skipped line 3: FormatException: Value not accepted for currency\nEURO'),
        ]);
        expect(r.result.importedRows, 1);
      });

      test('dry run', () async {
        final p = await importer.previewAssetEventImport(preview: trades, mappings: mappings, numberLocale: 'en_US');
        expect(shape(p.issues), [
          (ImportIssueKind.rejected, 2, '', '', 'currency', 'Line 2: FormatException: Empty currency'),
          (ImportIssueKind.rejected, 3, '', '', 'currency', 'Line 3: FormatException: Value not accepted for currency\nEURO'),
        ]);
      });
    });
  });

  group('filtered-mode seed', () {
    const statement = FilePreview(
      columns: ['Date', 'Amount', 'State'],
      rows: [
        {'Date': '2025-01-15', 'Amount': '50', 'State': 'COMPLETED'},
        {'Date': '2025-01-16', 'Amount': '999', 'State': 'DECLINED'},
      ],
      totalRows: 2,
    );
    const mappings = [
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
    ];

    Future<TransactionImportPreview> dryRun() => importer.previewTransactionImport(
      preview: statement,
      mappings: mappings,
      accountId: acct,
      balanceMode: 'filtered',
      balanceFilterColumn: 'State',
      balanceFilterInclude: {'COMPLETED'},
    );

    Future<void> import({bool rerun = false}) => importer.importTransactions(
      preview: statement,
      mappings: mappings,
      accountId: acct,
      balanceMode: 'filtered',
      balanceFilterColumn: 'State',
      balanceFilterInclude: {'COMPLETED'},
      replaceOnlyImportedRows: rerun,
    );

    final from = DateTime(2025, 1, 15);

    test('the value-date last row booked before the import: its stored balance', () async {
      await stored(DateTime(2025, 1, 10), 100, value: DateTime(2025, 1, 12), balance: 70);
      await stored(DateTime(2025, 1, 11), -30, value: DateTime(2025, 1, 9), balance: -30);
      expect(((await dryRun()).predictedBalance, (await dryRun()).openingBalanceUnknown), (120, false));
      await import();
      expect(await ledger(from: from), [(50, 120, TransactionStatus.settled), (999, 120, TransactionStatus.cancelled)]);
    });

    test('that row has no balance: unknown, none stored', () async {
      await stored(DateTime(2025, 1, 10), 100, balance: 70);
      await stored(DateTime(2025, 1, 11), -30, value: DateTime(2025, 1, 13));
      expect(((await dryRun()).predictedBalance, (await dryRun()).openingBalanceUnknown), (null, true));
      await import();
      expect(await ledger(from: from), [(50, null, TransactionStatus.settled), (999, null, TransactionStatus.cancelled)]);
    });

    test('no row before: 0', () async {
      await stored(DateTime(2025, 1, 20), 5, balance: 5);
      expect(((await dryRun()).predictedBalance, (await dryRun()).openingBalanceUnknown), (50, false));
    });

    group('a re-run counts only the hand-entered rows before it', () {
      test('the hand-entered one, not a later imported one', () async {
        await stored(DateTime(2025, 1, 5), 70, balance: 70);
        await stored(DateTime(2025, 1, 10), 430, balance: 500, raw: '{"Date":"2025-01-10"}');
        expect((await dryRun()).predictedBalance, 550, reason: 'a dry run counts every row');
        await import(rerun: true);
        expect(await ledger(), [
          (70, 70, TransactionStatus.settled),
          (50, 120, TransactionStatus.settled),
          (999, 120, TransactionStatus.cancelled),
        ]);
      });

      test('only imported rows before: 0', () async {
        await stored(DateTime(2025, 1, 10), 430, balance: 500, raw: '{"Date":"2025-01-10"}');
        await import(rerun: true);
        expect(await ledger(), [(50, 50, TransactionStatus.settled), (999, 50, TransactionStatus.cancelled)]);
      });

      test('a hand-entered row without a balance: unknown', () async {
        await stored(DateTime(2025, 1, 5), 70);
        await stored(DateTime(2025, 1, 10), 430, balance: 500, raw: '{"Date":"2025-01-10"}');
        await import(rerun: true);
        expect(await ledger(), [
          (70, null, TransactionStatus.settled),
          (50, null, TransactionStatus.settled),
          (999, null, TransactionStatus.cancelled),
        ]);
      });
    });
  });

  group('the running balance an import stores', () {
    Future<ImportResult> import(
      List<Map<String, String>> rows, {
      required String mode,
      List<ColumnMapping> extra = const [],
      String? filterColumn,
      Set<String>? include,
    }) => importer.importTransactions(
      preview: FilePreview(columns: rows.first.keys.toList(), rows: rows, totalRows: rows.length),
      mappings: [
        const ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        const ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ...extra,
      ],
      accountId: acct,
      balanceMode: mode,
      balanceFilterColumn: filterColumn,
      balanceFilterInclude: include,
      numberLocaleOverride: 'en_US',
    );

    Future<Map<String, (double?, TransactionStatus)>> byDescription() async => {
      for (final t in await (db.select(db.transactions)..where((t) => t.rawMetadata.isNotNull())).get())
        t.description: (t.balanceAfter, t.status),
    };

    const valueDate = ColumnMapping(sourceColumn: 'Value', targetField: 'valueDate');
    const description = ColumnMapping(sourceColumn: 'Description', targetField: 'description');

    test('cumulative: from the sum before the import, in value-date order, same day by file order, in cents', () async {
      await stored(DateTime(2025, 1, 5), 10.1);
      await import(
        [
          {'Date': '2025-01-20', 'Value': '2025-01-20', 'Amount': '0.1', 'Description': 'a'},
          {'Date': '2025-01-15', 'Value': '2025-01-22', 'Amount': '0.2', 'Description': 'b'},
          {'Date': '2025-01-16', 'Value': '2025-01-16', 'Amount': '-5.55', 'Description': 'c'},
          {'Date': '2025-01-16', 'Value': '2025-01-16', 'Amount': '1', 'Description': 'd'},
        ],
        mode: 'cumulative',
        extra: const [valueDate, description],
      );
      expect(await byDescription(), {
        'a': (5.65, TransactionStatus.settled),
        'b': (5.85, TransactionStatus.settled),
        'c': (4.55, TransactionStatus.settled),
        'd': (5.55, TransactionStatus.settled),
      });
    });

    test('filtered: an excluded row carries the balance and is cancelled unless its status is mapped', () async {
      await import(
        [
          {'Date': '2025-02-01', 'Amount': '100', 'State': 'DONE', 'Status': '', 'Description': 'a'},
          {'Date': '2025-02-02', 'Amount': '-30', 'State': 'FAILED', 'Status': '', 'Description': 'b'},
          {'Date': '2025-02-03', 'Amount': '10', 'State': 'FAILED', 'Status': 'pending', 'Description': 'c'},
          {'Date': '2025-02-04', 'Amount': '5.05', 'State': 'DONE', 'Status': '', 'Description': 'd'},
        ],
        mode: 'filtered',
        extra: const [
          description,
          ColumnMapping(sourceColumn: 'Status', targetField: 'status'),
        ],
        filterColumn: 'State',
        include: {'DONE'},
      );
      expect(await byDescription(), {
        'a': (100, TransactionStatus.settled),
        'b': (100, TransactionStatus.cancelled),
        'c': (100, TransactionStatus.pending),
        'd': (105.05, TransactionStatus.settled),
      });
    });

    for (final include in [null, <String>{}]) {
      test('filtered with ${include == null ? 'no' : 'an empty'} filter set: every row moves it', () async {
        await import(
          [
            {'Date': '2025-02-01', 'Amount': '100', 'State': 'DONE', 'Description': 'a'},
            {'Date': '2025-02-02', 'Amount': '-30', 'State': 'FAILED', 'Description': 'b'},
          ],
          mode: 'filtered',
          extra: const [description],
          filterColumn: 'State',
          include: include,
        );
        expect(await byDescription(), {'a': (100, TransactionStatus.settled), 'b': (70, TransactionStatus.settled)});
      });
    }

    test('column: the value-date balance anchored on the last booked bank balance', () async {
      await import(
        [
          {'Date': '2025-03-01', 'Value': '2025-03-01', 'Amount': '100', 'Balance': '1100', 'Description': 'a'},
          {'Date': '2025-03-02', 'Value': '2025-02-28', 'Amount': '-30', 'Balance': '1070', 'Description': 'b'},
        ],
        mode: 'column',
        extra: const [
          valueDate,
          description,
          ColumnMapping(sourceColumn: 'Balance', targetField: 'balanceAfter'),
        ],
      );
      expect(await byDescription(), {'a': (1070, TransactionStatus.settled), 'b': (970, TransactionStatus.settled)});
    });
  });

  group('the running balance the ledger recalculates', () {
    late TransactionService service;
    setUp(() => service = TransactionService(db));

    Future<Map<String, (double?, TransactionStatus)>> byDescription() async => {
      for (final t in await db.select(db.transactions).get()) t.description: (t.balanceAfter, t.status),
    };

    Future<int> row(String name, int day, double amount, {double? balance, String? state, TransactionStatus? status}) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2025, 1, day),
            valueDate: DateTime(2025, 1, day),
            amount: amount,
            description: Value(name),
            balanceAfter: Value(balance),
            rawMetadata: Value(state == null ? null : jsonEncode({'State': state})),
            status: status == null ? const Value.absent() : Value(status),
          ),
        );

    test('cumulative: value-date order, same day by id, in cents; only changed rows are written', () async {
      await row('A', 10, 0.1);
      await row('B', 5, 0.2, balance: 0.2);
      await row('C', 10, -0.05);
      await row('D', 5, 1);
      expect(await service.recalculateBalances(acct, balanceMode: 'cumulative'), 3, reason: 'B already holds its balance');
      expect(await byDescription(), {
        'A': (1.3, TransactionStatus.settled),
        'B': (0.2, TransactionStatus.settled),
        'C': (1.25, TransactionStatus.settled),
        'D': (1.2, TransactionStatus.settled),
      });
      expect(await service.recalculateBalances(acct, balanceMode: 'cumulative'), 0);
    });

    test('filtered: an excluded row carries the balance and is cancelled; a row without statement data is excluded', () async {
      await row('A', 1, 100, state: 'DONE');
      await row('B', 2, -30, state: 'FAILED');
      await row('C', 3, -7, state: 'FAILED', status: TransactionStatus.cancelled);
      await row('D', 4, 12.34);
      await row('E', 5, 0.66, state: 'DONE', status: TransactionStatus.pending);
      final updated = await service.recalculateBalances(
        acct,
        balanceMode: 'filtered',
        savedMappings: const {'__balanceFilterColumn': 'State', '__balanceFilterInclude': '["DONE"]'},
      );
      expect(updated, 5);
      expect(await byDescription(), {
        'A': (100, TransactionStatus.settled),
        'B': (100, TransactionStatus.cancelled),
        'C': (100, TransactionStatus.cancelled),
        'D': (100, TransactionStatus.cancelled),
        'E': (100.66, TransactionStatus.pending),
      });
    });

    test('filtered, every value: every row moves it, nothing is cancelled', () async {
      await row('A', 1, 100, state: 'DONE');
      await row('B', 2, -30, state: 'FAILED');
      await service.recalculateBalances(acct, balanceMode: 'filtered', savedMappings: const {'__balanceFilterColumn': 'State'});
      expect(await byDescription(), {'A': (100, TransactionStatus.settled), 'B': (70, TransactionStatus.settled)});
    });

    test('a saved row keeps its status: the one just created in a filtered account', () async {
      await db
          .into(db.importConfigs)
          .insert(
            ImportConfigsCompanion.insert(
              accountId: Value(acct),
              mappingsJson: Value(
                jsonEncode({'__balanceMode': 'filtered', '__balanceFilterColumn': 'State', '__balanceFilterInclude': '["DONE"]'}),
              ),
            ),
          );
      await row('A', 1, 100, state: 'DONE');
      await service.create(accountId: acct, operationDate: DateTime(2025, 1, 2), amount: -10, currency: 'EUR', description: 'cash');
      expect(await byDescription(), {'A': (100, TransactionStatus.settled), 'cash': (100, TransactionStatus.settled)});
    });
  });
}
