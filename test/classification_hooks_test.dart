// Derived merchant keys are written by every code path that creates or
// edits a transaction: import, manual create, manual update. Plus the
// category dimension of the ledger filter.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/rule_service.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/accounts/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'A'));
  });
  tearDown(() => db.close());

  Future<Transaction> get(int id) => (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  group('TransactionService', () {
    test('create stores merchant key / counterparty / entry kind and optional category', () async {
      final svc = TransactionService(db);
      final groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
      final id = await svc.create(
        accountId: acct,
        operationDate: DateTime(2024, 1, 1),
        amount: -12,
        description: 'POS SPAR 20170429',
        currency: 'EUR',
        categoryId: groceries,
      );
      final t = await get(id);
      expect(t.merchantKey, 'SPAR');
      expect(t.counterparty, 'SPAR');
      expect(t.entryKind, BankEntryKind.cardPayment);
      expect(t.categoryId, groceries);
    });

    test('update recomputes keys only when description/amount change', () async {
      final svc = TransactionService(db);
      final id = await svc.create(
        accountId: acct,
        operationDate: DateTime(2024, 1, 1),
        amount: -12,
        description: 'POS SPAR 20170429',
        currency: 'EUR',
      );
      await svc.update(id, const TransactionsCompanion(balanceAfter: Value(5)));
      expect((await get(id)).merchantKey, 'SPAR');

      await svc.update(id, const TransactionsCompanion(description: Value('To HERA S.P.A.')));
      final t = await get(id);
      expect(t.merchantKey, 'HERASPA');
      expect(t.entryKind, BankEntryKind.transfer);

      // Flipping the sign changes which side of a payer/payee pair is used.
      await svc.update(id, const TransactionsCompanion(description: Value('Bonifico - Ord: ALICE Ben: BOB Dt-ord: 1/1/24')));
      expect((await get(id)).merchantKey, 'BOB');
      await svc.update(id, const TransactionsCompanion(amount: Value(12)));
      expect((await get(id)).merchantKey, 'ALICE');
      expect(await svc.update(9999, const TransactionsCompanion(description: Value('x'))), isFalse);
    });
  });

  group('ImportService', () {
    test('imported rows carry merchant keys derived from description + raw metadata', () async {
      final importer = ImportService(db);
      final dir = Directory.systemTemp.createTempSync('clf_import_');
      final file = File('${dir.path}/t.csv')
        ..writeAsStringSync('''
Date,Amount,Description,Tipo
15/01/2024,-42.50,Esselunga Milano,Pagamento con carta
16/01/2024,-100.00,Ricarica di *1172,Ricarica
''');
      final preview = await importer.parseFile(file.path);
      final result = await importer.importTransactions(
        preview: preview,
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
          ColumnMapping(sourceColumn: 'Description', targetField: 'description'),
        ],
        accountId: acct,
      );
      expect(result.importedRows, 2);
      final txs = await (db.select(db.transactions)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(txs[0].merchantKey, 'ESSELUNGAMILANO');
      expect(txs[0].entryKind, BankEntryKind.cardPayment, reason: 'type hint read from the raw metadata column');
      expect(txs[1].merchantKey, 'TOPUP*1172');
      expect(txs[1].entryKind, BankEntryKind.cardTopUp);
      expect(txs.every((t) => t.categoryId == null), isTrue, reason: 'import never assigns a category by itself');

      // A rule + post-import classify (as the wizard/import step does).
      final groceries = (await (db.select(db.categories)..where((c) => c.key.equals('groceries'))).getSingle()).id;
      await RuleService(db).create(matchType: RuleMatchType.merchantKey, pattern: 'ESSELUNGAMILANO', categoryId: groceries);
      final r = await TransactionClassifierService(db).classifyAll(accountId: acct);
      expect(r.changed, 1);
      expect(r.excluded, 1, reason: 'the bank-declared top-up is a transfer: never categorized');
      expect(r.uncategorizedAfter, 0);
      dir.deleteSync(recursive: true);
    });
  });

  group('TransactionFilter category dimension', () {
    test('empty = pass-through; set restricts; null means uncategorized', () {
      const none = TransactionFilter.none;
      expect(none.hasCategoryFilter, isFalse);
      expect(none.hasRowFilter, isFalse);
      expect(none.matchesCategory(3), isTrue);
      expect(none.matchesCategory(null), isTrue);

      final f = none.toggleCategory(3);
      expect(f.hasCategoryFilter, isTrue);
      expect(f.hasRowFilter, isTrue);
      expect(f.isActive, isTrue);
      expect(f.activeCount, 1);
      expect(f.matchesCategory(3), isTrue);
      expect(f.matchesCategory(4), isFalse);
      expect(f.matchesCategory(null), isFalse);

      final g = f.toggleCategory(null);
      expect(g.categoryIds, {3, null});
      expect(g.matchesCategory(null), isTrue);
      expect(g.activeCount, 1, reason: 'the category dimension counts once');

      expect(g.toggleCategory(3).toggleCategory(null).hasCategoryFilter, isFalse);
      expect(g.copyWith(categoryIds: const {}).hasCategoryFilter, isFalse);
    });

    test('category does not interfere with kind/date/amount matching', () {
      final f = TransactionFilter.none.toggleCategory(1);
      expect(f.matches({EntryKind.outflow}, DateTime(2024, 1, 1), -5), isTrue);
    });
  });
}
