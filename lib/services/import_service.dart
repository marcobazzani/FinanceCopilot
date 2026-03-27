import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart' as xl;

import '../database/database.dart';
import '../database/tables.dart';
import '../utils/amount_parser.dart' as amt;
import '../utils/formatters.dart' show monthMap;
import '../utils/logger.dart';
import 'exchange_rate_service.dart';
import 'isin_lookup_service.dart';

final _log = getLogger('ImportService');

/// A single term in a formula: an operator (+/-) and a source column.
class FormulaTerm {
  final String operator; // '+' or '-'
  final String sourceColumn;

  const FormulaTerm({required this.operator, required this.sourceColumn});
}

/// Column mapping: user picks which source column maps to which target field.
/// For simple mappings, [sourceColumn] is set.
/// For formula mappings (e.g. amount = ColA + ColB), [formulaTerms] is set instead.
/// For balance-diff mode, [balanceDiffColumn] is set — amount is computed as
/// the difference between consecutive balance values.
class ColumnMapping {
  final String? sourceColumn;
  final String targetField; // e.g. 'date', 'amount', 'description', etc.
  final List<FormulaTerm>? formulaTerms;
  final String? balanceDiffColumn;
  final List<String>? multiColumns; // combine multiple columns (concat strings, sum numbers)
  final String multiDelimiter; // delimiter for string concatenation (default: space)

  const ColumnMapping({this.sourceColumn, required this.targetField, this.formulaTerms, this.balanceDiffColumn, this.multiColumns, this.multiDelimiter = ' '});

  bool get isFormula => formulaTerms != null && formulaTerms!.isNotEmpty;
  bool get isBalanceDiff => balanceDiffColumn != null;
  bool get isMultiColumn => multiColumns != null && multiColumns!.length > 1;
}

/// Result of parsing a file before column mapping.
class FilePreview {
  final List<String> columns;
  /// Preview rows for UI display (first 5 + last 5 = max 10).
  /// For full row access during import, re-parse the file.
  final List<Map<String, String>> rows;
  final int totalRows;

  /// Source file metadata for re-parsing during import.
  final String? filePath;
  final String? clipboardText;
  final int skipRows;
  final bool noHeader;
  final String? sheetName;

  const FilePreview({
    required this.columns,
    required this.rows,
    required this.totalRows,
    this.filePath,
    this.clipboardText,
    this.skipRows = 0,
    this.noHeader = false,
    this.sheetName,
  });
}

/// Result of an import operation.
class ImportResult {
  final int totalRows;
  final int importedRows;
  final int deletedRows;
  final int errorRows;
  final List<String> errors;

  const ImportResult({
    required this.totalRows,
    required this.importedRows,
    this.deletedRows = 0,
    required this.errorRows,
    this.errors = const [],
  });
}

/// Target entity type for import.
enum ImportTarget { transaction, assetEvent, income }

/// Result of an asset import that groups by ISIN.
class AssetImportResult {
  final ImportResult result;
  final Map<String, int> assetsByIsin; // ISIN → asset ID
  const AssetImportResult({required this.result, required this.assetsByIsin});
}

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

/// Generic file importer: reads CSV/XLSX/XLS, previews columns,
/// applies user column mapping, hashes rows for dedup, and inserts.
class ImportService {
  final AppDatabase _db;

  ImportService(this._db);

  // ──────────────────────────────────────────────
  // Step 1: Parse file → FilePreview
  // ──────────────────────────────────────────────

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

    _log.info('_getFullRows: re-parsing ${preview.totalRows} rows from source');
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

  // ──────────────────────────────────────────────
  // Helpers: mapping resolution
  // ──────────────────────────────────────────────

  /// Resolve a mapping value from a row: simple column lookup, formula, or multi-column.
  String? _resolveMapping(ColumnMapping mapping, Map<String, String> row) {
    if (mapping.isFormula) {
      return _evaluateFormula(mapping.formulaTerms!, row);
    }
    if (mapping.isMultiColumn) {
      return _resolveMultiColumn(mapping.multiColumns!, row, mapping.multiDelimiter);
    }
    return row[mapping.sourceColumn];
  }

  /// Combine multiple columns: if all values are numeric → sum, otherwise concatenate with delimiter.
  String _resolveMultiColumn(List<String> columns, Map<String, String> row, String delimiter) {
    final values = columns.map((c) => (row[c] ?? '').trim()).where((v) => v.isNotEmpty).toList();
    if (values.isEmpty) return '';

    // Try numeric sum
    final nums = values.map((v) => _tryParseAmount(v)).toList();
    if (nums.every((n) => n != null)) {
      return nums.fold(0.0, (a, b) => a + b!).toString();
    }

    // String concatenation with delimiter
    return values.join(delimiter);
  }

  /// Evaluate a formula: sum of terms (each term is +/- a column's numeric value).
  String _evaluateFormula(List<FormulaTerm> terms, Map<String, String> row) {
    double result = 0;
    for (final term in terms) {
      final raw = row[term.sourceColumn] ?? '';
      final value = _tryParseAmount(raw) ?? 0;
      if (term.operator == '-') {
        result -= value;
      } else {
        result += value;
      }
    }
    return result.toString();
  }

  // ──────────────────────────────────────────────
  // Step 3: Import with mapping + dedup
  // ──────────────────────────────────────────────

  /// Import rows as Transactions.
  /// Algorithm: find the oldest date in the CSV, delete all DB rows for this
  /// account from that date onward, then insert all CSV rows. This guarantees
  /// no orphan rows from previous imports with changed data.
  Future<ImportResult> importTransactions({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,
    void Function(int processed, int total)? onProgress,
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,
  }) async {
    _log.info('importTransactions: accountId=$accountId, ${preview.totalRows} rows, ${mappings.length} mappings');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      _log.severe('importTransactions: missing required mappings');
      return const ImportResult(
        totalRows: 0, importedRows: 0, errorRows: 0,
        errors: ['date and amount columns are required'],
      );
    }

    // Pre-compute balance-diff amounts if needed
    List<double>? balanceDiffAmounts;
    if (amountMapping.isBalanceDiff) {
      _log.info('importTransactions: balance-diff mode, column=${amountMapping.balanceDiffColumn}');
      final balCol = amountMapping.balanceDiffColumn!;
      balanceDiffAmounts = [];
      double? prevBalance;
      for (final row in preview.rows) {
        final raw = row[balCol] ?? '';
        final balance = _tryParseAmount(raw);
        if (balance != null && prevBalance != null) {
          balanceDiffAmounts.add(balance - prevBalance);
        } else {
          balanceDiffAmounts.add(balance ?? 0);
        }
        prevBalance = balance;
      }
    }

    // Pre-resolve field mappings once
    final descMapping = mappingByField['description'];
    final balanceMapping = mappingByField['balanceAfter'];
    final currencyMapping = mappingByField['currency'];
    final valueDateMapping = mappingByField['valueDate'];
    final statusMapping = mappingByField['status'];

    // Parse all rows
    var imported = 0;
    var errorCount = 0;
    final errors = <String>[];
    final parsedRows = <_ParsedTransactionRow>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final dateStr = _resolveMapping(dateMapping, row) ?? '';
        final double amount;
        if (balanceDiffAmounts != null) {
          amount = balanceDiffAmounts[i];
        } else {
          final amountStr = _resolveMapping(amountMapping, row) ?? '';
          amount = _parseAmount(amountStr);
        }
        final date = _parseDate(dateStr);

        final rawMetadata = <String, String>{};
        for (final col in preview.columns) {
          rawMetadata[col] = row[col] ?? '';
        }

        DateTime? valueDate;
        if (valueDateMapping != null) {
          final vdStr = _resolveMapping(valueDateMapping, row);
          if (vdStr != null && vdStr.isNotEmpty) {
            try { valueDate = _parseDate(vdStr); } catch (_) {}
          }
        }

        TransactionStatus? txStatus;
        if (statusMapping != null) {
          final sStr = (_resolveMapping(statusMapping, row) ?? '').toLowerCase().trim();
          txStatus = TransactionStatus.values.where((s) => s.name.toLowerCase() == sStr).firstOrNull;
        }

        parsedRows.add(_ParsedTransactionRow(
          date: date,
          valueDate: valueDate,
          amount: amount,
          description: descMapping != null ? (_resolveMapping(descMapping, row) ?? '') : '',
          balanceAfterFromColumn: balanceMapping != null ? _tryParseAmount(_resolveMapping(balanceMapping, row)) : null,
          currency: currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? 'EUR') : 'EUR',
          status: txStatus,
          rawMetadata: rawMetadata,
          hash: null,
          filterColumnValue: balanceFilterColumn != null ? (row[balanceFilterColumn] ?? '').trim() : null,
          csvIndex: i,
        ));
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importTransactions: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    if (parsedRows.isEmpty) {
      return ImportResult(totalRows: preview.totalRows, importedRows: 0, errorRows: errorCount, errors: errors);
    }

    // Compute balanceAfter
    _computeBalances(parsedRows, balanceMode, balanceFilterInclude);

    // Find the oldest date in the parsed rows
    final oldestDate = parsedRows.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final cutoffEpoch = DateTime(oldestDate.year, oldestDate.month, oldestDate.day).millisecondsSinceEpoch ~/ 1000;

    // Delete all DB rows for this account from oldest CSV date onward
    final deleted = await _db.customUpdate(
      'DELETE FROM transactions WHERE account_id = ? AND operation_date >= ?',
      variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
      updates: {_db.transactions},
    );
    _log.info('importTransactions: deleted $deleted rows from ${oldestDate.toIso8601String().substring(0, 10)} onward');

    // Report parsing complete, starting DB write
    onProgress?.call(preview.rows.length, preview.rows.length);

    // Batch insert all parsed rows
    final companions = parsedRows.map((r) => TransactionsCompanion.insert(
      accountId: accountId,
      operationDate: r.date,
      valueDate: r.valueDate ?? r.date,
      amount: r.amount,
      description: Value(r.description),
      balanceAfter: Value(r.balanceAfter),
      currency: Value(r.currency),
      status: r.status != null ? Value(r.status!) : const Value.absent(),
      rawMetadata: Value(jsonEncode(r.rawMetadata)),
    )).toList();

    _log.info('importTransactions: batch-inserting ${companions.length} rows');
    await _db.batch((batch) {
      batch.insertAll(_db.transactions, companions);
    });

    _log.info('importTransactions: done — imported=$imported, deleted=$deleted, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      deletedRows: deleted,
      errorRows: errorCount,
      errors: errors,
    );
  }

  /// Import rows as AssetEvents, grouped by ISIN.
  /// Auto-creates Asset entries for each unique ISIN found in the data.
  /// Returns the import result plus a map of created/reused asset IDs by ISIN.
  Future<AssetImportResult> importAssetEventsGrouped({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    void Function(int processed, int total)? onProgress,
    bool computeFee = false,
    IsinLookupService? isinLookup,
    Set<String>? buyValues,
    Set<String>? sellValues,
    /// ISIN → selected exchange option (from UI picker). If null, uses first result.
    Map<String, IsinExchangeOption>? selectedExchanges,
    /// If provided, fills missing exchange rates from historical data after import.
    ExchangeRateService? rateService,
    required String baseCurrency,
  }) async {
    _log.info('importAssetEventsGrouped: ${preview.totalRows} rows, ${mappings.length} mappings');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];
    final isinMapping = mappingByField['isin'];

    if (isinMapping == null) {
      _log.severe('importAssetEventsGrouped: missing required mappings');
      return AssetImportResult(
        result: const ImportResult(
          totalRows: 0, importedRows: 0, errorRows: 0,
          errors: ['ISIN column is required'],
        ),
        assetsByIsin: {},
      );
    }

    // Pre-resolve field mappings once
    final typeMapping = mappingByField['type'];
    final qtyMapping = mappingByField['quantity'];
    final priceMapping = mappingByField['price'];
    final currencyMapping = mappingByField['currency'];
    final exchangeRateMapping = mappingByField['exchangeRate'];
    final commMapping = mappingByField['commission'];
    final descMapping = mappingByField['description'];

    var imported = 0;
    var errorCount = 0;
    final errors = <String>[];

    // First pass: collect unique ISINs and find/create assets
    final isinToRows = <String, List<int>>{};
    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      final isin = (_resolveMapping(isinMapping, row) ?? '').trim().toUpperCase();
      if (isin.isEmpty) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: empty ISIN');
        continue;
      }
      isinToRows.putIfAbsent(isin, () => []).add(i);
    }

    _log.info('importAssetEventsGrouped: found ${isinToRows.length} unique ISINs');

    // Find or create asset for each ISIN
    final assetsByIsin = <String, int>{};
    final existingAssets = await _db.select(_db.assets).get();
    final existingByIsin = <String, int>{};
    for (final a in existingAssets) {
      if (a.isin != null && a.isin!.isNotEmpty) {
        existingByIsin[a.isin!.toUpperCase()] = a.id;
      }
    }

    // Resolve new ISINs — use selected exchanges from UI if provided
    final newIsins = isinToRows.keys.where((i) => !existingByIsin.containsKey(i)).toList();

    for (final isin in isinToRows.keys) {
      if (existingByIsin.containsKey(isin)) {
        assetsByIsin[isin] = existingByIsin[isin]!;
        _log.fine('importAssetEventsGrouped: reusing asset id=${existingByIsin[isin]} for ISIN=$isin');
      } else {
        // Use selected exchange from UI picker, or lookup first result
        final selected = selectedExchanges?[isin];
        String name;
        String? ticker;
        String? exchange;

        if (selected != null) {
          name = selected.name;
          ticker = selected.ticker;
          exchange = selected.exchange;
        } else if (isinLookup != null) {
          final lookup = await isinLookup.lookup(isin);
          final best = lookup.bestFor(null);
          name = best?.name ?? isin;
          ticker = best?.ticker;
          exchange = best?.exchange;
        } else {
          name = isin;
        }

        final currency = currencyMapping != null
            ? (_resolveMapping(currencyMapping, preview.rows[isinToRows[isin]!.first]) ?? 'EUR')
            : 'EUR';
        final assetId = await _db.into(_db.assets).insert(AssetsCompanion.insert(
          name: name.length > 200 ? name.substring(0, 200) : name,
          assetType: AssetType.stockEtf,
          valuationMethod: ValuationMethod.eventDriven,
          ticker: Value(ticker),
          isin: Value(isin),
          currency: Value(currency),
          exchange: Value(exchange),
        ));
        assetsByIsin[isin] = assetId;
        _log.info('importAssetEventsGrouped: created asset id=$assetId for ISIN=$isin, name=$name, ticker=$ticker, exchange=$exchange');
      }
    }

    // Second pass: build event companions
    final companions = <AssetEventsCompanion>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      final isin = (_resolveMapping(isinMapping, row) ?? '').trim().toUpperCase();
      final assetId = assetsByIsin[isin];
      if (assetId == null) {
        if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
        continue; // already counted as error in first pass
      }

      try {
        final DateTime date;
        if (dateMapping != null) {
          final dateStr = _resolveMapping(dateMapping, row) ?? '';
          date = _parseDate(dateStr);
        } else {
          final now = DateTime.now();
          date = DateTime(now.year, now.month, now.day);
        }

        final rawMetadata = <String, String>{};
        for (final col in preview.columns) {
          rawMetadata[col] = row[col] ?? '';
        }

        final qty = qtyMapping != null ? _tryParseAmount(_resolveMapping(qtyMapping, row)) : null;
        final price = priceMapping != null ? _tryParseAmount(_resolveMapping(priceMapping, row)) : null;

        // Amount: from column, or auto-calculated as quantity * price
        final double amount;
        if (amountMapping != null) {
          amount = _parseAmount(_resolveMapping(amountMapping, row) ?? '');
        } else if (qty != null && price != null) {
          amount = qty * price;
        } else {
          amount = 0;
        }
        final rate = exchangeRateMapping != null ? _tryParseAmount(_resolveMapping(exchangeRateMapping, row)) : null;

        // Event type: from column with custom mappings, or inferred from sign
        final EventType eventType;
        if (typeMapping != null) {
          final typeStr = _resolveMapping(typeMapping, row) ?? 'BUY';
          eventType = _parseEventType(typeStr, buyValues: buyValues, sellValues: sellValues);
        } else {
          final isNeg = (qty != null && qty < 0) || amount < 0;
          eventType = isNeg ? EventType.sell : EventType.buy;
        }

        // Fee: from column or computed as |amount| - qty * price / rate
        double? commission;
        if (computeFee && qty != null && price != null) {
          final effectiveRate = (rate != null && rate != 0) ? rate : 1.0;
          commission = (amount.abs() - qty * price / effectiveRate).abs();
        } else if (commMapping != null) {
          commission = _tryParseAmount(_resolveMapping(commMapping, row));
        }

        companions.add(AssetEventsCompanion.insert(
          assetId: assetId,
          date: date,
          type: eventType,
          amount: amount,
          quantity: Value(qty),
          price: Value(price),
          currency: Value(currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? 'EUR') : 'EUR'),
          exchangeRate: Value(rate),
          commission: Value(commission),
          notes: Value(descMapping != null ? _resolveMapping(descMapping, row) : null),
          rawMetadata: Value(jsonEncode(rawMetadata)),
        ));
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importAssetEventsGrouped: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    onProgress?.call(preview.rows.length, preview.rows.length);

    // Date-based wipe-and-replace: for each asset, delete events from oldest CSV date onward
    var totalDeleted = 0;
    // Group companions by assetId and find oldest date per asset
    final byAsset = <int, List<AssetEventsCompanion>>{};
    for (final c in companions) {
      (byAsset[c.assetId.value] ??= []).add(c);
    }
    for (final entry in byAsset.entries) {
      final assetId = entry.key;
      final events = entry.value;
      final oldestDate = events.map((e) => e.date.value).reduce((a, b) => a.isBefore(b) ? a : b);
      final cutoff = DateTime(oldestDate.year, oldestDate.month, oldestDate.day);
      final deleted = await _db.customUpdate(
        'DELETE FROM asset_events WHERE asset_id = ? AND date >= ?',
        variables: [Variable.withInt(assetId), Variable.withInt(cutoff.millisecondsSinceEpoch ~/ 1000)],
        updates: {_db.assetEvents},
      );
      totalDeleted += deleted;
      _log.fine('importAssetEventsGrouped: asset $assetId — deleted $deleted events from ${cutoff.toIso8601String().substring(0, 10)}');
    }

    _log.info('importAssetEventsGrouped: batch-inserting ${companions.length} events (deleted $totalDeleted old)');
    await _db.batch((batch) {
      batch.insertAll(_db.assetEvents, companions);
    });

    // Fill missing exchange rates from historical data
    if (rateService != null) {
      var filled = 0;
      for (final assetId in byAsset.keys) {
        final events = await (_db.select(_db.assetEvents)
              ..where((e) => e.assetId.equals(assetId) & e.exchangeRate.isNull() & e.currency.equals(baseCurrency).not()))
            .get();
        for (final ev in events) {
          final rate = await rateService.getRate(baseCurrency, ev.currency, ev.date);
          if (rate != null) {
            await (_db.update(_db.assetEvents)..where((e) => e.id.equals(ev.id)))
                .write(AssetEventsCompanion(exchangeRate: Value(rate)));
            filled++;
          }
        }
      }
      if (filled > 0) _log.info('importAssetEventsGrouped: filled $filled missing exchange rates');
    }

    _log.info('importAssetEventsGrouped: done — imported=$imported, deleted=$totalDeleted, errors=$errorCount, assets=${assetsByIsin.length}');
    return AssetImportResult(
      result: ImportResult(
        totalRows: preview.totalRows,
        importedRows: imported,

        errorRows: errorCount,
        errors: errors,
      ),
      assetsByIsin: assetsByIsin,
    );
  }

  /// Import rows as Income records.
  Future<ImportResult> importIncomes({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    String defaultCurrency = 'EUR',
    void Function(int processed, int total)? onProgress,
  }) async {
    _log.info('importIncomes: ${preview.totalRows} rows, ${mappings.length} mappings, defaultCurrency=$defaultCurrency');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      return const ImportResult(
        totalRows: 0, importedRows: 0, errorRows: 0,
        errors: ['date and amount columns are required'],
      );
    }

    final typeMapping = mappingByField['type'];
    final currencyMapping = mappingByField['currency'];

    var imported = 0;
    var errorCount = 0;
    final errors = <String>[];
    final companions = <IncomesCompanion>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final dateStr = _resolveMapping(dateMapping, row) ?? '';
        final amountStr = _resolveMapping(amountMapping, row) ?? '';
        final date = _parseDate(dateStr);
        final amount = _parseAmount(amountStr);
        final typeStr = typeMapping != null ? (_resolveMapping(typeMapping, row) ?? '') : '';
        final currency = currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? defaultCurrency) : defaultCurrency;
        final type = typeStr.toLowerCase().contains('rimborso') || typeStr.toLowerCase().contains('refund')
            ? IncomeType.refund
            : IncomeType.income;

        companions.add(IncomesCompanion.insert(
          date: date,
          amount: amount,
          type: Value(type),
          currency: Value(currency.isNotEmpty ? currency : defaultCurrency),
        ));
        imported++;
      } catch (e, stack) {
        errorCount++;
        errors.add('Skipped line ${i + 1}: $e');
        _log.warning('importIncomes: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    onProgress?.call(preview.rows.length, preview.rows.length);

    _log.info('importIncomes: batch-inserting ${companions.length} rows');
    await _db.batch((batch) {
      batch.insertAll(_db.incomes, companions);
    });

    _log.info('importIncomes: done — imported=$imported, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      errorRows: errorCount,
      errors: errors,
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────


  /// Parse a date string. Supports common formats.

  DateTime _parseDate(String s) {
    s = s.trim();
    if (s.isEmpty) throw const FormatException('Empty date');

    // Strip surrounding quotes
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }

    // ── Numeric formats ──

    // dd/MM/yyyy or dd-MM-yyyy or dd.MM.yyyy (with optional HH:mm:ss)
    final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(s);
    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
        int.tryParse(dmy.group(4) ?? '') ?? 0,
        int.tryParse(dmy.group(5) ?? '') ?? 0,
        int.tryParse(dmy.group(6) ?? '') ?? 0,
      );
    }

    // MM/dd/yyyy (US format — only if month > 12 makes it unambiguous, otherwise treated as dd/MM above)
    // We handle this via the fallback below.

    // yyyy-MM-dd or yyyy/MM/dd (with optional time T or space separated)
    final ymd = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[T\s](\d{1,2}):(\d{2})(?::(\d{2}))?)?').firstMatch(s);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
        int.tryParse(ymd.group(4) ?? '') ?? 0,
        int.tryParse(ymd.group(5) ?? '') ?? 0,
        int.tryParse(ymd.group(6) ?? '') ?? 0,
      );
    }

    // dd/MM/yy (2-digit year)
    final dmy2 = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})$').firstMatch(s);
    if (dmy2 != null) {
      var year = int.parse(dmy2.group(3)!);
      year += year > 50 ? 1900 : 2000;
      return DateTime(year, int.parse(dmy2.group(2)!), int.parse(dmy2.group(1)!));
    }

    // yyyyMMdd (compact, no separators)
    final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
    if (compact != null) {
      return DateTime(
        int.parse(compact.group(1)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(3)!),
      );
    }

    // ── Named month formats ──

    // dd MMM yyyy or dd-MMM-yyyy (e.g. "20 Feb 2017", "20-Feb-2017")
    final namedDmy = RegExp(r'^(\d{1,2})[\s\-.](\w+)[\s\-.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$', caseSensitive: false).firstMatch(s);
    if (namedDmy != null) {
      final month = monthMap[namedDmy.group(2)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(namedDmy.group(3)!),
          month,
          int.parse(namedDmy.group(1)!),
          int.tryParse(namedDmy.group(4) ?? '') ?? 0,
          int.tryParse(namedDmy.group(5) ?? '') ?? 0,
          int.tryParse(namedDmy.group(6) ?? '') ?? 0,
        );
      }
    }

    // MMM dd, yyyy (e.g. "Feb 20, 2017", "February 20, 2017")
    final namedMdy = RegExp(r'^(\w+)\s+(\d{1,2}),?\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$', caseSensitive: false).firstMatch(s);
    if (namedMdy != null) {
      final month = monthMap[namedMdy.group(1)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(namedMdy.group(3)!),
          month,
          int.parse(namedMdy.group(2)!),
          int.tryParse(namedMdy.group(4) ?? '') ?? 0,
          int.tryParse(namedMdy.group(5) ?? '') ?? 0,
          int.tryParse(namedMdy.group(6) ?? '') ?? 0,
        );
      }
    }

    // yyyy MMM dd (e.g. "2017 Feb 20")
    final namedYmd = RegExp(r'^(\d{4})[\s\-.](\w+)[\s\-.](\d{1,2})$', caseSensitive: false).firstMatch(s);
    if (namedYmd != null) {
      final month = monthMap[namedYmd.group(2)!.toLowerCase()];
      if (month != null) {
        return DateTime(
          int.parse(namedYmd.group(1)!),
          month,
          int.parse(namedYmd.group(3)!),
        );
      }
    }

    // ── Epoch timestamps ──

    // Unix seconds (10 digits) or milliseconds (13 digits)
    final epoch = RegExp(r'^(\d{10,13})$').firstMatch(s);
    if (epoch != null) {
      final n = int.parse(epoch.group(1)!);
      return n > 9999999999
          ? DateTime.fromMillisecondsSinceEpoch(n)
          : DateTime.fromMillisecondsSinceEpoch(n * 1000);
    }

    // ── Fallback: Dart's DateTime.parse (handles ISO 8601) ──
    try {
      return DateTime.parse(s);
    } catch (_) {
      throw FormatException('Invalid date format: $s');
    }
  }

  double _parseAmount(String s) => amt.parseAmount(s);
  double? _tryParseAmount(String? s) => amt.tryParseAmount(s);

  EventType _parseEventType(String s, {Set<String>? buyValues, Set<String>? sellValues}) {
    final normalized = s.trim().toUpperCase().replaceAll(' ', '_');
    // Custom user-defined mappings take priority
    if (buyValues != null && buyValues.any((v) => v.toUpperCase() == normalized)) return EventType.buy;
    if (sellValues != null && sellValues.any((v) => v.toUpperCase() == normalized)) return EventType.sell;
    // Direct enum match
    final direct = EventType.values.where((e) => e.name.toUpperCase() == normalized).firstOrNull;
    if (direct != null) return direct;
    // Common aliases
    const sellAliases = {'SELL', 'VENDITA', 'VENDI', 'S', 'V', 'VERKAUF', 'VENTE'};
    const buyAliases = {'BUY', 'ACQUISTO', 'COMPRA', 'B', 'A', 'KAUF', 'ACHAT'};
    if (sellAliases.contains(normalized)) return EventType.sell;
    if (buyAliases.contains(normalized)) return EventType.buy;
    return EventType.buy;
  }

  /// Compute balanceAfter for parsed rows based on the selected mode.
  void _computeBalances(
    List<_ParsedTransactionRow> rows,
    String balanceMode,
    Set<String>? balanceFilterInclude,
  ) {
    if (rows.isEmpty || balanceMode == 'none') return;

    if (balanceMode == 'column') {
      // Already set from CSV column in balanceAfterFromColumn
      for (final r in rows) {
        r.balanceAfter = r.balanceAfterFromColumn;
      }
      return;
    }

    // Sort chronologically (date ASC, csvIndex ASC) so cumulative balance
    // accumulates from oldest to newest, regardless of CSV row order.
    final indexed = List.generate(rows.length, (i) => i);
    indexed.sort((a, b) {
      final cmp = rows[a].date.compareTo(rows[b].date);
      if (cmp != 0) return cmp;
      return rows[a].csvIndex.compareTo(rows[b].csvIndex);
    });

    // All arithmetic in integer cents to avoid floating point errors
    int _toCents(double v) => (v * 100).round();
    double _fromCents(int c) => c / 100;

    if (balanceMode == 'cumulative') {
      int balanceCents = 0;
      for (final i in indexed) {
        balanceCents += _toCents(rows[i].amount);
        rows[i].balanceAfter = _fromCents(balanceCents);
      }
      _log.info('_computeBalances: cumulative — final balance=${_fromCents(balanceCents)}');
    } else if (balanceMode == 'filtered') {
      int balanceCents = 0;
      for (final i in indexed) {
        final filterVal = rows[i].filterColumnValue ?? '';
        final included = balanceFilterInclude == null ||
            balanceFilterInclude.isEmpty ||
            balanceFilterInclude.contains(filterVal);
        if (included) {
          balanceCents += _toCents(rows[i].amount);
        }
        rows[i].balanceAfter = _fromCents(balanceCents);
      }
      _log.info('_computeBalances: filtered — final balance=${_fromCents(balanceCents)}');
    }
  }
}

/// Internal data class for a parsed transaction row before building companion.
class _ParsedTransactionRow {
  final DateTime date;
  final DateTime? valueDate;
  final double amount;
  final String description;
  final double? balanceAfterFromColumn;
  final String currency;
  final TransactionStatus? status;
  final Map<String, String> rawMetadata;
  final String? hash;
  final String? filterColumnValue;
  final int csvIndex;

  double? balanceAfter;

  _ParsedTransactionRow({
    required this.date,
    this.valueDate,
    required this.amount,
    required this.description,
    this.balanceAfterFromColumn,
    required this.currency,
    this.status,
    required this.rawMetadata,
    required this.hash,
    this.filterColumnValue,
    required this.csvIndex,
  });
}
