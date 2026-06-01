import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/logger.dart';
import '../utils/uuid_v7.dart';

final _log = getLogger('PortfolioModelService');

const _modelCatalogRoot = 'PortfolioModels/';
const _weightTolerance = 0.05;
final _isinPattern = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');

class PortfolioModelValidationException implements Exception {
  final List<String> messages;
  const PortfolioModelValidationException(this.messages);

  @override
  String toString() => 'PortfolioModelValidationException(${messages.join('; ')})';
}

class PortfolioModelReadOnlyException implements Exception {
  final String modelId;
  const PortfolioModelReadOnlyException(this.modelId);

  @override
  String toString() => 'PortfolioModelReadOnlyException($modelId)';
}

class PortfolioModelInputItem {
  final String isin;
  final double targetWeight;
  final String description;

  const PortfolioModelInputItem({
    required this.isin,
    required this.targetWeight,
    this.description = '',
  });

  PortfolioModelInputItem normalised() => PortfolioModelInputItem(
    isin: normaliseIsin(isin),
    targetWeight: targetWeight,
    description: description.trim(),
  );
}

class ParsedPortfolioModel {
  final String id;
  final String name;
  final int? year;
  final int? equityPercent;
  final PortfolioModelVariant variant;
  final List<PortfolioModelInputItem> items;

  const ParsedPortfolioModel({
    required this.id,
    required this.name,
    required this.year,
    required this.equityPercent,
    required this.variant,
    required this.items,
  });
}

class PortfolioModelWithItems {
  final PortfolioModel model;
  final List<PortfolioModelItem> items;

  const PortfolioModelWithItems({
    required this.model,
    required this.items,
  });
}

class PortfolioUnresolvedHolding {
  final int assetId;
  final String assetName;
  final String reason;

  const PortfolioUnresolvedHolding({
    required this.assetId,
    required this.assetName,
    required this.reason,
  });
}

class PortfolioExtraHolding {
  final int assetId;
  final String assetName;
  final String? isin;
  final double currentValue;
  final double currentWeight;

  const PortfolioExtraHolding({
    required this.assetId,
    required this.assetName,
    required this.isin,
    required this.currentValue,
    required this.currentWeight,
  });
}

class PortfolioDivergenceRow {
  final PortfolioModelItem target;
  final List<int> assetIds;
  final double targetValue;
  final double currentValue;
  final double currentWeight;

  const PortfolioDivergenceRow({
    required this.target,
    required this.assetIds,
    required this.targetValue,
    required this.currentValue,
    required this.currentWeight,
  });

  bool get isUnmatched => assetIds.isEmpty;
  double get valueDivergence => currentValue - targetValue;
  double get weightDivergence => currentWeight - target.targetWeight;
}

class PortfolioDivergence {
  final Pillar pillar;
  final PortfolioModel model;
  final double resolvedValue;
  final List<PortfolioDivergenceRow> rows;
  final List<PortfolioExtraHolding> extraHoldings;
  final List<PortfolioUnresolvedHolding> unresolvedHoldings;

  const PortfolioDivergence({
    required this.pillar,
    required this.model,
    required this.resolvedValue,
    required this.rows,
    required this.extraHoldings,
    required this.unresolvedHoldings,
  });
}

class _ResolvedPillarHolding {
  final Asset asset;
  final double totalQuantity;
  final double pillarQuantity;
  final double currentValue;

  const _ResolvedPillarHolding({
    required this.asset,
    required this.totalQuantity,
    required this.pillarQuantity,
    required this.currentValue,
  });

  String? get normalisedIsin {
    final isin = asset.isin?.trim();
    if (isin == null || isin.isEmpty) return null;
    return normaliseIsin(isin);
  }
}

String normaliseIsin(String value) => value.trim().toUpperCase();

class PortfolioModelService {
  final AppDatabase _db;
  final AssetBundle _bundle;

  PortfolioModelService(this._db, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  Future<List<PortfolioModel>> getAll() =>
      (_db.select(_db.portfolioModels)..orderBy([
            (m) => OrderingTerm.asc(m.sortOrder),
            (m) => OrderingTerm.asc(m.name),
          ]))
          .get();

  Stream<List<PortfolioModel>> watchAll() =>
      (_db.select(_db.portfolioModels)..orderBy([
            (m) => OrderingTerm.asc(m.sortOrder),
            (m) => OrderingTerm.asc(m.name),
          ]))
          .watch();

  Future<PortfolioModel?> getById(String id) => (_db.select(_db.portfolioModels)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<List<PortfolioModelItem>> getItems(String modelId) =>
      (_db.select(_db.portfolioModelItems)
            ..where((i) => i.modelId.equals(modelId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();

  Stream<List<PortfolioModelItem>> watchItems(String modelId) =>
      (_db.select(_db.portfolioModelItems)
            ..where((i) => i.modelId.equals(modelId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .watch();

  Future<PortfolioModelWithItems?> getWithItems(String modelId) async {
    final model = await getById(modelId);
    if (model == null) return null;
    return PortfolioModelWithItems(model: model, items: await getItems(modelId));
  }

  Future<List<ParsedPortfolioModel>> loadBuiltInModels() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths = manifest.listAssets().where((path) => path.startsWith(_modelCatalogRoot) && path.endsWith('.md')).toList()
      ..sort(_catalogPathCompare);

    final out = <ParsedPortfolioModel>[];
    for (final path in paths) {
      final markdown = await _bundle.loadString(path);
      out.add(parseMarkdown(markdown, path: path));
    }
    return out;
  }

  Future<int> seedBuiltInModels() async {
    final models = await loadBuiltInModels();
    await _db.transaction(() async {
      for (var index = 0; index < models.length; index++) {
        final parsed = models[index];
        validateItems(parsed.items, context: parsed.id);
        await _db
            .into(_db.portfolioModels)
            .insertOnConflictUpdate(
              PortfolioModelsCompanion.insert(
                id: parsed.id,
                name: parsed.name,
                variant: parsed.variant,
                isBuiltIn: const Value(true),
                year: Value(parsed.year),
                equityPercent: Value(parsed.equityPercent),
                sortOrder: Value(index),
                updatedAt: Value(DateTime.now()),
              ),
            );
        await (_db.delete(_db.portfolioModelItems)..where((i) => i.modelId.equals(parsed.id))).go();
        await _insertItems(parsed.id, parsed.items);
      }
    });
    _log.info('seedBuiltInModels: seeded ${models.length} models');
    return models.length;
  }

  Future<String> createCustomModel({
    required String name,
    required List<PortfolioModelInputItem> items,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const PortfolioModelValidationException(['name is required']);
    }
    validateItems(items, context: trimmedName);
    final id = UuidV7.generate();
    final maxSort = await (_db.selectOnly(
      _db.portfolioModels,
    )..addColumns([_db.portfolioModels.sortOrder.max()])).map((row) => row.read(_db.portfolioModels.sortOrder.max())).getSingleOrNull();
    await _db.transaction(() async {
      await _db
          .into(_db.portfolioModels)
          .insert(
            PortfolioModelsCompanion.insert(
              id: id,
              name: trimmedName,
              variant: PortfolioModelVariant.custom,
              isBuiltIn: const Value(false),
              sortOrder: Value((maxSort ?? -1) + 1),
            ),
          );
      await _insertItems(id, items);
    });
    return id;
  }

  Future<void> updateCustomModel(
    String modelId, {
    String? name,
    List<PortfolioModelInputItem>? items,
  }) async {
    final model = await getById(modelId);
    if (model == null) return;
    if (model.isBuiltIn) throw PortfolioModelReadOnlyException(modelId);
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw const PortfolioModelValidationException(['name is required']);
    }
    if (items != null) validateItems(items, context: trimmedName ?? model.name);

    await _db.transaction(() async {
      await (_db.update(_db.portfolioModels)..where((m) => m.id.equals(modelId))).write(
        PortfolioModelsCompanion(
          name: trimmedName == null ? const Value.absent() : Value(trimmedName),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (items != null) {
        await (_db.delete(_db.portfolioModelItems)..where((i) => i.modelId.equals(modelId))).go();
        await _insertItems(modelId, items);
      }
    });
  }

  Future<void> deleteCustomModel(String modelId) async {
    final model = await getById(modelId);
    if (model == null) return;
    if (model.isBuiltIn) throw PortfolioModelReadOnlyException(modelId);
    await (_db.delete(_db.portfolioModels)..where((m) => m.id.equals(modelId))).go();
  }

  Future<PortfolioDivergence?> computeDivergenceForPillar({
    required String pillarId,
    required Map<int, double> marketValuesByAssetId,
  }) async {
    final pillar = await (_db.select(_db.pillars)..where((p) => p.id.equals(pillarId))).getSingleOrNull();
    final modelId = pillar?.portfolioModelId;
    if (pillar == null || modelId == null || modelId.isEmpty) return null;
    final model = await getById(modelId);
    if (model == null) return null;
    final targetItems = await getItems(model.id);
    final holdings = await _resolvedHoldings(pillarId, marketValuesByAssetId);
    final resolved = holdings.resolved;
    final totalValue = resolved.fold<double>(0, (sum, h) => sum + h.currentValue);

    final targetIsins = targetItems.map((item) => normaliseIsin(item.isin)).toSet();
    final matchedByIsin = <String, ({double value, List<int> assetIds})>{};
    final extras = <PortfolioExtraHolding>[];

    for (final holding in resolved) {
      final isin = holding.normalisedIsin;
      final currentWeight = totalValue <= 0 ? 0.0 : holding.currentValue / totalValue * 100;
      if (isin != null && targetIsins.contains(isin)) {
        final previous = matchedByIsin[isin];
        matchedByIsin[isin] = (
          value: (previous?.value ?? 0) + holding.currentValue,
          assetIds: [...?previous?.assetIds, holding.asset.id],
        );
      } else {
        extras.add(
          PortfolioExtraHolding(
            assetId: holding.asset.id,
            assetName: holding.asset.name,
            isin: holding.asset.isin,
            currentValue: holding.currentValue,
            currentWeight: currentWeight,
          ),
        );
      }
    }

    final rows = <PortfolioDivergenceRow>[];
    for (final item in targetItems) {
      final key = normaliseIsin(item.isin);
      final matched = matchedByIsin[key];
      final current = matched?.value ?? 0.0;
      rows.add(
        PortfolioDivergenceRow(
          target: item,
          assetIds: matched?.assetIds ?? const [],
          targetValue: totalValue * item.targetWeight / 100.0,
          currentValue: current,
          currentWeight: totalValue <= 0 ? 0.0 : current / totalValue * 100,
        ),
      );
    }

    return PortfolioDivergence(
      pillar: pillar,
      model: model,
      resolvedValue: totalValue,
      rows: rows,
      extraHoldings: extras,
      unresolvedHoldings: holdings.unresolved,
    );
  }

  Future<void> _insertItems(String modelId, List<PortfolioModelInputItem> rawItems) async {
    final items = rawItems.map((item) => item.normalised()).toList();
    await _db.batch((batch) {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        batch.insert(
          _db.portfolioModelItems,
          PortfolioModelItemsCompanion.insert(
            modelId: modelId,
            isin: item.isin,
            targetWeight: item.targetWeight,
            description: Value(item.description),
            sortOrder: Value(i),
          ),
        );
      }
    });
  }

  Future<({List<_ResolvedPillarHolding> resolved, List<PortfolioUnresolvedHolding> unresolved})> _resolvedHoldings(
    String pillarId,
    Map<int, double> marketValuesByAssetId,
  ) async {
    final assignments = await (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId))).get();
    final resolved = <_ResolvedPillarHolding>[];
    final unresolved = <PortfolioUnresolvedHolding>[];

    for (final assignment in assignments) {
      final asset = await (_db.select(_db.assets)..where((a) => a.id.equals(assignment.assetId))).getSingleOrNull();
      if (asset == null) continue;
      final totalQty = await _totalQuantity(asset.id);
      if (totalQty <= 0) {
        unresolved.add(
          PortfolioUnresolvedHolding(
            assetId: asset.id,
            assetName: asset.name,
            reason: 'no current quantity',
          ),
        );
        continue;
      }
      final fullMarketValue = marketValuesByAssetId[asset.id];
      if (fullMarketValue == null) {
        unresolved.add(
          PortfolioUnresolvedHolding(
            assetId: asset.id,
            assetName: asset.name,
            reason: 'missing price or FX rate',
          ),
        );
        continue;
      }
      resolved.add(
        _ResolvedPillarHolding(
          asset: asset,
          totalQuantity: totalQty,
          pillarQuantity: assignment.quantity,
          currentValue: fullMarketValue * (assignment.quantity / totalQty),
        ),
      );
    }
    return (resolved: resolved, unresolved: unresolved);
  }

  Future<double> _totalQuantity(int assetId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(CASE WHEN type = ? THEN ABS(COALESCE(quantity, 0)) '
          'WHEN type = ? THEN -ABS(COALESCE(quantity, 0)) ELSE 0 END), 0) AS qty '
          'FROM asset_events WHERE asset_id = ? AND quantity IS NOT NULL',
          variables: [
            Variable.withString(EventType.buy.name),
            Variable.withString(EventType.sell.name),
            Variable.withInt(assetId),
          ],
          readsFrom: {_db.assetEvents},
        )
        .getSingle();
    return row.read<double>('qty');
  }

  static ParsedPortfolioModel parseMarkdown(String markdown, {String? path}) {
    final lines = const LineSplitter().convert(markdown);
    final titleLine = lines.firstWhere(
      (line) => line.trimLeft().startsWith('#'),
      orElse: () => '',
    );
    final name = titleLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    final idLine = lines.firstWhere(
      (line) => line.trimLeft().startsWith('ID:'),
      orElse: () => '',
    );
    final idMatch = RegExp(r'ID:\s*`?([^`\s]+)`?').firstMatch(idLine);
    final id = idMatch?.group(1)?.trim();
    if (id == null || id.isEmpty) {
      throw PortfolioModelValidationException(['missing model ID${path == null ? '' : ' in $path'}']);
    }

    final items = <PortfolioModelInputItem>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
      final cells = trimmed.substring(1, trimmed.length - 1).split('|').map((cell) => cell.trim()).toList();
      if (cells.length < 3) continue;
      final first = cells[0].toLowerCase();
      if (first == 'isin' || first.replaceAll('-', '').isEmpty) continue;
      final weight = _parseWeight(cells[1]);
      if (weight == null) {
        throw PortfolioModelValidationException(['invalid weight "${cells[1]}" in $id']);
      }
      items.add(
        PortfolioModelInputItem(
          isin: cells[0],
          targetWeight: weight,
          description: cells.sublist(2).join(' | '),
        ),
      );
    }
    validateItems(items, context: id);

    final source = '$name ${path ?? ''} $id';
    final year = int.tryParse(RegExp(r'(20\d{2})').firstMatch(source)?.group(1) ?? '');
    final equity = int.tryParse(RegExp(r'(\d{1,3})\s*[-%]\s*equity', caseSensitive: false).firstMatch(source)?.group(1) ?? '');
    final variant = source.toLowerCase().contains('mini') ? PortfolioModelVariant.mini : PortfolioModelVariant.full;

    return ParsedPortfolioModel(
      id: id,
      name: name.isEmpty ? id : name,
      year: year,
      equityPercent: equity,
      variant: variant,
      items: items.map((item) => item.normalised()).toList(),
    );
  }

  @visibleForTesting
  static void validateItems(List<PortfolioModelInputItem> rawItems, {String? context}) {
    final errors = <String>[];
    if (rawItems.isEmpty) {
      errors.add('at least one item is required');
    }
    final seen = <String>{};
    var total = 0.0;
    for (var i = 0; i < rawItems.length; i++) {
      final row = rawItems[i].normalised();
      final rowLabel = context == null ? 'row ${i + 1}' : '$context row ${i + 1}';
      if (row.isin.isEmpty) {
        errors.add('$rowLabel: ISIN is required');
      } else if (!_isinPattern.hasMatch(row.isin)) {
        errors.add('$rowLabel: ISIN is malformed');
      }
      if (row.targetWeight <= 0) {
        errors.add('$rowLabel: weight must be positive');
      }
      if (!seen.add(row.isin)) {
        errors.add('$rowLabel: duplicate ISIN ${row.isin}');
      }
      total += row.targetWeight;
    }
    if ((total - 100).abs() > _weightTolerance) {
      errors.add('weights must sum to 100% (got ${total.toStringAsFixed(2)}%)');
    }
    if (errors.isNotEmpty) throw PortfolioModelValidationException(errors);
  }

  static double? _parseWeight(String raw) {
    final cleaned = raw.replaceAll('%', '').trim();
    return double.tryParse(cleaned);
  }
}

int _catalogPathCompare(String a, String b) {
  final pa = _catalogPathParts(a);
  final pb = _catalogPathParts(b);
  final year = pa.year.compareTo(pb.year);
  if (year != 0) return year;
  final equity = pa.equity.compareTo(pb.equity);
  if (equity != 0) return equity;
  if (pa.variant != pb.variant) {
    return pa.variant == PortfolioModelVariant.full ? -1 : 1;
  }
  return a.compareTo(b);
}

({int year, int equity, PortfolioModelVariant variant}) _catalogPathParts(String path) {
  final year = int.tryParse(RegExp(r'PortfolioModels/(\d{4})/').firstMatch(path)?.group(1) ?? '') ?? 0;
  final equity = int.tryParse(RegExp(r'/(\d+)-equity/').firstMatch(path)?.group(1) ?? '') ?? 0;
  final variant = path.endsWith('/mini-portfolio.md') ? PortfolioModelVariant.mini : PortfolioModelVariant.full;
  return (year: year, equity: equity, variant: variant);
}
