import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart' show exchangeCurrency;
import 'package:finance_copilot/utils/formatters.dart' show formatYmd;

part 'portfolio_rebalance_models.dart';

final _log = getLogger('PortfolioRebalanceService');

class PortfolioRebalanceService {
  final AppDatabase _db;
  late final ExchangeRateService _rates = ExchangeRateService(_db);
  late final PortfolioModelService _models = PortfolioModelService(_db);
  late final AssetService _assets = AssetService(_db);
  final WebMarketDataService? _marketData;

  PortfolioRebalanceService(this._db, {WebMarketDataService? marketDataService}) : _marketData = marketDataService;

  Future<PortfolioRebalanceDraft> buildDraft({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
    bool resolveMissingTargets = true,
  }) async {
    if (mode == PortfolioRebalanceMode.buyOnly && contributionAmount < 0) {
      throw ArgumentError('contributionAmount must be >= 0');
    }
    final date = _dateOnly(asOf ?? DateTime.now());
    final baseCurrency = await _baseCurrency();
    final defaultTaxRate = await _defaultTaxRate();
    final pillars = await _pillarsForScope(scope);
    final allRows = <PortfolioRebalanceDraftRow>[];
    final allUnresolved = <PortfolioRebalanceUnresolved>[];
    var availableCashBase = 0.0;
    var targetBuyBase = 0.0;
    var executedBuyBase = 0.0;
    var buyShortfallBase = 0.0;
    var leftoverCashBase = 0.0;
    var currentPortfolioValueBase = 0.0;
    var projectedPortfolioValueBase = 0.0;

    for (final pillar in pillars) {
      final result = await _buildPillarDraft(
        pillar: pillar,
        mode: mode,
        contributionAmount: scope.kind == PortfolioRebalanceScopeKind.currentPillar ? contributionAmount : 0,
        asOf: date,
        baseCurrency: baseCurrency,
        defaultTaxRate: defaultTaxRate,
        resolveMissingTargets: resolveMissingTargets,
      );
      allRows.addAll(result.rows);
      allUnresolved.addAll(result.unresolved);
      availableCashBase += result.availableCashBase;
      targetBuyBase += result.targetBuyBase;
      executedBuyBase += result.executedBuyBase;
      buyShortfallBase += result.buyShortfallBase;
      leftoverCashBase += result.leftoverCashBase;
      currentPortfolioValueBase += result.currentPortfolioValueBase;
      projectedPortfolioValueBase += result.projectedPortfolioValueBase;
    }

    return PortfolioRebalanceDraft(
      mode: mode,
      scope: scope,
      baseCurrency: baseCurrency,
      rows: allRows,
      unresolved: allUnresolved,
      availableCashBase: availableCashBase,
      targetBuyBase: targetBuyBase,
      executedBuyBase: executedBuyBase,
      buyShortfallBase: buyShortfallBase,
      leftoverCashBase: leftoverCashBase,
      currentPortfolioValueBase: currentPortfolioValueBase,
      projectedPortfolioValueBase: projectedPortfolioValueBase,
    );
  }

  Stream<PortfolioRebalanceDraft> buildDraftStream({
    required PortfolioRebalanceScope scope,
    required PortfolioRebalanceMode mode,
    double contributionAmount = 0,
    DateTime? asOf,
  }) async* {
    final partial = await buildDraft(
      scope: scope,
      mode: mode,
      contributionAmount: contributionAmount,
      asOf: asOf,
      resolveMissingTargets: false,
    );
    yield partial;

    final resolved = await buildDraft(
      scope: scope,
      mode: mode,
      contributionAmount: contributionAmount,
      asOf: asOf,
      resolveMissingTargets: true,
    );
    yield resolved;
  }

  Future<List<int>> applyDraft(
    PortfolioRebalanceDraft draft,
    AssetEventService eventService, {
    DateTime? date,
  }) async {
    final appliedAt = _dateOnly(date ?? DateTime.now());
    final ids = <int>[];
    for (final row in draft.rows) {
      if (row.isPlaceholder) continue;
      var assetId = row.assetId;
      if (assetId == null) {
        final spec = row.autoCreateSpec;
        if (row.type != EventType.buy || spec == null || row.isin == null) continue;
        assetId = await _createTargetAssetForDraftRow(
          draft: draft,
          row: row,
          spec: spec,
          appliedAt: appliedAt,
        );
      }
      ids.add(
        await eventService.create(
          assetId: assetId,
          date: appliedAt,
          type: row.type,
          amount: row.amount,
          quantity: row.estimatedQuantity,
          price: row.price,
          currency: row.currency,
          notes: row.notes,
        ),
      );
      if (row.assetId == null && row.type == EventType.buy) {
        await _db
            .into(_db.pillarAssets)
            .insertOnConflictUpdate(
              PillarAssetsCompanion.insert(
                pillarId: row.pillarId,
                assetId: assetId,
                quantity: row.estimatedQuantity,
              ),
            );
      }
    }
    _log.info('applyDraft: inserted ${ids.length} asset events');
    return ids;
  }

  Future<
    ({
      List<PortfolioRebalanceDraftRow> rows,
      List<PortfolioRebalanceUnresolved> unresolved,
      double availableCashBase,
      double targetBuyBase,
      double executedBuyBase,
      double buyShortfallBase,
      double leftoverCashBase,
      double grossSellBase,
      double currentPortfolioValueBase,
      double projectedPortfolioValueBase,
    })
  >
  _buildPillarDraft({
    required Pillar pillar,
    required PortfolioRebalanceMode mode,
    required double contributionAmount,
    required DateTime asOf,
    required String baseCurrency,
    required double defaultTaxRate,
    required bool resolveMissingTargets,
  }) async {
    final modelId = pillar.portfolioModelId;
    if (modelId == null || modelId.isEmpty) {
      return (
        rows: const <PortfolioRebalanceDraftRow>[],
        unresolved: [
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            reason: PortfolioRebalanceUnresolvedReason.missingModel,
          ),
        ],
        availableCashBase: 0.0,
        targetBuyBase: 0.0,
        executedBuyBase: 0.0,
        buyShortfallBase: 0.0,
        leftoverCashBase: 0.0,
        grossSellBase: 0.0,
        currentPortfolioValueBase: 0.0,
        projectedPortfolioValueBase: 0.0,
      );
    }
    final model = await _models.getWithItems(modelId);
    if (model == null) {
      return (
        rows: const <PortfolioRebalanceDraftRow>[],
        unresolved: [
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            reason: PortfolioRebalanceUnresolvedReason.missingModel,
          ),
        ],
        availableCashBase: 0.0,
        targetBuyBase: 0.0,
        executedBuyBase: 0.0,
        buyShortfallBase: 0.0,
        leftoverCashBase: 0.0,
        grossSellBase: 0.0,
        currentPortfolioValueBase: 0.0,
        projectedPortfolioValueBase: 0.0,
      );
    }

    final unresolved = <PortfolioRebalanceUnresolved>[];
    final positions = await _positionsForPillar(
      pillar,
      asOf: asOf,
      baseCurrency: baseCurrency,
      unresolved: unresolved,
    );
    final resolvedValue = positions.fold<double>(0, (sum, p) => sum + p.currentValueBase);
    if (resolvedValue <= 0 && contributionAmount <= 0) {
      return (
        rows: const <PortfolioRebalanceDraftRow>[],
        unresolved: unresolved,
        availableCashBase: 0.0,
        targetBuyBase: 0.0,
        executedBuyBase: 0.0,
        buyShortfallBase: 0.0,
        leftoverCashBase: 0.0,
        grossSellBase: 0.0,
        currentPortfolioValueBase: resolvedValue,
        projectedPortfolioValueBase: resolvedValue,
      );
    }

    final targetsByIsin = {
      for (final item in model.items) normaliseIsin(item.isin): item,
    };
    final positionsByIsin = <String, List<_Position>>{};
    final extraPositions = <_Position>[];
    for (final position in positions) {
      final isin = position.isin;
      if (isin == null) {
        unresolved.add(
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            assetId: position.asset.id,
            assetName: position.asset.name,
            reason: PortfolioRebalanceUnresolvedReason.missingIsin,
          ),
        );
        extraPositions.add(position);
      } else if (targetsByIsin.containsKey(isin)) {
        positionsByIsin.putIfAbsent(isin, () => []).add(position);
      } else {
        extraPositions.add(position);
      }
    }

    final groups = <String, _PositionGroup>{};
    for (final entry in targetsByIsin.entries) {
      final targetPositions = positionsByIsin[entry.key] ?? const <_Position>[];
      if (targetPositions.isEmpty) {
        final synthetic = await _syntheticPositionForTargetIsin(
          pillar: pillar,
          isin: entry.key,
          asOf: asOf,
          baseCurrency: baseCurrency,
          unresolved: unresolved,
        );
        if (synthetic == null) {
          final remoteTarget = resolveMissingTargets
              ? await _syntheticTargetForTargetIsin(
                  pillar: pillar,
                  target: entry.value,
                  isin: entry.key,
                  asOf: asOf,
                  baseCurrency: baseCurrency,
                )
              : null;
          if (remoteTarget != null) {
            groups[entry.key] = _PositionGroup(
              isin: entry.key,
              target: entry.value,
              positions: const [],
              syntheticTarget: remoteTarget,
            );
            continue;
          }
          groups[entry.key] = _PositionGroup(
            isin: entry.key,
            target: entry.value,
            positions: const [],
            placeholder: _TargetPlaceholder(
              pillar: pillar,
              target: entry.value,
            ),
          );
          continue;
        }
        groups[entry.key] = _PositionGroup(
          isin: entry.key,
          target: entry.value,
          positions: [synthetic],
        );
        continue;
      }
      groups[entry.key] = _PositionGroup(
        isin: entry.key,
        target: entry.value,
        positions: targetPositions,
      );
    }

    final rows = <PortfolioRebalanceDraftRow>[];
    final buyNeeds = <_BuyNeed>[];
    var availableCashBase = mode == PortfolioRebalanceMode.buyOnly ? contributionAmount : 0.0;
    var targetBuyBase = 0.0;
    var grossSellBase = 0.0;

    if (mode == PortfolioRebalanceMode.sellAndBuy) {
      for (final position in extraPositions) {
        final sellResult = _sellRowsForPositions(
          positions: [position],
          sellBaseAmount: position.currentValueBase,
          defaultTaxRate: defaultTaxRate,
        );
        rows.addAll(sellResult.rows);
        availableCashBase += sellResult.netBase;
        grossSellBase += sellResult.grossBase;
      }
    }

    final targetPortfolioValue = mode == PortfolioRebalanceMode.buyOnly ? resolvedValue + contributionAmount : resolvedValue;
    for (final group in groups.values) {
      final targetBase = targetPortfolioValue * group.target.targetWeight / 100.0;
      final delta = group.currentValueBase - targetBase;
      if (mode == PortfolioRebalanceMode.sellAndBuy && delta > 0.01) {
        final sellResult = _sellRowsForPositions(
          positions: group.positions,
          sellBaseAmount: delta,
          defaultTaxRate: defaultTaxRate,
        );
        rows.addAll(sellResult.rows);
        availableCashBase += sellResult.netBase;
        grossSellBase += sellResult.grossBase;
      } else if (-delta > 0.01) {
        targetBuyBase += -delta;
        if (group.placeholder != null) {
          rows.add(_placeholderBuyRow(group, targetBase));
        } else {
          buyNeeds.add(_BuyNeed(group: group, desiredBase: -delta));
        }
      }
    }

    final totalNeed = buyNeeds.fold<double>(0, (sum, need) => sum + need.desiredBase);
    final buyQuantities = <_PositionGroup, int>{};
    var remainingCashBase = availableCashBase;
    var executedBuyBase = 0.0;
    if (remainingCashBase > 0.01 && totalNeed > 0) {
      while (true) {
        _BuyNeed? bestNeed;
        double bestAfterError = double.infinity;
        double bestUnitBase = double.infinity;
        double bestRemainingNeed = -1;

        for (final need in buyNeeds) {
          final unitBase = need.group.unitBaseValue;
          if (unitBase <= 0 || unitBase > remainingCashBase + 1e-9) continue;
          final allocatedQuantity = buyQuantities[need.group] ?? 0;
          final allocatedBase = allocatedQuantity * unitBase;
          final remainingNeed = need.desiredBase - allocatedBase;
          if (remainingNeed <= 0.01) continue;
          final afterError = (remainingNeed - unitBase).abs();
          if (bestNeed == null ||
              afterError < bestAfterError - 1e-12 ||
              ((afterError - bestAfterError).abs() <= 1e-12 &&
                  (unitBase < bestUnitBase - 1e-12 ||
                      ((unitBase - bestUnitBase).abs() <= 1e-12 && remainingNeed > bestRemainingNeed + 1e-12)))) {
            bestNeed = need;
            bestAfterError = afterError;
            bestUnitBase = unitBase;
            bestRemainingNeed = remainingNeed;
          }
        }

        if (bestNeed == null) break;
        buyQuantities[bestNeed.group] = (buyQuantities[bestNeed.group] ?? 0) + 1;
        remainingCashBase -= bestNeed.group.unitBaseValue;
        if (remainingCashBase <= 0.01) break;
      }
    }

    for (final entry in buyQuantities.entries) {
      final buyRows = _buyRowsForGroup(
        entry.key,
        entry.value,
      );
      rows.addAll(buyRows);
      executedBuyBase += buyRows.fold<double>(0, (sum, row) => sum + row.baseAmount);
    }

    final projectedPortfolioValueBase = resolvedValue + executedBuyBase - grossSellBase;

    return (
      rows: rows,
      unresolved: unresolved,
      availableCashBase: availableCashBase,
      targetBuyBase: targetBuyBase,
      executedBuyBase: executedBuyBase,
      buyShortfallBase: math.max(0.0, targetBuyBase - executedBuyBase),
      leftoverCashBase: math.max(0.0, remainingCashBase),
      grossSellBase: grossSellBase,
      currentPortfolioValueBase: resolvedValue,
      projectedPortfolioValueBase: projectedPortfolioValueBase,
    );
  }

  PortfolioRebalanceDraftRow _placeholderBuyRow(_PositionGroup group, double desiredBase) {
    final placeholder = group.placeholder!;
    final description = placeholder.target.description.trim();
    return PortfolioRebalanceDraftRow(
      pillarId: placeholder.pillar.id,
      pillarName: placeholder.pillar.name,
      assetId: null,
      assetName: description.isNotEmpty ? description : group.isin,
      isin: group.isin,
      type: EventType.buy,
      amount: desiredBase,
      baseAmount: desiredBase,
      estimatedQuantity: 0,
      price: 0,
      currency: '',
      fxRate: 0,
      estimatedTax: 0,
      currentBaseValue: 0,
      projectedBaseValue: desiredBase,
      isPlaceholder: true,
      notes: 'Portfolio rebalance placeholder',
    );
  }

  Future<_Position?> _syntheticPositionForTargetIsin({
    required Pillar pillar,
    required String isin,
    required DateTime asOf,
    required String baseCurrency,
    required List<PortfolioRebalanceUnresolved> unresolved,
  }) async {
    final assetRow = await _db
        .customSelect(
          "SELECT * FROM assets WHERE UPPER(TRIM(COALESCE(isin, ''))) = ? LIMIT 1",
          variables: [Variable<String>(normaliseIsin(isin))],
          readsFrom: {_db.assets},
        )
        .get();
    final asset = assetRow.isEmpty ? null : _db.assets.map(assetRow.first.data);
    if (asset == null) return null;
    final price = await _latestMarketPrice(asset.id, asOf);
    if (price == null) {
      unresolved.add(
        PortfolioRebalanceUnresolved(
          pillarId: pillar.id,
          pillarName: pillar.name,
          assetId: asset.id,
          assetName: asset.name,
          isin: asset.isin,
          reason: PortfolioRebalanceUnresolvedReason.missingMarketPrice,
        ),
      );
      return null;
    }
    final fxRate = asset.currency == baseCurrency ? 1.0 : await _rates.getRate(asset.currency, baseCurrency, asOf);
    if (fxRate == null || fxRate <= 0) {
      unresolved.add(
        PortfolioRebalanceUnresolved(
          pillarId: pillar.id,
          pillarName: pillar.name,
          assetId: asset.id,
          assetName: asset.name,
          isin: asset.isin,
          reason: PortfolioRebalanceUnresolvedReason.missingFxRate,
        ),
      );
      return null;
    }
    return _Position(
      pillar: pillar,
      asset: asset,
      totalQuantity: 0,
      pillarQuantity: 0,
      price: price,
      fxRate: fxRate,
      currentValueBase: 0,
      investedValueBase: 0,
    );
  }

  _SellResult _sellRowsForPositions({
    required List<_Position> positions,
    required double sellBaseAmount,
    required double defaultTaxRate,
  }) {
    final totalValue = positions.fold<double>(0, (sum, p) => sum + p.currentValueBase);
    if (totalValue <= 0 || sellBaseAmount <= 0) return const _SellResult(rows: [], grossBase: 0, taxBase: 0);
    final cappedSell = math.min(sellBaseAmount, totalValue);
    final unitBase = positions.first.unitBaseValue;
    if (unitBase <= 0) return const _SellResult(rows: [], grossBase: 0, taxBase: 0);
    final exactQuantity = cappedSell / unitBase;
    final wholeQuantity = (exactQuantity + 1e-9).floor();
    if (wholeQuantity <= 0) return const _SellResult(rows: [], grossBase: 0, taxBase: 0);
    final rows = <PortfolioRebalanceDraftRow>[];
    var grossBase = 0.0;
    var taxBase = 0.0;
    final remainders = <({double remainder, _Position position, int quantity})>[];
    var allocatedQuantity = 0;
    for (final position in positions) {
      final exactQuantityForPosition = wholeQuantity * position.currentValueBase / totalValue;
      final quantity = (exactQuantityForPosition + 1e-9).floor();
      allocatedQuantity += quantity;
      remainders.add((remainder: exactQuantityForPosition - quantity, position: position, quantity: quantity));
    }
    var remaining = wholeQuantity - allocatedQuantity;
    remainders.sort((a, b) => b.remainder.compareTo(a.remainder));
    for (var i = 0; i < remaining && i < remainders.length; i++) {
      final entry = remainders[i];
      remainders[i] = (remainder: entry.remainder, position: entry.position, quantity: entry.quantity + 1);
    }
    for (final entry in remainders) {
      final quantity = entry.quantity.toDouble();
      if (quantity <= 0) continue;
      final position = entry.position;
      final baseAmount = quantity * unitBase;
      final taxRate = (position.asset.taxRate ?? defaultTaxRate).clamp(0.0, 1.0);
      final positiveGain = math.max(position.currentValueBase - position.investedValueBase, 0.0);
      final gainRatio = position.currentValueBase <= 0 ? 0.0 : positiveGain / position.currentValueBase;
      final estimatedTax = baseAmount * gainRatio * taxRate;
      final amount = baseAmount / position.fxRate;
      final projectedBaseValue = math.max(position.currentValueBase - baseAmount, 0.0);
      grossBase += baseAmount;
      taxBase += estimatedTax;
      rows.add(
        PortfolioRebalanceDraftRow(
          pillarId: position.pillar.id,
          pillarName: position.pillar.name,
          assetId: position.asset.id,
          assetName: position.asset.name,
          isin: position.asset.isin,
          type: EventType.sell,
          amount: amount,
          baseAmount: baseAmount,
          estimatedQuantity: quantity,
          price: position.price,
          currency: position.asset.currency,
          fxRate: position.fxRate,
          estimatedTax: estimatedTax,
          currentBaseValue: position.currentValueBase,
          projectedBaseValue: projectedBaseValue,
          notes: 'Portfolio rebalance draft',
        ),
      );
    }
    return _SellResult(rows: rows, grossBase: grossBase, taxBase: taxBase);
  }

  List<PortfolioRebalanceDraftRow> _buyRowsForGroup(
    _PositionGroup group,
    int quantity,
  ) {
    final unitBase = group.unitBaseValue;
    if (unitBase <= 0) return const [];
    if (quantity <= 0) return const [];
    final actualBaseAmount = quantity * unitBase;
    if (group.syntheticTarget != null) {
      final synthetic = group.syntheticTarget!;
      return [
        PortfolioRebalanceDraftRow(
          pillarId: synthetic.pillar.id,
          pillarName: synthetic.pillar.name,
          assetId: null,
          assetName: synthetic.assetName,
          isin: synthetic.createSpec.isin,
          type: EventType.buy,
          amount: actualBaseAmount / synthetic.fxRate,
          baseAmount: actualBaseAmount,
          estimatedQuantity: quantity.toDouble(),
          price: synthetic.price,
          currency: synthetic.createSpec.currency,
          fxRate: synthetic.fxRate,
          estimatedTax: 0,
          currentBaseValue: 0,
          projectedBaseValue: actualBaseAmount,
          autoCreateSpec: synthetic.createSpec,
          notes: 'Portfolio rebalance draft',
        ),
      ];
    }
    final position = group.positions.first;
    return [
      PortfolioRebalanceDraftRow(
        pillarId: position.pillar.id,
        pillarName: position.pillar.name,
        assetId: position.asset.id,
        assetName: position.asset.name,
        isin: position.asset.isin,
        type: EventType.buy,
        amount: actualBaseAmount / position.fxRate,
        baseAmount: actualBaseAmount,
        estimatedQuantity: quantity.toDouble(),
        price: position.price,
        currency: position.asset.currency,
        fxRate: position.fxRate,
        estimatedTax: 0,
        currentBaseValue: position.currentValueBase,
        projectedBaseValue: position.currentValueBase + actualBaseAmount,
        autoCreateSpec: null,
        notes: 'Portfolio rebalance draft',
      ),
    ];
  }

  Future<_SyntheticTargetAsset?> _syntheticTargetForTargetIsin({
    required Pillar pillar,
    required PortfolioModelItem target,
    required String isin,
    required DateTime asOf,
    required String baseCurrency,
  }) async {
    final marketData = _marketData;
    if (marketData == null) return null;

    final resolved = await marketData.resolveListingsByIsin(
      isin: isin,
      description: target.description,
      preferredTicker: target.preferredTicker,
      preferredExchange: target.preferredExchange,
    );
    if (resolved.isEmpty) return null;

    resolved.sort((a, b) {
      int score(ProviderSearchResult r) {
        final ccy = exchangeCurrency[r.exchange];
        if (ccy == baseCurrency) return 0;
        if (r.exchange == 'Milan') return 1;
        return 2;
      }

      final byScore = score(a).compareTo(score(b));
      if (byScore != 0) return byScore;
      return a.exchange.compareTo(b.exchange);
    });

    for (final candidate in resolved) {
      final currency = exchangeCurrency[candidate.exchange];
      if (currency == null || candidate.symbol.trim().isEmpty) continue;
      final history = await marketData.fetchHistoricalPricesForListing(
        candidate,
        asOf.subtract(const Duration(days: 14)),
      );
      final entries = history.entries.where((entry) => !entry.key.isAfter(asOf)).toList()..sort((a, b) => b.key.compareTo(a.key));
      if (entries.isEmpty) continue;
      final price = entries.first.value;
      if (price <= 0) continue;
      final fxRate = currency == baseCurrency ? 1.0 : await _rates.getRate(currency, baseCurrency, asOf);
      if (fxRate == null || fxRate <= 0) continue;

      final classification = classifyFromProviderType(candidate.type);
      final createSpec = PortfolioRebalanceAutoCreateSpec(
        isin: normaliseIsin(isin),
        ticker: candidate.symbol,
        exchange: candidate.exchange,
        currency: currency,
        instrumentType: classification.$1,
        assetClass: classification.$2,
        assetType: _defaultAssetTypeFor(classification.$1, classification.$2),
      );
      final assetName = target.description.trim().isNotEmpty
          ? target.description.trim()
          : candidate.description.trim().isNotEmpty
          ? candidate.description.trim()
          : normaliseIsin(isin);
      return _SyntheticTargetAsset(
        pillar: pillar,
        target: target,
        assetName: assetName,
        createSpec: createSpec,
        price: price,
        fxRate: fxRate,
      );
    }
    return null;
  }

  AssetType _defaultAssetTypeFor(InstrumentType instrumentType, AssetClass assetClass) {
    switch (instrumentType) {
      case InstrumentType.bond:
        return AssetType.bondEtf;
      case InstrumentType.etc:
        return assetClass == AssetClass.commodities ? AssetType.goldEtc : AssetType.commEtf;
      case InstrumentType.crypto:
        return AssetType.crypto;
      case InstrumentType.pension:
        return AssetType.pension;
      case InstrumentType.deposit:
        return AssetType.deposit;
      case InstrumentType.realEstate:
        return AssetType.realEstate;
      case InstrumentType.alternative:
        return AssetType.alternative;
      case InstrumentType.liability:
        return AssetType.liability;
      case InstrumentType.fund:
      case InstrumentType.etf:
      case InstrumentType.stock:
        return AssetType.stockEtf;
      case InstrumentType.cash:
        return AssetType.cash;
    }
  }

  Future<int> _createTargetAssetForDraftRow({
    required PortfolioRebalanceDraft draft,
    required PortfolioRebalanceDraftRow row,
    required PortfolioRebalanceAutoCreateSpec spec,
    required DateTime appliedAt,
  }) async {
    final intermediaryId = await _preferredIntermediaryIdForPillar(row.pillarId);
    final assetId = await _assets.create(
      name: row.assetName,
      intermediaryId: intermediaryId,
      ticker: spec.ticker,
      isin: spec.isin,
      exchange: spec.exchange,
      currency: spec.currency,
      instrumentType: spec.instrumentType,
      assetClass: spec.assetClass,
      assetType: spec.assetType,
    );
    await _db
        .into(_db.marketPrices)
        .insertOnConflictUpdate(
          MarketPricesCompanion.insert(
            assetId: assetId,
            date: appliedAt,
            closePrice: row.price,
            currency: spec.currency,
          ),
        );
    _log.info(
      'applyDraft: auto-created asset $assetId for ${spec.isin} '
      '(${spec.ticker}@${spec.exchange}) price=${row.price} ${spec.currency} on ${formatYmd(appliedAt)}',
    );
    return assetId;
  }

  Future<int> _preferredIntermediaryIdForPillar(String pillarId) async {
    final rows = await _db
        .customSelect(
          'SELECT a.intermediary_id AS intermediary_id, COUNT(*) AS cnt '
          'FROM pillar_assets pa '
          'JOIN assets a ON a.id = pa.asset_id '
          'WHERE pa.pillar_id = ? '
          'GROUP BY a.intermediary_id '
          'ORDER BY cnt DESC, a.intermediary_id ASC '
          'LIMIT 1',
          variables: [Variable.withString(pillarId)],
          readsFrom: {_db.pillarAssets, _db.assets},
        )
        .getSingleOrNull();
    final existing = rows?.readNullable<int>('intermediary_id');
    if (existing != null) return existing;

    final fallback =
        await (_db.select(_db.intermediaries)
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder), (i) => OrderingTerm.asc(i.id)])
              ..limit(1))
            .getSingleOrNull();
    if (fallback != null) return fallback.id;

    return _db
        .into(_db.intermediaries)
        .insert(
          IntermediariesCompanion.insert(name: 'Default'),
        );
  }

  Future<List<_Position>> _positionsForPillar(
    Pillar pillar, {
    required DateTime asOf,
    required String baseCurrency,
    required List<PortfolioRebalanceUnresolved> unresolved,
  }) async {
    final assignments = await (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillar.id))).get();
    final positions = <_Position>[];
    for (final assignment in assignments) {
      final asset = await (_db.select(_db.assets)..where((a) => a.id.equals(assignment.assetId))).getSingleOrNull();
      if (asset == null) continue;
      final totalQty = await _totalQuantity(asset.id, asOf: asOf);
      if (totalQty <= 0) {
        unresolved.add(
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            assetId: asset.id,
            assetName: asset.name,
            reason: PortfolioRebalanceUnresolvedReason.missingCurrentQuantity,
          ),
        );
        continue;
      }
      final price = await _latestMarketPrice(asset.id, asOf);
      if (price == null) {
        unresolved.add(
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            assetId: asset.id,
            assetName: asset.name,
            isin: asset.isin,
            reason: PortfolioRebalanceUnresolvedReason.missingMarketPrice,
          ),
        );
        continue;
      }
      final fxRate = asset.currency == baseCurrency ? 1.0 : await _rates.getRate(asset.currency, baseCurrency, asOf);
      if (fxRate == null || fxRate <= 0) {
        unresolved.add(
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            assetId: asset.id,
            assetName: asset.name,
            isin: asset.isin,
            reason: PortfolioRebalanceUnresolvedReason.missingFxRate,
          ),
        );
        continue;
      }
      final investedBase = await _investedBase(asset, totalQty, baseCurrency, asOf);
      if (investedBase == null) {
        unresolved.add(
          PortfolioRebalanceUnresolved(
            pillarId: pillar.id,
            pillarName: pillar.name,
            assetId: asset.id,
            assetName: asset.name,
            isin: asset.isin,
            reason: PortfolioRebalanceUnresolvedReason.missingCostBasisFx,
          ),
        );
        continue;
      }
      final bondDivisor = asset.instrumentType == InstrumentType.bond ? 100.0 : 1.0;
      final currentValueBase = assignment.quantity * price / bondDivisor * fxRate;
      positions.add(
        _Position(
          pillar: pillar,
          asset: asset,
          totalQuantity: totalQty,
          pillarQuantity: assignment.quantity,
          price: price,
          fxRate: fxRate,
          currentValueBase: currentValueBase,
          investedValueBase: investedBase * (assignment.quantity / totalQty),
        ),
      );
    }
    return positions;
  }

  Future<double> _totalQuantity(int assetId, {required DateTime asOf}) async {
    final endExclusive = asOf.add(const Duration(days: 1));
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CASE WHEN type = ? THEN ABS(COALESCE(quantity, 0)) '
          'WHEN type = ? THEN -ABS(COALESCE(quantity, 0)) ELSE 0 END), 0) AS qty '
          'FROM asset_events WHERE asset_id = ? AND quantity IS NOT NULL AND value_date < ?',
          variables: [
            Variable.withString(EventType.buy.name),
            Variable.withString(EventType.sell.name),
            Variable.withInt(assetId),
            Variable.withInt(endExclusive.millisecondsSinceEpoch ~/ 1000),
          ],
          readsFrom: {_db.assetEvents},
        )
        .getSingle();
    return row.read<double>('qty');
  }

  Future<double?> _latestMarketPrice(int assetId, DateTime asOf) async {
    final endExclusive = asOf.add(const Duration(days: 1));
    final row = await _db
        .customSelect(
          'SELECT close_price FROM market_prices WHERE asset_id = ? AND date < ? ORDER BY date DESC LIMIT 1',
          variables: [
            Variable.withInt(assetId),
            Variable.withInt(endExclusive.millisecondsSinceEpoch ~/ 1000),
          ],
          readsFrom: {_db.marketPrices},
        )
        .getSingleOrNull();
    return row?.readNullable<double>('close_price');
  }

  Future<double?> _investedBase(
    Asset asset,
    double currentQuantity,
    String baseCurrency,
    DateTime asOf,
  ) async {
    final endExclusive = asOf.add(const Duration(days: 1));
    final events =
        await (_db.select(_db.assetEvents)..where(
              (e) => e.assetId.equals(asset.id) & e.type.equalsValue(EventType.buy) & e.valueDate.isSmallerThanValue(endExclusive),
            ))
            .get();
    var buyBase = 0.0;
    var buyQty = 0.0;
    for (final event in events) {
      final amount = await _eventAmountBase(event, baseCurrency);
      if (amount == null) return null;
      buyBase += amount.abs();
      buyQty += event.quantity?.abs() ?? 0;
    }
    if (buyQty <= 0) return buyBase;
    if (currentQuantity <= 0) return 0;
    return buyBase / buyQty * currentQuantity;
  }

  Future<double?> _eventAmountBase(AssetEvent event, String baseCurrency) async {
    final amount = event.amount.abs();
    if (event.currency == baseCurrency) return amount;
    // Only a rate quoted against the current base converts correctly; one
    // stamped with a previous base is preserved data (see
    // AssetEventService.isExchangeRateUsableFor).
    if (AssetEventService.isExchangeRateUsableFor(event, baseCurrency)) {
      return amount / event.exchangeRate!;
    }
    final baseToEvent = await _rates.getRate(baseCurrency, event.currency, event.valueDate);
    if (baseToEvent != null && baseToEvent > 0) return amount / baseToEvent;
    final eventToBase = await _rates.getRate(event.currency, baseCurrency, event.valueDate);
    if (eventToBase != null && eventToBase > 0) return amount * eventToBase;
    return null;
  }

  Future<List<Pillar>> _pillarsForScope(PortfolioRebalanceScope scope) {
    switch (scope.kind) {
      case PortfolioRebalanceScopeKind.currentPillar:
        final pillarId = scope.pillarId;
        if (pillarId == null) return Future.value(const <Pillar>[]);
        return (_db.select(_db.pillars)..where((p) => p.id.equals(pillarId))).get();
      case PortfolioRebalanceScopeKind.allAssociatedPillars:
        // Exclude virtual portfolios from the batch scope: they overlap real
        // holdings and including them would double-count buy/sell trades.
        // Virtual portfolios can still be rebalanced individually via currentPillar.
        return (_db.select(_db.pillars)..where((p) => p.portfolioModelId.isNotNull() & p.kind.equalsValue(PillarKind.standard))).get();
    }
  }

  Future<String> _baseCurrency() async {
    final row = await (_db.select(_db.appConfigs)..where((c) => c.key.equals('BASE_CURRENCY'))).getSingleOrNull();
    return row?.value ?? 'EUR';
  }

  Future<double> _defaultTaxRate() async {
    final row = await (_db.select(_db.appConfigs)..where((c) => c.key.equals('TAX_RATE'))).getSingleOrNull();
    final parsed = double.tryParse(row?.value ?? '');
    return (parsed ?? 0.26).clamp(0.0, 1.0);
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}
