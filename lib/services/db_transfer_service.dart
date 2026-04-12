import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

final _log = getLogger('DbTransferService');

class DbTransferService {
  /// Get the internal DB file path.
  static Future<String> get dbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'finance_copilot.db');
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

    final result = await FilePicker.platform.saveFile(
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

  /// Import a user-selected DB file, replacing the internal DB.
  /// Returns the import source path on success, null if cancelled.
  /// The caller must close the current DB before calling this,
  /// and reload the DB provider after.
  static Future<String?> importDb() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Database',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (picked == null || picked.files.isEmpty) return null;

    final sourcePath = picked.files.single.path;
    if (sourcePath == null) return null;

    final targetPath = await dbPath;

    try {
      // Overwrite internal DB with the selected file
      final target = File(targetPath);
      if (await target.exists()) await target.delete();
      await File(sourcePath).copy(targetPath);
      _log.info('importDb: imported from $sourcePath');
      return sourcePath;
    } catch (e) {
      _log.severe('importDb: failed to copy: $e');
      rethrow;
    }
  }
}
