import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/database/database.dart';

/// Ad-hoc tests for the REVIEWED composition parsing heuristics.
///
/// The old code guessed an asset-class label from the provider's free-text
/// "Investment focus" field via a chain of `.contains()` keyword checks and
/// silently fell back to a generic "ETF" when nothing matched. That keyword
/// soup was replaced with one explicit, documented mapping table, and an
/// unmapped focus now returns `null` (logged) instead of a wrong generic.
/// `_isGeographic` likewise uses an explicit term table. These tests pin both.
void main() {
  late CompositionService service;

  setUp(() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CompositionService(db);
  });

  String focusHtml(String focus) => '<html><body><span data-testid="tl_etf-basics_value_investment-focus">$focus</span></body></html>';

  group('detectAssetClassFromHtml — explicit keyword map', () {
    test('equity focus → Stock ETF', () {
      expect(service.detectAssetClassFromHtml(focusHtml('Equity, World')), 'Stock ETF');
    });

    test('stock keyword → Stock ETF', () {
      expect(service.detectAssetClassFromHtml(focusHtml('US Stock Market')), 'Stock ETF');
    });

    test('bond / government / fixed income → Bond ETF', () {
      expect(service.detectAssetClassFromHtml(focusHtml('Bond, EUR')), 'Bond ETF');
      expect(service.detectAssetClassFromHtml(focusHtml('Government Bonds')), 'Bond ETF');
      expect(service.detectAssetClassFromHtml(focusHtml('Fixed Income')), 'Bond ETF');
    });

    test('commodity → Commodity ETF', () {
      expect(service.detectAssetClassFromHtml(focusHtml('Broad Commodities')), 'Commodity ETF');
    });

    test('gold / precious metal → Gold ETC', () {
      expect(service.detectAssetClassFromHtml(focusHtml('Physical Gold')), 'Gold ETC');
      expect(service.detectAssetClassFromHtml(focusHtml('Precious Metal')), 'Gold ETC');
    });

    test('money market → Money Market ETF (more specific wins over equity-ish prose)', () {
      expect(service.detectAssetClassFromHtml(focusHtml('Money Market, USD')), 'Money Market ETF');
    });

    test('matching is case-insensitive', () {
      expect(service.detectAssetClassFromHtml(focusHtml('EQUITY')), 'Stock ETF');
    });

    test('UNMAPPED focus returns null — NOT a silent generic "ETF" fallback', () {
      // Pins the removed heuristic's old behavior away: previously this
      // returned "ETF"; now an unknown focus is surfaced and left unset.
      expect(service.detectAssetClassFromHtml(focusHtml('Cryptocurrency Basket')), isNull);
      expect(service.detectAssetClassFromHtml(focusHtml('Real Estate')), isNull);
    });

    test('missing focus field returns null', () {
      expect(service.detectAssetClassFromHtml('<html><body>no focus here</body></html>'), isNull);
    });
  });

  group('isGeographicTerm — explicit term table', () {
    test('recognises known regions/countries', () {
      for (final t in ['World', 'Global', 'Europe', 'USA', 'Japan', 'Emerging Markets', 'North America']) {
        expect(service.isGeographicTerm(t), isTrue, reason: '"$t" should be geographic');
      }
    });

    test('is case-insensitive and matches as substring', () {
      expect(service.isGeographicTerm('developed europe'), isTrue);
    });

    test('non-geographic sectors are not flagged', () {
      for (final t in ['Technology', 'Healthcare', 'Financials', 'Information Technology']) {
        expect(service.isGeographicTerm(t), isFalse, reason: '"$t" is a sector, not a geography');
      }
    });
  });
}
