import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/db_file_name.dart';
import 'package:finance_copilot/utils/logger.dart';

final _log = getLogger('DbTransferService');

class DbTransferService {
  /// Get the internal DB file path.
  static Future<String> get dbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, dbFileName);
  }

  /// Export the internal DB to a user-chosen location.
  /// Returns the export path on success, null if cancelled.
  static Future<String?> exportDb() async {
    final path = await dbPath;
    final file = File(path);
    if (!await file.exists()) {
      _log.warning('exportDb: DB file not found at $path');
      return null;
    }

    final result = await FilePicker.saveFile(
      dialogTitle: 'Export Database',
      fileName: 'FinanceCopilot.db',
      type: FileType.any,
    );
    if (result == null) return null;

    try {
      final target = File(result);
      if (await target.exists()) await target.delete();
      await file.copy(result);
      _log.info('exportDb: exported to $result');
      return result;
    } catch (e) {
      _log.severe('exportDb: failed to copy: $e');
      rethrow;
    }
  }

  /// Pick a user-selected DB file and merge it into the currently-open DB.
  ///
  /// Uses SQLite ATTACH via [AppDatabase.mergeFromAttachedDb] instead of
  /// replacing the database file. This keeps the import safe while Drift has
  /// active stream subscribers and avoids Windows file-lock failures.
  /// Returns the import source path on success, null if cancelled.
  static Future<String?> importDb(AppDatabase db) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Import Database',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final sourcePath = picked.files.single.path;
    if (sourcePath == null) return null;

    return importDbFromPath(db, sourcePath);
  }

  /// Merge a database file into [db] without replacing the open SQLite file.
  static Future<String> importDbFromPath(
    AppDatabase db,
    String sourcePath,
  ) async {
    try {
      await db.mergeFromAttachedDb(sourcePath);
      _log.info('importDb: merged from $sourcePath');
      return sourcePath;
    } catch (e) {
      _log.severe('importDb: failed to merge: $e');
      rethrow;
    }
  }
}
