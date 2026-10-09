// Privacy mode on the dashboard hides the SIZE of the position — cash, income,
// expenses, net worth, projections — never public market data or shape
// (percentages, ratings, unit prices of listed instruments).
//
// Every test asserts a masked figure AND a readable one on the same screen: a
// test that only checks "the amount is blurred" passes just as happily on a
// screen where everything is blurred, which is the other way this rule breaks.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // The bundle caches the default-charts JSON as a Future created in the
    // first test's fake-async zone; a later test awaiting that cached Future
    // never resumes, and the History tab would render no charts at all.
    rootBundle.clear();
  });
  tearDown(() => db.close());

  /// 15,000 cash; a listed fund (10 units, TER 0.20%) closing at 121 today; a
  /// manually valued house (1 unit, 250,000); a 3,000 salary every month of
  /// 2025 and of January–February 2026.
  Future<void> seed() async {
    final acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2024, 12, 1),
            valueDate: DateTime(2024, 12, 1),
            amount: 15000,
            balanceAfter: const Value(15000),
            description: const Value('Opening'),
          ),
        );
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final fund = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            ter: const Value(0.2),
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: fund,
            date: DateTime(2024, 12, 2),
            valueDate: DateTime(2024, 12, 2),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    // Today's close is below the March high: no all-time-high celebration
    // overlays the History tab.
    for (final (date, close) in [(DateTime(2024, 12, 2), 100.0), (DateTime(2026, 3, 2), 125.0), (DateTime(2026, 3, 9), 120.0), (today, 121.0)]) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: fund, date: date, closePrice: close, currency: 'EUR'));
    }
    final home = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Home'));
    final house = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'House',
            assetType: AssetType.realEstate,
            valuationMethod: ValuationMethod.eventDriven,
            intermediaryId: home,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: house,
            date: DateTime(2024, 12, 5),
            valueDate: DateTime(2024, 12, 5),
            type: EventType.buy,
            amount: 250000,
            quantity: const Value(1),
            price: const Value(250000),
          ),
        );
    await db
        .into(db.marketPrices)
        .insert(MarketPricesCompanion.insert(assetId: house, date: DateTime(2024, 12, 5), closePrice: 250000, currency: 'EUR'));
    for (final (year, months) in [(2025, 12), (2026, 2)]) {
      for (var m = 1; m <= months; m++) {
        final d = DateTime(year, m, 15);
        await db.into(db.incomes).insert(IncomesCompanion.insert(date: d, valueDate: d, amount: 3000));
      }
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The price-change rows load asynchronously after the tab opens.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> setPrivate(WidgetTester tester, bool value) async {
    container.read(privacyModeProvider.notifier).state = value;
    await settle(tester);
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Finder inDialog(Pattern text) => find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(text));

  /// Whether [text] can be selected (and so copied) out of the open dialog.
  bool selectable(String text) =>
      find.byWidgetPredicate((w) => w is SelectableText && (w.data ?? w.textSpan!.toPlainText()).contains(text)).evaluate().isNotEmpty;

  Future<void> openInfo(WidgetTester tester, String kpiName) async {
    final card = find.ancestor(of: find.text(kpiName), matching: find.byType(Card)).first;
    final info = find.descendant(of: card, matching: find.byIcon(Icons.info_outline));
    await tester.ensureVisible(info);
    await settle(tester);
    await tester.tap(info);
    await settle(tester);
  }

  Future<void> closeDialog(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, label)));
    await settle(tester);
  }

  testWidgets('KPI formula: privacy blurs the amounts plugged into it and keeps them out of the copyable text; the symbolic '
      'formula and a percentage-only formula stay readable', (tester) async {
    await seed();
    await pumpDashboard(tester);
    try {
      // Privacy off: the formula renders as before, figures included.
      await openInfo(tester, 'Net Worth Liquidity Ratio');
      expect(selectable('15,000 / '), isTrue);
      expect(masked(inDialog('15,000 / ')), isFalse);
      await closeDialog(tester, 'Close');

      await setPrivate(tester, true);

      await openInfo(tester, 'Net Worth Liquidity Ratio');
      final figures = inDialog('15,000 / ');
      expect(figures, findsOneWidget);
      expect(masked(figures), isTrue, reason: 'cash and net worth are position size');
      expect(selectable('15,000'), isFalse, reason: 'a masked amount must not be copyable out of the dialog');
      final symbolic = inDialog('Cash / Net Worth x 100');
      expect(symbolic, findsOneWidget);
      expect(masked(symbolic), isFalse, reason: 'the symbolic formula carries no figure');
      await closeDialog(tester, 'Close');

      // Savings Rate carries the end-of-year projection: every amount in it is
      // position size too (income, expenses, savings, projections) — and only
      // the amounts: the words around them stay readable.
      await openInfo(tester, 'Savings Rate');
      final projection = find.descendant(of: find.byType(AlertDialog), matching: find.text('36,000.00 €'));
      expect(projection, findsWidgets);
      expect(masked(projection.first), isTrue, reason: 'income totals and projections are position size');
      expect(masked(inDialog('the full-year total was')), isFalse, reason: 'the sentence around the amount is not');
      expect(selectable('36,000'), isFalse);
      expect(masked(inDialog('Savings / Income x 100')), isFalse);
      await closeDialog(tester, 'Close');

      // The TER formula is a percentage: shape, not magnitude.
      await openInfo(tester, 'TER');
      final ter = inDialog(RegExp(r'Weighted Avg TER\n[0-9.]+%'));
      expect(ter, findsOneWidget);
      expect(masked(ter), isFalse, reason: 'a weighted TER is a percentage, not a position figure');
      await closeDialog(tester, 'Close');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('FIRE dialog: the expense estimate, its components and the FI target are masked; the coverage stays readable', (tester) async {
    await seed();
    await pumpDashboard(tester);
    try {
      await setPrivate(tester, true);
      await openInfo(tester, 'FI Target Progress');

      Finder valueOf(Finder label) {
        final row = find.ancestor(of: label, matching: find.byType(Row)).first;
        final labelText = tester.widget<Text>(label).data!;
        return find.descendant(of: row, matching: find.byWidgetPredicate((w) => w is Text && w.data != null && w.data != labelText));
      }

      for (final label in [
        find.text('Estimated annual expenses'),
        find.textContaining('Current-year projection'),
        find.text('  Previous year'),
        find.text('FI Target'),
      ]) {
        expect(label, findsOneWidget);
        final value = valueOf(label);
        expect(value, findsOneWidget);
        expect(masked(value), isTrue, reason: '${tester.widget<Text>(label).data} is position size');
      }
      final coverage = valueOf(find.text('Target coverage'));
      expect(tester.widget<Text>(coverage).data, endsWith('%'));
      expect(masked(coverage), isFalse, reason: 'the coverage is a percentage: shape, not magnitude');
      await closeDialog(tester, 'Cancel');
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('Price Changes: a manually valued asset\'s unit price is masked, a listed fund\'s price stays readable', (tester) async {
    await seed();
    await pumpDashboard(tester);
    try {
      await tester.tap(find.widgetWithText(Tab, 'History'));
      await settle(tester);
      final card = find.ancestor(of: find.text('Price Changes'), matching: find.byType(Card));
      Finder inCard(String text) => find.descendant(of: card, matching: find.text(text));

      await pumpUntilFound(tester, inCard('250,000.00'));
      expect(inCard('250,000.00'), findsOneWidget);
      expect(masked(inCard('250,000.00')), isFalse, reason: 'nothing is masked before privacy is on');

      await setPrivate(tester, true);
      expect(masked(inCard('250,000.00')), isTrue, reason: 'one unit of a manually valued house: its "price" is the position value');
      expect(masked(inCard('121.00')), isFalse, reason: 'a listed price is public market data');
      expect(masked(inCard('+0.83%')), isFalse, reason: 'a price change is a percentage');
    } finally {
      await unmount(tester);
    }
  });
}
