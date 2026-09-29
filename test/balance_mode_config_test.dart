// The balance mode an account's running balance is recalculated in comes
// from its saved import config (`__balanceMode` and the settings next to it).
//
//  * A config that stores no mode (an earlier app version wrote them) is left
//    alone by every automatic recalculation — after a create, an edit or a
//    delete, and by the one-shot recalculation of migration 25 — and its
//    balances are not computed (computesBalances is false: 'Balance after'
//    stays editable). The import wizard and the balance dialog still start
//    from cumulative for it, and store the mode they apply.
//  * The only config the app writes without a mode today is the number-format
//    placeholder an import stores before the wizard saves its settings. It
//    holds no settings at all and reads as no import config: balances are
//    left alone.
//  * Unreadable settings (corrupt JSON, an unknown mode, a filter set of an
//    unexpected shape) crashed the recalculation after the row was already
//    deleted, or were read as another mode (an unknown mode wiped every
//    balance). They are now logged and the balances left as they are; a
//    filter set stored as a JSON list (as the v47 migration accepts) is read.
//  * One row whose raw statement data is not a JSON object stopped the whole
//    recalculation: it is now read as a row without statement data.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';

void main() {
  late AppDatabase db;
  late TransactionService service;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  Future<void> config(String mappingsJson, {int? account}) => db
      .into(db.importConfigs)
      .insert(
        ImportConfigsCompanion.insert(accountId: Value(account ?? acct), mappingsJson: Value(mappingsJson), numberLocale: const Value('en_US')),
      );

  Future<int> row(int day, double amount, {String? raw, double? balance, int? account}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account ?? acct,
          operationDate: DateTime(2024, 3, day),
          valueDate: DateTime(2024, 3, day),
          amount: amount,
          description: Value('Day $day'),
          balanceAfter: Value(balance),
          rawMetadata: Value(raw),
        ),
      );

  Future<List<double?>> balances({int? account}) async => [
    for (final t
        in await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(account ?? acct))
              ..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)]))
            .get())
      t.balanceAfter,
  ];

  Future<List<TransactionStatus>> statuses() async => [
    for (final t in await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.valueDate), (t) => OrderingTerm.asc(t.id)])).get())
      t.status,
  ];

  /// Three rows with stale balances and a fourth one deleted: a recalculation
  /// shows as fresh balances on the three that remain.
  Future<void> deleteOne() async {
    await row(1, 100, balance: 7, raw: jsonEncode({'State': 'DONE', 'Bank': '1100'}));
    await row(2, -30, balance: 7, raw: jsonEncode({'State': 'FAILED', 'Bank': '1070'}));
    await row(3, 10, balance: 7, raw: jsonEncode({'State': 'DONE', 'Bank': '1080'}));
    final gone = await row(4, 5, balance: 7, raw: jsonEncode({'State': 'DONE', 'Bank': '1085'}));
    await service.delete(gone);
  }

  group('BalanceMode', () {
    test('its names are the stored strings', () {
      expect(BalanceMode.values.map((m) => m.name), ['none', 'cumulative', 'column', 'filtered']);
      for (final m in BalanceMode.values) {
        expect(BalanceMode.parse(m.name), m);
      }
    });

    test('no stored mode is the documented default, an unknown one is unreadable', () {
      expect(BalanceMode.parse(null), BalanceMode.cumulative);
      expect(BalanceMode.byDefault, BalanceMode.cumulative);
      expect(BalanceMode.parse('Cumulative'), isNull);
      expect(BalanceMode.parse(''), isNull);
      expect(BalanceMode.parse(42), isNull);
    });
  });

  group('a config without a balance mode: every automatic recalculation leaves the balances alone', () {
    const keyless = '{"date":"Date","amount":"Amount","description":"Description"}';

    test('after a delete', () async {
      await config(keyless);
      await deleteOne();
      expect(await balances(), [7, 7, 7]);
    });

    test('after a create and an edit: a typed balance stays as typed', () async {
      await config(keyless);
      await row(1, 100, balance: 7);
      final id = await service.create(accountId: acct, operationDate: DateTime(2024, 3, 2), amount: -30, balanceAfter: 500, currency: 'EUR');
      expect(await balances(), [7, 500]);
      await service.update(id, const TransactionsCompanion(amount: Value(-40), balanceAfter: Value(460)));
      expect(await balances(), [7, 460]);
    });

    test('by the one-shot recalculation of every account (migration 25), which leaves column mode alone', () async {
      await config(keyless);
      final column = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Bank'));
      await config('{"__balanceMode":"column","balanceAfter":"Bank"}', account: column);
      final cumulative = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
      await config('{"__balanceMode":"cumulative"}', account: cumulative);
      // An asset-scoped config has no account: it is not an account's.
      await db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(scope: const Value('income')));
      await row(1, 100, balance: 7);
      await row(2, -30, balance: 7);
      await row(1, 100, balance: 3, account: column, raw: '{"Bank":"1100"}');
      await row(1, 50, balance: 7, account: cumulative);
      await row(2, 25, balance: 7, account: cumulative);

      await service.recalcAllFromImportConfigs(skip: const {BalanceMode.column});
      expect(await balances(), [7, 7], reason: 'no stored mode: left alone');
      expect(await balances(account: column), [3], reason: 'column mode is skipped');
      expect(await balances(account: cumulative), [50, 75], reason: 'a stored mode is recalculated');
    });

    test('its balances are not computed: the edit form keeps them editable', () async {
      await config(keyless);
      expect(await service.computesBalances(acct), isFalse);
      final savings = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
      await config('{"__balanceMode":"cumulative"}', account: savings);
      expect(await service.computesBalances(savings), isTrue, reason: 'a stored mode computes them');
    });

    test('logged once per recalculation, below INFO', () async {
      await config(keyless);
      await row(1, 100, balance: 7);
      final records = <LogRecord>[];
      final level = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.where((r) => r.loggerName == 'TransactionService').listen(records.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = level;
      });

      await service.recalcFromImportConfig(acct);
      expect([for (final r in records) (r.level, r.message.contains('stores no balance mode'))], [(Level.FINE, true)]);
    });

    test('only a stored mode counts as one', () {
      expect(SavedImportMappings.decode(keyless).storesBalanceMode, isFalse);
      expect(SavedImportMappings.decode('{"__balanceMode":null}').storesBalanceMode, isFalse);
      expect(SavedImportMappings.decode('{"__balanceMode":"cumulative"}').storesBalanceMode, isTrue);
      expect(SavedImportMappings.decode('{"__balanceMode":"none"}').storesBalanceMode, isTrue);
    });

    test('the same settings as the reader', () {
      final settings = SavedImportMappings.decode(keyless).balance!;
      expect(settings.mode, BalanceMode.cumulative);
      expect(settings.filterInclude, isEmpty);
    });
  });

  group('no import config, or only the number-format placeholder: balances are left alone', () {
    test('an account imported without saved settings keeps a hand-entered balance (placeholder config)', () async {
      await ImportService(db).importTransactions(
        preview: const FilePreview(
          columns: ['Date', 'Amount', 'Balance'],
          rows: [
            {'Date': '01/03/2024', 'Amount': '100', 'Balance': '1100'},
          ],
          totalRows: 1,
          numberLocale: 'en_US',
        ),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Balance', targetField: 'balanceAfter'),
        ],
        accountId: acct,
        balanceMode: 'column',
      );
      expect(
        jsonDecode((await db.select(db.importConfigs).getSingle()).mappingsJson),
        isEmpty,
        reason: 'the placeholder: a number format, no settings',
      );

      await service.create(accountId: acct, operationDate: DateTime(2024, 3, 5), amount: -10, balanceAfter: 500, currency: 'EUR');
      expect(await balances(), [1100, 500]);
    });

    test('an explicit none', () async {
      await config('{"__balanceMode":"none"}');
      await deleteOne();
      expect(await balances(), [7, 7, 7]);
    });
  });

  group('unreadable balance settings are never read as another mode', () {
    test('a filter set stored as a JSON list is read', () async {
      await config(
        jsonEncode({
          '__balanceMode': 'filtered',
          '__balanceFilterColumn': 'State',
          '__balanceFilterInclude': ['DONE'],
        }),
      );
      await deleteOne();
      expect(await balances(), [100, 100, 110]);
      expect(await statuses(), [TransactionStatus.settled, TransactionStatus.cancelled, TransactionStatus.settled]);
    });

    for (final (what, json) in [
      ('mappings that are not JSON', 'not json'),
      ('mappings that are a JSON list', '["__balanceMode"]'),
      ('an unknown mode', '{"__balanceMode":"cumulativ"}'),
      ('a mode that is not text', '{"__balanceMode":42}'),
      ('a filter set that is not JSON', '{"__balanceMode":"filtered","__balanceFilterColumn":"State","__balanceFilterInclude":"DONE"}'),
      ('a filter set of objects', '{"__balanceMode":"filtered","__balanceFilterColumn":"State","__balanceFilterInclude":"[{\\"a\\":1}]"}'),
      ('a filter column that is not text', '{"__balanceMode":"filtered","__balanceFilterColumn":7}'),
      ('a balance column that is not text', '{"__balanceMode":"column","balanceAfter":["Bank"]}'),
    ]) {
      test('$what: the delete succeeds, the balances are left as they are', () async {
        await config(json);
        await deleteOne();
        expect(await balances(), [7, 7, 7]);
        expect(await statuses(), everyElement(TransactionStatus.settled));
      });
    }

    test('settings a mode does not use do not block it', () async {
      await config('{"__balanceMode":"cumulative","__balanceFilterInclude":"not json","balanceAfter":3}');
      await deleteOne();
      expect(await balances(), [100, 70, 80]);
    });

    test('recalculating in an unknown mode changes nothing (it used to clear every balance)', () async {
      await row(1, 100, balance: 7);
      expect(await service.recalculateBalances(acct, balanceMode: 'bogus'), 0);
      expect(await balances(), [7]);
    });
  });

  group('raw statement data that is not a JSON object', () {
    for (final (what, raw) in [('not JSON', '{"Bank": '), ('a JSON list', '["1070"]'), ('JSON null', 'null')]) {
      test('column mode, $what: the row has no bank figure, the others still anchor the series', () async {
        await row(1, 100, raw: '{"Bank":"1100"}');
        await row(2, -30, raw: raw);
        await row(3, 10, raw: '{"Bank":"1080"}');
        final r = await service.recalculateBalancesDetailed(acct, balanceMode: 'column', savedMappings: const {'balanceAfter': 'Bank'});
        expect(r.anchored, isTrue);
        expect(await balances(), [1100, 1070, 1080]);
      });

      test('filtered mode, $what: read like a row without statement data', () async {
        await row(1, 100, raw: '{"State":"DONE"}');
        await row(2, -30, raw: raw);
        await row(3, 10, raw: '{"State":"DONE"}');
        await service.recalculateBalances(
          acct,
          balanceMode: 'filtered',
          savedMappings: const {'__balanceFilterColumn': 'State', '__balanceFilterInclude': '["DONE"]'},
        );
        expect(await balances(), [100, 100, 110]);
        expect(await statuses(), [TransactionStatus.settled, TransactionStatus.cancelled, TransactionStatus.settled]);
      });
    }

    test('decodeRawMetadata: a JSON object, or null (logged) for anything else', () {
      expect(decodeRawMetadata('{"a":"1"}'), {'a': '1'});
      expect(decodeRawMetadata(null), isNull);
      expect(decodeRawMetadata('["a"]'), isNull);
      expect(decodeRawMetadata('{"a": '), isNull);
    });
  });
}
