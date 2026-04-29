import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/investing_page_parser.dart';

void main() {
  group('parseInvestingPage', () {
    test('extracts pair_id, name, symbol and exchange from bond page', () {
      final html = File('test/fixtures/instrument_page_be0000351602.html').readAsStringSync();
      final result = parseInvestingPage(
        html,
        Uri.parse('https://www.investing.com/rates-bonds/be0000351602'),
      );

      expect(result, isNotNull);
      expect(result!.cid, 1181400);
      expect(result.description, 'Belgium 0 22-Oct-2027');
      expect(result.symbol, 'BE000035160=MI');
      expect(result.exchange, 'Milan');
      expect(result.flag, 'IT');
      expect(result.type.toLowerCase(), contains('bond'));
      expect(result.url, '/rates-bonds/be0000351602');
    });

    test('extracts ETF pair_id and metadata', () {
      final html = File('test/fixtures/instrument_page_ivv_etf.html').readAsStringSync();
      final result = parseInvestingPage(
        html,
        Uri.parse('https://www.investing.com/etfs/ishares-core-s-p-500'),
      );

      expect(result, isNotNull);
      expect(result!.cid, 949553);
      expect(result.description, contains('iShares Core S&P 500'));
      expect(result.symbol, 'XUS');
      expect(result.exchange, 'Toronto');
      expect(result.flag, 'CA');
      expect(result.type.toLowerCase(), contains('etf'));
    });

    test('returns null for HTML without __NEXT_DATA__', () {
      const html = '<html><body><h1>Just a moment...</h1></body></html>';
      expect(parseInvestingPage(html, Uri.parse('https://www.investing.com/x')), isNull);
    });

    test('returns null when JSON has no recognized instrument store', () {
      const html = '''
        <script id="__NEXT_DATA__" type="application/json">
        {"props":{"pageProps":{"state":{"newsStore":{"items":[]}}}}}
        </script>
      ''';
      expect(parseInvestingPage(html, Uri.parse('https://www.investing.com/news/x')), isNull);
    });
  });
}
