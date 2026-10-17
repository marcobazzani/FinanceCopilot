// Every row of a ledger starts with its icon in the same place, and its title
// after it in the same place: a category's badge (tappable or not), a row's
// in/out arrow, a transfer or no-op pair, a "Saving for" row. A list tile
// starts its title right after its leading widget, so a wider tap target on
// the category badges used to push their icons and titles off the others.
import 'package:drift/drift.dart' hide isNotNull, isNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/category_service.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/account_detail_screen.dart';
import 'package:finance_copilot/ui/widgets/category_ui.dart';

void main() {
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

  Future<void> tx(int account, String desc, double amount, DateTime day, {int? categoryId, TransactionStatus? status}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          accountId: account,
          operationDate: day,
          valueDate: day,
          amount: amount,
          description: Value(desc),
          categoryId: Value(categoryId),
          status: status == null ? const Value.absent() : Value(status),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpLedger(WidgetTester tester, Account account) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: AccountDetailScreen(account: account)),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<Account> account(int id) => (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  /// The row titled [title], its leading [icon] and where they are drawn.
  ({double iconCenter, double titleStart}) layoutOf(WidgetTester tester, String title, IconData icon) {
    final row = find.ancestor(of: find.text(title), matching: find.byType(ListTile)).first;
    final glyph = find.descendant(of: row, matching: find.byIcon(icon));
    expect(glyph, findsOneWidget, reason: '$title starts with ${icon.codePoint}');
    return (iconCenter: tester.getCenter(glyph).dx, titleStart: tester.getTopLeft(find.text(title)).dx);
  }

  void expectAligned(WidgetTester tester, Map<String, IconData> rows) {
    final layouts = {for (final e in rows.entries) e.key: layoutOf(tester, e.key, e.value)};
    final first = layouts.values.first;
    for (final e in layouts.entries) {
      expect(e.value.iconCenter, closeTo(first.iconCenter, 0.01), reason: '${e.key}: its icon');
      expect(e.value.titleStart, closeTo(first.titleStart, 0.01), reason: '${e.key}: its title');
    }
  }

  testWidgets('an account: category badges, the uncategorized one, arrows and a no-op pair line up', (tester) async {
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    await tx(main, 'Mystery shop', -7, DateTime(2026, 1, 11));
    await tx(main, 'To savings', -100, DateTime(2026, 1, 15));
    await tx(savings, 'From main', 100, DateTime(2026, 1, 15));
    await tx(main, 'Charge in', 80, DateTime(2026, 1, 18));
    await tx(main, 'Charge out', -80, DateTime(2026, 1, 18));
    await tx(main, 'Failed card', -9, DateTime(2026, 1, 20), status: TransactionStatus.cancelled);
    await pumpLedger(tester, await account(main));
    try {
      expectAligned(tester, {
        'Coop': Icons.shopping_cart_outlined,
        'Mystery shop': Icons.help_outline,
        'To savings': Icons.arrow_upward,
        'No-op': Icons.sync_alt,
        'Failed card': Icons.arrow_upward,
      });
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('all accounts: a transfer pair and a "Saving for" row line up with the category badges', (tester) async {
    await tx(main, 'Coop', -12.5, DateTime(2026, 1, 10), categoryId: groceries);
    await tx(main, 'To savings', -100, DateTime(2026, 1, 15));
    await tx(savings, 'From main', 100, DateTime(2026, 1, 15));
    await ExtraordinaryEventService(db).create(
      name: 'Car',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 1200,
      currency: 'EUR',
      eventDate: DateTime(2026, 2, 1),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2026, 1, 1),
      spreadEnd: DateTime(2026, 1, 1),
    );
    await pumpLedger(tester, buildAllAccountsVirtual('All accounts'));
    try {
      expectAligned(tester, {
        'Coop': Icons.shopping_cart_outlined,
        'Transfer': Icons.swap_horiz,
        'Saving for Car': Icons.savings_outlined,
      });
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a category badge takes the same room whether it can be tapped or not', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryAvatar(key: const Key('tappable'), category: null, onTap: () {}, tooltip: 'Classify'),
              const CategoryAvatar(key: Key('plain'), category: null),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('tappable'))), tester.getSize(find.byKey(const Key('plain'))));
    final icons = find.byIcon(Icons.help_outline);
    expect(tester.getCenter(icons.at(0)).dx, closeTo(tester.getCenter(icons.at(1)).dx, 0.01));
  });
}
