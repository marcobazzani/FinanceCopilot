import 'dart:io';
import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;

import '../utils/logger.dart';
import 'import_service.dart' show FilePreview;

final _log = getLogger('FileParserService');

// ──────────────────────────────────────────────
// Top-level functions for isolate parsing
// ──────────────────────────────────────────────

FilePreview _parseCsvIsolate(Map<String, dynamic> args) {
  final content = args['content'] as String;
  final separator = args['separator'] as String?;
  final skipRows = args['skipRows'] as int;
  final noHeader = args['noHeader'] as bool? ?? false;

  // Auto-detect separator
  final firstLine = content.split('\n').first;
  final semicolons = ';'.allMatches(firstLine).length;
  final commas = ','.allMatches(firstLine).length;
  final tabs = '\t'.allMatches(firstLine).length;
  final sep = separator ?? (tabs > commas && tabs > semicolons ? '\t' : semicolons > commas ? ';' : ',');

  final rows = Csv(fieldDelimiter: sep, lineDelimiter: '\n').decode(content);
  if (rows.isEmpty) return const FilePreview(columns: [], rows: [], totalRows: 0);

  var nonEmptyRows = rows.where((row) => row.any((cell) => cell.toString().trim().isNotEmpty)).toList();
  if (nonEmptyRows.isEmpty) return const FilePreview(columns: [], rows: [], totalRows: 0);

  if (skipRows > 0 && skipRows < nonEmptyRows.length) {
    nonEmptyRows = nonEmptyRows.sublist(skipRows);
  }

  final List<String> columns;
  final List<Map<String, String>> dataRows;

  if (noHeader) {
    final colCount = nonEmptyRows.first.length;
    columns = List.generate(colCount, (i) => 'Column ${i + 1}');
    dataRows = nonEmptyRows.map((row) {
      final map = <String, String>{};
      for (var i = 0; i < columns.length && i < row.length; i++) {
        map[columns[i]] = row[i].toString().trim();
      }
      return map;
    }).toList();
  } else {
    columns = nonEmptyRows.first.map((e) => e.toString().trim()).toList();
    dataRows = nonEmptyRows.skip(1).map((row) {
      final map = <String, String>{};
      for (var i = 0; i < columns.length && i < row.length; i++) {
        map[columns[i]] = row[i].toString().trim();
      }
      return map;
    }).toList();
  }

  return FilePreview(columns: columns, rows: dataRows, totalRows: dataRows.length);
}

FilePreview _parseExcelIsolate(Map<String, dynamic> args) {
  final bytes = args['bytes'] as List<int>;
  final sheetName = args['sheetName'] as String?;
  final skipRows = args['skipRows'] as int;
  final noHeader = args['noHeader'] as bool? ?? false;

  final excel = xl.Excel.decodeBytes(bytes);
  final sheet = sheetName != null ? excel.tables[sheetName] : excel.tables.values.first;

  if (sheet == null || sheet.rows.isEmpty) {
    return const FilePreview(columns: [], rows: [], totalRows: 0);
  }

  final effectiveRows = skipRows > 0 && skipRows < sheet.rows.length
      ? sheet.rows.sublist(skipRows)
      : sheet.rows;

  if (effectiveRows.isEmpty) return const FilePreview(columns: [], rows: [], totalRows: 0);

  final List<String> columns;
  final List<Map<String, String>> dataRows;

  if (noHeader) {
    final colCount = effectiveRows.first.length;
    columns = List.generate(colCount, (i) => 'Column ${i + 1}');
    dataRows = effectiveRows.map((row) {
      final map = <String, String>{};
      for (var i = 0; i < columns.length && i < row.length; i++) {
        map[columns[i]] = row[i]?.value?.toString().trim() ?? '';
      }
      return map;
    }).toList();
  } else {
    final headerRow = effectiveRows.first;
    columns = headerRow.map((cell) => cell?.value?.toString().trim() ?? '').toList();
    dataRows = effectiveRows.skip(1).map((row) {
      final map = <String, String>{};
      for (var i = 0; i < columns.length && i < row.length; i++) {
        map[columns[i]] = row[i]?.value?.toString().trim() ?? '';
      }
      return map;
    }).toList();
  }

  return FilePreview(columns: columns, rows: dataRows, totalRows: dataRows.length);
}

List<String> _listSheetsIsolate(List<int> bytes) {
  final excel = xl.Excel.decodeBytes(bytes);
  return excel.tables.keys.toList();
}

// ──────────────────────────────────────────────
// FileParserService — CSV/Excel/clipboard parsing
// ──────────────────────────────────────────────

class FileParserService {
  /// Parse a file and return a preview of columns + rows.
  /// Runs heavy parsing in a separate isolate to avoid UI jank.
  Future<FilePreview> parseFile(String filePath, {String? sheetName, int skipRows = 0, bool noHeader = false}) async {
    _log.info('parseFile: path=$filePath, sheet=$sheetName, skipRows=$skipRows, noHeader=$noHeader');
    final ext = filePath.toLowerCase().split('.').last;
    final FilePreview result;
    switch (ext) {
      case 'csv':
      case 'tsv':
        final content = await File(filePath).readAsString();
        result = await Isolate.run(() => _parseCsvIsolate({
          'content': content,
          'separator': ext == 'tsv' ? '\t' : null,
          'skipRows': skipRows,
          'noHeader': noHeader,
        }));
      case 'xlsx':
      case 'xls':
        final bytes = await File(filePath).readAsBytes();
        result = await Isolate.run(() => _parseExcelIsolate({
          'bytes': bytes,
          'sheetName': sheetName,
          'skipRows': skipRows,
          'noHeader': noHeader,
        }));
      default:
        throw UnsupportedError('Unsupported file format: .$ext');
    }
    // Cap rows for preview (first 5 + last 5) to save memory; import re-parses
    final previewRows = _capPreviewRows(result.rows);
    _log.info('parseFile: parsed ${result.columns.length} columns, ${result.totalRows} rows (preview: ${previewRows.length})');
    return FilePreview(
      columns: result.columns,
      rows: previewRows,
      totalRows: result.totalRows,
      filePath: filePath,
      skipRows: skipRows,
      noHeader: noHeader,
      sheetName: sheetName,
    );
  }

  /// List available sheet names in an Excel file (runs in isolate).
  Future<List<String>> listSheets(String filePath) async {
    _log.fine('listSheets: $filePath');
    final bytes = await File(filePath).readAsBytes();
    final sheets = await Isolate.run(() => _listSheetsIsolate(bytes));
    _log.info('listSheets: found ${sheets.length} sheets: $sheets');
    return sheets;
  }

  /// Parse clipboard/pasted text as CSV/TSV → FilePreview.
  Future<FilePreview> parseClipboard(String text, {int skipRows = 0, bool noHeader = false}) async {
    _log.info('parseClipboard: ${text.length} chars, skipRows=$skipRows, noHeader=$noHeader');
    final result = await Isolate.run(() => _parseCsvIsolate({
      'content': text,
      'separator': null, // auto-detect
      'skipRows': skipRows,
      'noHeader': noHeader,
    }));
    final previewRows = _capPreviewRows(result.rows);
    _log.info('parseClipboard: parsed ${result.columns.length} columns, ${result.totalRows} rows (preview: ${previewRows.length})');
    return FilePreview(
      columns: result.columns,
      rows: previewRows,
      totalRows: result.totalRows,
      clipboardText: text,
      skipRows: skipRows,
      noHeader: noHeader,
    );
  }

  /// Cap rows to first 5 + last 5 for preview display. Saves memory for large files.
  static List<Map<String, String>> _capPreviewRows(List<Map<String, String>> rows, {int headTail = 5}) {
    if (rows.length <= headTail * 2) return rows;
    return [...rows.take(headTail), ...rows.skip(rows.length - headTail)];
  }

  /// Re-parse the full file to get ALL rows (for import, not preview).
  /// Returns a FilePreview with all rows — only call this during import.
  Future<FilePreview> getFullRows(FilePreview preview) async {
    // If preview already has all rows (small file), return as-is
    if (preview.rows.length >= preview.totalRows) return preview;

    _log.info('getFullRows: re-parsing ${preview.totalRows} rows from source');
    if (preview.filePath != null) {
      final ext = preview.filePath!.toLowerCase().split('.').last;
      switch (ext) {
        case 'csv':
        case 'tsv':
          final content = await File(preview.filePath!).readAsString();
          return Isolate.run(() => _parseCsvIsolate({
            'content': content,
            'separator': ext == 'tsv' ? '\t' : null,
            'skipRows': preview.skipRows,
            'noHeader': preview.noHeader,
          }));
        case 'xlsx':
        case 'xls':
          final bytes = await File(preview.filePath!).readAsBytes();
          return Isolate.run(() => _parseExcelIsolate({
            'bytes': bytes,
            'sheetName': preview.sheetName,
            'skipRows': preview.skipRows,
            'noHeader': preview.noHeader,
          }));
      }
    } else if (preview.clipboardText != null) {
      return Isolate.run(() => _parseCsvIsolate({
        'content': preview.clipboardText!,
        'separator': null,
        'skipRows': preview.skipRows,
        'noHeader': preview.noHeader,
      }));
    }
    return preview;
  }
}
