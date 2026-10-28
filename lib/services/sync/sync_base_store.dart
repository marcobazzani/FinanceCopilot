import 'dart:convert';

import 'package:finance_copilot/database/db_file_name.dart';
import 'package:finance_copilot/services/app_settings.dart';
import 'package:finance_copilot/services/sync/backup_sync_status.dart';

/// Where a device keeps its last backup or restore ([SyncBase]) for each
/// Google account.
abstract interface class SyncBaseStore {
  Future<SyncBase?> read(String account);
  Future<void> write(String account, SyncBase base);

  /// Forgets every account's sync: the database starts over.
  Future<void> clear();
}

/// [SyncBaseStore] in the device's settings file, one entry per database
/// file: dev and prod builds share the settings file, never a sync base.
class SettingsSyncBaseStore implements SyncBaseStore {
  /// [databaseName] defaults to the build's database file name.
  const SettingsSyncBaseStore({String? databaseName}) : _databaseName = databaseName;

  final String? _databaseName;

  String get _key => 'driveSyncBase|${_databaseName ?? dbFileName}';

  Future<Map<String, Object?>> _all() async {
    final raw = await AppSettings.get(_key);
    if (raw == null || raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, Object?>;
  }

  @override
  Future<SyncBase?> read(String account) async {
    final entry = (await _all())[account];
    return entry is Map<String, Object?> ? SyncBase.fromJson(entry) : null;
  }

  @override
  Future<void> write(String account, SyncBase base) async {
    final all = await _all();
    all[account] = base.toJson();
    await AppSettings.set(_key, jsonEncode(all));
  }

  @override
  Future<void> clear() => AppSettings.set(_key, '');
}
