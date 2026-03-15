import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/logger.dart';

final _log = getLogger('ImportConfigService');

class ImportConfigService {
  final AppDatabase _db;

  ImportConfigService(this._db);

  /// Load saved import config for an account. Returns null if none saved.
  Future<ImportConfig?> getByAccount(int accountId) async {
    final query = _db.select(_db.importConfigs)
      ..where((c) => c.accountId.equals(accountId));
    final results = await query.get();
    if (results.isEmpty) return null;
    _log.fine('getByAccount: loaded config for account $accountId');
    return results.first;
  }

  /// Save or update import config for an account.
  Future<void> save({
    required int accountId,
    required int skipRows,
    required Map<String, String?> mappings,
    required List<Map<String, String>> formula,
    required List<String> hashColumns,
  }) async {
    final mappingsJson = jsonEncode(mappings);
    final formulaJson = jsonEncode(formula);
    final hashColumnsJson = jsonEncode(hashColumns);

    // Check if config exists
    final existing = await getByAccount(accountId);
    if (existing != null) {
      _log.info('save: updating config for account $accountId');
      await (_db.update(_db.importConfigs)
            ..where((c) => c.accountId.equals(accountId)))
          .write(ImportConfigsCompanion(
        skipRows: Value(skipRows),
        mappingsJson: Value(mappingsJson),
        formulaJson: Value(formulaJson),
        hashColumnsJson: Value(hashColumnsJson),
        updatedAt: Value(DateTime.now()),
      ));
    } else {
      _log.info('save: creating config for account $accountId');
      await _db.into(_db.importConfigs).insert(ImportConfigsCompanion.insert(
            accountId: accountId,
            skipRows: Value(skipRows),
            mappingsJson: Value(mappingsJson),
            formulaJson: Value(formulaJson),
            hashColumnsJson: Value(hashColumnsJson),
          ));
    }
  }
}
