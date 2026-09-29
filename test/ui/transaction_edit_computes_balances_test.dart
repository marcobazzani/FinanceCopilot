// TransactionEditScreen asks the ledger whether the account's balances are
// computed — TransactionService.computesBalances, the single source of truth
// its save path uses to replace a written balance — instead of re-deriving it
// from the saved import config. 'Balance after' is read-only exactly when the
// ledger says so, whatever the config looks like. (The outcome for each saved
// balance setting is pinned in transaction_edit_balance_after_test.dart.)
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/transaction_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';

/// Answers [computesBalances] with [computes] and records the accounts asked.
class _ScriptedLedger extends TransactionService {
  _ScriptedLedger(super.db, {required this.computes});

  final bool computes;
  final asked = <int>[];

  @override
  Future<bool> computesBalances(int accountId) async {
    asked.add(accountId);
    return computes;
  }
}

/// Opens [screen] on a push once the locale is loaded, as in the app.
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
  const s = AppStrings.en;
  late AppDatabase db;
  late Account account;
  late Transaction tx;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    account = await (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
    final txId = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: id,
            operationDate: DateTime(2024, 3, 1),
            valueDate: DateTime(2024, 3, 1),
            amount: -20,
            balanceAfter: const Value(80),
          ),
        );
    tx = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, TransactionService ledger) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
          transactionServiceProvider.overrideWithValue(ledger),
        ],
        child: MaterialApp(
          home: _Launcher(() => TransactionEditScreen(transaction: tx, account: account)),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder balanceField() => find.widgetWithText(TextFormField, s.balanceAfter);

  testWidgets('no import config, but the ledger computes the balances: read-only', (tester) async {
    final ledger = _ScriptedLedger(db, computes: true);
    await open(tester, ledger);
    try {
      expect(ledger.asked, [account.id]);
      expect(balanceField(), findsNothing);
      expect(find.text(s.balanceAfterComputedHint), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a cumulative config, but the ledger leaves the balances as they are: editable', (tester) async {
    await db
        .into(db.importConfigs)
        .insert(ImportConfigsCompanion.insert(accountId: Value(account.id), mappingsJson: const Value('{"__balanceMode":"cumulative"}')));
    final ledger = _ScriptedLedger(db, computes: false);
    await open(tester, ledger);
    try {
      expect(ledger.asked, [account.id]);
      expect(balanceField(), findsOneWidget);
      expect(find.text(s.balanceAfterComputedHint), findsNothing);
    } finally {
      await unmount(tester);
    }
  });
}
