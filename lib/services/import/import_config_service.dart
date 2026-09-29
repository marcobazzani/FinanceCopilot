import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('ImportConfigService');

/// The scope an [ImportConfig] is keyed by. Each import mode persists its
/// mapping/transform/type-tag setup under a different natural key:
/// - transaction → accountId
/// - assetByIsin → intermediaryId (assets are created under the intermediary)
/// - assetSingle → assetId (the single target asset; intermediary implied)
/// - income      → a single global config (no key)
enum ImportConfigScope { transaction, assetByIsin, assetSingle, income }

extension ImportConfigScopeName on ImportConfigScope {
  String get wire => switch (this) {
    ImportConfigScope.transaction => 'transaction',
    ImportConfigScope.assetByIsin => 'assetByIsin',
    ImportConfigScope.assetSingle => 'assetSingle',
    ImportConfigScope.income => 'income',
  };
}

class ImportConfigService {
  final AppDatabase _db;

  ImportConfigService(this._db);

  /// Load saved import config for an account (transaction scope). Returns
  /// null if none saved. Kept for backwards compatibility with callers that
  /// only deal with account-scoped transaction imports.
  Future<ImportConfig?> getByAccount(int accountId) => _getScoped(ImportConfigScope.transaction, accountId: accountId);

  /// Load the config for an intermediary-scoped asset-event (byIsin) import.
  Future<ImportConfig?> getByIntermediary(int intermediaryId) => _getScoped(ImportConfigScope.assetByIsin, intermediaryId: intermediaryId);

  /// Load the config for a single-asset-scoped asset-event import.
  Future<ImportConfig?> getByAsset(int assetId) => _getScoped(ImportConfigScope.assetSingle, assetId: assetId);

  /// Load the single global income import config.
  Future<ImportConfig?> getIncome() => _getScoped(ImportConfigScope.income);

  Future<ImportConfig?> _getScoped(
    ImportConfigScope scope, {
    int? accountId,
    int? intermediaryId,
    int? assetId,
  }) async {
    // A scoped config without the id its scope is keyed by is a caller bug:
    // say which id is missing instead of crashing inside the query.
    int keyOf(String name, int? value) => value ?? (throw ArgumentError.value(value, name, 'required by a ${scope.wire} import config'));
    final query = _db.select(_db.importConfigs)
      ..where((c) {
        final inScope = c.scope.equals(scope.wire);
        return switch (scope) {
          ImportConfigScope.transaction => inScope & c.accountId.equals(keyOf('accountId', accountId)),
          ImportConfigScope.assetByIsin => inScope & c.intermediaryId.equals(keyOf('intermediaryId', intermediaryId)),
          ImportConfigScope.assetSingle => inScope & c.assetId.equals(keyOf('assetId', assetId)),
          ImportConfigScope.income => inScope,
        };
      });
    final results = await query.get();
    if (results.isEmpty) return null;
    return results.first;
  }

  /// Save or update an account-scoped (transaction) import config.
  Future<void> save({
    required int accountId,
    required int skipRows,
    required Map<String, String?> mappings,
    required List<Map<String, String>> formula,
    required List<String> hashColumns,
    String? numberLocale,
  }) => saveScoped(
    scope: ImportConfigScope.transaction,
    accountId: accountId,
    skipRows: skipRows,
    mappings: mappings,
    formula: formula,
    hashColumns: hashColumns,
    numberLocale: numberLocale,
  );

  /// Save or update an import config in any [scope]. Exactly one of
  /// accountId/intermediaryId/assetId must be set for a scoped config (income
  /// uses none); an [ArgumentError] names the one [scope] needs when it is
  /// missing. Upserts on the (scope, key) tuple.
  ///
  /// A null [numberLocale] is the wizard's "Auto": no choice, so an existing
  /// config keeps its stored format (the one its rows were read with); only an
  /// explicit format replaces it.
  Future<void> saveScoped({
    required ImportConfigScope scope,
    int? accountId,
    int? intermediaryId,
    int? assetId,
    required int skipRows,
    required Map<String, String?> mappings,
    required List<Map<String, String>> formula,
    required List<String> hashColumns,
    String? numberLocale,
  }) async {
    final mappingsJson = jsonEncode(mappings);
    final formulaJson = jsonEncode(formula);
    final hashColumnsJson = jsonEncode(hashColumns);

    final existing = await _getScoped(
      scope,
      accountId: accountId,
      intermediaryId: intermediaryId,
      assetId: assetId,
    );
    if (existing != null) {
      _log.info('saveScoped: updating ${scope.wire} config (id=${existing.id})');
      await (_db.update(_db.importConfigs)..where((c) => c.id.equals(existing.id))).write(
        ImportConfigsCompanion(
          skipRows: Value(skipRows),
          mappingsJson: Value(mappingsJson),
          formulaJson: Value(formulaJson),
          hashColumnsJson: Value(hashColumnsJson),
          numberLocale: numberLocale == null ? const Value.absent() : Value(numberLocale),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      _log.info('saveScoped: creating ${scope.wire} config');
      await _db
          .into(_db.importConfigs)
          .insert(
            ImportConfigsCompanion.insert(
              accountId: Value(accountId),
              intermediaryId: Value(intermediaryId),
              assetId: Value(assetId),
              scope: Value(scope.wire),
              skipRows: Value(skipRows),
              mappingsJson: Value(mappingsJson),
              formulaJson: Value(formulaJson),
              hashColumnsJson: Value(hashColumnsJson),
              numberLocale: Value(numberLocale),
            ),
          );
    }
  }
}
