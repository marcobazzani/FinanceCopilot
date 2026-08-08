// `_fetchFundFromProvider` used to carry a SECOND, hand-rolled copy of the
// provider search: a plain Dio GET against `api/search/v2/search`, reading a
// `quotes` array. That endpoint is dead (200 with an empty payload, see #97) and
// the plain client carries no Cloudflare cookies, so it 403'd on every app start
// and logged a warning for every fund the user holds.
//
// It now delegates to the single search implementation. These tests pin that
// delegation, so a future endpoint move can't leave a second copy behind.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

void main() {
  late AppDatabase db;
  late int intermediaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    intermediaryId = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Allianz'));
  });
  tearDown(() => db.close());

  /// A fund, i.e. the `0P...` identifier shape that routes to the provider
  /// fund path rather than the ETF/stock sources.
  Future<Asset> fundAsset() async {
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Allianz Insieme - Linea Azionaria',
            assetType: AssetType.stockEtf,
            instrumentType: const Value(InstrumentType.fund),
            valuationMethod: ValuationMethod.marketPrice,
            isin: const Value('0P0000CWZR'),
            intermediaryId: intermediaryId,
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  test('fund composition goes through the shared search, not a private call', () async {
    await fundAsset();
    final searched = <String>[];
    final provider = WebMarketDataService(
      db,
      jsFetchOverride: (url, domainId) async {
        searched.add(url);
        return {
          'instruments': [
            {
              'id': 1078584,
              'symbol': '0P0000CWZR',
              'exchange_short_name': 'Milan',
              'long_name': 'Allianz Insieme - Linea Azionaria',
              'type': 'fund',
              'link': '/funds/allianz-insieme-azionaria?cid=1078584',
            },
          ],
        };
      },
      // No page ever resolves in this test; we only care about which endpoint
      // the search step hits.
      pageFetcher: (uri) async => null,
    );

    final service = CompositionService(db, providerService: provider);
    await service.syncCompositions();

    expect(searched, isNotEmpty, reason: 'the shared search must have been used');
    expect(
      searched.every((u) => u.contains(kProviderSearchHost)),
      isTrue,
      reason: 'fund lookup must use the live instrument-search host, got $searched',
    );
    expect(
      searched.any((u) => u.contains('/api/search/v2/search')),
      isFalse,
      reason: 'the dead legacy endpoint must not be called again',
    );
  });

  test('a fund with no search hit is skipped quietly, leaving no composition', () async {
    final provider = WebMarketDataService(
      db,
      jsFetchOverride: (url, domainId) async => {'instruments': const []},
      pageFetcher: (uri) async => null,
    );
    final asset = await fundAsset();

    await CompositionService(db, providerService: provider).syncCompositions();

    // No composition invented for an unresolvable fund.
    final rows = await (db.select(db.assetCompositions)..where((c) => c.assetId.equals(asset.id))).get();
    expect(rows, isEmpty);
  });

  test('without a provider service the fund path is a no-op rather than a crash', () async {
    await fundAsset();
    // providerService omitted: previously this path still fired a raw Dio
    // request; now it must simply do nothing.
    await CompositionService(db).syncCompositions();
    expect(await db.select(db.assetCompositions).get(), isEmpty);
  });
}
