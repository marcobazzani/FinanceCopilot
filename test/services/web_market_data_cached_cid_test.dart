// A resolved instrument id is cached per (search term, exchange); later price
// fetches must reuse it instead of repeating the search round-trip.
//
// The cache hit was reached only by the live-data integration walkthrough,
// and only when an earlier step of that run had already resolved (and so
// cached) the same instrument — which depended on the provider's answers.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            ticker: const Value('SWDA'),
            exchange: const Value('Milan'),
            intermediaryId: intermediaryId,
          ),
        );
  });
  tearDown(() => db.close());

  test('a cached instrument id is reused: prices are fetched without searching again', () async {
    await db.into(db.appConfigs).insert(AppConfigsCompanion.insert(key: 'PROVIDER_CID_SWDA_Milan', value: '4242'));
    final requested = <String>[];
    final svc = WebMarketDataService(
      db,
      jsFetchOverride: (url, domainId) async {
        requested.add(url);
        return {
          'data': [
            {'rowDateTimestamp': '2026-03-09T00:00:00Z', 'last_closeRaw': 101.5},
            {'rowDateTimestamp': '2026-03-10T00:00:00Z', 'last_closeRaw': '102.25'},
          ],
        };
      },
    );

    final prices = await svc.fetchHistoricalPrices('SWDA', 'EUR', DateTime(2026, 3, 1));

    expect(requested, hasLength(1), reason: 'one history request, no search');
    expect(requested.single, contains('/historical/4242?'));
    expect(prices, {DateTime(2026, 3, 9): 101.5, DateTime(2026, 3, 10): 102.25});
  });
}
