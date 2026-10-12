// End-to-end round trips of the opening-balance feature: the user types the
// balance their bank shows, `TransactionService.planOpeningBalance` works
// out the transaction that would bring the app to it, and the caller
// creates it through `create` — the same path "Add transaction" uses, so it
// is an ordinary row with no marker. These tests exercise ImportService and
// TransactionService together, the way `_executeImport` will.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';

void main() {
  late AppDatabase db;
  late ImportService importer;
  late TransactionService txService;
  late CategoryService catService;
  late int acct;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = ImportService(db);
    txService = TransactionService(db);
    catService = CategoryService(db);
    acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
  });
  tearDown(() => db.close());

  /// What `_executeImport` does after the import's own balance recalculation:
  /// plan an opening balance for [actualBalance], and create it when there is
  /// one — with the category [CategoryService.openingBalanceCategoryFor]
  /// gives its sign.
  Future<double?> addOpening(double actualBalance) async {
    final plan = await txService.planOpeningBalance(accountId: acct, balanceMode: BalanceMode.cumulative, actualBalance: actualBalance);
    if (plan == null) return null;
    final categoryId = await catService.openingBalanceCategoryFor(plan.amount);
    await txService.create(
      accountId: acct,
      operationDate: plan.anchorDate,
      amount: plan.amount,
      description: 'Opening balance',
      currency: 'EUR',
      categoryId: categoryId,
    );
    await txService.recalculateBalances(acct, balanceMode: 'cumulative');
    return plan.amount;
  }

  Future<double?> latestBalance() async {
    final rows = await txService.getByAccount(acct);
    for (final t in rows) {
      if (t.balanceAfter != null) return t.balanceAfter;
    }
    return null;
  }

  group('TransactionImportPreview.lastDay', () {
    test('the latest date on either timeline, across rows', () async {
      final p = await importer.previewTransactionImport(
        preview: const FilePreview(
          columns: ['Date', 'Value', 'Amount'],
          rows: [
            {'Date': '2026-03-01', 'Value': '2026-03-01', 'Amount': '100'},
            // Booked later but value-dated earlier (a card payment settling
            // early): the LATER of the two still counts.
            {'Date': '2026-03-10', 'Value': '2026-03-05', 'Amount': '-40'},
          ],
          totalRows: 2,
        ),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Value', targetField: 'valueDate'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: acct,
      );
      expect(p.lastDay, DateTime(2026, 3, 10));
    });

    test('null when nothing parsed', () async {
      final p = await importer.previewTransactionImport(
        preview: const FilePreview(columns: ['Date', 'Amount'], rows: [], totalRows: 0),
        mappings: const [
          ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
          ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
        ],
        accountId: acct,
      );
      expect(p.lastDay, isNull);
    });
  });

  group('round trips', () {
    const preview = FilePreview(
      columns: ['Date', 'Amount'],
      rows: [
        {'Date': '2026-03-01', 'Amount': '100'},
        {'Date': '2026-03-05', 'Amount': '-40'},
      ],
      totalRows: 2,
    );
    const mappings = [
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Amount', targetField: 'amount'),
    ];

    test('first import: the typed balance becomes an opening row before the earliest transaction', () async {
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');
      expect(await latestBalance(), 60, reason: "the app's own history: 100 − 40");

      final added = await addOpening(560);
      expect(added, 500);
      expect(await latestBalance(), 560);

      final opening = (await txService.getByAccount(acct)).singleWhere((t) => t.description == 'Opening balance');
      expect(opening.operationDate, DateTime(2026, 2, 28));
      expect(opening.valueDate, DateTime(2026, 2, 28));
      expect(opening.status, TransactionStatus.settled);
      expect(opening.currency, 'EUR');
      expect(opening.rawMetadata, isNull, reason: 'an ordinary hand-entered row, not an imported one');
      final cat = await catService.getByKey(CategoryService.openingBalanceIncomeKey);
      expect(opening.categoryId, cat!.id);
    });

    test('typing the same balance again adds nothing: never a duplicate', () async {
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');
      await addOpening(560);

      final again = await addOpening(560);
      expect(again, isNull);
      expect((await txService.getByAccount(acct)).where((t) => t.description == 'Opening balance'), hasLength(1));
    });

    test('re-importing the same file keeps the opening row and the balance it set', () async {
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');
      await addOpening(560);

      // A normal re-import of the same file: wipe-and-replace from its
      // oldest date (2026-03-01) onward. The opening row is dated before
      // that, so it survives.
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');

      expect(await latestBalance(), 560);
      expect((await txService.getByAccount(acct)).where((t) => t.description == 'Opening balance'), hasLength(1));
    });

    test('re-running the import from stored rows keeps the opening row (it has no raw metadata)', () async {
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');
      await addOpening(560);

      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
        replaceOnlyImportedRows: true,
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');

      expect(await latestBalance(), 560);
      expect((await txService.getByAccount(acct)).where((t) => t.description == 'Opening balance'), hasLength(1));
    });

    test('an older file reaching back past the opening row replaces it, like any other row', () async {
      await importer.importTransactions(
        preview: preview,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');
      await addOpening(560);

      // A fuller export reaching back before the opening row's date.
      const olderFile = FilePreview(
        columns: ['Date', 'Amount'],
        rows: [
          {'Date': '2026-02-01', 'Amount': '60'},
          {'Date': '2026-03-01', 'Amount': '100'},
          {'Date': '2026-03-05', 'Amount': '-40'},
        ],
        totalRows: 3,
      );
      final result = await importer.importTransactions(
        preview: olderFile,
        mappings: mappings,
        accountId: acct,
        balanceMode: 'cumulative',
        numberLocaleOverride: 'en_US',
      );
      expect(
        result.deletedRows,
        3,
        reason: 'the two 2026-03 rows AND the opening row dated 2026-02-28 — all on or after the new cutoff, 2026-02-01',
      );
      await txService.recalculateBalances(acct, balanceMode: 'cumulative');

      expect((await txService.getByAccount(acct)).where((t) => t.description == 'Opening balance'), isEmpty);
      expect(await latestBalance(), 120, reason: '60 + 100 − 40, no opening row anymore');

      // The user re-states the real balance for the new, earlier history.
      final added = await addOpening(560);
      expect(added, 440);
      expect(await latestBalance(), 560);
      final opening = (await txService.getByAccount(acct)).singleWhere((t) => t.description == 'Opening balance');
      expect(opening.operationDate, DateTime(2026, 1, 31));
    });

    group('balance-diff amount mode (amount = the difference between consecutive stated balances)', () {
      const balanceDiffFile = FilePreview(
        columns: ['Date', 'Balance'],
        rows: [
          {'Date': '2026-03-01', 'Balance': '100'},
          {'Date': '2026-03-05', 'Balance': '60'},
        ],
        totalRows: 2,
      );
      const balanceDiffMappings = [
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Balance', targetField: 'amount', balanceDiffColumn: 'Balance'),
      ];

      test('first import: the first row contributes 0 (no seed yet) — a documented limitation, not what this feature fixes', () async {
        await importer.importTransactions(
          preview: balanceDiffFile,
          mappings: balanceDiffMappings,
          accountId: acct,
          balanceMode: 'cumulative',
          numberLocaleOverride: 'en_US',
        );
        await txService.recalculateBalances(acct, balanceMode: 'cumulative');
        // row1 = 0 (unseeded), row2 = 60 − 100 = −40. The file's OWN last
        // stated balance (60) is what a correct bank balance is.
        expect(await latestBalance(), -40);
      });

      test(
        "typing the file's own true closing balance adds exactly its first stated balance as the opening, and a re-run reproduces every amount unchanged",
        () async {
          await importer.importTransactions(
            preview: balanceDiffFile,
            mappings: balanceDiffMappings,
            accountId: acct,
            balanceMode: 'cumulative',
            numberLocaleOverride: 'en_US',
          );
          await txService.recalculateBalances(acct, balanceMode: 'cumulative');

          final added = await addOpening(60);
          expect(added, 100, reason: "the first row's own stated balance: it never got to move the balance by it");
          expect(await latestBalance(), 60);

          Future<List<double>> amountsInOrder() async {
            final rows = await txService.getByAccount(acct);
            final sorted = List.of(rows)
              ..sort((a, b) {
                final c = a.valueDate.compareTo(b.valueDate);
                return c != 0 ? c : a.id.compareTo(b.id);
              });
            return [for (final t in sorted) t.amount];
          }

          final before = await amountsInOrder();

          // Re-run the SAME file from stored rows: the opening row (no raw
          // metadata) seeds the balance-diff computation with its own stored
          // balance (100) — exactly the figure it was created with — so every
          // row's amount comes out identical. No corruption from one feature
          // leaning on the other's seed.
          await importer.importTransactions(
            preview: balanceDiffFile,
            mappings: balanceDiffMappings,
            accountId: acct,
            balanceMode: 'cumulative',
            numberLocaleOverride: 'en_US',
            replaceOnlyImportedRows: true,
          );
          await txService.recalculateBalances(acct, balanceMode: 'cumulative');

          expect(await amountsInOrder(), before);
          expect(await latestBalance(), 60, reason: 'idempotent: the same actual balance holds after a re-run');
        },
      );
    });
  });
}
