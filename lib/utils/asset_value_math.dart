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

/// Default capital-gains tax rate (fraction) used when neither the asset nor
/// the user have set one. Italian retail default.
const double kDefaultTaxRate = 0.26;

/// Compute the after-tax "Net Value" of an asset position at a single point.
///
///   net = invested + max(0, gain) × (1 − taxRate)
///
/// Losses are *not* credited with a phantom tax saving: an unrealized loss
/// has no tax effect, so the formula degenerates to `net = market` when
/// `gain ≤ 0`. [taxRate] is expected as a fraction (0.26 = 26%) and is
/// clamped to `[0, 1]`.
double computeAssetNetValue({
  required double invested,
  required double market,
  required double taxRate,
}) {
  final t = taxRate.clamp(0.0, 1.0);
  final gain = market - invested;
  if (gain <= 0) return market;
  return invested + gain * (1 - t);
}
