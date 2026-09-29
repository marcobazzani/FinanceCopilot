// Regression: the asset search cast the market price service to the web
// provider (`as WebMarketDataService`) inside its debounce timer, before the
// try block. With any other price service — every provider override, an
// offline service — the cast threw an uncaught error from the timer and the
// spinner never stopped. A service without instrument search now simply
// yields no results.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/asset_search.dart';

/// A price service with no instrument search (not the web provider).
class _OfflinePriceService extends MarketPriceService {
  _OfflinePriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('a price service without instrument search ends the search with no results', (tester) async {
    final reported = <List<ProviderSearchResult>>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflinePriceService(db)),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => AlertDialog(
              content: AssetSearchSection(widgetRef: ref, onSelect: (_) {}, onResultsChanged: reported.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'SWDA');
    // The section debounces for 400ms before querying.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the spinner must stop');
    expect(find.text(AppStrings.of('en').noResultsFound), findsOneWidget);
    expect(reported, [isEmpty]);
  });
}
