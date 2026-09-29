import 'package:finance_copilot/database/tables.dart' show InstrumentType;
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('AssetValueMath');

/// Divisor that turns a quoted price into a per-unit money value: a bond is
/// quoted as a percentage of face value (per 100 nominal), so its price is
/// divided by 100; every other instrument is quoted per unit.
double bondPriceDivisor(InstrumentType type) => type == InstrumentType.bond ? 100.0 : 1.0;

/// Compute an asset's value in the base currency.
///
/// Returns null when [fxRate] is null — the caller must skip the asset or
/// surface the missing rate instead of fabricating a value with an implicit
/// 1:1 FX rate, which would silently mis-value foreign-currency holdings.
///
/// [bondDivisor] is 100 for bonds (price is quoted as a percentage of face
/// value) and 1 for everything else — see [bondPriceDivisor].
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

/// The default capital-gains tax rate stored under `TAX_RATE` — [stored], a
/// fraction (0.26 = 26%) — clamped to [0, 1]; [kDefaultTaxRate] when none is
/// stored. A stored value that does not read as a number falls back to
/// [kDefaultTaxRate] as well, with a warning: a setting that stopped applying
/// shows in the log instead of silently becoming the default. The one reading
/// of the setting: the settings/dashboard provider and the rebalance use it.
double parseStoredTaxRate(String? stored) {
  if (stored == null) return kDefaultTaxRate;
  final parsed = double.tryParse(stored);
  if (parsed == null) {
    _log.warning('TAX_RATE "$stored" is not a number: the default $kDefaultTaxRate applies');
    return kDefaultTaxRate;
  }
  return parsed.clamp(0.0, 1.0);
}

/// Moving-average cost basis of one position: feed it the position's buys and
/// sells in chronological order (value date, then id), every amount in the
/// same currency. The single implementation behind the asset stats, the
/// base-currency cost basis and the rebalance tax estimate.
///
///  - a buy with a quantity adds its amount and quantity to the pool;
///  - a buy without one (a cash-only contribution) has no unit to attach a
///    cost to: it is kept apart and always counts in full;
///  - a sell removes quantity at the pool's CURRENT average cost — a sell
///    never changes the average cost of what remains, only the pool's size —
///    and never more than the pool holds;
///  - once the pool is empty the position is closed: a later buy starts a new
///    pool instead of being blended with the disposed lot's price (buy 1 @
///    100, sell it, buy 1 @ 200 costs 200, not 150).
class CostBasisPool {
  double _cost = 0;
  double _quantity = 0;
  double _cashOnly = 0;
  double _held = 0;

  /// Units bought minus units sold. Not clamped: selling more than was
  /// bought reads negative.
  double get heldQuantity => _held;

  /// A buy of [quantity] units (0 for a cash-only contribution) for [amount].
  void buy(double amount, double quantity) {
    _held += quantity;
    if (quantity > 0) {
      _cost += amount;
      _quantity += quantity;
    } else {
      _cashOnly += amount;
    }
  }

  /// A sell of [quantity] units.
  void sell(double quantity) {
    _held -= quantity;
    if (_quantity > 0 && quantity > 0) {
      final average = _cost / _quantity;
      final removed = quantity > _quantity ? _quantity : quantity;
      _cost -= average * removed;
      _quantity -= removed;
      // Clamp instead of letting floating-point remainders survive a full
      // liquidation as a near-zero residue.
      if (_quantity <= 1e-9) {
        _cost = 0;
        _quantity = 0;
      }
    }
  }

  /// Cost basis of what is still held: the per-unit pool — zero once nothing
  /// is held ([heldQuantity] unless the caller knows the held quantity
  /// better) — plus the cash-only contributions, which share sales don't
  /// affect.
  double costBasis({double? heldQuantity}) => ((heldQuantity ?? _held) <= 0 ? 0.0 : _cost) + _cashOnly;
}

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
