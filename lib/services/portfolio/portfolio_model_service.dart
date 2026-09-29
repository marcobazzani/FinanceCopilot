import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/uuid_v7.dart';

final _log = getLogger('PortfolioModelService');

const _modelCatalogRoot = 'PortfolioModels/';
const _weightTolerance = 0.05;
final _isinPattern = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');

/// What a portfolio model check found wrong.
enum PortfolioModelIssueKind {
  /// A custom model without a name.
  nameRequired,

  /// A catalog file without a model ID.
  missingId,

  /// A catalog row whose weight does not read as a number.
  invalidWeight,

  /// A model without items.
  noItems,

  /// A row without an ISIN.
  isinRequired,

  /// A row whose ISIN is not one.
  isinMalformed,

  /// A row whose weight is zero or negative.
  weightNotPositive,

  /// A row repeating the ISIN of an earlier one.
  duplicateIsin,

  /// Weights not summing to 100%.
  weightsTotal,
}

/// One problem a portfolio model check found: its [kind]; for a row, the
/// 1-based [row] and the model it is numbered in ([context], when given; the
/// model ID for [PortfolioModelIssueKind.invalidWeight]); what it names
/// ([value]: the duplicate ISIN, the unreadable weight, the catalog file
/// without an ID) and, for [PortfolioModelIssueKind.weightsTotal], the
/// weights' [total].
class PortfolioModelIssue {
  final PortfolioModelIssueKind kind;
  final int? row;
  final String? context;
  final String? value;
  final double? total;

  const PortfolioModelIssue(this.kind, {this.row, this.context, this.value, this.total});

  /// This problem worded by [s], its number written by [number].
  String _text(AppStrings s, String Function(double) number) {
    final rowLabel = row == null ? '' : s.portfolioModelRow(row!, context);
    return switch (kind) {
      PortfolioModelIssueKind.nameRequired => s.portfolioModelNameRequired,
      PortfolioModelIssueKind.missingId => s.portfolioModelMissingId(value),
      PortfolioModelIssueKind.invalidWeight => s.portfolioModelInvalidWeight(value!, context!),
      PortfolioModelIssueKind.noItems => s.portfolioModelNoItems,
      PortfolioModelIssueKind.isinRequired => s.portfolioModelIsinRequired(rowLabel),
      PortfolioModelIssueKind.isinMalformed => s.portfolioModelIsinMalformed(rowLabel),
      PortfolioModelIssueKind.weightNotPositive => s.portfolioModelWeightNotPositive(rowLabel),
      PortfolioModelIssueKind.duplicateIsin => s.portfolioModelDuplicateIsin(rowLabel, value!),
      PortfolioModelIssueKind.weightsTotal => s.portfolioModelWeightsTotal(number(total!)),
    };
  }
}

class PortfolioModelValidationException implements Exception {
  final List<PortfolioModelIssue> issues;
  const PortfolioModelValidationException(this.issues);

  /// The problems in English, as the checks word them.
  List<String> get messages => [for (final issue in issues) issue._text(AppStrings.en, (v) => v.toStringAsFixed(2))];

  /// The problems in the language of [s], the weights' total written in the
  /// display [locale].
  List<String> localizedMessages(AppStrings s, {required String locale}) {
    final number = NumberFormat('0.00', locale);
    return [for (final issue in issues) issue._text(s, number.format)];
  }

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
  final String? preferredTicker;
  final String? preferredExchange;

  const PortfolioModelInputItem({
    required this.isin,
    required this.targetWeight,
    this.description = '',
    this.preferredTicker,
    this.preferredExchange,
  });

  PortfolioModelInputItem normalised() => PortfolioModelInputItem(
    isin: normaliseIsin(isin),
    targetWeight: targetWeight,
    description: description.trim(),
    preferredTicker: _blankToNull(preferredTicker?.trim()),
    preferredExchange: _blankToNull(preferredExchange?.trim()),
  );
}

String? _blankToNull(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
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
  final double currentValue;
  final double currentWeight;

  const PortfolioDivergenceRow({
    required this.target,
    required this.assetIds,
    required this.currentValue,
    required this.currentWeight,
  });

  bool get isUnmatched => assetIds.isEmpty;
}

class PortfolioDivergence {
  final Pillar pillar;
  final PortfolioModel model;
  final List<PortfolioDivergenceRow> rows;
  final List<PortfolioExtraHolding> extraHoldings;

  const PortfolioDivergence({
    required this.pillar,
    required this.model,
    required this.rows,
    required this.extraHoldings,
  });
}

class _ResolvedPillarHolding {
  final Asset asset;
  final double currentValue;

  const _ResolvedPillarHolding({
    required this.asset,
    required this.currentValue,
  });

  String? get normalisedIsin {
    final isin = asset.isin?.trim();
    if (isin == null || isin.isEmpty) return null;
    return normaliseIsin(isin);
  }
}

String normaliseIsin(String value) => value.trim().toUpperCase();

/// Whether [value] is exactly an ISIN: two letters, nine letters or digits and
/// a check digit. Case-sensitive: callers pass upper-cased text.
bool isIsin(String value) => _isinPattern.hasMatch(value);

/// The key an instrument resolved for the search [query] is cached under: the
/// query upper-cased when it is an ISIN, otherwise exactly as typed.
String isinCacheKey(String query) {
  final upper = query.toUpperCase();
  return isIsin(upper) ? upper : query;
}

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
      throw const PortfolioModelValidationException([PortfolioModelIssue(PortfolioModelIssueKind.nameRequired)]);
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
      throw const PortfolioModelValidationException([PortfolioModelIssue(PortfolioModelIssueKind.nameRequired)]);
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
    final resolved = await _resolvedHoldings(pillarId, marketValuesByAssetId);
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
          currentValue: current,
          currentWeight: totalValue <= 0 ? 0.0 : current / totalValue * 100,
        ),
      );
    }

    return PortfolioDivergence(
      pillar: pillar,
      model: model,
      rows: rows,
      extraHoldings: extras,
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
            preferredTicker: Value(item.preferredTicker),
            preferredExchange: Value(item.preferredExchange),
            sortOrder: Value(i),
          ),
        );
      }
    });
  }

  /// The pillar's holdings with a current quantity and a market value, at the
  /// pillar's share of that value. One without either has no value to weigh.
  Future<List<_ResolvedPillarHolding>> _resolvedHoldings(
    String pillarId,
    Map<int, double> marketValuesByAssetId,
  ) async {
    final assignments = await (_db.select(_db.pillarAssets)..where((pa) => pa.pillarId.equals(pillarId))).get();
    final resolved = <_ResolvedPillarHolding>[];

    for (final assignment in assignments) {
      final asset = await (_db.select(_db.assets)..where((a) => a.id.equals(assignment.assetId))).getSingleOrNull();
      if (asset == null) continue;
      final totalQty = await _totalQuantity(asset.id);
      if (totalQty <= 0) continue;
      final fullMarketValue = marketValuesByAssetId[asset.id];
      if (fullMarketValue == null) continue;
      resolved.add(
        _ResolvedPillarHolding(
          asset: asset,
          currentValue: fullMarketValue * (assignment.quantity / totalQty),
        ),
      );
    }
    return resolved;
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
      throw PortfolioModelValidationException([PortfolioModelIssue(PortfolioModelIssueKind.missingId, value: path)]);
    }

    final items = <PortfolioModelInputItem>[];
    List<String>? headers;
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
      final cells = trimmed.substring(1, trimmed.length - 1).split('|').map((cell) => cell.trim()).toList();
      if (cells.length < 3) continue;
      final first = cells[0].toLowerCase();
      if (first == 'isin') {
        headers = cells.map((cell) => cell.toLowerCase()).toList();
        continue;
      }
      if (first.replaceAll('-', '').isEmpty) continue;
      final weight = _parseWeight(cells[1]);
      if (weight == null) {
        throw PortfolioModelValidationException([PortfolioModelIssue(PortfolioModelIssueKind.invalidWeight, value: cells[1], context: id)]);
      }
      String? headerValue(List<String> names) {
        final currentHeaders = headers;
        if (currentHeaders == null) return null;
        for (final name in names) {
          final index = currentHeaders.indexOf(name);
          if (index >= 0 && index < cells.length) return cells[index];
        }
        return null;
      }

      final description = headerValue(const ['description', 'asset', 'name']) ?? cells.sublist(2).join(' | ');
      items.add(
        PortfolioModelInputItem(
          isin: cells[0],
          targetWeight: weight,
          description: description,
          preferredTicker: headerValue(const ['ticker', 'preferred ticker']),
          preferredExchange: headerValue(const ['exchange', 'preferred exchange']),
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
    final errors = <PortfolioModelIssue>[];
    if (rawItems.isEmpty) {
      errors.add(const PortfolioModelIssue(PortfolioModelIssueKind.noItems));
    }
    final seen = <String>{};
    var total = 0.0;
    for (var i = 0; i < rawItems.length; i++) {
      final row = rawItems[i].normalised();
      PortfolioModelIssue issue(PortfolioModelIssueKind kind, {String? value}) =>
          PortfolioModelIssue(kind, row: i + 1, context: context, value: value);
      if (row.isin.isEmpty) {
        errors.add(issue(PortfolioModelIssueKind.isinRequired));
      } else if (!isIsin(row.isin)) {
        errors.add(issue(PortfolioModelIssueKind.isinMalformed));
      }
      if (row.targetWeight <= 0) {
        errors.add(issue(PortfolioModelIssueKind.weightNotPositive));
      }
      if (!seen.add(row.isin)) {
        errors.add(issue(PortfolioModelIssueKind.duplicateIsin, value: row.isin));
      }
      total += row.targetWeight;
    }
    if ((total - 100).abs() > _weightTolerance) {
      errors.add(PortfolioModelIssue(PortfolioModelIssueKind.weightsTotal, total: total));
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
