import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';

// The strict ISIN shape (two letters, nine letters or digits, a check digit)
// behind every "is this an ISIN?" question the asset and model dialogs ask.
void main() {
  test('isIsin: exactly two letters, nine letters or digits, a check digit', () {
    expect(isIsin('IE00B4L5Y983'), isTrue);
    expect(isIsin('LU1234567890'), isTrue);
    for (final value in ['ie00b4l5y983', ' IE00B4L5Y983', 'IE00B4L5Y98X', 'IE00B4L5Y98', 'IE00B4L5Y9833', '1E00B4L5Y983', 'IE00B4L5-983', '']) {
      expect(isIsin(value), isFalse, reason: value);
    }
  });

  test('isinCacheKey: an ISIN upper-cased, anything else as typed', () {
    expect(isinCacheKey('ie00b4l5y983'), 'IE00B4L5Y983');
    expect(isinCacheKey('IE00B4L5Y983'), 'IE00B4L5Y983');
    expect(isinCacheKey('vwce'), 'vwce');
    expect(isinCacheKey('ie00b4l5y98x'), 'ie00b4l5y98x');
  });

  group('portfolio model rows', () {
    void validate(String isin) => PortfolioModelService.validateItems([PortfolioModelInputItem(isin: isin, targetWeight: 100)]);

    test('an ISIN is read trimmed and upper-cased', () {
      expect(() => validate('IE00B4L5Y983'), returnsNormally);
      expect(() => validate('  ie00b4l5y983 '), returnsNormally);
    });

    test('anything else is malformed', () {
      for (final isin in ['bad', 'IE00B4L5Y98X', 'IE00B4L5Y98', 'IE00B4L5Y9833', '1E00B4L5Y983', 'IE00B4L5-983']) {
        expect(
          () => validate(isin),
          throwsA(isA<PortfolioModelValidationException>().having((e) => e.messages, 'messages', contains('row 1: ISIN is malformed'))),
          reason: isin,
        );
      }
    });
  });
}
