part of 'dashboard_screen.dart';

/// Dashboard-local alias for [CachedRateResolver].
typedef _RateResolver = CachedRateResolver;

/// Currency symbol lookup for display.
String currencySymbol(String code) {
  return switch (code) {
    'EUR' => '\u20ac',
    'USD' => '\$',
    'GBP' => '\u00a3',
    'JPY' => '\u00a5',
    'CHF' => 'CHF',
    _ => code,
  };
}

// Price change period selection — survives ListView.builder recycling
final _priceChangeNumberProvider = StateProvider<int>((ref) => 1);
final _priceChangeUnitProvider = StateProvider<String>((ref) => 'd');
