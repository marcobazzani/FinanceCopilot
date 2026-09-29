import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/domain/running_balance.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart';
import 'package:finance_copilot/services/domain/asset_event_service.dart';
import 'package:finance_copilot/utils/amount_parser.dart' as amt;
import 'package:finance_copilot/utils/asset_value_math.dart' show bondPriceDivisor;
import 'package:finance_copilot/utils/date_parser.dart' as date_parse;
import 'package:finance_copilot/utils/formatters.dart' show formatYmd;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/import/file_parser_service.dart';
import 'package:finance_copilot/services/import/stored_import_data.dart';
import 'package:finance_copilot/services/market/isin_lookup_service.dart';

part 'asset_import_flow.dart';

final _log = getLogger('ImportService');

/// A single term in a formula: an operator (+/-) and a source column.
class FormulaTerm {
  final String operator; // '+' or '-'
  final String sourceColumn;

  const FormulaTerm({required this.operator, required this.sourceColumn});
}

/// The amount a formula of [terms] gives for [row]: the sum of the terms,
/// each + or − its column's number read in [locale], without the noise of
/// binary arithmetic ([ImportService._figureSum]). A blank cell adds 0 (an
/// optional column left empty is fine); a cell that is not a number gives no
/// amount (null) — never a half-correct sum. The single evaluation the import
/// stores and the wizard previews.
double? formulaAmount(List<FormulaTerm> terms, Map<String, String> row, {required String locale}) {
  final values = <double>[];
  for (final term in terms) {
    final raw = (row[term.sourceColumn] ?? '').trim();
    if (raw.isEmpty) continue;
    final value = amt.tryParseAmount(raw, locale: locale);
    if (value == null) return null;
    values.add(term.operator == '-' ? -value : value);
  }
  return ImportService._figureSum(values);
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

  const ColumnMapping({
    this.sourceColumn,
    required this.targetField,
    this.formulaTerms,
    this.balanceDiffColumn,
    this.multiColumns,
    this.multiDelimiter = ' ',
  });

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

  /// Locale used to format numeric XLSX cells when stringifying. Stored so
  /// `getFullRows` can detect when a locale change requires re-parsing.
  final String? numberLocale;

  const FilePreview({
    required this.columns,
    required this.rows,
    required this.totalRows,
    this.filePath,
    this.clipboardText,
    this.skipRows = 0,
    this.noHeader = false,
    this.sheetName,
    this.numberLocale,
  });
}

/// What an [ImportIssue] is about.
enum ImportIssueKind {
  /// The date and amount columns are not both mapped: nothing is imported.
  dateAndAmountRequired,

  /// Neither an ISIN column nor a single target asset: nothing is imported.
  isinRequired,

  /// The row has no ISIN.
  emptyIsin,

  /// The date cell is empty (and there is no value date to use instead).
  emptyDate,

  /// [ImportIssue.value] is not a date.
  invalidDate,

  /// The amount cell is empty.
  emptyAmount,

  /// [ImportIssue.value] is not a number in the [ImportIssue.locale] format.
  invalidAmount,

  /// The type value [ImportIssue.value] was not tagged in the wizard.
  untaggedType,

  /// The values of [ImportIssue.fields] were refused: the database does not
  /// accept them, or a mapped cell the row needs a value from is blank.
  rejected,

  /// The replacement was refused as a whole: it would have deleted stored
  /// rows it could not replace. Nothing was changed.
  replaceAborted,

  /// Any other failure; [ImportIssue.value] is the error text.
  other,
}

/// One reason rows were not imported, structured so the wizard can word it
/// in the user's language. [message] is the English text the logs show.
class ImportIssue {
  final ImportIssueKind kind;

  /// 1-based data row the issue is about; 0 when it concerns the whole import.
  final int line;

  /// The offending cell (a date, an amount, a type value), or the error text
  /// of an [ImportIssueKind.other] failure.
  final String value;

  /// Number format an [ImportIssueKind.invalidAmount] cell was read with.
  final String locale;

  /// [ImportIssueKind.rejected]: the target fields (`date`, `currency`, …)
  /// whose values were refused.
  final List<String> fields;

  /// [ImportIssueKind.replaceAborted]: rows that could not be stored, stored
  /// rows the replacement would have deleted, and its first replaced day.
  final int rejectedRows;
  final int existingRows;
  final DateTime? replaceFrom;

  final String message;

  const ImportIssue(
    this.kind,
    this.message, {
    this.line = 0,
    this.value = '',
    this.locale = '',
    this.fields = const [],
    this.rejectedRows = 0,
    this.existingRows = 0,
    this.replaceFrom,
  });

  @override
  String toString() => message;
}

/// Result of an import operation.
class ImportResult {
  final int totalRows;
  final int importedRows;
  final int deletedRows;
  final int errorRows;

  /// Why rows were skipped — or the import refused — in row order.
  final List<ImportIssue> issues;

  /// [issues] as English text, for logs.
  List<String> get errors => [for (final i in issues) i.message];

  /// External fee rows (asset imports) whose `(isin, orderRef)` key matched
  /// no parent Buy/Sell. The fee amount was discarded; the count is
  /// surfaced so the user can investigate. Always 0 for transaction imports.
  final int unmatchedFees;

  /// External fee rows successfully folded into a parent's `commission`.
  final int attachedFees;

  const ImportResult({
    required this.totalRows,
    required this.importedRows,
    this.deletedRows = 0,
    required this.errorRows,
    this.issues = const [],
    this.unmatchedFees = 0,
    this.attachedFees = 0,
  });
}

/// Target entity type for import.
enum ImportTarget { transaction, assetEvent, income }

/// Preview of a transaction import (dry run, no DB writes).
class TransactionImportPreview {
  final int parsedRows;
  final int errorRows;

  /// The first issues found (at most 5), in row order.
  final List<ImportIssue> issues;
  final double importSum;
  final double? predictedBalance;

  /// No [predictedBalance] because the balance the import continues from is
  /// unknown: the row before it has no stored balance.
  final bool openingBalanceUnknown;
  final int rowsToReplace;

  const TransactionImportPreview({
    required this.parsedRows,
    required this.errorRows,
    this.issues = const [],
    required this.importSum,
    this.predictedBalance,
    this.openingBalanceUnknown = false,
    required this.rowsToReplace,
  });
}

/// Generic file importer: applies user column mapping, hashes rows for dedup,
/// and inserts. File parsing is delegated to [FileParserService].
class ImportService {
  final AppDatabase _db;
  final FileParserService _parser = FileParserService();

  /// Locale used for the current import call. Set by each public import
  /// method before any number parsing happens, then read by `_parseAmount`
  /// and `_tryParseAmount`. Defaults to en_US for safety.
  String _activeLocale = 'en_US';

  /// Number format of the account's STORED statement text (`raw_metadata`).
  /// Fixed once set: every later import is parsed with the file's own format
  /// ([_activeLocale]) and its numeric cells are re-spelled into this one
  /// before being stored, so one account never mixes spellings again.
  String _storedLocale = 'en_US';

  ImportService(this._db);

  // ──────────────────────────────────────────────
  // Step 1: Parse file → FilePreview (delegates to FileParserService)
  // ──────────────────────────────────────────────

  Future<FilePreview> parseFile(String filePath, {String? sheetName, int skipRows = 0, bool noHeader = false, String? numberLocale}) =>
      _parser.parseFile(filePath, sheetName: sheetName, skipRows: skipRows, noHeader: noHeader, numberLocale: numberLocale);

  Future<List<String>> listSheets(String filePath) => _parser.listSheets(filePath);

  Future<FilePreview> parseClipboard(String text, {int skipRows = 0, bool noHeader = false}) =>
      _parser.parseClipboard(text, skipRows: skipRows, noHeader: noHeader);

  Future<FilePreview> getFullRows(FilePreview preview, {String? numberLocale}) => _parser.getFullRows(preview, numberLocale: numberLocale);

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
      return _formatAmount(_figureSum([for (final n in nums) n!]));
    }

    // String concatenation with delimiter
    return values.join(delimiter);
  }

  /// The sum of [terms] — figures read from a statement — without the noise
  /// of binary arithmetic: rounded to 15 significant digits of the largest
  /// term or partial sum ([amt.stripFloatNoise]), so `1000.10 − 1000.05` is
  /// exactly 0.05.
  static double _figureSum(Iterable<double> terms) {
    var sum = 0.0;
    var magnitude = 0.0;
    for (final t in terms) {
      sum += t;
      if (t.abs() > magnitude) magnitude = t.abs();
      if (sum.abs() > magnitude) magnitude = sum.abs();
    }
    return amt.stripFloatNoise(sum, magnitude: magnitude);
  }

  /// Build per-row amounts from running balances: each amount is the
  /// difference between this row's balance and the most recent prior valid
  /// balance. The first row has no prior balance and contributes 0; rows
  /// with missing/garbage cells also contribute 0 but do NOT clear the
  /// last-known balance, so a single bad cell doesn't cause the next row
  /// to look like a huge transaction.
  /// Amount of each row as the difference between consecutive statement
  /// balances. [seedBalance] is the statement balance just before the first
  /// row (see [_balanceDiffSeed]); when unknown the first row contributes 0
  /// rather than inventing a transaction out of the opening balance.
  List<double> _computeBalanceDiffs(List<Map<String, String>> rows, String balCol, {double? seedBalance}) {
    final out = <double>[];
    double? prevBalance = seedBalance;
    for (final row in rows) {
      final balance = _tryParseAmount(row[balCol] ?? '');
      if (balance != null && prevBalance != null) {
        out.add(_figureSum([balance, -prevBalance]));
      } else {
        out.add(0);
      }
      if (balance != null) prevBalance = balance;
    }
    return out;
  }

  /// The statement balance that precedes the first row of a balance-diff
  /// import, learned from what the account already stores:
  ///
  ///  * rows exist BEFORE the first imported date (appending a statement):
  ///    the last such row's statement balance (or, when it has none, the
  ///    stored running balance before the import — [_storedBalanceBefore]);
  ///  * no rows before, but rows from that date on are being replaced
  ///    (re-run from stored data): the earliest replaced row's statement
  ///    balance minus its stored amount — i.e. the opening balance the
  ///    account was originally imported with (0 for an account that started
  ///    from nothing, so its opening deposit stays a transaction);
  ///  * nothing stored: null — the first row contributes 0.
  Future<double?> _balanceDiffSeed({
    required int accountId,
    required String balCol,
    required List<Map<String, String>> rows,
    required ColumnMapping dateMapping,
    bool replaceOnlyImportedRows = false,
  }) async {
    DateTime? first;
    for (final row in rows) {
      final d = _tryParseDateMapping(dateMapping, row);
      if (d != null && (first == null || d.isBefore(first))) first = d;
    }
    if (first == null) return null;
    final cutoff = DateTime(first.year, first.month, first.day);

    double? statementBalance(Transaction t) {
      final meta = decodeRawMetadata(t.rawMetadata);
      return meta == null ? null : _tryParseAmount(meta[balCol]?.toString() ?? '');
    }

    // A re-run replaces EVERY imported row of the account, so only rows the
    // user entered by hand can precede the import; imported ones are about
    // to be deleted and must not seed anything.
    final before =
        await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    t.operationDate.isSmallerThanValue(cutoff) &
                    (replaceOnlyImportedRows ? t.rawMetadata.isNull() : const Constant(true)),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.operationDate), (t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (before != null) {
      // The statement balance is booking-order data, so the last BOOKED row's
      // is the one just before the import. A row without one (entered by
      // hand) falls back to the stored running balance, which lives on the
      // value-date timeline.
      return statementBalance(before) ??
          (await _storedBalanceBefore(accountId, cutoff.millisecondsSinceEpoch ~/ 1000, survivorsOnly: replaceOnlyImportedRows))?.balance;
    }

    final earliestReplaced =
        await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    t.rawMetadata.isNotNull() &
                    (replaceOnlyImportedRows ? const Constant(true) : t.operationDate.isBiggerOrEqualValue(cutoff)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.operationDate), (t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (earliestReplaced == null) return null;
    final bal = statementBalance(earliestReplaced);
    if (bal == null) return null;
    final seed = bal - earliestReplaced.amount;
    // With nothing before the import, the opening balance can only be 0
    // (the first row is the opening deposit) or the first statement balance
    // (the first row contributes 0). Anything else means the stored amount
    // is already wrong; do not let it seed the next import.
    if (replaceOnlyImportedRows && seed.abs() > 0.005 && (seed - bal).abs() > 0.005) {
      _log.fine('balance-diff seed: stored amount of the earliest row is inconsistent with its statement balance ($seed); seed unknown');
      return null;
    }
    return seed;
  }

  /// Evaluate a formula ([formulaAmount]) as the mapping's text: an empty
  /// string when a cell is not a number, so the row's amount surfaces as
  /// missing rather than as a half-correct sum.
  String _evaluateFormula(List<FormulaTerm> terms, Map<String, String> row) {
    final amount = formulaAmount(terms, row, locale: _activeLocale);
    if (amount == null) {
      _log.fine('formula: a cell of ${[for (final t in terms) '${t.sourceColumn}="${row[t.sourceColumn]}"']} is not a number - row dropped');
      return '';
    }
    return _formatAmount(amount);
  }

  /// Format a numeric result so it round-trips through `_parseAmount`,
  /// without rounding away precision. See [amt.formatAmountLossless].
  String _formatAmount(double v) => amt.formatAmountLossless(v, locale: _activeLocale);

  /// Re-parse the underlying file when the preview's `numberLocale` no
  /// longer matches `_activeLocale`. Only matters for XLSX (numeric cells
  /// are formatted at parse time): a cell's stringified value depends on
  /// which locale was active when it was parsed, so a locale change must
  /// re-derive it. CSV/clipboard text is locale-agnostic at the row-string
  /// level — those cells are the RAW text the user pasted or a bank
  /// exported, already in whatever format the source used — so it's a
  /// true no-op there. Re-interpreting a dot-decimal-shaped CSV/clipboard
  /// value as if it were a serialized double would corrupt a genuine
  /// thousands-separated number (e.g. it_IT "1.234" meaning 1234, not the
  /// fraction 1.234).
  ///
  /// If an XLSX/XLS source file is unavailable (e.g. integration tests
  /// that copy to a tmp dir and delete it), fall back to re-formatting the
  /// in-memory row strings: numeric-looking dot-decimal values get
  /// rewritten in the active locale's format. This fallback is only safe
  /// for XLSX/XLS — never reached for CSV/clipboard, which return above.
  Future<FilePreview> _ensurePreviewLocale(FilePreview preview) async {
    if (preview.numberLocale == _activeLocale) return preview;
    // Clipboard (no filePath) and non-XLSX files (CSV/TSV/PDF) are
    // locale-agnostic at the row-string level — nothing to re-derive.
    if (preview.filePath == null) return preview;
    final ext = preview.filePath!.toLowerCase().split('.').last;
    if (ext != 'xlsx' && ext != 'xls') return preview;
    if (!await File(preview.filePath!).exists()) {
      return _reformatPreviewInPlace(preview);
    }
    // Inline re-parse (no Isolate.run): test environments pump a handful
    // of frames and would otherwise time out waiting for an isolate.
    return _parser.getFullRowsInProcess(preview, numberLocale: _activeLocale);
  }

  /// Rewrite strings that look like a Dart-default `double.toString()`
  /// (e.g. "7707.97", "-42.5") so they round-trip through the active
  /// locale's parser. Invariant: only digits, optional sign, exactly one
  /// dot — that's the shape XLSX cells produce when no locale is given.
  /// Only called for XLSX/XLS previews (see [_ensurePreviewLocale]) — CSV
  /// and clipboard text never reach this method, so a genuine
  /// thousands-separated CSV cell is never mistaken for a serialized double.
  static final _dotDecimal = RegExp(r'^-?\d+\.\d+$');
  FilePreview _reformatPreviewInPlace(FilePreview preview) {
    final newRows = preview.rows.map((row) {
      final out = <String, String>{};
      row.forEach((k, v) {
        if (_dotDecimal.hasMatch(v)) {
          out[k] = amt.formatAmountLossless(double.parse(v), locale: _activeLocale);
        } else {
          out[k] = v;
        }
      });
      return out;
    }).toList();
    return FilePreview(
      columns: preview.columns,
      rows: newRows,
      totalRows: preview.totalRows,
      filePath: preview.filePath,
      clipboardText: preview.clipboardText,
      skipRows: preview.skipRows,
      noHeader: preview.noHeader,
      sheetName: preview.sheetName,
      numberLocale: _activeLocale,
    );
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

    /// A [BalanceMode] name ([BalanceMode.byDefault] when omitted); any other
    /// text is refused before anything is written.
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,

    /// User's per-import locale choice from the wizard. Persisted to
    /// `ImportConfigs.numberLocale` for this account when non-null.
    /// NULL means "Auto — fall back to the saved value or [appLocale]".
    String? numberLocaleOverride,

    /// App's configured locale (e.g. `it_IT`). Used as the final fallback
    /// when no per-source override or saved value exists.
    String? appLocale,

    /// Re-run from stored data: replace only rows that came from an import
    /// (have raw metadata); manually entered rows in the range are kept.
    bool replaceOnlyImportedRows = false,

    /// Preview columns computed by the wizard (splits). They are mapped like
    /// any other column but are NOT statement data, so they are excluded
    /// from the stored raw metadata — a later re-run recomputes them.
    Set<String> derivedColumns = const {},
  }) async {
    final mode = _balanceModeNamed(balanceMode);
    await _setLocaleForAccount(
      accountId: accountId,
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    preview = await _ensurePreviewLocale(preview);
    _log.info('importTransactions: accountId=$accountId, ${preview.totalRows} rows, ${mappings.length} mappings, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final respell = _storedLocale != _activeLocale;
    final numericCols = respell ? _numericColumnsOf(mappings) : const <String>{};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      _log.severe('importTransactions: missing required mappings');
      return const ImportResult(
        totalRows: 0,
        importedRows: 0,
        errorRows: 0,
        issues: [_dateAndAmountRequired],
      );
    }

    // Pre-compute balance-diff amounts if needed.
    List<double>? balanceDiffAmounts;
    if (amountMapping.isBalanceDiff) {
      final balCol = amountMapping.balanceDiffColumn!;
      final seed = await _balanceDiffSeed(
        accountId: accountId,
        balCol: balCol,
        rows: preview.rows,
        dateMapping: dateMapping,
        replaceOnlyImportedRows: replaceOnlyImportedRows,
      );
      _log.fine('importTransactions: balance-diff mode, column=$balCol, seed=$seed');
      balanceDiffAmounts = _computeBalanceDiffs(preview.rows, balCol, seedBalance: seed);
    }

    // Fetch account's currency for fallback
    final account = await (_db.select(_db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
    final accountCurrency = account.currency;

    // Pre-resolve field mappings once
    final descMapping = mappingByField['description'];
    final balanceMapping = mappingByField['balanceAfter'];
    final currencyMapping = mappingByField['currency'];
    final valueDateMapping = mappingByField['valueDate'];
    final statusMapping = mappingByField['status'];

    // Parse all rows
    var imported = 0;
    var errorCount = 0;
    final issues = <ImportIssue>[];
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

        var valueDate = _tryParseDateMapping(valueDateMapping, row);
        final date = _parseDateWithFallback(dateStr, valueDate);
        valueDate ??= date;

        final rawMetadata = <String, String>{};
        for (final col in preview.columns) {
          if (derivedColumns.contains(col)) continue;
          var cell = row[col] ?? '';
          // A file in another number format than the account's stored text:
          // re-spell the numeric cells so the stored history stays uniform
          // and re-parseable under the saved locale.
          if (respell && numericCols.contains(col) && cell.trim().isNotEmpty) {
            final v = amt.tryParseAmount(cell, locale: _activeLocale);
            if (v != null) cell = amt.formatAmountLossless(v, locale: _storedLocale);
          }
          rawMetadata[col] = cell;
        }

        TransactionStatus? txStatus;
        if (statusMapping != null) {
          final sStr = (_resolveMapping(statusMapping, row) ?? '').toLowerCase().trim();
          txStatus = TransactionStatus.values.where((s) => s.name.toLowerCase() == sStr).firstOrNull;
        }

        parsedRows.add(
          _ParsedTransactionRow(
            date: date,
            valueDate: valueDate,
            amount: amount,
            description: descMapping != null ? (_resolveMapping(descMapping, row) ?? '') : '',
            balanceAfterFromColumn: balanceMapping != null ? _tryParseAmount(_resolveMapping(balanceMapping, row)) : null,
            currency: currencyMapping != null ? (_resolveMapping(currencyMapping, row) ?? accountCurrency) : accountCurrency,
            status: txStatus,
            rawMetadata: rawMetadata,
            filterColumnValue: balanceFilterColumn != null ? (row[balanceFilterColumn] ?? '').trim() : null,
            csvIndex: i,
          ),
        );
      } catch (e, stack) {
        errorCount++;
        issues.add(_rowIssue(i + 1, e));
        _log.fine('importTransactions: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    if (parsedRows.isEmpty) {
      return ImportResult(totalRows: preview.totalRows, importedRows: 0, errorRows: errorCount, issues: issues);
    }

    // Pre-validate every parsed row against the DB's own column
    // constraints (nullability, text length, etc.) BEFORE the destructive
    // delete below. Some constraints — e.g. a mapped currency column that
    // isn't exactly 3 characters — are only enforced by Drift at insert
    // time, past the per-row parse step above. Without this pass, the
    // delete could commit and the insert then fail, permanently wiping
    // the account's prior transactions for the replaced range while
    // inserting nothing to replace them. A row that fails here is skipped
    // exactly like a parse error — good rows still import.
    final validRows = <_ParsedTransactionRow>[];
    final rejectedDates = <DateTime>[];
    for (final r in parsedRows) {
      final verification = _db.transactions.validateIntegrity(_buildTransactionCompanion(r, accountId), isInserting: true);
      if (verification.dataValid) {
        validRows.add(r);
        continue;
      }
      errorCount++;
      rejectedDates.add(r.date);
      try {
        verification.throwIfInvalid(r);
      } on InvalidDataException catch (e) {
        issues.add(
          ImportIssue(
            ImportIssueKind.rejected,
            'Skipped line ${r.csvIndex + 1}: ${e.message}',
            line: r.csvIndex + 1,
            // The companion's column names, in the wizard's field names.
            fields: [for (final m in e.errors.keys) m.dartGetterName == 'operationDate' ? 'date' : m.dartGetterName],
          ),
        );
        _log.warning('importTransactions: line ${r.csvIndex + 1} failed DB validation: ${e.message}');
      }
    }

    if (validRows.isEmpty) {
      return ImportResult(totalRows: preview.totalRows, importedRows: 0, errorRows: errorCount, issues: issues);
    }

    // Find the oldest date among the rows that will actually be inserted.
    final oldestDate = validRows.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final cutoffEpoch = DateTime(oldestDate.year, oldestDate.month, oldestDate.day).millisecondsSinceEpoch ~/ 1000;

    // A rejected row that falls INSIDE the replaced range is unreplaceable
    // data loss waiting to happen: the delete below would remove the
    // previously-stored copy of that transaction, and nothing would be
    // inserted in its place. Wiping the range is only safe when the file is
    // a complete record of it.
    //
    // Refuse the whole replacement in that case — touching nothing at all is
    // the only outcome that cannot destroy a transaction the user still has.
    // The errors already list the offending lines, so the user can fix the
    // file and re-import. When the range holds no rows yet there is nothing
    // to lose, so the good rows still import.
    //
    // Note this deliberately keys off DB-validation rejections only. Rows
    // that fail the earlier PARSE step are tolerated as before: those are
    // typically not transactions at all (footers, totals, blank lines), and
    // treating them as missing data would refuse most real bank exports.
    // On a re-run the replaced range is the whole imported set, so every
    // rejected row is inside it.
    final rejectedInReplacedRange = replaceOnlyImportedRows
        ? rejectedDates.isNotEmpty
        : rejectedDates.any((d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000 >= cutoffEpoch);
    if (rejectedInReplacedRange) {
      final existingInRange = replaceOnlyImportedRows
          ? await _countImportedRows(accountId)
          : await _countTransactionsFrom(accountId, cutoffEpoch);
      if (existingInRange > 0) {
        final msg =
            'Aborted: ${rejectedDates.length} row(s) could not be stored, so replacing '
            '${formatYmd(oldestDate)} onward would have deleted $existingInRange existing '
            'transaction(s) without replacing them. Nothing was changed — fix the rows '
            'listed above and re-import.';
        issues.add(
          ImportIssue(
            ImportIssueKind.replaceAborted,
            msg,
            rejectedRows: rejectedDates.length,
            existingRows: existingInRange,
            replaceFrom: DateTime(oldestDate.year, oldestDate.month, oldestDate.day),
          ),
        );
        _log.severe('importTransactions: $msg');
        return ImportResult(totalRows: preview.totalRows, importedRows: 0, errorRows: errorCount, issues: issues);
      }
    }

    // Seed cumulative balance from the true pre-cutoff sum so newly inserted
    // rows continue from the existing account balance instead of restarting at 0.
    // Null (filtered mode, the row before has no stored balance): the balance
    // the rows continue from is unknown, so none is stored for them.
    final preCutoffBalance = await _preCutoffBalance(
      accountId,
      cutoffEpoch,
      balanceMode: mode,
      survivorsOnly: replaceOnlyImportedRows,
    );
    if (preCutoffBalance == null) {
      _log.warning('importTransactions: the row before ${formatYmd(oldestDate)} has no stored balance - imported rows get none');
    }

    // Compute balanceAfter
    _computeBalances(validRows, mode, balanceFilterInclude, preCutoffBalance);

    var companions = validRows.map((r) => _buildTransactionCompanion(r, accountId)).toList();

    // Delete the replaced range and insert every replacement row in ONE
    // transaction: every row was already validated above, so this batch
    // is expected to succeed in full. If something still throws here
    // (an unexpected DB-level error, not a bad row), the transaction
    // rolls back the delete too rather than leaving the range wiped with
    // nothing inserted — the exception propagates to the caller, which
    // already surfaces import failures to the user.
    // [replaceOnlyImportedRows] (re-run from stored data) leaves rows the
    // user entered by hand (no raw_metadata) untouched: they were never part
    // of the import being re-run.
    // A re-run's input IS the whole imported set, so the whole imported set
    // is what it replaces — not "from the oldest date onward": a row whose
    // stored date is off would otherwise survive as a duplicate.
    var deleted = 0;
    await _db.transaction(() async {
      // User annotations on the rows about to be replaced survive the
      // replacement: they are re-attached to the regenerated row with the
      // same booking day, amount and description.
      final annotated =
          await (_db.select(_db.transactions)..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    (replaceOnlyImportedRows
                        ? t.rawMetadata.isNotNull()
                        : t.operationDate.isBiggerOrEqualValue(DateTime.fromMillisecondsSinceEpoch(cutoffEpoch * 1000))) &
                    (t.categoryId.isNotNull() | t.expenseType.isNotNull() | t.tags.equals('[]').not()),
              ))
              .get();
      companions = _carryOverAnnotations(companions, annotated);

      if (replaceOnlyImportedRows) {
        deleted = await _db.customUpdate(
          'DELETE FROM transactions WHERE account_id = ? AND raw_metadata IS NOT NULL',
          variables: [Variable.withInt(accountId)],
          updates: {_db.transactions},
        );
        _log.info('importTransactions: re-run - deleted all $deleted imported rows of the account');
      } else {
        deleted = await _db.customUpdate(
          'DELETE FROM transactions WHERE account_id = ? AND operation_date >= ?',
          variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
          updates: {_db.transactions},
        );
        _log.info('importTransactions: deleted $deleted rows from ${formatYmd(oldestDate)} onward');
      }

      // Report parsing complete, starting DB write
      onProgress?.call(preview.rows.length, preview.rows.length);

      _log.info('importTransactions: batch-inserting ${companions.length} rows');
      await _db.batch((batch) => batch.insertAll(_db.transactions, companions));
      imported += companions.length;
    });

    _log.info('importTransactions: done - imported=$imported, deleted=$deleted, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      deletedRows: deleted,
      errorRows: errorCount,
      issues: issues,
    );
  }

  /// Re-attach user annotations (category, tags, expense type) from the rows
  /// being replaced to the regenerated rows. Matching key: booking day,
  /// amount in cents and description — the identity an import preserves.
  /// Each annotated row is used at most once; unmatched ones are dropped
  /// (their transaction no longer exists in the new data).
  static List<TransactionsCompanion> _carryOverAnnotations(
    List<TransactionsCompanion> companions,
    List<Transaction> annotated,
  ) {
    if (annotated.isEmpty) return companions;
    String key(DateTime day, double amount, String desc) => '${day.year}-${day.month}-${day.day}|${(amount * 100).round()}|$desc';
    final pool = <String, List<Transaction>>{};
    for (final t in annotated) {
      (pool[key(t.operationDate, t.amount, t.description)] ??= []).add(t);
    }
    var carried = 0;
    final out = <TransactionsCompanion>[];
    for (final c in companions) {
      final k = key(c.operationDate.value, c.amount.value, c.description.present ? c.description.value : '');
      final list = pool[k];
      if (list == null || list.isEmpty) {
        out.add(c);
        continue;
      }
      final src = list.removeAt(0);
      carried++;
      out.add(c.copyWith(categoryId: Value(src.categoryId), expenseType: Value(src.expenseType), tags: Value(src.tags)));
    }
    _log.info('importTransactions: carried over annotations on $carried of ${annotated.length} annotated rows');
    return out;
  }

  /// Rebuild an import preview from the raw statement columns stored on every
  /// imported row of [accountId] (`transactions.raw_metadata`), so an import
  /// can be re-mapped and re-run without the original file. Rows the user
  /// entered by hand (no raw metadata) are not part of it. Returns null when
  /// the account has no imported rows.
  ///
  /// [numberLocale] is the account's SAVED number format; when the account
  /// has none, the preview carries null and the wizard requires the user to
  /// choose one explicitly — stored text is parsed with a guessed locale
  /// never (a `2,000.00` read under `it_IT` is 2.00).
  Future<FilePreview?> previewFromStoredRows(int accountId, {String? numberLocale}) async {
    final rows =
        await (_db.select(_db.transactions)
              ..where((t) => t.accountId.equals(accountId) & t.rawMetadata.isNotNull())
              ..orderBy([(t) => OrderingTerm.asc(t.operationDate), (t) => OrderingTerm.asc(t.id)]))
            .get();
    final columns = <String>[];
    final seen = <String>{};
    final data = <Map<String, String>>[];
    for (final t in rows) {
      final decoded = decodeRawMetadata(t.rawMetadata);
      if (decoded == null) continue;
      final row = <String, String>{};
      for (final e in decoded.entries) {
        final k = e.key.toString();
        if (seen.add(k)) columns.add(k);
        row[k] = e.value?.toString() ?? '';
      }
      data.add(row);
    }
    if (data.isEmpty) return null;
    // Every row exposes every column so mappings resolve uniformly.
    for (final r in data) {
      for (final c in columns) {
        r.putIfAbsent(c, () => '');
      }
    }
    _log.info('previewFromStoredRows: account=$accountId rows=${data.length} columns=${columns.length} locale=$numberLocale');
    return FilePreview(columns: columns, rows: data, totalRows: data.length, numberLocale: numberLocale);
  }

  /// Count the account's imported rows (those carrying raw statement data) —
  /// exactly the rows a re-run from stored data replaces.
  Future<int> _countImportedRows(int accountId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM transactions WHERE account_id = ? AND raw_metadata IS NOT NULL',
          variables: [Variable.withInt(accountId)],
        )
        .getSingle();
    return row.read<int>('cnt');
  }

  /// Count the account's existing transactions from [cutoffEpoch] onward —
  /// i.e. exactly the rows a wipe-and-replace import is about to delete.
  Future<int> _countTransactionsFrom(int accountId, int cutoffEpoch) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM transactions WHERE account_id = ? AND operation_date >= ?',
          variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
          readsFrom: {_db.transactions},
        )
        .getSingle();
    return row.read<int>('cnt');
  }

  /// Build the `Transactions` companion for one parsed row. Shared by the
  /// pre-insert validation pass and the final batch insert so both use
  /// identical column mapping.
  TransactionsCompanion _buildTransactionCompanion(_ParsedTransactionRow r, int accountId) {
    final keys = normalizeDescription(description: r.description, rawMetadata: r.rawMetadata, inflow: r.amount > 0);
    return TransactionsCompanion.insert(
      accountId: accountId,
      operationDate: r.date,
      valueDate: r.valueDate ?? r.date,
      amount: r.amount,
      description: Value(r.description),
      balanceAfter: Value(r.balanceAfter),
      currency: Value(r.currency),
      status: r.status != null ? Value(r.status!) : const Value.absent(),
      rawMetadata: Value(jsonEncode(r.rawMetadata)),
      merchantKey: Value(keys.merchantKey),
      counterparty: Value(keys.counterparty),
      entryKind: Value(keys.entryKind),
    );
  }

  /// Import rows as Income records.
  ///
  /// When a `type` column is mapped, every distinct value MUST be tagged via
  /// the wizard chips into exactly one of [incomeValues] / [refundValues] /
  /// [pensionContributionValues]. An untagged/unknown value fails loudly
  /// (row skipped + error) — there is no keyword guessing and no silent
  /// fallback to plain income, because a mis-typed refund would silently
  /// inflate income totals. When no `type` column is mapped, every row is
  /// [IncomeType.income].
  Future<ImportResult> importIncomes({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required String defaultCurrency,
    void Function(int processed, int total)? onProgress,

    /// Type-column values the user tagged as plain income / refund / pension
    /// contribution via the wizard chips. Matched exactly (normalized) — no
    /// substring or keyword inference.
    Set<String>? incomeValues,
    Set<String>? refundValues,
    Set<String>? pensionContributionValues,

    /// User's per-import locale choice. Persisted to the
    /// `IMPORT_INCOME_LOCALE` AppConfigs key when non-null.
    String? numberLocaleOverride,

    /// App's configured locale (e.g. `it_IT`). Final fallback.
    String? appLocale,
  }) async {
    await _setLocaleForIncome(
      override: numberLocaleOverride,
      appLocale: appLocale,
    );
    _log.info('importIncomes: ${preview.totalRows} rows, ${mappings.length} mappings, defaultCurrency=$defaultCurrency, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      return const ImportResult(
        totalRows: 0,
        importedRows: 0,
        errorRows: 0,
        issues: [_dateAndAmountRequired],
      );
    }

    final typeMapping = mappingByField['type'];
    final currencyMapping = mappingByField['currency'];

    var imported = 0;
    var errorCount = 0;
    final issues = <ImportIssue>[];
    final companions = <IncomesCompanion>[];
    const progressInterval = 100;

    for (var i = 0; i < preview.rows.length; i++) {
      final row = preview.rows[i];
      try {
        final amountStr = _resolveMapping(amountMapping, row) ?? '';
        final amount = _parseAmount(amountStr);

        var valueDate = _tryParseDateMapping(mappingByField['valueDate'], row);
        final date = _parseDateWithFallback(_resolveMapping(dateMapping, row) ?? '', valueDate);
        valueDate ??= date;
        final typeStr = typeMapping != null ? (_resolveMapping(typeMapping, row) ?? '') : '';
        final currency = _mappedCurrencyCell(currencyMapping, row) ?? defaultCurrency;
        final type = _resolveIncomeType(
          typeStr,
          hasTypeColumn: typeMapping != null,
          incomeValues: incomeValues,
          refundValues: refundValues,
          pensionContributionValues: pensionContributionValues,
        );

        companions.add(
          IncomesCompanion.insert(
            date: date,
            valueDate: valueDate,
            amount: amount,
            type: Value(type),
            currency: Value(currency),
          ),
        );
        imported++;
      } catch (e, stack) {
        errorCount++;
        issues.add(_rowIssue(i + 1, e));
        _log.fine('importIncomes: skipped line ${i + 1}: $e', e, stack);
      }
      if (i % progressInterval == 0) onProgress?.call(i + 1, preview.rows.length);
    }

    onProgress?.call(preview.rows.length, preview.rows.length);

    _log.info('importIncomes: batch-inserting ${companions.length} rows');
    await _db.batch((batch) {
      batch.insertAll(_db.incomes, companions);
    });

    _log.info('importIncomes: done - imported=$imported, errors=$errorCount');
    return ImportResult(
      totalRows: preview.totalRows,
      importedRows: imported,
      errorRows: errorCount,
      issues: issues,
    );
  }

  // ──────────────────────────────────────────────
  // Preview (dry-run) methods
  // ──────────────────────────────────────────────

  /// Dry-run a transaction import: parse all rows, compute predicted balance,
  /// and count rows that would be replaced — without touching the DB.
  Future<TransactionImportPreview> previewTransactionImport({
    required FilePreview preview,
    required List<ColumnMapping> mappings,
    required int accountId,

    /// A [BalanceMode] name, as in [importTransactions].
    String balanceMode = 'cumulative',
    String? balanceFilterColumn,
    Set<String>? balanceFilterInclude,

    /// Locale used for parsing during preview only — NOT persisted.
    String? numberLocale,
    String? appLocale,
  }) async {
    final mode = _balanceModeNamed(balanceMode);
    final saved =
        numberLocale ?? (await (_db.select(_db.importConfigs)..where((c) => c.accountId.equals(accountId))).getSingleOrNull())?.numberLocale;
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);
    preview = await _ensurePreviewLocale(preview);
    _log.info('previewTransactionImport: accountId=$accountId, ${preview.totalRows} rows, locale=$_activeLocale');
    final mappingByField = {for (final m in mappings) m.targetField: m};
    final dateMapping = mappingByField['date'];
    final amountMapping = mappingByField['amount'];

    if (dateMapping == null || amountMapping == null) {
      return const TransactionImportPreview(
        parsedRows: 0,
        errorRows: 0,
        importSum: 0,
        rowsToReplace: 0,
        issues: [_dateAndAmountRequired],
      );
    }

    // Pre-compute balance-diff amounts if needed (same seed as the import).
    List<double>? balanceDiffAmounts;
    if (amountMapping.isBalanceDiff) {
      final balCol = amountMapping.balanceDiffColumn!;
      final seed = await _balanceDiffSeed(accountId: accountId, balCol: balCol, rows: preview.rows, dateMapping: dateMapping);
      balanceDiffAmounts = _computeBalanceDiffs(preview.rows, balCol, seedBalance: seed);
    }

    final valueDateMapping = mappingByField['valueDate'];

    var parsed = 0;
    var errorCount = 0;
    final issues = <ImportIssue>[];
    double importSum = 0;
    DateTime? oldestDate;

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

        final valueDate = _tryParseDateMapping(valueDateMapping, row);
        final date = _parseDateWithFallback(dateStr, valueDate);

        // Check filtered mode
        if (mode == BalanceMode.filtered && balanceFilterColumn != null) {
          final filterVal = (row[balanceFilterColumn] ?? '').trim();
          final included = balanceFilterInclude == null || balanceFilterInclude.isEmpty || balanceFilterInclude.contains(filterVal);
          if (included) importSum += amount;
        } else {
          importSum += amount;
        }

        if (oldestDate == null || date.isBefore(oldestDate)) oldestDate = date;
        parsed++;
      } catch (e) {
        errorCount++;
        if (issues.length < 5) issues.add(_rowIssue(i + 1, e, label: 'Line'));
      }
    }

    // Count rows that would be deleted (replaced)
    var rowsToReplace = 0;
    double? predictedBalance;
    var openingBalanceUnknown = false;
    if (oldestDate != null) {
      final cutoffEpoch = DateTime(oldestDate.year, oldestDate.month, oldestDate.day).millisecondsSinceEpoch ~/ 1000;

      final countResult = await _db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM transactions WHERE account_id = ? AND operation_date >= ?',
            variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
          )
          .getSingle();
      rowsToReplace = countResult.read<int>('cnt');

      // Predicted balance = balance before cutoff + sum of CSV amounts.
      // The pre-cutoff balance source depends on balanceMode — see
      // _preCutoffBalance for why cumulative uses SUM and filtered uses
      // stored balance_after.
      if (mode == BalanceMode.column) {
        // In column mode, the balance comes from the CSV — just show the import sum
        predictedBalance = null;
      } else {
        final balanceBefore = await _preCutoffBalance(accountId, cutoffEpoch, balanceMode: mode);
        openingBalanceUnknown = balanceBefore == null;
        predictedBalance = balanceBefore == null ? null : balanceBefore + importSum;
      }
    }

    _log.fine(
      'previewTransactionImport: parsed=$parsed, errors=$errorCount, sum=$importSum, '
      'predicted=$predictedBalance, toReplace=$rowsToReplace',
    );
    return TransactionImportPreview(
      parsedRows: parsed,
      errorRows: errorCount,
      issues: issues,
      importSum: importSum,
      predictedBalance: predictedBalance,
      openingBalanceUnknown: openingBalanceUnknown,
      rowsToReplace: rowsToReplace,
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  static const _dateAndAmountRequired = ImportIssue(ImportIssueKind.dateAndAmountRequired, 'date and amount columns are required');

  /// The issue of data row [line], which failed with [error]. [label] opens
  /// the English message: 'Skipped line' on import, 'Line' in a dry run.
  static ImportIssue _rowIssue(int line, Object error, {String label = 'Skipped line'}) {
    final message = '$label $line: $error';
    return switch (error) {
      date_parse.DateParseException(:final raw, :final empty) => ImportIssue(
        empty ? ImportIssueKind.emptyDate : ImportIssueKind.invalidDate,
        message,
        line: line,
        value: raw,
      ),
      amt.AmountParseException(:final raw, :final empty, :final locale) => ImportIssue(
        empty ? ImportIssueKind.emptyAmount : ImportIssueKind.invalidAmount,
        message,
        line: line,
        value: raw,
        locale: locale,
      ),
      _UntaggedTypeException(:final raw) => ImportIssue(ImportIssueKind.untaggedType, message, line: line, value: raw),
      _RefusedCellException(:final field) => ImportIssue(ImportIssueKind.rejected, message, line: line, fields: [field]),
      _ => ImportIssue(ImportIssueKind.other, message, line: line, value: '$error'),
    };
  }

  /// [name] as a [BalanceMode]. Any other text is a caller's mistake, refused
  /// before anything is read or written — never imported as another mode.
  static BalanceMode _balanceModeNamed(String name) =>
      BalanceMode.parse(name) ?? (throw ArgumentError.value(name, 'balanceMode', 'not a balance mode'));

  /// Parse a date string. Delegates to shared [date_parse.parseDate]. A text
  /// with a zone ('Z', '+02:00') is an instant: it is read on the local
  /// calendar, like every date the app shows, so the calendar day the import
  /// cutoffs and annotation keys take of it is the local one — its UTC fields
  /// taken as a local day replaced the stored rows of the day before.
  DateTime _parseDate(String s) => date_parse.parseDate(s).toLocal();

  /// Try to parse a date column from [mapping] in [row]; returns null on missing/invalid.
  DateTime? _tryParseDateMapping(ColumnMapping? mapping, Map<String, String> row) {
    if (mapping == null) return null;
    final s = _resolveMapping(mapping, row);
    if (s == null || s.isEmpty) return null;
    try {
      return _parseDate(s);
    } catch (_) {
      return null;
    }
  }

  /// Parse [dateStr] with fallback to [fallback] when parsing fails.
  /// If both fail (parse error and no fallback), rethrows the parse error.
  DateTime _parseDateWithFallback(String dateStr, DateTime? fallback) {
    try {
      return _parseDate(dateStr);
    } catch (_) {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  double _parseAmount(String s) => amt.parseAmount(s, locale: _activeLocale);
  double? _tryParseAmount(String? s) => amt.tryParseAmount(s, locale: _activeLocale);

  /// The cell of the mapped currency column [mapping] in [row]; null when no
  /// currency column is mapped (the caller's default currency applies). A
  /// blank cell is not the default currency: the row is refused
  /// ([_RefusedCellException.blank]), never imported in a guessed one.
  String? _mappedCurrencyCell(ColumnMapping? mapping, Map<String, String> row) {
    if (mapping == null) return null;
    final cell = _resolveMapping(mapping, row) ?? '';
    if (cell.trim().isEmpty) throw const _RefusedCellException.blank('currency');
    return cell;
  }

  // ──────────────────────────────────────────────
  // Number-locale persistence (per-flow)
  // ──────────────────────────────────────────────

  /// Resolve the effective locale for a transaction import on [accountId]:
  /// 1. wizard `override` (also persists it to ImportConfigs)
  /// 2. previously-saved `ImportConfigs.numberLocale[accountId]`
  /// 3. `appLocale`
  /// 4. `en_US` (final fallback in [amt.resolveImportLocale])
  Future<void> _setLocaleForAccount({
    required int accountId,
    required String? override,
    required String? appLocale,
  }) async {
    final existing = await (_db.select(_db.importConfigs)..where((c) => c.accountId.equals(accountId))).getSingleOrNull();
    // The file's format: the user's choice for this file, else the account's
    // format (the usual case: same bank, same export), else the app locale.
    _activeLocale = amt.resolveImportLocale(saved: override ?? existing?.numberLocale, appLocale: appLocale);
    // The stored text's format: whatever the account already has. It is set
    // by the first import and never changed by a later file — a file in a
    // different format is re-spelled into it on write.
    _storedLocale = existing?.numberLocale ?? _activeLocale;
    if (_storedLocale != _activeLocale) {
      _log.info('import: file format $_activeLocale, stored format $_storedLocale - numeric cells re-spelled on write');
    }

    if (existing == null) {
      await _db
          .into(_db.importConfigs)
          .insert(
            ImportConfigsCompanion.insert(
              accountId: Value(accountId),
              scope: const Value('transaction'),
              numberLocale: Value(_storedLocale),
            ),
          );
    } else if (existing.numberLocale == null) {
      await (_db.update(_db.importConfigs)..where((c) => c.accountId.equals(accountId))).write(
        ImportConfigsCompanion(numberLocale: Value(_storedLocale), updatedAt: Value(DateTime.now())),
      );
    }
  }

  /// Columns the mappings read as numbers — the cells whose spelling the
  /// stored locale governs.
  static Set<String> _numericColumnsOf(List<ColumnMapping> mappings) {
    final cols = <String>{};
    for (final m in mappings) {
      if (m.targetField != 'amount' && m.targetField != 'balanceAfter') continue;
      if (m.sourceColumn != null) cols.add(m.sourceColumn!);
      if (m.balanceDiffColumn != null) cols.add(m.balanceDiffColumn!);
      for (final t in m.formulaTerms ?? const <FormulaTerm>[]) {
        cols.add(t.sourceColumn);
      }
    }
    return cols;
  }

  /// Resolve the effective locale for an asset-event import on
  /// [intermediaryId]. Same priority order as [_setLocaleForAccount];
  /// persistence target is `Intermediaries.defaultImportLocale`.
  Future<void> _setLocaleForIntermediary({
    required int intermediaryId,
    required String? override,
    required String? appLocale,
  }) async {
    final saved =
        override ?? (await (_db.select(_db.intermediaries)..where((i) => i.id.equals(intermediaryId))).getSingleOrNull())?.defaultImportLocale;
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);

    if (override != null) {
      await (_db.update(_db.intermediaries)..where((i) => i.id.equals(intermediaryId))).write(
        IntermediariesCompanion(
          defaultImportLocale: Value(override),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  static const _incomeLocaleConfigKey = 'IMPORT_INCOME_LOCALE';

  /// Resolve the effective locale for an income import. Persistence target
  /// is the `IMPORT_INCOME_LOCALE` AppConfigs row (single global value;
  /// income imports don't have a per-source key today).
  Future<void> _setLocaleForIncome({
    required String? override,
    required String? appLocale,
  }) async {
    String? saved = override;
    if (saved == null) {
      final row = await _db
          .customSelect(
            'SELECT value FROM app_configs WHERE key = ?',
            variables: [Variable.withString(_incomeLocaleConfigKey)],
          )
          .getSingleOrNull();
      final v = row?.read<String?>('value');
      if (v != null && v.isNotEmpty) saved = v;
    }
    _activeLocale = amt.resolveImportLocale(saved: saved, appLocale: appLocale);

    if (override != null) {
      await _db
          .into(_db.appConfigs)
          .insertOnConflictUpdate(
            AppConfigsCompanion.insert(
              key: _incomeLocaleConfigKey,
              value: override,
              description: const Value('Number-format locale for income imports'),
            ),
          );
    }
  }

  /// Normalize a type-column cell value (or a user's chip tag) for matching:
  /// trim, upper-case, and collapse spaces to underscores. Single source of
  /// truth shared by income- and asset-event type resolution so a multi-word
  /// tag (e.g. "POSIZIONE INDIVIDUALE") matches the same-normalized cell.
  String _normalizeTypeValue(String v) => v.trim().toUpperCase().replaceAll(' ', '_');

  /// Resolve an income row's [IncomeType] from its type-column value using
  /// ONLY the user's explicit wizard-chip tags — no keyword/substring guess.
  ///
  /// - No type column mapped ([hasTypeColumn] false): always
  ///   [IncomeType.income].
  /// - A value tagged into one of the sets resolves to that type.
  /// - Any other (untagged) value throws — the wizard gate normally prevents
  ///   this, but a loud failure here guards against a mis-typed refund
  ///   silently inflating income totals.
  IncomeType _resolveIncomeType(
    String s, {
    required bool hasTypeColumn,
    Set<String>? incomeValues,
    Set<String>? refundValues,
    Set<String>? pensionContributionValues,
  }) {
    if (!hasTypeColumn) return IncomeType.income;
    final normalized = _normalizeTypeValue(s);
    bool tagged(Set<String>? set) => set != null && set.any((v) => _normalizeTypeValue(v) == normalized);
    if (tagged(incomeValues)) return IncomeType.income;
    if (tagged(refundValues)) return IncomeType.refund;
    if (tagged(pensionContributionValues)) return IncomeType.pensionContribution;
    throw _UntaggedTypeException('Untagged income type "$s" (normalized: "$normalized")', raw: s);
  }

  /// Returns `null` when the row is an external fee row (the type value
  /// matched [feeValues] — e.g. "Commissioni" / "Bollo" in cash-flow-style
  /// broker exports). Fee rows are handled by the caller's two-pass loop
  /// (matched by orderRef and folded into the parent's commission, or
  /// dropped when no match). Throws when the type value is genuinely
  /// unrecognized.
  EventType? _parseEventType(
    String s, {
    Set<String>? buyValues,
    Set<String>? sellValues,
    Set<String>? feeValues,
    Set<String>? revalueValues,

    /// Kept for wizard-API compatibility — these values map to
    /// `EventType.buy`. Pension contributions are accounting-equivalent
    /// to a discounted-NAV purchase: same effect on cost basis and
    /// qty-at-revalue. Collapsing them to `buy` keeps the event model
    /// lean (3 types) and avoids two SQL paths everywhere.
    Set<String>? contributeValues,
  }) {
    final normalized = _normalizeTypeValue(s);
    // Custom user-defined mappings take priority — wizard chip tags win
    // over built-in aliases so users can override surprising defaults.
    // Tagged values are normalized the SAME way as the cell value so a tag
    // containing spaces (e.g. "POSIZIONE INDIVIDUALE") matches the
    // space→underscore-normalized cell.
    if (feeValues != null && feeValues.any((v) => _normalizeTypeValue(v) == normalized)) return null;
    if (buyValues != null && buyValues.any((v) => _normalizeTypeValue(v) == normalized)) return EventType.buy;
    if (sellValues != null && sellValues.any((v) => _normalizeTypeValue(v) == normalized)) return EventType.sell;
    if (revalueValues != null && revalueValues.any((v) => _normalizeTypeValue(v) == normalized)) return EventType.revalue;
    if (contributeValues != null && contributeValues.any((v) => _normalizeTypeValue(v) == normalized)) return EventType.buy;
    // Direct enum match (literal BUY / SELL / REVALUE in the cell).
    final direct = EventType.values.where((e) => e.name.toUpperCase() == normalized).firstOrNull;
    if (direct != null) return direct;
    // Unknown type — fail loudly so the user knows to tag this value via the
    // wizard chips (buy/sell/revalue/fee) or omit the type column. There are
    // NO built-in keyword aliases: type classification is purely explicit
    // (user tags + literal enum names). A silent guess could mis-type rows —
    // e.g. turning dividends/taxes/transfers into phantom buys and inflating
    // the asset's cost basis.
    throw _UntaggedTypeException('Unknown event type "$s" (normalized: "$normalized")', raw: s);
  }

  /// Pre-cutoff balance for the account at [cutoffEpoch].
  ///
  /// In `cumulative` mode every transaction contributes to the running
  /// balance, so SUM(amount) is the source of truth (immune to per-batch
  /// `balance_after` drift from older partial-period imports).
  ///
  /// In `filtered` mode some rows are excluded by a CSV-only filter column
  /// that doesn't exist in the DB, so SUM(amount) over-counts. We instead
  /// trust the stored `balance_after` previous imports wrote as the
  /// *filtered* cumulative — see [_storedBalanceBefore] for which row's.
  /// Null when that row has no stored balance: what the import continues
  /// from is unknown, and 0 would be an invented figure. With no row before
  /// the import at all, it starts from 0.
  ///
  /// [survivorsOnly] (re-run from stored data): every imported row is about
  /// to be replaced, so only hand-entered rows count as "already there".
  Future<double?> _preCutoffBalance(
    int accountId,
    int cutoffEpoch, {
    required BalanceMode balanceMode,
    bool survivorsOnly = false,
  }) async {
    final survivors = survivorsOnly ? ' AND raw_metadata IS NULL' : '';
    if (balanceMode == BalanceMode.filtered) {
      final before = await _storedBalanceBefore(accountId, cutoffEpoch, survivorsOnly: survivorsOnly);
      return before == null ? 0.0 : before.balance;
    }
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount), 0) AS s FROM transactions '
          'WHERE account_id = ? AND operation_date < ?$survivors',
          variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
        )
        .getSingle();
    return row.read<double>('s');
  }

  /// Stored `balance_after` of the account just before the rows booked from
  /// [cutoffEpoch] on: the one of the VALUE-DATE last row booked before it.
  /// Stored balances are a value-date running balance (see
  /// running_balance.dart), so the figure on the last BOOKED row is not what
  /// the account held before the import. Null when there is no such row; its
  /// `balance` is null when it carries none. [survivorsOnly] as in
  /// [_preCutoffBalance].
  Future<({double? balance})?> _storedBalanceBefore(int accountId, int cutoffEpoch, {bool survivorsOnly = false}) async {
    final row = await _db
        .customSelect(
          'SELECT balance_after FROM transactions '
          'WHERE account_id = ? AND operation_date < ?${survivorsOnly ? ' AND raw_metadata IS NULL' : ''} '
          'ORDER BY value_date DESC, id DESC LIMIT 1',
          variables: [Variable.withInt(accountId), Variable.withInt(cutoffEpoch)],
        )
        .getSingleOrNull();
    return row == null ? null : (balance: row.readNullable<double>('balance_after'));
  }

  /// Compute balanceAfter for parsed rows based on the selected mode.
  /// [startingBalance] seeds cumulative/filtered modes so newly imported rows
  /// continue from the account's existing balance instead of restarting at 0.
  /// Null (unknown, see [_preCutoffBalance]): no balance is computed — filtered
  /// mode still marks its excluded rows cancelled.
  void _computeBalances(
    List<_ParsedTransactionRow> rows,
    BalanceMode balanceMode,
    Set<String>? balanceFilterInclude,
    double? startingBalance,
  ) {
    if (rows.isEmpty || balanceMode == BalanceMode.none) return;

    // The value-date timeline (the canonical "money moved" date, per
    // AGENTS.md), file order breaking ties: the one the ledger's
    // recalculation walks too, so both store the same balances for the same
    // set of transactions.
    final timeline = [
      for (final r in rows)
        RunningBalanceRow(
          valueDate: r.valueDate ?? r.date,
          bookingDate: r.date,
          order: r.csvIndex,
          amount: r.amount,
          statedBalance: r.balanceAfterFromColumn,
        ),
    ];

    if (balanceMode == BalanceMode.column) {
      // The bank's balance column is a booking-order figure. Stored balances
      // live on the value-date timeline, anchored on the bank's closing (same
      // rule as TransactionService.recalculateBalances).
      final anchored = anchoredRunningBalances(timeline);
      for (var i = 0; i < rows.length; i++) {
        rows[i].balanceAfter = anchored.balances[i];
      }
      _log.fine('_computeBalances: column - anchored=${anchored.anchored} closing=${anchored.bankClosing} opening=${anchored.opening}');
      return;
    }

    // Filtered mode: a row whose filter value is excluded does not move the
    // balance.
    final moves = [
      for (final r in rows)
        balanceMode == BalanceMode.cumulative ||
            balanceFilterInclude == null ||
            balanceFilterInclude.isEmpty ||
            balanceFilterInclude.contains(r.filterColumnValue ?? ''),
    ];
    final balances = runningBalances(timeline, opening: startingBalance, moves: (i) => moves[i]);
    for (var i = 0; i < rows.length; i++) {
      // Excluded from the balance == not a real movement (cancelled/
      // declined). Mark it so downstream views can show it struck-through
      // and exclude it from amount-based totals. Its balance is the carried
      // running value (it did not move money), and an explicit status-column
      // mapping, if any, is not overridden.
      if (!moves[i]) rows[i].status ??= TransactionStatus.cancelled;
      rows[i].balanceAfter = balances[i];
    }
    _log.fine('_computeBalances: ${balanceMode.name} - done (seed=$startingBalance)');
  }
}

/// A type-column value the wizard did not tag; [raw] is the cell.
class _UntaggedTypeException extends FormatException {
  final String raw;

  const _UntaggedTypeException(super.message, {required this.raw});
}

/// A cell of a mapped column the row needs a value from ([field], a wizard
/// field name) that is blank, or that the database does not accept: the row
/// is refused before anything is written — never filled with a default, and
/// never failing the whole import when it is stored.
class _RefusedCellException extends FormatException {
  final String field;

  /// A blank cell.
  const _RefusedCellException.blank(this.field) : super('Empty $field');

  /// A [cell] the database does not accept.
  const _RefusedCellException(this.field, String cell) : super('Value not accepted for $field', cell);
}

/// Internal data class for a parsed transaction row before building companion.
class _ParsedTransactionRow {
  final DateTime date;
  final DateTime? valueDate;
  final double amount;
  final String description;
  final double? balanceAfterFromColumn;
  final String currency;

  /// Mutable: filtered balance mode sets this to [TransactionStatus.cancelled]
  /// for rows whose filter value is excluded from the balance, so an
  /// excluded ("not real") row is also marked cancelled. Defaults to the
  /// explicit status-column mapping (if any), else null → DB default settled.
  TransactionStatus? status;
  final Map<String, String> rawMetadata;
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
    this.filterColumnValue,
    required this.csvIndex,
  });
}
