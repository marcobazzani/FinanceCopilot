// The intermediary UI the Accounts and Assets lists share: the group header
// ("<name> (<count>)", business icon; accounts also have an Unassigned group)
// and the row's "move to intermediary" menu (the intermediaries, the current
// one checked, plus Unassigned for an account). Pinned on both screens before
// they were made one widget each.
//
// Pinned bug: picking Unassigned in an account's menu did nothing — the menu
// reported it as a null value, which a popup menu treats as "dismissed".
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
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late int broker;
  late int other;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker', sortOrder: const Value(0)));
    other = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other broker', sortOrder: const Value(1)));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seedAccount(String name, int? intermediary) =>
      db.into(db.accounts).insert(AccountsCompanion.insert(name: name, intermediaryId: Value(intermediary)));

  Future<int> seedAsset(String name, int intermediary) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.marketPrice,
          intermediaryId: intermediary,
        ),
      );

  /// A group header: its icon left of its "<name> (<count>)" title, in the
  /// muted w600 titleSmall.
  void expectHeader(WidgetTester tester, String title, IconData icon) {
    final text = find.text(title);
    expect(text, findsOneWidget, reason: title);
    final row = find.ancestor(of: text, matching: find.byType(Row)).first;
    final iconFinder = find.descendant(of: row, matching: find.byIcon(icon));
    expect(iconFinder, findsOneWidget, reason: '$title: icon');
    expect(tester.widget<Icon>(iconFinder).size, 18);
    expect(tester.widget<Icon>(iconFinder).color, Colors.grey);
    final theme = Theme.of(tester.element(text));
    final style = tester.widget<Text>(text).style;
    expect(style?.fontWeight, FontWeight.w600);
    expect(style?.color, theme.colorScheme.onSurfaceVariant);
    expect(style?.fontSize, theme.textTheme.titleSmall?.fontSize);
  }

  /// Opens the move menu of the row showing [rowText].
  Future<void> openMoveMenu(WidgetTester tester, String rowText) async {
    final row = find.ancestor(of: find.text(rowText), matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip(s.selectIntermediary)));
    await settle(tester);
  }

  Finder menuItem(String label) => find.ancestor(of: find.text(label).last, matching: find.byWidgetPredicate((w) => w is PopupMenuItem));

  bool checked(String label) => find.descendant(of: menuItem(label), matching: find.byIcon(Icons.check)).evaluate().isNotEmpty;

  group('accounts', () {
    testWidgets('pin: a header per intermediary, then Unassigned', (tester) async {
      await seedAccount('Main', broker);
      await seedAccount('Loose', null);
      await pump(tester, const AccountsScreen());
      try {
        expectHeader(tester, 'Broker (1)', Icons.business);
        expectHeader(tester, '${s.unassigned} (1)', Icons.folder_open);
        expect(find.text('Other broker (0)'), findsNothing, reason: 'an empty group is not listed');
        expect(tester.getTopLeft(find.text('Broker (1)')).dy, lessThan(tester.getTopLeft(find.text('${s.unassigned} (1)')).dy));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('pin: the move menu lists the intermediaries and Unassigned, checks the current one, and moves', (tester) async {
      final main = await seedAccount('Main', broker);
      await pump(tester, const AccountsScreen());
      try {
        await openMoveMenu(tester, 'Main');
        final header = find.ancestor(of: find.text(s.selectIntermediary).last, matching: find.byWidgetPredicate((w) => w is PopupMenuItem));
        expect((tester.widget(header) as PopupMenuItem).enabled, isFalse, reason: 'the header is not a choice');
        expect(checked('Broker'), isTrue);
        expect(checked('Other broker'), isFalse);
        expect(checked(s.unassigned), isFalse);

        await tester.tap(find.text('Other broker').last);
        await settle(tester);
        expect((await (db.select(db.accounts)..where((a) => a.id.equals(main))).getSingle()).intermediaryId, other);
        expect(find.text('Other broker (1)'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('picking Unassigned moves the account out of its intermediary', (tester) async {
      final main = await seedAccount('Main', broker);
      await pump(tester, const AccountsScreen());
      try {
        await openMoveMenu(tester, 'Main');
        await tester.tap(find.text(s.unassigned).last);
        await settle(tester);
        expect((await (db.select(db.accounts)..where((a) => a.id.equals(main))).getSingle()).intermediaryId, isNull);
        expect(find.text('${s.unassigned} (1)'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('assets', () {
    testWidgets('pin: a header per intermediary holding assets', (tester) async {
      await seedAsset('World ETF', broker);
      await pump(tester, const AssetsScreen());
      try {
        expectHeader(tester, 'Broker (1)', Icons.business);
        expect(find.textContaining('Other broker'), findsNothing);
        expect(find.textContaining(s.unassigned), findsNothing, reason: 'every asset has an intermediary');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('pin: the move menu lists the intermediaries, no Unassigned, checks the current one, and moves', (tester) async {
      final asset = await seedAsset('World ETF', broker);
      await pump(tester, const AssetsScreen());
      try {
        await openMoveMenu(tester, 'World ETF');
        expect(find.text(s.selectIntermediary), findsWidgets);
        expect(checked('Broker'), isTrue);
        expect(checked('Other broker'), isFalse);
        expect(find.text(s.unassigned), findsNothing);

        await tester.tap(find.text('Other broker').last);
        await settle(tester);
        expect((await (db.select(db.assets)..where((a) => a.id.equals(asset))).getSingle()).intermediaryId, other);
        expect(find.text('Other broker (1)'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });
}
