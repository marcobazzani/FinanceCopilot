import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/investing_com_service.dart';
import 'package:finance_copilot/ui/screens/assets_screen.dart';

InvestingSearchResult _r({
  required int cid,
  required String description,
  required String exchange,
  String symbol = '',
  String flag = '',
  String type = '',
}) =>
    InvestingSearchResult(
      cid: cid,
      description: description,
      symbol: symbol,
      exchange: exchange,
      flag: flag,
      type: type,
    );

void main() {
  group('exchangeListingsFor (multi-exchange UI stress test)', () {
    test('one ISIN listed on three exchanges → three distinct listings', () {
      // iShares Core S&P 500 (IE00B5BMR087) lists on Milano, Xetra, London.
      final results = [
        _r(cid: 100, description: 'iShares Core S&P 500', exchange: 'Milano'),
        _r(cid: 101, description: 'iShares Core S&P 500', exchange: 'Xetra'),
        _r(cid: 102, description: 'iShares Core S&P 500', exchange: 'London'),
        _r(cid: 200, description: 'Some Other Fund', exchange: 'Milano'),
      ];
      final listings = exchangeListingsFor(results, results[0]);
      expect(listings.length, 3);
      expect(listings.map((l) => l.cid).toSet(), {100, 101, 102});
      expect(listings.map((l) => l.exchange).toSet(), {'Milano', 'Xetra', 'London'});
    });

    test('two ISINs each on multiple exchanges → only siblings of the picked one', () {
      // Two distinct instruments coexisting in one search result set.
      final results = [
        _r(cid: 1, description: 'Vanguard FTSE All-World', exchange: 'Milano'),
        _r(cid: 2, description: 'Vanguard FTSE All-World', exchange: 'Xetra'),
        _r(cid: 3, description: 'Vanguard FTSE All-World', exchange: 'London'),
        _r(cid: 4, description: 'iShares MSCI World', exchange: 'Milano'),
        _r(cid: 5, description: 'iShares MSCI World', exchange: 'Xetra'),
      ];

      final vwrl = exchangeListingsFor(results, results[1]);
      expect(vwrl.map((l) => l.cid).toSet(), {1, 2, 3});

      final swda = exchangeListingsFor(results, results[3]);
      expect(swda.map((l) => l.cid).toSet(), {4, 5});
    });

    test('drops listings whose exchange we cannot map to an internal code', () {
      final results = [
        _r(cid: 1, description: 'Foo', exchange: 'Milano'),
        _r(cid: 2, description: 'Foo', exchange: 'WildExchange99'),
      ];
      final listings = exchangeListingsFor(results, results[0]);
      expect(listings.map((l) => l.cid).toSet(), {1});
    });

    test('falls back to the picked result when no siblings are mappable', () {
      final picked = _r(cid: 9, description: 'Bond X', exchange: 'WildExchange99');
      // Even if exchange is unmappable, the user should see the picked result.
      final listings = exchangeListingsFor([picked], picked);
      expect(listings.length, 1);
      expect(listings.first.cid, 9);
    });

    test('descriptions that differ are not treated as siblings', () {
      final results = [
        _r(cid: 1, description: 'iShares Core S&P 500', exchange: 'Milano'),
        _r(cid: 2, description: 'iShares Core S&P 500 USD (Dist)', exchange: 'Milano'),
      ];
      final listings = exchangeListingsFor(results, results[0]);
      expect(listings.map((l) => l.cid).toSet(), {1});
    });
  });
}
