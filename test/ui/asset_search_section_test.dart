// Regression: the asset-search dialogs threw as soon as the search returned
// results.
//
// `AlertDialog` measures its content's INTRINSIC width. All three call sites
// (create asset, edit asset, portfolio model) passed the section inside a loose
// `ConstrainedBox(maxWidth: 400)`, so the dialog asked for intrinsics — and the
// results list is a shrink-wrapping viewport, which cannot report them without
// building every child. Every rebuild threw
// "RenderShrinkWrappingViewport does not support returning intrinsic
// dimensions".
//
// It stayed invisible because the provider's instrument search had silently
// stopped returning results, so the list branch was never rendered: users only
// ever saw the "not found" branch, which is a SingleChildScrollView and does
// support intrinsics.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/asset_search.dart';

/// Two listings for one ISIN, in the shape the instrument-search endpoint
/// returns them.
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
    {
      'id': 995447,
      'symbol': 'SWDA',
      'exchange_short_name': 'London',
      'long_name': 'iShares Core MSCI World UCITS ETF USD (Acc)',
      'country': 'United Kingdom',
      'type': 'etf',
      'link': '/etfs/ishares-msci-world---acc?cid=995447',
      'ISIN': 'IE00B4L5Y983',
    },
  ],
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The section rendered exactly as the production dialogs render it:
  /// straight into `AlertDialog.content`.
  Widget harness({required Size surface}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        marketPriceServiceProvider.overrideWith(
          (ref) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => _searchPayload()),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: surface),
          child: Consumer(
            builder: (context, ref, _) => AlertDialog(
              title: const Text('New Asset'),
              content: AssetSearchSection(
                widgetRef: ref,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> runSearch(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'SWDA');
    // The section debounces for 400ms before querying.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('rendering search results inside an AlertDialog does not throw', (tester) async {
    await tester.pumpWidget(harness(surface: const Size(1200, 900)));
    await tester.pumpAndSettle();

    await runSearch(tester);

    expect(
      tester.takeException(),
      isNull,
      reason:
          'AlertDialog measured the results list intrinsically — the section '
          'must impose a tight width so no intrinsic pass is needed',
    );
    // The results really did render (otherwise the assertion above is vacuous:
    // the empty branch is a SingleChildScrollView and never threw).
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('iShares Core MSCI World UCITS ETF USD (Acc)'), findsNWidgets(2));
    expect(find.textContaining('Milan'), findsNothing, reason: 'exchange is not part of the row text');
  });

  testWidgets('tapping a result reports the parsed listing', (tester) async {
    ProviderSearchResult? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWith(
            (ref) => WebMarketDataService(db, jsFetchOverride: (url, domainId) async => _searchPayload()),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => AlertDialog(
              content: AssetSearchSection(widgetRef: ref, onSelect: (r) => picked = r),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await runSearch(tester);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.cid, 46925);
    expect(picked!.isin, 'IE00B4L5Y983');
    expect(picked!.exchange, 'Milan');
  });

  testWidgets('narrow phone-sized dialog still lays out without overflow', (tester) async {
    // A tight 400px would overflow a 360px-wide screen once dialog insets are
    // taken off, so the section must clamp to what's available.
    await tester.pumpWidget(harness(surface: const Size(360, 720)));
    await tester.pumpAndSettle();
    await runSearch(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });
}
