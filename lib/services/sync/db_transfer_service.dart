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
  ///
  /// Exports a `VACUUM INTO` snapshot (see [AppDatabase.snapshotToTempFile])
  /// rather than the live DB file: reading the live file directly could
  /// capture a torn copy mid-write (background price sync, an in-progress
  /// import, etc.), producing an export that looks fine but is silently
  /// inconsistent. The snapshot's bytes are passed to [FilePicker.saveFile]
  /// so this also works on Android/iOS, where the plugin performs the
  /// actual write itself and requires `bytes` up front — a bare
  /// `saveFile(...)` call without `bytes` throws on those platforms.
  ///
  /// [dialogTitle] titles the picker, in the UI language.
  ///
  /// Returns the export path on success, null if cancelled.
  static Future<String?> exportDb(AppDatabase db, {required String dialogTitle}) async {
    final snapshotPath = await db.snapshotToTempFile();
    try {
      final bytes = await File(snapshotPath).readAsBytes();
      final saved = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: 'FinanceCopilot.db',
        type: FileType.any,
        bytes: bytes,
      );
      if (saved == null) return null;
      // A file on disk reads as its path; a platform document (e.g. an
      // Android content URI) as its URI.
      final result = saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
      _log.info('exportDb: exported to $result');
      return result;
    } catch (e) {
      _log.severe('exportDb: failed to export: $e');
      rethrow;
    } finally {
      try {
        await File(snapshotPath).delete();
      } catch (e) {
        _log.warning('exportDb: failed to delete snapshot tmp file (harmless): $e');
      }
    }
  }

  /// Pick a user-selected DB file and merge it into the currently-open DB.
  ///
  /// Uses SQLite ATTACH via [AppDatabase.mergeFromAttachedDb] instead of
  /// replacing the database file. This keeps the import safe while Drift has
  /// active stream subscribers and avoids Windows file-lock failures.
  /// [dialogTitle] titles the picker, in the UI language.
  /// Returns the import source path on success, null if cancelled.
  static Future<String?> importDb(AppDatabase db, {required String dialogTitle}) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    final sourcePath = picked?.path;
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
