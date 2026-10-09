// A file date carrying a zone ('Z', '+02:00') parses to a UTC instant. The
// wipe-and-replace cutoffs took its UTC calendar day as a LOCAL midnight: in
// Europe/Rome "2024-03-01T23:30:00Z" is 00:30 on 2 March, but the cutoff became
// 1 March and the stored rows of 1 March that are not in the file were
// deleted. Parsed instants are now read on the local calendar, like every
// date the app shows. Expectations are written in local days, so the tests
// hold in any time zone (run them with TZ=UTC too).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late int acct;

  const stamp = '2024-03-01T23:30:00Z';
  final instant = DateTime.parse(stamp).toLocal();
  // The local calendar day the file starts on, and noon of the day before.
  final firstDay = DateTime(instant.year, instant.month, instant.day);
  final dayBefore = DateTime(firstDay.year, firstDay.month, firstDay.day - 1, 12);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<int> stored(DateTime when, double amount, {String? raw, int? categoryId, String description = ''}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: acct,
          operationDate: when,
          valueDate: when,
          amount: amount,
          description: Value(description),
          rawMetadata: Value(raw),
          categoryId: Value(categoryId),
        ),
      );

  const file = FilePreview(
    columns: ['When', 'Amount', 'Balance', 'Description'],
    rows: [
      {'When': stamp, 'Amount': '100', 'Balance': '1100', 'Description': 'Salary'},
    ],
    totalRows: 1,
    numberLocale: 'en_US',
  );
  const mappings = [
    ColumnMapping(sourceColumn: 'When', targetField: 'date'),
    ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
    ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
  ];

  Future<List<Transaction>> rows() => (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.operationDate)])).get();

  test('the stored rows of the local day before the file survive the replace; the dry run agrees', () async {
    final kept = await stored(dayBefore, 7);
    final preview = await importer.previewTransactionImport(preview: file, mappings: mappings, accountId: acct);
    expect(preview.rowsToReplace, 0);

    final r = await importer.importTransactions(preview: file, mappings: mappings, accountId: acct);
    expect(r.deletedRows, 0);
    final all = await rows();
    expect(all.map((t) => t.id), contains(kept));
    expect(all.last.operationDate, DateTime.parse(stamp).toLocal(), reason: 'the instant itself is stored unchanged');
  });

  test('a stored row of the file\'s own local day is replaced', () async {
    await stored(firstDay, 7);
    final r = await importer.importTransactions(preview: file, mappings: mappings, accountId: acct);
    expect(r.deletedRows, 1);
  });

  test('the balance-difference seed is the statement balance of the local day before', () async {
    await stored(dayBefore, 7, raw: '{"Balance":"1000"}');
    await importer.importTransactions(
      preview: file,
      mappings: const [
        ColumnMapping(sourceColumn: 'When', targetField: 'date'),
        ColumnMapping(targetField: 'amount', balanceDiffColumn: 'Balance'),
      ],
      accountId: acct,
    );
    expect((await rows()).map((t) => t.amount), [7, 100]);
  });

  test('annotations carry over to the regenerated row of the same local day', () async {
    final groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
    await stored(DateTime.parse(stamp).toLocal(), 100, categoryId: groceries, description: 'Salary');
    await importer.importTransactions(preview: file, mappings: mappings, accountId: acct);
    expect((await rows()).single.categoryId, groceries);
  });

  test('asset events: the stored events of the local day before the file survive the replace', () async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final fund = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.alternative,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: broker,
          ),
        );
    final kept = await db
        .into(db.assetEvents)
        .insert(AssetEventsCompanion.insert(assetId: fund, date: dayBefore, valueDate: dayBefore, type: EventType.buy, amount: 7));
    final r = await importer.importAssetEventsGrouped(
      preview: file,
      mappings: const [
        ColumnMapping(sourceColumn: 'When', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
      ],
      baseCurrency: 'EUR',
      intermediaryId: broker,
      targetAssetId: fund,
    );
    expect(r.result.importedRows, 1);
    final events = await db.select(db.assetEvents).get();
    expect(events.map((e) => e.id), contains(kept));
    expect(events, hasLength(2));
  });
}
