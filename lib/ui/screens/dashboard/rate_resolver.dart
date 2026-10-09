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

// Price change period selection — survives ListView.builder recycling.
// These hold the *session* override (what the user tapped this run); null means
// "no override → use the persisted default, else the built-in 'd'/1".
final _priceChangeNumberOverrideProvider = StateProvider<int?>((ref) => null);
final _priceChangeUnitOverrideProvider = StateProvider<String?>((ref) => null);
