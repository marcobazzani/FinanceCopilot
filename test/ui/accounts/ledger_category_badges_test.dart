// Every account ledger (one account, or all of them) shows each row's
// category: the category's icon in its colour, round, where the row starts,
// and its name beside the date — "Uncategorized" when it has none. Tapping
// the icon opens the classification card in a sheet (the wizard's own card)
// to classify the row from the ledger.
//
// Rows the ledger already explains — a transfer, a no-op pair, an
// adjustment, a cancelled row — take no category: they keep their in/out
// arrow, say why (the role, unless a badge already does), and offer nothing
// to classify.
//
// Privacy mode masks the amounts, never the category: it is no position size.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/classification/ledger_roles.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late int main;
  late int savings;
  late int groceries;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    main = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    savings = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Savings'));
    groceries = (await CategoryService(db).getByKey('groceries'))!.id;
  });
  tearDown(() => db.close());

  /// A row of [account] as an import writes it: with the merchant key, the
  /// counterparty and the entry kind the classifier reads.
  Future<int> tx(
    int account,
    String desc,
    double amount,
    DateTime day, {
    int? categoryId,
    TransactionStatus status = TransactionStatus.settled,
  }) {
    final n = TransactionClassifierService.normalize(description: desc, amount: amount);
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account,
            operationDate: day,
            valueDate: day,
            amount: amount,
            description: Value(desc),
            categoryId: Value(categoryId),
            status: Value(status),
            merchantKey: Value(n.merchantKey),
            counterparty: Value(n.counterparty),
            entryKind: Value(n.entryKind),
          ),
        );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget home, {bool private = false}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          privacyModeProvider.overrideWith((ref) => private),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> pumpLedger(WidgetTester tester, Account account, {bool private = false}) =>
      pumpScreen(tester, AccountDetailScreen(account: account), private: private);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Account> account(int id) => (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  Future<int?> categoryOf(int id) async => (await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle()).categoryId;

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// The ledger row titled [title] (the first, when several are).
  Finder rowOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(ListTile)).first;

  /// The category badge of the row [id]: present only on a row that takes a
  /// category.
  Finder badgeOf(int id) => find.byKey(ValueKey('txCategory:$id'));

  Future<void> tapApply(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('wizardApply')));
    await tester.tap(find.byKey(const Key('wizardApply')));
    await settle(tester);
  }

  testWidgets('a row shows its category\'s icon and name, an uncategorized one says so; privacy masks the amount, never the category', (
    tester,
  ) async {
    final coop = await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    final mystery = await tx(main, 'Mystery shop', -7, DateTime(2026, 1, 11));
    await pumpLedger(tester, await account(main), private: true);
    try {
      expect(find.descendant(of: badgeOf(coop), matching: find.byIcon(Icons.shopping_cart_outlined)), findsOneWidget);
      final name = find.descendant(of: rowOf('Coop'), matching: find.text('Groceries'));
      expect(name, findsOneWidget);
      expect(masked(name), isFalse, reason: 'a category is no position size');
      final amount = find.descendant(of: rowOf('Coop'), matching: find.text('-EUR12.50'));
      expect(amount, findsOneWidget);
      expect(masked(amount), isTrue, reason: 'the amount is');
      expect(
        find.descendant(of: rowOf('Coop'), matching: find.byIcon(Icons.arrow_upward)),
        findsNothing,
        reason: 'the category replaces the arrow',
      );

      expect(find.descendant(of: badgeOf(mystery), matching: find.byIcon(Icons.help_outline)), findsOneWidget);
      expect(find.descendant(of: rowOf('Mystery shop'), matching: find.text('Uncategorized')), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('rows the ledger explains take no category: they keep their arrow, say why once, and offer nothing to classify', (tester) async {
    final out = await tx(main, 'To savings', -100, DateTime(2026, 1, 15));
    await tx(savings, 'From main', 100, DateTime(2026, 1, 15));
    final failed = await tx(main, 'Failed card', -9, DateTime(2026, 1, 16), status: TransactionStatus.cancelled);
    await pumpLedger(tester, await account(main));
    try {
      final transfer = rowOf('To savings');
      expect(badgeOf(out), findsNothing, reason: 'nothing to classify');
      expect(find.descendant(of: transfer, matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
      expect(find.descendant(of: transfer, matching: find.text(s.ledgerRoleName(LedgerRole.transfer))), findsOneWidget);
      expect(find.descendant(of: transfer, matching: find.text('Uncategorized')), findsNothing);

      final cancelled = rowOf('Failed card');
      expect(badgeOf(failed), findsNothing);
      expect(
        find.descendant(of: cancelled, matching: find.text('Cancelled')),
        findsOneWidget,
        reason: 'its badge says why, and only it',
      );
      expect(find.descendant(of: cancelled, matching: find.text('Uncategorized')), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('tapping the category opens the classification card; applied by merchant, the row and its similar ones are classified', (
    tester,
  ) async {
    // Groceries used once: offered among the card's chips.
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    final first = await tx(main, 'Esselunga', -20, DateTime(2026, 1, 12));
    final second = await tx(main, 'Esselunga', -30, DateTime(2026, 1, 14));
    await pumpLedger(tester, await account(main));
    try {
      expect(find.byTooltip(s.classifyTransaction), findsNWidgets(3), reason: 'every row that takes a category');
      await tester.tap(badgeOf(first));
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TransactionClassifyCard), findsOneWidget);
      expect(find.text('1 other similar transaction'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('recentCat_$groceries')));
      await settle(tester);
      await tapApply(tester);

      expect(find.byType(TransactionClassifyCard), findsNothing, reason: 'the sheet closes once applied');
      expect(await categoryOf(first), groceries);
      expect(await categoryOf(second), groceries, reason: 'same merchant');
      for (final id in [first, second]) {
        expect(find.descendant(of: badgeOf(id), matching: find.byIcon(Icons.shopping_cart_outlined)), findsOneWidget);
      }
      expect(find.text('Groceries'), findsNWidgets(3), reason: 'the ledger follows');
      expect(find.text('Uncategorized'), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Skip closes the sheet and changes nothing', (tester) async {
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    final row = await tx(main, 'Esselunga', -20, DateTime(2026, 1, 12));
    await pumpLedger(tester, await account(main));
    try {
      await tester.tap(badgeOf(row));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('recentCat_$groceries')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('wizardSkip')));
      await tester.tap(find.byKey(const Key('wizardSkip')));
      await settle(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(await categoryOf(row), isNull);
      expect(find.descendant(of: rowOf('Esselunga'), matching: find.text('Uncategorized')), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the All-accounts ledger shows the categories too, and classifies from there', (tester) async {
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    final here = await tx(savings, 'Esselunga', -20, DateTime(2026, 1, 12));
    final sibling = await tx(main, 'Esselunga', -30, DateTime(2026, 1, 14));
    await pumpLedger(tester, buildAllAccountsVirtual('Every account'));
    try {
      expect(find.descendant(of: rowOf('Coop'), matching: find.text('Groceries')), findsOneWidget);
      expect(
        find.descendant(of: rowOf('Coop'), matching: find.text('Main')),
        findsOneWidget,
        reason: 'the account badge stays',
      );

      await tester.tap(badgeOf(here));
      await settle(tester);
      expect(find.byType(TransactionClassifyCard), findsOneWidget);
      await tester.tap(find.text(s.wizardScopeOnlyThis));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('recentCat_$groceries')));
      await settle(tester);
      await tapApply(tester);

      expect(await categoryOf(here), groceries);
      expect(await categoryOf(sibling), isNull, reason: 'only this transaction');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('while rows are being selected, tapping a category selects the row instead', (tester) async {
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    final row = await tx(main, 'Esselunga', -20, DateTime(2026, 1, 12));
    await pumpLedger(tester, await account(main));
    try {
      await tester.longPress(find.text('Coop'));
      await settle(tester);
      expect(find.text(s.nSelected(1)), findsOneWidget);

      await tester.tap(badgeOf(row), warnIfMissed: false);
      await settle(tester);
      expect(find.text(s.nSelected(2)), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a row that cannot be classified opens a sheet that says so, and closes', (tester) async {
    final out = await tx(main, 'To savings', -100, DateTime(2026, 1, 15));
    await tx(savings, 'From main', 100, DateTime(2026, 1, 15));
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(out))).getSingle();
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTransactionClassifySheet(context, tx: row, title: s.classifyTransaction),
            child: const Text('open'),
          ),
        ),
      ),
    );
    try {
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text(s.transactionNotClassifiable), findsOneWidget);
      expect(find.byType(TransactionClassifyCard), findsNothing);

      await tester.tap(find.byType(CloseButton));
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
