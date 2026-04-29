/// Compute an asset's value in the base currency.
///
/// Returns null when [fxRate] is null — the caller must skip the asset or
/// surface the missing rate instead of fabricating a value with an implicit
/// 1:1 FX rate, which would silently mis-value foreign-currency holdings.
///
/// [bondDivisor] is 100 for bonds (price is quoted as a percentage of face
/// value) and 1 for everything else.
double? computeAssetBaseValue({
  required double quantity,
  required double price,
  required double bondDivisor,
  required double? fxRate,
}) {
  if (fxRate == null) return null;
  return quantity * price / bondDivisor * fxRate;
}
