/// Integration test for the account-detail ledger filter and single-account
/// no-op collapsing.
///
/// Pins:
///   1. A same-account +X/-X same-day pair collapses into a No-op row in the
///      SINGLE-account detail view.
///   2. The structured filter sheet restricts the rendered ledger:
///      - "Show only → Outflows" shows only outflow rows;
///      - "Hide → Outflows" hides them (negative filtering);
///      - clearing via the active-filter pill restores everything.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

import 'helpers/test_app.dart';

Future<void> _seedTx(
  AppDatabase db, {
  required int account,
  required double amount,
  required DateTime date,
  required String desc,
}) async {
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: date,
          valueDate: date,
          amount: amount,
          description: Value(desc),
        ),
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Account-detail ledger: single-view no-op + filter sheet (show/hide)', (tester) async {
    final db = await pumpApp(tester);
    await longSettle(tester);

    final accId = await seedAccount(db, name: 'Filter Acct');
    final account = await (db.select(db.accounts)..where((a) => a.id.equals(accId))).getSingle();

    // A clean inflow, a clean outflow, and a same-day +X/-X no-op pair.
    await _seedTx(db, account: accId, amount: 1000.0, date: DateTime(2025, 1, 5), desc: 'Salary');
    await _seedTx(db, account: accId, amount: -250.0, date: DateTime(2025, 1, 10), desc: 'Rent');
    await _seedTx(db, account: accId, amount: 80.0, date: DateTime(2025, 1, 15), desc: 'Reversed charge in');
    await _seedTx(db, account: accId, amount: -80.0, date: DateTime(2025, 1, 15), desc: 'Reversed charge out');

    final ctx = tester.element(find.byType(Navigator).first);
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => AccountDetailScreen(account: account)),
    );
    await longSettle(tester);

    // (1) No-op collapsing now happens in the single-account view.
    expect(find.text('No-op'), findsOneWidget, reason: 'same-day +X/-X pair collapses into a No-op row in single view');
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);

    Future<void> openSheet() async {
      await tester.tap(find.byKey(const Key('ledgerFilterButton')));
      await longSettle(tester);
    }

    Future<void> apply() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await longSettle(tester);
    }

    // (2a) Show only Outflows → Rent visible, Salary and the no-op gone.
    await openSheet();
    await tester.tap(find.byKey(const ValueKey('kindChip_show_outflow')));
    await apply();
    expect(find.text('Rent'), findsOneWidget, reason: 'outflow row passes the Show-only Outflows filter');
    expect(find.text('Salary'), findsNothing, reason: 'inflow filtered out');
    expect(find.text('No-op'), findsNothing, reason: 'no-op filtered out');
    expect(find.text('Outflows'), findsOneWidget, reason: 'an active-filter pill summarizes the applied filter');

    // Clear via the active-filter pill → everything back.
    await tester.ensureVisible(find.byKey(const Key('clearAllPill')));
    await tester.tap(find.byKey(const Key('clearAllPill')));
    await longSettle(tester);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('No-op'), findsOneWidget);

    // (2b) Hide Outflows (negative filter) → Rent gone, Salary + No-op remain.
    await openSheet();
    await tester.tap(find.byKey(const ValueKey('kindChip_hide_outflow')));
    await apply();
    expect(find.text('Rent'), findsNothing, reason: 'outflow row hidden by the Hide-Outflows filter');
    expect(find.text('Salary'), findsOneWidget, reason: 'inflow still shown');
    expect(find.text('No-op'), findsOneWidget, reason: 'no-op still shown');
  });
}
