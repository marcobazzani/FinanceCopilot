part of 'portfolio_rebalance_service.dart';

enum PortfolioRebalanceMode { sellAndBuy, buyOnly }

enum PortfolioRebalanceScopeKind { currentPillar, allAssociatedPillars }

enum PortfolioRebalanceUnresolvedReason {
  missingModel,
  missingCurrentQuantity,
  missingMarketPrice,
  missingFxRate,
  missingCostBasisFx,
  missingIsin,
  unmatchedModelItem,
}

class PortfolioRebalanceScope {
  final PortfolioRebalanceScopeKind kind;
  final String? pillarId;

  const PortfolioRebalanceScope._(this.kind, this.pillarId);
  const PortfolioRebalanceScope.currentPillar(String pillarId) : this._(PortfolioRebalanceScopeKind.currentPillar, pillarId);
  const PortfolioRebalanceScope.allAssociatedPillars() : this._(PortfolioRebalanceScopeKind.allAssociatedPillars, null);
}

class PortfolioRebalanceUnresolved {
  final String? pillarId;
  final String? pillarName;
  final int? assetId;
  final String? assetName;
  final String? isin;
  final PortfolioRebalanceUnresolvedReason reason;

  const PortfolioRebalanceUnresolved({
    required this.reason,
    this.pillarId,
    this.pillarName,
    this.assetId,
    this.assetName,
    this.isin,
  });
}

class PortfolioRebalanceDraftRow {
  final String pillarId;
  final String pillarName;
  final int? assetId;
  final String assetName;
  final String? isin;
  final EventType type;
  final double amount;
  final double baseAmount;
  final double estimatedQuantity;
  final double price;
  final String currency;
  final double fxRate;
  final double estimatedTax;
  final double currentBaseValue;
  final double projectedBaseValue;
  final bool isPlaceholder;
  final PortfolioRebalanceAutoCreateSpec? autoCreateSpec;
  final String notes;

  const PortfolioRebalanceDraftRow({
    required this.pillarId,
    required this.pillarName,
    required this.assetId,
    required this.assetName,
    required this.isin,
    required this.type,
    required this.amount,
    required this.baseAmount,
    required this.estimatedQuantity,
    required this.price,
    required this.currency,
    required this.fxRate,
    required this.estimatedTax,
    required this.currentBaseValue,
    required this.projectedBaseValue,
    this.isPlaceholder = false,
    this.autoCreateSpec,
    required this.notes,
  });
}

class PortfolioRebalanceAutoCreateSpec {
  final String isin;
  final String ticker;
  final String exchange;
  final String currency;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final AssetType assetType;

  const PortfolioRebalanceAutoCreateSpec({
    required this.isin,
    required this.ticker,
    required this.exchange,
    required this.currency,
    required this.instrumentType,
    required this.assetClass,
    required this.assetType,
  });
}

class PortfolioRebalanceDraft {
  final PortfolioRebalanceMode mode;
  final PortfolioRebalanceScope scope;
  final String baseCurrency;
  final List<PortfolioRebalanceDraftRow> rows;
  final List<PortfolioRebalanceUnresolved> unresolved;
  final double availableCashBase;
  final double targetBuyBase;
  final double executedBuyBase;
  final double buyShortfallBase;
  final double leftoverCashBase;
  final double currentPortfolioValueBase;
  final double projectedPortfolioValueBase;

  const PortfolioRebalanceDraft({
    required this.mode,
    required this.scope,
    required this.baseCurrency,
    required this.rows,
    required this.unresolved,
    required this.availableCashBase,
    required this.targetBuyBase,
    required this.executedBuyBase,
    required this.buyShortfallBase,
    required this.leftoverCashBase,
    required this.currentPortfolioValueBase,
    required this.projectedPortfolioValueBase,
  });

  bool get hasTrades => rows.isNotEmpty;
  bool get hasExecutableTrades => rows.any((row) => !row.isPlaceholder);
  double get estimatedTax => rows.fold<double>(0, (sum, row) => sum + row.estimatedTax);
}

class _TargetPlaceholder {
  final Pillar pillar;
  final PortfolioModelItem target;

  const _TargetPlaceholder({
    required this.pillar,
    required this.target,
  });
}

class _SyntheticTargetAsset {
  final Pillar pillar;
  final PortfolioModelItem target;
  final String assetName;
  final PortfolioRebalanceAutoCreateSpec createSpec;
  final double price;
  final double fxRate;

  const _SyntheticTargetAsset({
    required this.pillar,
    required this.target,
    required this.assetName,
    required this.createSpec,
    required this.price,
    required this.fxRate,
  });

  double get unitBaseValue => price / (createSpec.instrumentType == InstrumentType.bond ? 100.0 : 1.0) * fxRate;
}

class _Position {
  final Pillar pillar;
  final Asset asset;
  final double totalQuantity;
  final double pillarQuantity;
  final double price;
  final double fxRate;
  final double currentValueBase;
  final double investedValueBase;

  const _Position({
    required this.pillar,
    required this.asset,
    required this.totalQuantity,
    required this.pillarQuantity,
    required this.price,
    required this.fxRate,
    required this.currentValueBase,
    required this.investedValueBase,
  });

  String? get isin {
    final value = asset.isin?.trim();
    if (value == null || value.isEmpty) return null;
    return normaliseIsin(value);
  }

  double get bondDivisor => asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;
  double get unitBaseValue => price / bondDivisor * fxRate;
}

class _PositionGroup {
  final String isin;
  final PortfolioModelItem target;
  final List<_Position> positions;
  final _TargetPlaceholder? placeholder;
  final _SyntheticTargetAsset? syntheticTarget;

  const _PositionGroup({
    required this.isin,
    required this.target,
    required this.positions,
    this.placeholder,
    this.syntheticTarget,
  });

  double get currentValueBase => positions.fold<double>(0, (sum, p) => sum + p.currentValueBase);
  double get unitBaseValue {
    if (syntheticTarget != null) return syntheticTarget!.unitBaseValue;
    if (placeholder != null) return double.infinity;
    if (positions.isEmpty) return 0;
    return positions.first.unitBaseValue;
  }
}

class _BuyNeed {
  final _PositionGroup group;
  final double desiredBase;

  const _BuyNeed({
    required this.group,
    required this.desiredBase,
  });
}

class _SellResult {
  final List<PortfolioRebalanceDraftRow> rows;
  final double grossBase;
  final double taxBase;

  const _SellResult({
    required this.rows,
    required this.grossBase,
    required this.taxBase,
  });

  double get netBase => grossBase - taxBase;
}
