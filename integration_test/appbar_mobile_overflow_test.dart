/// Focused check: on a phone-width layout the account-detail AppBar's
/// screen-local actions collapse into the overflow menu, and the
/// overflow-aware [tapAppBarAction] helper can still reach "Add Transaction".
///
/// Reproduces the Android (phone) layout on the desktop test host by forcing a
/// narrow view, so the overflow path is exercised without an emulator.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone width: Add Transaction reachable via the account-detail overflow', (tester) async {
    // ~400 x 800 logical px → mobile layout (< 600).
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = await pumpApp(tester);
    await longSettle(tester);

    final accId = await seedAccount(db, name: 'Revolut');
    // Seed transactions so the detail renders rows — each row has its own
    // PopupMenuButton (default Icons.more_vert), which must NOT be mistaken for
    // the AppBar overflow when tapping a screen-local action.
    for (var i = 0; i < 5; i++) {
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: accId,
              operationDate: DateTime(2025, 6, i + 1),
              valueDate: DateTime(2025, 6, i + 1),
              amount: -10.0 - i,
            ),
          );
    }
    final acc = await (db.select(db.accounts)..where((a) => a.id.equals(accId))).getSingle();

    final ctx = tester.element(find.byType(Navigator).first);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => AccountDetailScreen(account: acc)));
    await longSettle(tester);

    // On a phone this must open the overflow and tap the entry.
    await tapAppBarAction(tester, AppStrings.en.tooltipAddTransaction);
    await longSettle(tester);

    // TransactionEditScreen opens with its form fields.
    expect(find.byType(TextFormField), findsWidgets);
  });
}
