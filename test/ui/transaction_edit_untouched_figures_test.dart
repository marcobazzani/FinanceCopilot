// TransactionEditScreen never rewrites a figure the user did not touch: the
// amount and the balance after are pre-filled with every digit (in the
// locale spelling the save parses back), so a description-only edit keeps
// an imported -20.125 at -20.125. The form used to pre-fill two decimals and
// write back the rounded value.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';

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

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<Transaction> insertTx({required double amount, double? balance}) async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account.id,
            operationDate: DateTime(2024, 3, 8),
            valueDate: DateTime(2024, 3, 10),
            amount: amount,
            balanceAfter: Value(balance),
            description: const Value('Card payment'),
          ),
        );
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> open(WidgetTester tester, String locale, Transaction tx) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          privacyModeProvider.overrideWith((ref) => false),
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

  String fieldText(WidgetTester tester, int index) => tester.widget<TextFormField>(find.byType(TextFormField).at(index)).controller!.text;

  for (final (locale, amount, balance) in [('it_IT', '-20,125', '1000,4567'), ('en_US', '-20.125', '1000.4567')]) {
    testWidgets('$locale: a description-only edit keeps the amount and the balance to the last digit', (tester) async {
      final tx = await insertTx(amount: -20.125, balance: 1000.4567);
      await open(tester, locale, tx);
      try {
        expect(fieldText(tester, 1), amount, reason: 'every digit, in the locale spelling');
        expect(fieldText(tester, 4), balance);
        await tester.enterText(find.byType(TextFormField).at(2), 'Card payment, groceries');
        await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
        await settle(tester);

        expect(find.byType(TransactionEditScreen), findsNothing, reason: 'saved without a validation error');
        final saved = (await db.select(db.transactions).get()).single;
        expect(saved.description, 'Card payment, groceries');
        expect(saved.amount, -20.125);
        expect(saved.balanceAfter, 1000.4567);
      } finally {
        await unmount(tester);
      }
    });
  }

  testWidgets('an amount the locale spells exactly keeps its usual pre-fill', (tester) async {
    final tx = await insertTx(amount: -1234.5, balance: 5000);
    await open(tester, 'it_IT', tx);
    try {
      expect(fieldText(tester, 1), '-1.234,50');
      expect(fieldText(tester, 4), '5.000,00');
    } finally {
      await unmount(tester);
    }
  });
}
