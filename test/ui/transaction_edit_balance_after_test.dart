// TransactionEditScreen, 'Balance after' against the account's saved balance
// setting:
// - when the account's import config computes the running balance
//   (cumulative, column or filtered), the balance after is derived — the
//   ledger recomputes it after every save — so it is shown read-only with a
//   hint, masked in privacy mode like any read-only position figure, and no
//   typed value is sent;
// - without a computing config (none, the `{}` placeholder an import stores
//   before its settings, a 'none' mode, or settings that cannot be read) the
//   field stays editable and a typed balance is saved as typed.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';

/// Records what the screen sends on update.
class _RecordingTransactions extends TransactionService {
  _RecordingTransactions(super.db);

  final updates = <TransactionsCompanion>[];

  @override
  Future<bool> update(int id, TransactionsCompanion companion) {
    updates.add(companion);
    return super.update(id, companion);
  }
}

/// Opens [screen] on a push once the locale is loaded, as in the app (the
/// shell watches it): the screen reads the locale once in initState.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.screen);
  final Widget Function() screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;
  late Account account;
  late _RecordingTransactions transactions;

  const hint = "Computed by the account's balance setting on every save";

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    transactions = _RecordingTransactions(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> config(String mappingsJson) =>
      db.into(db.importConfigs).insert(ImportConfigsCompanion.insert(accountId: Value(account.id), mappingsJson: Value(mappingsJson)));

  Future<Transaction> insertTx(int day, double amount, double balance) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            operationDate: DateTime(2024, 3, day),
            valueDate: DateTime(2024, 3, day),
            amount: amount,
            balanceAfter: Value(balance),
            description: Value('Row $day'),
          ),
        );
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Transaction> reload(Transaction tx) => (db.select(db.transactions)..where((t) => t.id.equals(tx.id))).getSingle();

  Future<void> open(WidgetTester tester, {Transaction? tx, bool isPrivate = false}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          privacyModeProvider.overrideWith((ref) => isPrivate),
          transactionServiceProvider.overrideWithValue(transactions),
        ],
        child: MaterialApp(
          home: _Launcher(() => TransactionEditScreen(transaction: tx, account: account)),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(TransactionEditScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await settle(tester);
  }

  group('a config that computes the balance', () {
    for (final mode in ['cumulative', 'column', 'filtered']) {
      testWidgets('$mode: the balance after is read-only, with a hint, and is not sent', (tester) async {
        await config('{"__balanceMode":"$mode"}');
        await insertTx(1, 100, 100);
        final tx = await insertTx(2, -20, 80);
        await open(tester, tx: tx);
        try {
          expect(field('Balance After'), findsNothing, reason: 'nothing to type: it is recomputed after the save');
          expect(find.text('Balance After'), findsOneWidget);
          expect(find.text('80,00'), findsOneWidget);
          expect(find.text(hint), findsOneWidget);

          await tester.enterText(field('Description'), 'Groceries');
          await tapButton(tester, 'Save Changes');

          expect(find.byType(TransactionEditScreen), findsNothing);
          expect(transactions.updates.single.balanceAfter.present, isFalse, reason: 'no typed value is sent over the derived one');
          expect((await reload(tx)).description, 'Groceries');
        } finally {
          await unmount(tester);
        }
      });
    }

    testWidgets('an edited amount saves and the ledger recomputes the balance after', (tester) async {
      await config('{"__balanceMode":"cumulative"}');
      await insertTx(1, 100, 100);
      final tx = await insertTx(2, -20, 80);
      await open(tester, tx: tx);
      try {
        await tester.enterText(field('Amount *'), '-30');
        await tapButton(tester, 'Save Changes');

        final saved = await reload(tx);
        expect(saved.amount, -30);
        expect(saved.balanceAfter, 70, reason: 'the running sum after the edit');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a new row: no balance to type, the ledger computes it', (tester) async {
      await config('{"__balanceMode":"cumulative"}');
      await insertTx(1, 100, 100);
      await open(tester);
      try {
        expect(field('Balance After'), findsNothing);
        expect(find.text(hint), findsOneWidget);
        await tester.enterText(field('Amount *'), '-12,50');
        await tapButton(tester, 'Create Transaction');

        final created = (await db.select(db.transactions).get()).singleWhere((t) => t.amount == -12.5);
        expect(created.balanceAfter, 87.5);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy mode masks the read-only balance, not the amount input nor the hint', (tester) async {
      await config('{"__balanceMode":"cumulative"}');
      await insertTx(1, 100, 100);
      final tx = await insertTx(2, -20, 80);
      await open(tester, tx: tx, isPrivate: true);
      try {
        final balance = find.text('80,00');
        expect(balance, findsOneWidget);
        expect(masked(balance), isTrue, reason: 'an account balance is a position size');
        expect(masked(find.text('Balance After')), isFalse, reason: 'a label is no figure');
        expect(masked(find.text(hint)), isFalse);
        expect(masked(field('Amount *')), isFalse, reason: 'an input the user types stays as it is');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('no config that computes the balance', () {
    for (final (name, mappings) in [
      ('no config', null),
      ('the {} placeholder', '{}'),
      ('mode none', '{"__balanceMode":"none"}'),
      ('an unreadable mode', '{"__balanceMode":"bogus"}'),
    ]) {
      testWidgets('$name: the balance after stays editable and a typed one is saved', (tester) async {
        if (mappings != null) await config(mappings);
        await insertTx(1, 100, 100);
        final tx = await insertTx(2, -20, 80);
        await open(tester, tx: tx);
        try {
          expect(find.text(hint), findsNothing);
          expect(tester.widget<TextFormField>(field('Balance After')).controller!.text, '80,00');
          await tester.enterText(field('Balance After'), '500');
          await tapButton(tester, 'Save Changes');

          expect(find.byType(TransactionEditScreen), findsNothing);
          expect((await reload(tx)).balanceAfter, 500);
        } finally {
          await unmount(tester);
        }
      });
    }
  });
}
