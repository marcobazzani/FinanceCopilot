// Live contract test for the provider's instrument-search endpoint.
//
// This is the check that was MISSING when the provider moved instrument search
// to a new host: the legacy endpoint kept answering 200 with a permanently
// empty `quotes` array, so `search()` returned zero results for every query
// without raising anything. New assets could not be created and imports could
// not resolve a name or cid; assets already carrying a cached cid kept pricing
// normally, which hid the regression until a user reported "Instrument not
// found" for a mainstream ETF.
//
// The offline parsing contract lives in test/market_instrument_search_test.dart
// and runs on every job. THIS test is the one that fails when the upstream
// endpoint moves or changes shape again, so it must keep hitting the network.
//
// It deliberately asserts on stable, high-liquidity instruments and only on
// invariants the app depends on (cid, symbol, exchange, ISIN) — never on
// prices, which move.

@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/main.dart';
import 'package:finance_copilot/services/market/isin_lookup_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('provider instrument search still resolves ISINs and tickers', (tester) async {
    await pumpApp(tester, useRealServices: true);
    final container = ProviderScope.containerOf(tester.element(find.byType(FinanceCopilotApp)));
    final provider = container.read(marketPriceServiceProvider) as WebMarketDataService;

    // A mainstream ETF (the one from the original report), an Italian
    // government bond and a stock — three different instrument classes, since
    // the payload's field set varies by class.
    const swdaIsin = 'IE00B4L5Y983';
    const btpIsin = 'IT0005340929';

    late List<ProviderSearchResult> byIsin;
    late List<ProviderSearchResult> byTicker;
    late List<ProviderSearchResult> bond;
    late IsinLookupResult lookup;
    await tester.runAsync(() async {
      byIsin = await provider.search(swdaIsin);
      byTicker = await provider.search('SWDA');
      bond = await provider.search(btpIsin);
      lookup = await IsinLookupService(provider).lookup(swdaIsin);
    });

    // ── The core invariant: a known ISIN must produce listings ──────────────
    expect(
      byIsin,
      isNotEmpty,
      reason:
          'searching a mainstream ETF ISIN returned nothing — the provider '
          'search endpoint has very likely moved or changed shape again. '
          'Check ${WebMarketDataService.searchUrlFor(swdaIsin)}',
    );
    expect(byTicker, isNotEmpty, reason: 'ticker search returned nothing for SWDA');
    expect(bond, isNotEmpty, reason: 'ISIN search returned nothing for an Italian government bond');

    // ── The fields the app actually consumes ───────────────────────────────
    final milan = byIsin.where((r) => r.exchange.toLowerCase().contains('milan')).firstOrNull;
    expect(milan, isNotNull, reason: 'SWDA should be listed on Milan; got exchanges ${byIsin.map((r) => r.exchange).toList()}');
    // cid drives every price fetch; it has been stable for years.
    expect(milan!.cid, 46925, reason: 'SWDA Milan cid changed — verify before updating this expectation');
    expect(milan.symbol, 'SWDA');
    expect(milan.description, isNotEmpty, reason: 'name is used verbatim as the asset name');
    expect(milan.url, isNotNull, reason: 'instrument URL is cached and reused for page scraping');

    // The endpoint returns the ISIN inline, which lets resolveListingsByIsin
    // verify a listing without fetching the instrument page. If this ever
    // stops arriving the app still works, but every lookup gets slower — so
    // assert it to make the regression visible.
    expect(milan.isin, swdaIsin, reason: 'search hits should carry their ISIN inline');

    // Every returned listing must be for the ISIN we asked for.
    for (final r in byIsin.where((r) => r.isin != null)) {
      expect(r.isin, swdaIsin, reason: 'ISIN query returned a listing for a different instrument');
    }

    // ── And the layer the New Asset dialog / import actually call ───────────
    expect(
      lookup.options,
      isNotEmpty,
      reason:
          'IsinLookupService found no listings — this is exactly what the '
          '"Instrument not found" report looked like',
    );
    expect(lookup.bestFor('Milan')?.cid, 46925);
    // Stocks come back as plural title-case `Equities`; ETFs as `etf`. Only
    // check that classification does not silently collapse to the fallback.
    expect(lookup.options.first.classification.$1.name, 'etf');
  });
}
