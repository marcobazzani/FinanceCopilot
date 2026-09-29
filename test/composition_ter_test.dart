// The TER of an asset comes from three places in the composition sync: the
// ETF profile page (full sync), the same page when only the TER is missing
// (TER-only sync), and the provider's fund page. Pins what each stores, that
// the full syncs leave an unchanged TER alone, and that the TER-only sync no
// longer asks the legacy search endpoint (dead: it answers an empty list, or a
// 403 to a client without the provider's cookies).
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';

/// Counts the statements that write an asset's TER.
class _TerWrites extends QueryInterceptor {
  int count = 0;

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) {
    if (statement.startsWith('UPDATE "assets"') && statement.contains('"ter"')) count++;
    return super.runUpdate(executor, statement, args);
  }
}

/// Serves the page [route] finds for a URL (none is a 404) and records every
/// request.
class _Pages implements HttpClientAdapter {
  _Pages(this.route);

  final String? Function(Uri) route;
  final requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri);
    final page = route(options.uri);
    return page == null
        ? ResponseBody.fromString('', 404)
        : ResponseBody.fromString(
            page,
            200,
            headers: {
              Headers.contentTypeHeader: ['text/html'],
            },
          );
  }

  @override
  void close({bool force = false}) {}
}

const _isin = 'IE00B4L5Y983';

bool _isProfile(Uri uri) => uri.path.endsWith('/etf-profile.html') && uri.queryParameters['isin'] == _isin;

/// The ETF profile page of [_isin], and nothing else.
_Pages _profilePages(String page) => _Pages((uri) => _isProfile(uri) ? page : null);

String _profile({String? ter}) =>
    '<html><body><table data-testid="etf-basics_data_table">'
    '<tr><td>Investment focus</td><td data-testid="tl_etf-basics_value_investment-focus">Equity, World</td></tr>'
    '${ter == null ? '' : '<tr><td>TER</td><td data-testid="tl_etf-basics_value_ter">$ter p.a.</td></tr>'}'
    '</table></body></html>';

void main() {
  late AppDatabase db;
  late _TerWrites terWrites;
  late int broker;

  setUp(() async {
    terWrites = _TerWrites();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(terWrites));
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<int> insertAsset({required String isin, double? ter, InstrumentType type = InstrumentType.etf}) => db
      .into(db.assets)
      .insert(
        AssetsCompanion.insert(
          name: 'World',
          assetType: AssetType.stockEtf,
          instrumentType: Value(type),
          assetClass: const Value(AssetClass.equity),
          valuationMethod: ValuationMethod.marketPrice,
          isin: Value(isin),
          ter: Value(ter),
          intermediaryId: broker,
        ),
      );

  Future<double?> terOf(int id) async => (await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle()).ter;

  Future<void> sync(_Pages pages, {WebMarketDataService? provider}) async {
    final service = CompositionService(db, dio: Dio()..httpClientAdapter = pages, providerService: provider);
    await service.syncCompositions();
  }

  group('full sync, ETF profile', () {
    test('stores the TER, reading a decimal comma', () async {
      final id = await insertAsset(isin: _isin);
      await sync(_profilePages(_profile(ter: '0,22%')));
      expect(await terOf(id), 0.22);
    });

    test('an unchanged TER is not written again', () async {
      final id = await insertAsset(isin: _isin, ter: 0.22);
      terWrites.count = 0;
      await sync(_profilePages(_profile(ter: '0.22%')));
      expect(await terOf(id), 0.22);
      expect(terWrites.count, 0);
    });

    test('a page without a TER leaves it unknown', () async {
      final id = await insertAsset(isin: _isin);
      await sync(_profilePages(_profile()));
      expect(await terOf(id), isNull);
    });
  });

  group('TER-only sync (composition already stored)', () {
    Future<int> assetWithComposition() async {
      final id = await insertAsset(isin: _isin);
      await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'World', weight: 100));
      return id;
    }

    test('stores the TER from the ETF profile', () async {
      final id = await assetWithComposition();
      final pages = _profilePages(_profile(ter: '0.07%'));
      await sync(pages);
      expect(await terOf(id), 0.07);
      expect(pages.requested.map(_isProfile), [true]);
    });

    test('a TER the ETF profile does not carry is not looked up through the legacy search endpoint', () async {
      final id = await assetWithComposition();
      final pages = _profilePages(_profile());
      await sync(pages);
      expect(await terOf(id), isNull);
      expect(pages.requested.map(_isProfile), [true], reason: 'got ${pages.requested}');
    });
  });

  group('full sync, fund page', () {
    const fundPage = '$kProviderBase/funds/world-fund';
    const expenses =
        '<html><body><span class="float_lang_base_1">Expenses</span><span class="float_lang_base_2 bold">0.84%</span></body></html>';

    WebMarketDataService provider() => WebMarketDataService(
      db,
      solveHeadless: () async => false,
      jsFetchOverride: (url, domainId) async => {
        'instruments': [
          {
            'id': 1078584,
            'symbol': '0P0000CWZR',
            'exchange_short_name': 'Milan',
            'long_name': 'World Fund',
            'type': 'fund',
            'link': '/funds/world-fund?cid=1078584',
          },
        ],
      },
    );

    test('stores the TER from the expenses line', () async {
      final id = await insertAsset(isin: '0P0000CWZR', type: InstrumentType.fund);
      await sync(_Pages((uri) => uri.toString() == fundPage ? expenses : null), provider: provider());
      expect(await terOf(id), 0.84);
    });

    test('an unchanged TER is not written again', () async {
      final id = await insertAsset(isin: '0P0000CWZR', ter: 0.84, type: InstrumentType.fund);
      terWrites.count = 0;
      await sync(_Pages((uri) => uri.toString() == fundPage ? expenses : null), provider: provider());
      expect(await terOf(id), 0.84);
      expect(terWrites.count, 0);
    });
  });
}
