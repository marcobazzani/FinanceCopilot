// Empty states: every list screen shows the same icon + tagline (+ optional
// action) layout when it has nothing to list. These pin what each screen shows
// and what its action does, so moving them onto the shared EmptyState widget
// cannot change either.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/accounts_screen.dart';
import 'package:finance_copilot/ui/screens/accounts/capex_screen.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/pillars_screen.dart';
import 'package:finance_copilot/ui/widgets/empty_state.dart';

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

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, {Size size = const Size(1200, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          marketPriceServiceProvider.overrideWith((ref) => _OfflineMarketPriceService(db)),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The tagline sits right under the icon, in the same centred column.
  void expectIconAboveTagline(WidgetTester tester, IconData icon, String tagline) {
    final iconFinder = find.byIcon(icon);
    final taglineFinder = find.text(tagline);
    expect(iconFinder, findsOneWidget);
    expect(taglineFinder, findsOneWidget);
    expect(tester.getCenter(iconFinder).dy, lessThan(tester.getCenter(taglineFinder).dy));
    expect(tester.getCenter(iconFinder).dx, moreOrLessEquals(tester.getCenter(taglineFinder).dx, epsilon: 1));
    expect(tester.widget<Icon>(iconFinder).size, 48);
    expect(tester.widget<Text>(taglineFinder).textAlign, TextAlign.center);
  }

  testWidgets('EmptyState: the action button appears only with both a label and a callback', (tester) async {
    var taps = 0;
    Future<void> pump(Widget w) => tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));

    await pump(const EmptyState(icon: Icons.inbox, message: 'Nothing here'));
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await pump(const EmptyState(icon: Icons.inbox, message: 'Nothing here', actionLabel: 'Add'));
    expect(find.byType(FilledButton), findsNothing, reason: 'a label without a callback would render a dead button');

    await pump(EmptyState(icon: Icons.inbox, message: 'Nothing here', actionLabel: 'Add', onAction: () => taps++));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    expect(taps, 1);
  });

  testWidgets('accounts: icon, tagline and a New Account action that opens the create dialog', (tester) async {
    await pumpScreen(tester, const AccountsScreen());
    try {
      expectIconAboveTagline(tester, Icons.account_balance, s.noAccountsYet);
      final action = find.widgetWithText(FilledButton, s.newAccountTitle);
      expect(action, findsOneWidget);
      expect(find.descendant(of: action, matching: find.byIcon(Icons.add)), findsOneWidget);

      await tester.tap(action);
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, s.newAccountTitle), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('accounts: no empty state once an intermediary exists', (tester) async {
    await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    await pumpScreen(tester, const AccountsScreen());
    try {
      expect(find.text(s.noAccountsYet), findsNothing);
      expect(find.text(s.allAccounts), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('assets: icon, tagline and a Create Asset action that opens the create dialog', (tester) async {
    await pumpScreen(tester, const AssetsScreen());
    try {
      expectIconAboveTagline(tester, Icons.pie_chart, s.noAssetsYet);
      final action = find.widgetWithText(FilledButton, s.createAsset);
      expect(action, findsOneWidget);
      expect(find.descendant(of: action, matching: find.byIcon(Icons.add)), findsOneWidget);

      await tester.tap(action);
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(s.createAssetTitle), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('adjustments: icon and tagline under the info box, no action button', (tester) async {
    await pumpScreen(tester, const AdjustmentsView());
    try {
      expectIconAboveTagline(tester, Icons.event_note, s.noEventsYet);
      expect(tester.getCenter(find.text(s.adjustmentsInfoTitle)).dy, lessThan(tester.getCenter(find.byIcon(Icons.event_note)).dy));
      expect(find.byType(FilledButton), findsNothing);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pillars: icon, tagline and a create action for the pillar kind of each tab', (tester) async {
    // Wide enough for the create dialog's portfolio-model labels in the test font.
    await pumpScreen(tester, const PillarsScreen(), size: const Size(2400, 1200));
    try {
      expectIconAboveTagline(tester, Icons.view_quilt_outlined, s.pillarsEmptyTitle);
      final action = find.widgetWithText(FilledButton, s.pillarsEmptyCta);
      expect(action, findsOneWidget);
      expect(find.descendant(of: action, matching: find.byIcon(Icons.add)), findsOneWidget);
      await tester.tap(action);
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, s.pillarCreateTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      await settle(tester);

      await tester.tap(find.widgetWithText(Tab, s.pillarTabVirtualPortfolios));
      await settle(tester);
      expectIconAboveTagline(tester, Icons.folder_special_outlined, s.virtualPortfoliosEmptyTitle);
      await tester.tap(find.widgetWithText(FilledButton, s.virtualPortfoliosEmptyCta));
      await settle(tester);
      expect(find.widgetWithText(AlertDialog, s.virtualPortfolioCreateTitle), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
