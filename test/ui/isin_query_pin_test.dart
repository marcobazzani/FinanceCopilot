// How the asset dialogs read an ISIN typed into the instrument search (Create
// Asset, and a portfolio model row's search):
//  * when nothing is found, the page-address recovery keys what it resolves by
//    the ISIN upper-cased, and by anything else exactly as typed;
//  * an ISIN-shaped query is the ISIN the created asset / model row gets.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';
import 'package:finance_copilot/ui/widgets/isin_url_paste_recovery.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

/// One listing, in the shape the instrument-search endpoint returns it.
Map<String, dynamic> _searchPayload() => {
  'instruments': [
    {
      'id': 46925,
      'symbol': 'SWDA',
      'display_symbol': 'SWDA',
      'exchange_short_name': 'Milan',
      'long_name': 'iShares Core MSCI World UCITS ETF USD (Acc)',
      'short_name': 'iShares Core MSCI World UCITS',
      'country': 'Italy',
      'type': 'etf',
      'link': '/etfs/ishares-msci-world---acc?cid=46925',
      'ISIN': 'IE00B4L5Y983',
    },
  ],
};

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  MarketPriceService offline(AppDatabase db) => _OfflineMarketPriceService(db);
  MarketPriceService web(AppDatabase db) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => _searchPayload());

  Future<void> pump(WidgetTester tester, Widget home, MarketPriceService Function(AppDatabase) market) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(market(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
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

  /// The search field of the (topmost) search dialog.
  Finder searchField() => find.descendant(of: find.byType(AlertDialog).last, matching: find.byType(TextField)).first;

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(searchField(), query);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  String recoveryKey(WidgetTester tester) => tester.widget<IsinUrlPasteRecovery>(find.byType(IsinUrlPasteRecovery)).cacheKey;

  Future<void> expectRecoveryKeys(WidgetTester tester) async {
    await search(tester, 'ie00b4l5y983');
    expect(recoveryKey(tester), 'IE00B4L5Y983');
    await search(tester, 'IE00B4L5Y983');
    expect(recoveryKey(tester), 'IE00B4L5Y983');
    await search(tester, 'vwce');
    expect(recoveryKey(tester), 'vwce');
    await search(tester, 'ie00b4l5y98x');
    expect(recoveryKey(tester), 'ie00b4l5y98x', reason: 'no check digit: not an ISIN');
  }

  group('Create Asset', () {
    Future<void> openCreateDialog(WidgetTester tester) async {
      final fab = find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add_asset');
      await tester.tap(fab.evaluate().isNotEmpty ? fab : find.text('Create Asset'));
      await settle(tester);
      expect(find.text('New Asset'), findsOneWidget);
    }

    testWidgets('the recovery key of a query that found nothing', (tester) async {
      await pump(tester, const AssetsScreen(), offline);
      try {
        await openCreateDialog(tester);
        await expectRecoveryKeys(tester);
      } finally {
        await unmount(tester);
      }
    });

    Future<String?> createdIsin(WidgetTester tester, String query) async {
      await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      await pump(tester, const AssetsScreen(), web);
      await openCreateDialog(tester);
      await search(tester, query);
      await tester.tap(find.text('iShares Core MSCI World UCITS ETF USD (Acc)'));
      await settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await settle(tester);
      await tester.tap(find.text('Broker').last);
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Create')));
      await settle(tester);
      return (await db.select(db.assets).get()).single.isin;
    }

    testWidgets('an ISIN typed as the query is the created asset\'s ISIN', (tester) async {
      try {
        expect(await createdIsin(tester, 'lu1234567890'), 'LU1234567890');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a ticker typed as the query gives the asset no ISIN', (tester) async {
      try {
        expect(await createdIsin(tester, 'SWDA'), isNull);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('portfolio model row search', () {
    Future<void> openRowSearch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      expect(find.text('Search Asset'), findsOneWidget);
    }

    testWidgets('the recovery key of a query that found nothing', (tester) async {
      await pump(tester, const Scaffold(body: PortfolioModelDialog()), offline);
      try {
        await openRowSearch(tester);
        await expectRecoveryKeys(tester);
      } finally {
        await unmount(tester);
      }
    });

    Future<String> rowIsin(WidgetTester tester, String query) async {
      await pump(tester, const Scaffold(body: PortfolioModelDialog()), web);
      await openRowSearch(tester);
      await search(tester, query);
      await tester.tap(find.text('iShares Core MSCI World UCITS ETF USD (Acc)'));
      await settle(tester);
      return tester.widget<TextField>(find.widgetWithText(TextField, 'ISIN')).controller!.text;
    }

    testWidgets('an ISIN typed as the query is the row\'s ISIN', (tester) async {
      try {
        expect(await rowIsin(tester, 'lu1234567890'), 'LU1234567890');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a ticker typed as the query takes the listing\'s ISIN', (tester) async {
      try {
        expect(await rowIsin(tester, 'SWDA'), 'IE00B4L5Y983');
      } finally {
        await unmount(tester);
      }
    });
  });
}
