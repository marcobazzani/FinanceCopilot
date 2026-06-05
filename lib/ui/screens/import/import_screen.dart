import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../../database/database.dart';
import '../../../database/tables.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/preview_transforms.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/market/isin_lookup_service.dart';
import 'package:finance_copilot/services/import/pdf_exceptions.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/dialogs.dart';
import '../../../utils/formatters.dart' as fmt;
import '../../../utils/logger.dart';
import '../../widgets/isin_url_paste_recovery.dart';

part 'column_mapper_step.dart';
part 'mapping_content.dart';
part 'refine_panel.dart';
part 'mode_sections.dart';
part 'amount_formula.dart';
part 'confirm_step.dart';
part 'quick_confirm_step.dart';
part 'result_step.dart';

final _log = getLogger('ImportScreen');

/// The full import wizard: pick file -> preview -> map columns -> select target -> confirm.
class ImportScreen extends ConsumerStatefulWidget {
  final int? preselectedAccountId;
  final ImportTarget? preselectedTarget;

  /// For integration tests: inject a pre-parsed file preview (bypasses file picker).
  final FilePreview? testPreview;

  /// When shared from another app (Android share target), auto-load this file.
  final String? initialFilePath;
  const ImportScreen({super.key, this.preselectedAccountId, this.preselectedTarget, this.testPreview, this.initialFilePath});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

/// Remember last directory across navigations and app restarts.
String? _lastDirectory;

Future<String?> _loadLastDirectory() async {
  if (_lastDirectory != null) return _lastDirectory;
  if (Platform.isAndroid || Platform.isIOS) return null; // no persistent last-dir on mobile
  try {
    final prefsDir = Directory(
      p.join(
        Platform.environment['HOME'] ?? '',
        'Library/Containers/net.bazzani.financecopilot/Data/Documents/FinanceCopilot',
      ),
    );
    final file = File(p.join(prefsDir.path, '.last_import_dir'));
    if (await file.exists()) {
      _lastDirectory = (await file.readAsString()).trim();
    }
  } catch (_) {}
  return _lastDirectory;
}

Future<void> _saveLastDirectory(String dir) async {
  _lastDirectory = dir;
  if (Platform.isAndroid || Platform.isIOS) return; // no persistent last-dir on mobile
  try {
    final prefsDir = Directory(
      p.join(
        Platform.environment['HOME'] ?? '',
        'Library/Containers/net.bazzani.financecopilot/Data/Documents/FinanceCopilot',
      ),
    );
    await File(p.join(prefsDir.path, '.last_import_dir')).writeAsString(dir);
  } catch (_) {}
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 1; // 1=preview+map, 2=confirm, 3=result
  /// When true, render the quick-confirm view (header preview + read-only mappings + Import / Let me edit)
  /// instead of the full column mapper. Auto-enabled when a saved config is applied successfully.
  bool _isQuickMode = false;
  FilePreview? _preview;

  /// Untransformed parser output. [_preview] is derived from this by applying
  /// [_transforms]. Kept so toggling/editing transforms doesn't require a
  /// file re-parse.
  FilePreview? _rawPreview;
  String? _filePath;
  String? _selectedSheet;
  int _skipRows = 0;
  final _skipRowsCtrl = TextEditingController(text: '0');
  ImportTarget _target = ImportTarget.transaction;
  int? _targetId; // accountId or assetId
  int? _selectedIntermediaryId; // for asset imports

  /// Number-format locale chosen in the wizard. `null` = "Auto" (resolved
  /// from the per-source saved value or from the app locale at import time).
  /// When the user explicitly picks a value here, it is persisted to the
  /// import-source config (per account / per intermediary / global income).
  String? _selectedNumberLocale;

  /// Effective locale to use for stringifying XLSX numeric cells. Mirrors
  /// the resolution `parseAmount` does later: explicit selection > app
  /// locale > en_US. Without this, parser would emit "7707.97" while
  /// parseAmount with it_IT would misread the dot as thousands separator.
  String _effectiveNumberLocale() => _selectedNumberLocale ?? ref.read(appLocaleProvider).value ?? 'en_US';

  // Asset import mode: 'historic' (date+rate required) or 'current' (default to today, rate auto-fetched)
  String _assetImportMode = 'historic';

  // Column mappings: targetField -> sourceColumn (for simple fields)
  final Map<String, String?> _mappings = {};

  // Formula terms for amount (visual formula builder)
  final List<FormulaTerm> _amountFormula = [];

  bool _noHeader = false;
  bool _sameSettlementDate = false; // when true, valueDate = date (operation date)
  String? _balanceDiffColumn; // when set, amount = balance[i] - balance[i-1]

  /// Post-parse row/column transforms (filters + column splits) chosen in the
  /// "Refine rows & columns" panel. Applied to the raw parser output to
  /// derive [_preview]. Works for any source (CSV/XLSX/PDF/clipboard).
  PreviewTransforms _transforms = const PreviewTransforms();

  // Debounce timer for skip-rows auto re-parse
  Timer? _skipRowsTimer;

  // Cached saved import config (loaded once, applied after every re-parse)
  ImportConfig? _savedConfig;

  // Cached full ISIN summary (from all rows, not capped preview)
  Map<String, int>? _fullIsinSummary;

  // Shared complete preview load. The mapper, confirm lookup, dry-run
  // preview, and final import can all request full rows; sharing the in-flight
  // work prevents duplicate XLSX reparses when the user proceeds quickly.
  FilePreview? _fullPreviewCache;
  Future<FilePreview>? _fullPreviewFuture;
  String? _fullPreviewLocale;

  // ISINs excluded from import by user (unchecked in exchange picker)
  final Set<String> _excludedIsins = {};

  ImportResult? _result;
  bool _importing = false;
  bool _parsing = false;
  int _importedSoFar = 0;
  int _importTotal = 0;
  String? _error;

  // Preview (dry-run) state
  TransactionImportPreview? _txPreview;
  AssetEventImportPreview? _assetPreview;
  bool _previewing = false;

  List<String> get _requiredFields => switch (_target) {
    ImportTarget.transaction => ['date', 'valueDate', 'amount', 'description'],
    // Asset event imports come in two flavors:
    //   - byIsin (ISIN-grouped, e.g. broker trades, 401(k) multi-sub-fund):
    //     ISIN column drives asset creation/lookup.
    //   - singleAsset (pension funds, manual holdings): every row routes
    //     to one pre-existing asset chosen by the user, no ISIN needed,
    //     unit columns are optional (cash-only contributes auto-fill).
    ImportTarget.assetEvent =>
      _assetEventMode == 'singleAsset'
          ? <String>[]
          : (_assetImportMode == 'historic'
                ? ['date', 'isin', 'quantity', 'price', 'currency', 'exchangeRate']
                : ['isin', 'quantity', 'price', 'currency']),
    ImportTarget.income => ['date', 'amount'],
  };

  List<String> get _optionalFields => switch (_target) {
    ImportTarget.transaction => ['currency', 'status'],
    ImportTarget.assetEvent => _assetImportMode == 'historic' ? ['description'] : ['date', 'exchangeRate', 'description'],
    ImportTarget.income => ['type', 'currency'],
  };

  // Multi-column mappings for optional fields: field -> [col1, col2, ...]
  final Map<String, List<String>> _multiMappings = {};
  // Delimiter for string concatenation in multi-column mappings (default: space)
  final Map<String, String> _multiDelimiters = {};

  // Balance computation mode: 'cumulative' | 'column' | 'filtered'
  String _balanceMode = 'cumulative';
  // For 'filtered' mode: which CSV column to filter on
  String? _balanceFilterColumn;
  // For 'filtered' mode: included status values
  final Set<String> _balanceFilterInclude = {};

  // Fee computation mode for asset imports: 'column' | 'computed'
  // 'column' = map from a CSV column (default)
  // 'computed' = fee = |amount| - quantity * price / exchangeRate
  String _feeMode = 'column';

  // Auto-calculate amount as quantity * price for asset events
  bool _autoCalcAmount = false;

  // Type detection: 'column' (map from CSV with custom values), 'sign' (infer from qty/amount sign)
  String _typeMode = 'column';
  final Set<String> _buyValues = {};
  final Set<String> _sellValues = {};

  /// Type-column values that mark a row as an external fee (e.g.
  /// "Commissioni" in Directa exports). When the user also maps an
  /// `orderRef` column, fee rows are folded into the parent Buy/Sell's
  /// commission. Without orderRef, they're silently dropped.
  final Set<String> _feeValues = {};

  /// Sign-mode convention: when true, a negative cash-flow amount is a BUY
  /// (Directa-style: negative = money out = bought it). Default false keeps
  /// the historical "negative = sell" behavior.
  bool _negativeIsBuy = false;
  // Revalue tagging — populated from the wizard's chip UI when the user
  // is importing position-snapshot rows (PPP TOTALEP, etc.). Pension
  // contributions get tagged Buy (cash inflow that grows the position —
  // semantically identical to a discounted buy). See `_parseEventType`
  // in lib/services/import_service.dart.
  final Set<String> _revalueValues = {};

  /// Optional column to source the amount from for Revalue rows only.
  /// Pension statements keep the position-snapshot value in a different
  /// column (e.g. Saldo) than per-row contributions (e.g. Entrate). When a
  /// Revalue type bucket exists and this is set, revalue rows read their
  /// amount from here. `null` = use the primary amount mapping for all rows.
  String? _revalueAmountColumn;

  // Asset-event single-asset mode: when set, every parsed row routes to
  // this pre-existing asset (pension funds, manual holdings) instead of
  // being grouped by ISIN. Toggled by a SegmentedButton in the wizard
  // when target = assetEvent.
  String _assetEventMode = 'byIsin'; // 'byIsin' | 'singleAsset'
  int? _singleAssetTargetId;

  // Cached unique values per column (from ALL rows, not just preview)
  final Map<String, List<String>> _fullUniqueValues = {};
  bool _loadingUniqueValues = false;

  // Exchange picker for asset imports (ISIN -> all available listings, user picks one)
  Map<String, IsinLookupResult>? _isinLookupResults;
  final Map<String, IsinExchangeOption> _selectedExchanges = {};
  String? _defaultExchange; // e.g. "Milano" -- applies to all ISINs
  bool _lookingUpIsins = false;

  /// When true, the preview shows ALL parsed rows in one scrollable table
  /// instead of the first-5 / last-5 split view. The full row set is loaded
  /// lazily ([_showAllRows]) only when the user toggles this on — never
  /// eagerly, so large CSV/XLSX don't pull every row into memory up front.
  bool _showAllPreviewRows = false;

  /// Lazily-loaded full row set for the "Show all" preview. Null until the
  /// user requests it; loaded via [_loadCompletePreview].
  List<Map<String, String>>? _showAllRows;
  bool _loadingShowAll = false;

  /// Complete (transformed) row set used to drive the preview WHEN transforms
  /// are active. Row filters/splits must be evaluated over every row — not the
  /// capped first-5/last-5 sample — otherwise middle rows (e.g. Marzo/Aprile
  /// in a pension statement) silently vanish from the preview and the kept-row
  /// count is wrong. Loaded once per (transform, locale) and reused.
  List<Map<String, String>>? _transformedFullRows;
  bool _loadingTransformedFull = false;

  /// True when the loaded source is a PDF. PDFs go through the table
  /// reconstructor, so "skip rows" has no useful meaning (it would just drop
  /// the first N reconstructed rows, not skip pre-header lines) — the control
  /// is hidden for PDFs; use row filters instead.
  bool get _isPdf => (_filePath ?? '').toLowerCase().endsWith('.pdf');

  // ignore: invalid_use_of_protected_member
  void _setState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _clearFullPreviewCache() {
    _fullPreviewCache = null;
    _fullPreviewFuture = null;
    _fullPreviewLocale = null;
  }

  /// Apply [_transforms] to a parser-produced [FilePreview], returning a new
  /// preview with derived columns and filtered rows. Shared by the capped
  /// preview and the full-row load so the import sees the same shape the
  /// user previewed.
  FilePreview _applyTransforms(FilePreview raw) {
    if (_transforms.isEmpty) return raw;
    final cols = _transforms.transformColumns(raw.columns);
    final rows = _transforms.transformRows(raw.rows);
    // Row filters change the effective row count. We can only state the exact
    // filtered total when we hold the COMPLETE row set (raw not capped);
    // filtering a capped sample (first5+last5) would understate the real
    // total. When capped, keep the raw total so the header isn't misleading —
    // the precise filtered count is shown once the full set is loaded
    // ("Show all") or computed at import.
    final isComplete = raw.rows.length >= raw.totalRows;
    final int effectiveTotal;
    if (_transforms.filters.isEmpty) {
      effectiveTotal = raw.totalRows;
    } else if (isComplete) {
      effectiveTotal = rows.length;
    } else {
      effectiveTotal = raw.totalRows;
    }
    return FilePreview(
      columns: cols,
      rows: rows,
      totalRows: effectiveTotal,
      filePath: raw.filePath,
      clipboardText: raw.clipboardText,
      skipRows: raw.skipRows,
      noHeader: raw.noHeader,
      sheetName: raw.sheetName,
      numberLocale: raw.numberLocale,
    );
  }

  /// Re-derive [_preview] from [_rawPreview] using the current transforms.
  /// Call after any transform edit. Re-runs auto-map so newly created split
  /// columns can be picked up.
  void _rebuildPreviewFromTransforms() {
    final raw = _rawPreview;
    if (raw == null) return;
    setState(() {
      _preview = _applyTransforms(raw);
      _clearFullPreviewCache();
      _fullIsinSummary = null;
      _fullUniqueValues.clear();
      // The previously-loaded full row sets are stale after a transform change.
      _showAllRows = null;
      _transformedFullRows = null;
      _autoMap(_preview!.columns);
      _reconcileTypeTags();
    });
    if (_savedConfig != null) _applySavedConfig(restoreTransforms: false);
    // Load the complete transformed set so the preview shows every affected
    // row (filters/splits evaluated over all rows, not the capped sample).
    _ensureTransformedFullRows();
    // If the user had "Show all" open, refresh it against the new transforms.
    if (_showAllPreviewRows) {
      _loadCompletePreview().then((full) {
        if (mounted) _setState(() => _showAllRows = full.rows);
      });
    }
  }

  /// Drop Buy/Sell/Revalue/Fee type tags that reference a value no longer
  /// present in the (post-transform) Type column. Column splits/filters can
  /// rewrite the Type column's text — e.g. "POSIZIONE INDIVIDUALE 01/01"
  /// becomes "POSIZIONE INDIVIDUALE" — which would otherwise leave the old
  /// tag orphaned and the new value silently untagged (→ "Unknown event
  /// type" at import). Pruning forces the value back into the "needs
  /// tagging" state so the wizard's gate catches it and the user re-tags.
  void _reconcileTypeTags() {
    final typeCol = _mappings['type'];
    if (typeCol == null || _preview == null) return;
    if (!_preview!.columns.contains(typeCol)) {
      // The previously-mapped type column no longer exists (e.g. renamed by
      // a split); clear all tags — they can't apply.
      _buyValues.clear();
      _sellValues.clear();
      _revalueValues.clear();
      _feeValues.clear();
      return;
    }
    // Prune against the FULL value set when it's loaded; otherwise fall back
    // to the capped preview. On a large file a tag's value may live beyond
    // the preview sample, so prefer the full set to avoid dropping a tag that
    // is actually still present.
    final current = (_fullUniqueValues[typeCol] ?? _uniqueColumnValues(typeCol)).toSet();
    _buyValues.removeWhere((v) => !current.contains(v));
    _sellValues.removeWhere((v) => !current.contains(v));
    _revalueValues.removeWhere((v) => !current.contains(v));
    _feeValues.removeWhere((v) => !current.contains(v));
  }

  /// Toggle the preview's "Show all rows" mode. Turning it ON lazily loads the
  /// full (transformed) row set via [_loadCompletePreview] — never eagerly, so
  /// big CSV/XLSX don't materialise every row until the user asks. Turning it
  /// OFF drops the loaded rows so they can be GC'd.
  Future<void> _toggleShowAllPreview() async {
    if (_showAllPreviewRows) {
      _setState(() {
        _showAllPreviewRows = false;
        _showAllRows = null;
      });
      return;
    }
    _setState(() => _loadingShowAll = true);
    try {
      final full = await _loadCompletePreview();
      if (!mounted) return;
      _setState(() {
        _showAllRows = full.rows;
        _showAllPreviewRows = true;
        _loadingShowAll = false;
      });
    } catch (e) {
      _log.warning('_toggleShowAllPreview: $e');
      if (mounted) _setState(() => _loadingShowAll = false);
    }
  }

  Future<FilePreview> _loadCompletePreview() {
    final preview = _preview!;
    final raw = _rawPreview ?? preview;
    // When the parser already returned every row (small file), the capped
    // preview IS complete — but only trust that on the RAW preview, since
    // filters make _preview.totalRows the post-filter count.
    if (raw.rows.length >= raw.totalRows) {
      return Future.value(_transforms.isEmpty ? preview : _applyTransforms(raw));
    }

    final locale = _effectiveNumberLocale();
    if (_fullPreviewCache != null && _fullPreviewLocale == locale) {
      return Future.value(_fullPreviewCache!);
    }

    final existing = _fullPreviewFuture;
    if (existing != null && _fullPreviewLocale == locale) return existing;

    final importer = ref.read(importServiceProvider);
    _fullPreviewLocale = locale;
    // getFullRows re-parses the source, so it returns the RAW (untransformed)
    // rows. Apply the same transforms the capped preview used so the import
    // operates on exactly what the user saw.
    _fullPreviewFuture = importer
        .getFullRows(raw, numberLocale: locale)
        .then((full) {
          final transformed = _applyTransforms(full);
          _fullPreviewCache = transformed;
          return transformed;
        })
        .whenComplete(() {
          _fullPreviewFuture = null;
        });
    return _fullPreviewFuture!;
  }

  /// Ensure [_transformedFullRows] is populated when transforms are active and
  /// the parser only returned a capped preview. Loads the complete transformed
  /// set once so the preview reflects EVERY row the filters/splits act on (no
  /// missing middle rows). No-op when transforms are empty, the raw set is
  /// already complete, or a load is already running/done.
  void _ensureTransformedFullRows() {
    final raw = _rawPreview;
    if (raw == null) return;
    if (_transforms.isEmpty) return;
    if (raw.rows.length >= raw.totalRows) return; // not capped — preview is complete
    if (_transformedFullRows != null || _loadingTransformedFull) return;
    _loadingTransformedFull = true;
    _loadCompletePreview()
        .then((full) {
          if (!mounted) return;
          _setState(() {
            _transformedFullRows = full.rows;
            _loadingTransformedFull = false;
          });
        })
        .catchError((Object e) {
          _log.warning('_ensureTransformedFullRows: $e');
          if (mounted) _setState(() => _loadingTransformedFull = false);
        });
  }

  IsinLookupService? _maybeIsinLookupService() {
    final priceService = ref.read(marketPriceServiceProvider);
    return priceService is WebMarketDataService ? IsinLookupService(priceService) : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.preselectedAccountId != null) {
      _target = ImportTarget.transaction;
      _targetId = widget.preselectedAccountId;
    }
    if (widget.preselectedTarget != null) {
      _target = widget.preselectedTarget!;
    }
    // Integration test injection: auto-load a pre-parsed preview
    if (widget.testPreview != null) {
      _rawPreview = widget.testPreview;
      _preview = widget.testPreview;
      _autoMap(widget.testPreview!.columns);
      // Mirror production _loadFile: apply any saved config for the
      // preselected account so quick-confirm renders when available.
      Future.microtask(() => _loadSavedConfig(widget.testPreview!.columns));
    }
    // Shared file from another app (Android share target)
    if (widget.initialFilePath != null) {
      Future.microtask(() => _loadFile(widget.initialFilePath!));
    }
  }

  @override
  void dispose() {
    _skipRowsTimer?.cancel();
    _skipRowsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.importTitle),
        leading: _step == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 1),
              )
            : null,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _step / 3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (_step) {
                1 => _buildColumnMapper(),
                2 => _buildConfirm(),
                3 => _buildResult(),
                _ => const SizedBox(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    _log.info('_pickFile: opening file picker');
    await _loadLastDirectory();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls', 'tsv', 'pdf'],
      initialDirectory: _lastDirectory,
    );

    if (result == null || result.files.single.path == null) {
      _log.info('_pickFile: cancelled by user');
      return;
    }

    final path = result.files.single.path!;
    await _saveLastDirectory(p.dirname(path));
    await _loadFile(path);
  }

  /// Parse and load a file by path (used by both file picker and share intent).
  Future<void> _loadFile(String path) async {
    _log.info('_loadFile: loading $path');
    setState(() {
      _error = null;
      _filePath = path;
      _parsing = true;
    });

    try {
      final importer = ref.read(importServiceProvider);
      final ext = path.toLowerCase().split('.').last;

      // For Excel files, check for multiple sheets
      if (ext == 'xlsx' || ext == 'xls') {
        final sheets = await importer.listSheets(path);
        if (sheets.length > 1) {
          _log.info('_loadFile: multi-sheet Excel, showing sheet picker');
          await _showSheetPicker(sheets);
          if (_selectedSheet == null) {
            _log.info('_loadFile: sheet selection cancelled');
            return;
          }
          _log.info('_loadFile: selected sheet=$_selectedSheet');
        }
      }

      final preview = await importer.parseFile(
        path,
        sheetName: _selectedSheet,
        skipRows: _skipRows,
        noHeader: _noHeader,
        numberLocale: _effectiveNumberLocale(),
      );
      if (preview.rows.isEmpty) {
        _log.warning('_loadFile: file is empty after parsing');
        setState(() => _error = ref.read(appStringsProvider).fileEmpty);
        return;
      }

      _log.info('_loadFile: parsed OK - ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _rawPreview = preview;
        _preview = _applyTransforms(preview);
        _clearFullPreviewCache();
        _fullIsinSummary = null;
        _parsing = false;
        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(_preview!.columns);
      });
      // Load saved config if we have a preselected account
      await _loadSavedConfig(preview.columns);
    } catch (e, stack) {
      _log.severe('_loadFile: error reading file', e, stack);
      final s = ref.read(appStringsProvider);
      setState(() {
        _error = switch (e) {
          PdfNoTextLayerException() => s.pdfNoTextLayer,
          PdfEncryptedException() => s.pdfEncrypted,
          PdfUnreadableTextException() => s.pdfUnreadableText,
          PdfTableNotDetectedException() => s.pdfTableNotDetected,
          _ => 'Error reading file: $e',
        };
        _parsing = false;
      });
    } finally {
      // Safety net: every early-return path in the try above (cancelled
      // sheet picker, empty file) must not leave the screen stuck on the
      // parsing spinner.
      if (mounted && _parsing) setState(() => _parsing = false);
    }
  }

  Future<void> _showSheetPicker(List<String> sheets) async {
    final s = ref.read(appStringsProvider);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.selectSheetTitle),
        children: sheets
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s),
                child: Text(s),
              ),
            )
            .toList(),
      ),
    );
    setState(() => _selectedSheet = selected);
  }

  /// Try to auto-map columns by matching common names.
  void _autoMap(List<String> columns) {
    final lowerCols = {for (final c in columns) c.toLowerCase(): c};

    /// Try to map a target field by trying a list of common column names.
    void tryMap(String field, List<String> keys) {
      for (final key in keys) {
        if (lowerCols.containsKey(key)) {
          _mappings[field] = lowerCols[key];
          return;
        }
      }
    }

    // Shared
    tryMap('date', ['data_operazione', 'operation_date', 'date', 'data', 'data di inizio']);
    tryMap('valueDate', ['data_valuta', 'data valuta', 'value_date', 'value date']);
    // If no value date column found, default to same as operation date
    if (_mappings['valueDate'] == null) _sameSettlementDate = true;
    tryMap('description', ['description', 'descrizione', 'causale', 'memo', 'note', 'notes', 'oggetto', 'dettagli']);

    if (_target == ImportTarget.transaction) {
      tryMap('amount', ['amount', 'importo', 'entrate', 'uscite', 'controvalore']);
    } else if (_target == ImportTarget.income) {
      tryMap('amount', ['amount', 'importo', 'stipendio', 'netto', 'salary', 'net']);
      tryMap('type', ['type', 'tipo', 'description', 'descrizione']);
      tryMap('currency', ['currency', 'valuta', 'divisa']);
    } else {
      // Asset event fields
      tryMap('isin', ['isin', 'codice isin', 'isin code']);
      tryMap('type', ['type', 'tipo', 'operazione', 'buy/sell', 'operation']);
      tryMap('quantity', ['quantity', 'quantità', 'quantita', 'qty', 'nominale']);
      tryMap('price', ['price', 'prezzo', 'corso', 'prezzo unitario', 'unit price']);
      tryMap('currency', ['currency', 'valuta', 'divisa', 'ccy']);
      tryMap('exchangeRate', ['exchange rate', 'cambio', 'tasso di cambio', 'fx rate', 'tasso']);
      tryMap('amount', ['amount', 'controvalore', 'equivalent value', 'importo', 'total', 'entrate', 'uscite']);
      tryMap('commission', ['fee', 'commission', 'commissione', 'commissioni', 'spese']);
    }
  }

  Future<void> _reparseFile() async {
    if (_filePath == null) return;
    _log.info('_reparseFile: re-parsing with skipRows=$_skipRows, sheet=$_selectedSheet');
    try {
      final importer = ref.read(importServiceProvider);
      final preview = await importer.parseFile(
        _filePath!,
        sheetName: _selectedSheet,
        skipRows: _skipRows,
        noHeader: _noHeader,
        numberLocale: _effectiveNumberLocale(),
      );
      if (preview.rows.isEmpty) {
        _log.warning('_reparseFile: empty after skipping $_skipRows rows');
        setState(() => _error = ref.read(appStringsProvider).fileEmptyAfterSkip(_skipRows));
        return;
      }
      _log.info('_reparseFile: OK - ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _rawPreview = preview;
        _preview = _applyTransforms(preview);
        _clearFullPreviewCache();
        _fullIsinSummary = null;
        _error = null;
        _mappings.clear();
        _amountFormula.clear();

        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(_preview!.columns);
      });

      // Re-apply saved config on top of auto-map
      if (_savedConfig != null) {
        _applySavedConfig();
      }
    } catch (e, stack) {
      _log.severe('_reparseFile: error', e, stack);
      setState(() => _error = ref.read(appStringsProvider).errorReparsingFile(e));
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      setState(() => _error = ref.read(appStringsProvider).clipboardEmpty);
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _filePath = null;
    });
    try {
      final importer = ref.read(importServiceProvider);
      final preview = await importer.parseClipboard(data.text!, skipRows: _skipRows, noHeader: _noHeader);
      if (preview.rows.isEmpty) {
        setState(() {
          _error = ref.read(appStringsProvider).noDataRowsClipboard;
          _parsing = false;
        });
        return;
      }
      setState(() {
        _rawPreview = preview;
        _preview = _applyTransforms(preview);
        _clearFullPreviewCache();
        _fullIsinSummary = null;
        _parsing = false;
        _mappings.clear();
        _amountFormula.clear();

        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(_preview!.columns);
      });
    } catch (e) {
      setState(() {
        _error = ref.read(appStringsProvider).errorParsingClipboard(e);
        _parsing = false;
      });
    }
  }

  /// Load saved import config for the current scope (account / intermediary /
  /// single asset / income) and cache it.
  Future<void> _loadSavedConfig(List<String> fileColumns) async {
    final svc = ref.read(importConfigServiceProvider);
    final ImportConfig? config;
    switch (_target) {
      case ImportTarget.transaction:
        final accountId = widget.preselectedAccountId ?? _targetId;
        if (accountId == null) return;
        config = await svc.getByAccount(accountId);
      case ImportTarget.assetEvent:
        if (_assetEventMode == 'singleAsset') {
          if (_singleAssetTargetId == null) return;
          config = await svc.getByAsset(_singleAssetTargetId!);
        } else {
          if (_selectedIntermediaryId == null) return;
          config = await svc.getByIntermediary(_selectedIntermediaryId!);
        }
      case ImportTarget.income:
        config = await svc.getIncome();
    }
    if (config == null) return;

    _log.info('_loadSavedConfig: found ${config.scope} config');
    _savedConfig = config;
    _selectedNumberLocale = config.numberLocale;

    // Check if noHeader is saved -- need to set before re-parse
    final savedMappings = (jsonDecode(config.mappingsJson) as Map<String, dynamic>);
    final savedNoHeader = savedMappings['__noHeader'] == 'true';
    final localeChanged = _preview != null && _preview!.numberLocale != _effectiveNumberLocale();
    final needsReparse = (config.skipRows > 0 && config.skipRows != _skipRows) || (savedNoHeader != _noHeader) || localeChanged;

    if (savedNoHeader) _noHeader = true;
    if (config.skipRows > 0) {
      _skipRows = config.skipRows;
      _skipRowsCtrl.text = _skipRows.toString();
    }

    if (needsReparse) {
      await _reparseFile();
    } else {
      _applySavedConfig();
    }

    // With transforms restored, ensure the preview reflects every row the
    // filters/splits act on (load the complete transformed set if capped).
    _ensureTransformedFullRows();

    // Auto-enable quick mode if the saved config covers all required fields.
    // The user can still tap "Let me edit" to drop into the full mapper.
    if (_canProceedToConfirm()) {
      setState(() => _isQuickMode = true);
    }
  }

  /// Apply cached saved config mappings/formula/hash to current preview columns.
  ///
  /// [restoreTransforms] controls whether the saved row-filters/column-splits
  /// are re-adopted. True on initial load (the saved transforms are
  /// authoritative and must shape the preview before tags/mappings match).
  /// False when re-invoked from [_rebuildPreviewFromTransforms] after a live
  /// refine edit, so the user's in-progress transforms aren't clobbered.
  void _applySavedConfig({bool restoreTransforms = true}) {
    final config = _savedConfig;
    if (config == null || _preview == null) return;

    // Restore preview transforms FIRST, so derived split columns exist before
    // mappings are matched against the column list.
    final preMappings = (jsonDecode(config.mappingsJson) as Map<String, dynamic>);
    final restoredFilters = <RowFilter>[];
    final restoredSplits = <ColumnSplit>[];
    var restoredCombine = FilterCombine.all;
    if (preMappings['__rowFilters'] != null) {
      for (final f in jsonDecode(preMappings['__rowFilters'] as String) as List<dynamic>) {
        restoredFilters.add(RowFilter.fromJson(f as Map<String, dynamic>));
      }
      restoredCombine = FilterCombine.values.firstWhere(
        (c) => c.name == preMappings['__filterCombine'],
        orElse: () => FilterCombine.all,
      );
    }
    if (preMappings['__columnSplits'] != null) {
      for (final sp in jsonDecode(preMappings['__columnSplits'] as String) as List<dynamic>) {
        restoredSplits.add(ColumnSplit.fromJson(sp as Map<String, dynamic>));
      }
    }
    if (restoreTransforms && (restoredFilters.isNotEmpty || restoredSplits.isNotEmpty)) {
      // Adopt the saved transforms and rebuild the preview from the raw rows
      // so derived split columns (and filtered rows) exist BEFORE mappings and
      // type-tags are matched below. The chips/mappings must align to the
      // split column values on the very first load — not only after a manual
      // refine edit re-triggers the rebuild.
      _transforms = PreviewTransforms(filters: restoredFilters, splits: restoredSplits, combine: restoredCombine);
      if (_rawPreview != null) _preview = _applyTransforms(_rawPreview!);
      // Invalidate full-row caches: when the file was loaded BEFORE the
      // target/mode (so transforms were empty), these hold pre-split values.
      // The type-tag chips read _fullUniqueValues, so stale entries would show
      // un-split values (e.g. "C/Azienda mese 01/2026" instead of "C/Azienda")
      // and the saved tags wouldn't match.
      _clearFullPreviewCache();
      _fullUniqueValues.clear();
      _transformedFullRows = null;
    }
    _log.fine(
      '_applySavedConfig: restoreTransforms=$restoreTransforms splits=${restoredSplits.length} filters=${restoredFilters.length} '
      'rawCols=${_rawPreview?.columns} previewCols=${_preview?.columns}',
    );

    final currentCols = _preview!.columns;
    _log.info('_applySavedConfig: applying to ${currentCols.length} columns: $currentCols');

    setState(() {
      final savedMappings = (jsonDecode(config.mappingsJson) as Map<String, dynamic>);
      _log.info('_applySavedConfig: savedMappings keys=${savedMappings.keys.toList()}');

      // Restore balanceDiffColumn and noHeader from special keys
      if (savedMappings.containsKey('__balanceDiffColumn')) {
        final balCol = savedMappings['__balanceDiffColumn'] as String?;
        if (balCol != null && currentCols.contains(balCol)) {
          _balanceDiffColumn = balCol;
        }
      }
      if (savedMappings['__noHeader'] == 'true') {
        _noHeader = true;
      }

      // Restore multi-column mappings and delimiters
      _multiMappings.clear();
      _multiDelimiters.clear();
      for (final entry in savedMappings.entries) {
        if (entry.key.startsWith('__multi_')) {
          final field = entry.key.substring(8); // strip '__multi_'
          final cols = (jsonDecode(entry.value as String) as List<dynamic>).cast<String>();
          final validCols = cols.where((c) => currentCols.contains(c)).toList();
          _log.info('_applySavedConfig: multi-col $field: saved=$cols valid=$validCols');
          if (validCols.length > 1) {
            _multiMappings[field] = validCols;
            _mappings[field] = null; // multi-column overrides single mapping
          }
        } else if (entry.key.startsWith('__delim_')) {
          final field = entry.key.substring(8); // strip '__delim_'
          _multiDelimiters[field] = entry.value as String;
          _log.info('_applySavedConfig: delim $field="${entry.value}"');
        }
      }

      // Restore balance mode config
      _balanceMode = (savedMappings['__balanceMode'] as String?) ?? 'cumulative';
      _balanceFilterColumn = savedMappings['__balanceFilterColumn'] as String?;
      if (_balanceFilterColumn != null && !currentCols.contains(_balanceFilterColumn)) {
        _balanceFilterColumn = null;
        _balanceMode = 'cumulative';
      }
      _balanceFilterInclude.clear();
      if (savedMappings.containsKey('__balanceFilterInclude')) {
        final vals = (jsonDecode(savedMappings['__balanceFilterInclude'] as String) as List<dynamic>).cast<String>();
        _balanceFilterInclude.addAll(vals);
      }
      _log.info('_applySavedConfig: balanceMode=$_balanceMode, filterCol=$_balanceFilterColumn, filterInclude=$_balanceFilterInclude');

      for (final entry in savedMappings.entries) {
        if (entry.key.startsWith('__')) continue; // skip meta keys
        if (entry.value != null && currentCols.contains(entry.value)) {
          // Don't override if we already have a multi-column mapping for this field
          if (!_multiMappings.containsKey(entry.key)) {
            _mappings[entry.key] = entry.value as String;
          }
        }
      }

      // Update sameSettlementDate flag based on restored mappings
      _sameSettlementDate = _mappings['valueDate'] == null || _mappings['valueDate'] == _mappings['date'];

      final savedFormula = (jsonDecode(config.formulaJson) as List<dynamic>);
      _amountFormula.clear();
      for (final term in savedFormula) {
        final op = term['operator'] as String;
        final col = term['sourceColumn'] as String;
        if (currentCols.contains(col)) {
          _amountFormula.add(FormulaTerm(operator: op, sourceColumn: col));
        }
      }

      // Restore asset-event-specific state (type tags, revalue amount source,
      // historic/current + fee mode). Type-tag values are validated against
      // the current Type column's values so a stale tag can't orphan.
      if (_target == ImportTarget.assetEvent) {
        _assetImportMode = (savedMappings['__assetImportMode'] as String?) ?? _assetImportMode;
        _typeMode = (savedMappings['__typeMode'] as String?) ?? _typeMode;
        _feeMode = (savedMappings['__feeMode'] as String?) ?? _feeMode;
        _negativeIsBuy = savedMappings['__negativeIsBuy'] == 'true';
        // Auto-calc (amount = qty × price) is mutually exclusive with a mapped
        // amount column. A mapped amount always wins; otherwise honor the
        // saved auto-calc flag. This prevents the contradictory state where
        // both are set (auto-calc then silently produced 0 for cash-only
        // pension rows that have no qty/price).
        _autoCalcAmount = _mappings['amount'] == null && savedMappings['__autoCalcAmount'] == 'true';

        final typeCol = _mappings['type'];
        // Prune a restored tag only when we can confirm its value is absent
        // from the FULL value set. The capped preview (first/last sample) may
        // not contain a value that exists deeper in a large file, so when only
        // the preview is available we keep saved tags as-is rather than
        // silently dropping a still-valid tag (the user would have to re-tag).
        final fullVals = typeCol != null ? _fullUniqueValues[typeCol] : null;
        final canPrune = typeCol != null && fullVals != null;
        final validTypeVals = (canPrune ? fullVals : const <String>[]).toSet();
        void restoreTagSet(Set<String> target, String key) {
          target.clear();
          if (savedMappings[key] != null) {
            for (final v in (jsonDecode(savedMappings[key] as String) as List<dynamic>).cast<String>()) {
              if (!canPrune || validTypeVals.contains(v)) target.add(v);
            }
          }
        }

        restoreTagSet(_buyValues, '__buyValues');
        restoreTagSet(_sellValues, '__sellValues');
        restoreTagSet(_revalueValues, '__revalueValues');
        restoreTagSet(_feeValues, '__feeValues');

        final revCol = savedMappings['__revalueAmountColumn'] as String?;
        _revalueAmountColumn = (revCol != null && currentCols.contains(revCol)) ? revCol : null;
      }

      _log.info(
        '_applySavedConfig: result - mappings=$_mappings, multiMappings=$_multiMappings, delimiters=$_multiDelimiters, formula=${_amountFormula.length} terms',
      );
    });
  }

  /// Save current import config for the target account.
  Future<void> _saveConfig() async {
    // Resolve the scope + key for the current import mode. Each mode persists
    // under its natural key (transaction→account, asset byIsin→intermediary,
    // asset single→asset, income→global). When no key is available the
    // config simply isn't saved.
    final ImportConfigScope scope;
    int? accountId;
    int? intermediaryId;
    int? assetId;
    switch (_target) {
      case ImportTarget.transaction:
        scope = ImportConfigScope.transaction;
        accountId = widget.preselectedAccountId ?? _targetId;
        if (accountId == null) return;
      case ImportTarget.assetEvent:
        if (_assetEventMode == 'singleAsset') {
          scope = ImportConfigScope.assetSingle;
          assetId = _singleAssetTargetId;
          if (assetId == null) return;
        } else {
          scope = ImportConfigScope.assetByIsin;
          intermediaryId = _selectedIntermediaryId;
          if (intermediaryId == null) return;
        }
      case ImportTarget.income:
        scope = ImportConfigScope.income;
    }

    // Store balanceDiffColumn, noHeader, multiMappings, multiDelimiters in mappings JSON
    final mappingsToSave = Map<String, String?>.from(_mappings);
    if (_balanceDiffColumn != null) {
      mappingsToSave['__balanceDiffColumn'] = _balanceDiffColumn;
    }
    if (_noHeader) {
      mappingsToSave['__noHeader'] = 'true';
    }
    // Save multi-column mappings as JSON arrays
    for (final entry in _multiMappings.entries) {
      if (entry.value.length > 1) {
        mappingsToSave['__multi_${entry.key}'] = jsonEncode(entry.value);
      }
    }
    // Save multi-column delimiters
    for (final entry in _multiDelimiters.entries) {
      mappingsToSave['__delim_${entry.key}'] = entry.value;
    }
    // Save balance mode config
    mappingsToSave['__balanceMode'] = _balanceMode;
    if (_balanceFilterColumn != null) {
      mappingsToSave['__balanceFilterColumn'] = _balanceFilterColumn;
    }
    if (_balanceFilterInclude.isNotEmpty) {
      mappingsToSave['__balanceFilterInclude'] = jsonEncode(_balanceFilterInclude.toList());
    }
    // Save preview transforms (row filters + column splits)
    if (_transforms.filters.isNotEmpty) {
      mappingsToSave['__rowFilters'] = jsonEncode(_transforms.filters.map((f) => f.toJson()).toList());
      mappingsToSave['__filterCombine'] = _transforms.combine.name;
    }
    if (_transforms.splits.isNotEmpty) {
      mappingsToSave['__columnSplits'] = jsonEncode(_transforms.splits.map((sp) => sp.toJson()).toList());
    }
    // Save asset-event-specific state so pension/broker imports round-trip.
    if (_target == ImportTarget.assetEvent) {
      mappingsToSave['__assetImportMode'] = _assetImportMode; // historic | current
      mappingsToSave['__typeMode'] = _typeMode; // column | sign
      if (_negativeIsBuy) mappingsToSave['__negativeIsBuy'] = 'true';
      if (_buyValues.isNotEmpty) mappingsToSave['__buyValues'] = jsonEncode(_buyValues.toList());
      if (_sellValues.isNotEmpty) mappingsToSave['__sellValues'] = jsonEncode(_sellValues.toList());
      if (_revalueValues.isNotEmpty) mappingsToSave['__revalueValues'] = jsonEncode(_revalueValues.toList());
      if (_feeValues.isNotEmpty) mappingsToSave['__feeValues'] = jsonEncode(_feeValues.toList());
      if (_revalueAmountColumn != null) mappingsToSave['__revalueAmountColumn'] = _revalueAmountColumn;
      mappingsToSave['__feeMode'] = _feeMode; // column | computed
      if (_autoCalcAmount) mappingsToSave['__autoCalcAmount'] = 'true';
    }

    await ref
        .read(importConfigServiceProvider)
        .saveScoped(
          scope: scope,
          accountId: accountId,
          intermediaryId: intermediaryId,
          assetId: assetId,
          skipRows: _skipRows,
          mappings: mappingsToSave,
          formula: _amountFormula.map((t) => {'operator': t.operator, 'sourceColumn': t.sourceColumn}).toList(),
          hashColumns: const [],
          numberLocale: _selectedNumberLocale,
        );
    _log.info('_saveConfig: saved ${scope.wire} config');
  }

  /// Get unique values from a specific column across all preview rows.
  List<String> _uniqueColumnValues(String column) {
    if (_preview == null) return [];
    final values = <String>{};
    for (final row in _preview!.rows) {
      final v = (row[column] ?? '').trim();
      if (v.isNotEmpty) values.add(v);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  /// Load unique values for a column from ALL rows (not just preview).
  Future<void> _loadFullUniqueValues(String column) async {
    if (_fullUniqueValues.containsKey(column) || _preview == null || _loadingUniqueValues) return;
    setState(() => _loadingUniqueValues = true);
    try {
      final full = await _loadCompletePreview();
      final values = <String>{};
      for (final row in full.rows) {
        final v = (row[column] ?? '').trim();
        if (v.isNotEmpty) values.add(v);
      }
      final sorted = values.toList()..sort();
      if (mounted) {
        setState(() {
          _fullUniqueValues[column] = sorted;
          _loadingUniqueValues = false;
        });
      }
    } catch (e) {
      _log.warning('_loadFullUniqueValues failed: $e');
      if (mounted) setState(() => _loadingUniqueValues = false);
    }
  }

  /// Try to resolve a mapped field as a numeric value from a row.
  double? _tryResolveNumeric(String field, Map<String, String> row) {
    final col = _mappings[field];
    if (col == null) return null;
    final raw = row[col] ?? '';
    return fmt.parseFlexibleNumber(raw);
  }

  /// Preview the result of combining multiple columns for a field.
  String _previewMultiMapping(String field, List<String> cols) {
    if (_preview == null || _preview!.rows.isEmpty) return '';
    final row = _preview!.rows.first;
    final values = cols.map((c) => row[c] ?? '').toList();
    final delimiter = _multiDelimiters[field] ?? ' ';

    // Try numeric sum first
    final nums = values.map((v) => fmt.parseFlexibleNumber(v)).toList();
    if (nums.every((n) => n != null)) {
      final sum = nums.fold(0.0, (a, b) => a + b!);
      return sum.toStringAsFixed(2);
    }
    // String concatenation with delimiter
    return values.where((v) => v.isNotEmpty).join(delimiter);
  }

  /// Determine which amount mode is active.
  String get _amountMode {
    if (_balanceDiffColumn != null) return 'balance';
    if (_amountFormula.isNotEmpty) return 'formula';
    return 'simple';
  }

  bool _canProceedToConfirm() {
    // Account required for transactions (selected in step 1 inline selector)
    if (_target == ImportTarget.transaction && (widget.preselectedAccountId ?? _targetId) == null) return false;
    // date must be mapped (unless asset events in current mode)
    if (_mappings['date'] == null && !(_target == ImportTarget.assetEvent && _assetImportMode == 'current')) return false;
    // Value date required for transactions (unless same as operation date)
    if (_target == ImportTarget.transaction && !_sameSettlementDate && _mappings['valueDate'] == null) return false;
    // amount: either simple mapping, formula, balance-diff, or auto-calc
    if (_mappings['amount'] == null && _amountFormula.isEmpty && _balanceDiffColumn == null && !_autoCalcAmount) return false;
    // Asset events: in `byIsin` mode require an ISIN column; in
    // `singleAsset` mode require a target asset id instead.
    if (_target == ImportTarget.assetEvent) {
      if (_assetEventMode == 'byIsin' && _mappings['isin'] == null) return false;
      if (_assetEventMode == 'singleAsset' && _singleAssetTargetId == null) return false;
    }
    // Asset events with "from column" type: every unique value must be
    // tagged as exactly one of Buy/Sell/Revalue/Fee. Fee is for non-event
    // rows (Commissioni); Revalue is for position-snapshot rows (TOTALEP).
    if (_target == ImportTarget.assetEvent && _typeMode == 'column' && _mappings['type'] != null) {
      final typeCol = _mappings['type']!;
      final uniqueVals = _fullUniqueValues[typeCol] ?? _uniqueColumnValues(typeCol);
      if (uniqueVals.isNotEmpty) {
        final allMapped = uniqueVals.every(
          (v) => _buyValues.contains(v) || _sellValues.contains(v) || _revalueValues.contains(v) || _feeValues.contains(v),
        );
        if (!allMapped) return false;
        // At least one Buy/Sell/Revalue tag must exist (file with only
        // fee rows would have nothing to import).
        if (_buyValues.isEmpty && _sellValues.isEmpty && _revalueValues.isEmpty) {
          return false;
        }
        // Fee bucket without an orderRef mapping silently drops fee rows;
        // that's an explicit design choice — no extra gate here.
      }
    }
    return true;
  }

  void _reset() {
    _preview = null;
    _rawPreview = null;
    _transforms = const PreviewTransforms();
    _showAllPreviewRows = false;
    _showAllRows = null;
    _loadingShowAll = false;
    _transformedFullRows = null;
    _loadingTransformedFull = false;
    _clearFullPreviewCache();
    _filePath = null;
    _selectedSheet = null;
    _skipRows = 0;
    _skipRowsCtrl.text = '0';
    _amountFormula.clear();
    _target = ImportTarget.transaction;
    _targetId = null;
    _isQuickMode = false;
    _mappings.clear();
    _result = null;
    _error = null;
    _parsing = false;
    _importedSoFar = 0;
    _importTotal = 0;

    _sameSettlementDate = false;
    _fullIsinSummary = null;
    _excludedIsins.clear();
    _multiMappings.clear();
    _multiDelimiters.clear();
    _noHeader = false;
    _balanceDiffColumn = null;
    _savedConfig = null;
    _balanceMode = 'cumulative';
    _balanceFilterColumn = null;
    _balanceFilterInclude.clear();
    _feeMode = 'column';
    _autoCalcAmount = false;
    _typeMode = 'column';
    _buyValues.clear();
    _sellValues.clear();
    _feeValues.clear();
    _mappings.remove('orderRef');
    _negativeIsBuy = false;
    _revalueValues.clear();
    _revalueAmountColumn = null;
    _assetEventMode = 'byIsin';
    _singleAssetTargetId = null;
    _isinLookupResults = null;
    _selectedExchanges.clear();
    _defaultExchange = null;
    _txPreview = null;
    _assetPreview = null;
    _previewing = false;
  }

  /// Build column mappings from current UI state. Shared by preview and import.
  List<ColumnMapping> _buildColumnMappings() {
    final mappings = <ColumnMapping>[];
    for (final e in _mappings.entries) {
      if (e.value == null) continue;
      if (e.key == 'amount' && (_amountFormula.isNotEmpty || _balanceDiffColumn != null)) continue;
      mappings.add(ColumnMapping(sourceColumn: e.value!, targetField: e.key));
    }
    if (_sameSettlementDate && _mappings['date'] != null) {
      mappings.removeWhere((m) => m.targetField == 'valueDate');
      mappings.add(ColumnMapping(sourceColumn: _mappings['date']!, targetField: 'valueDate'));
    }
    for (final e in _multiMappings.entries) {
      if (e.value.length < 2) continue;
      mappings.removeWhere((m) => m.targetField == e.key);
      mappings.add(ColumnMapping(targetField: e.key, multiColumns: List.of(e.value), multiDelimiter: _multiDelimiters[e.key] ?? ' '));
    }
    if (_balanceDiffColumn != null) {
      mappings.add(ColumnMapping(targetField: 'amount', balanceDiffColumn: _balanceDiffColumn));
    } else if (_amountFormula.isNotEmpty) {
      mappings.add(ColumnMapping(targetField: 'amount', formulaTerms: List.of(_amountFormula)));
    } else if (_mappings['amount'] != null) {
      mappings.add(ColumnMapping(sourceColumn: _mappings['amount']!, targetField: 'amount'));
    }
    // DEBUG-level diagnostic: the resolved mapping set is the single most
    // useful thing when an import produces unexpected values (e.g. all-zero
    // amounts). Kept permanently at fine() so it's hidden in normal runs but
    // available without a rebuild.
    _log.fine(
      '_buildColumnMappings: _mappings=$_mappings autoCalc=$_autoCalcAmount revalueAmtCol=$_revalueAmountColumn '
      'built=${mappings.map((m) => '${m.targetField}<-${m.sourceColumn ?? (m.isMultiColumn
              ? "multi${m.multiColumns}"
              : m.isFormula
              ? "formula"
              : m.balanceDiffColumn)}').toList()}',
    );
    return mappings;
  }

  /// Compute a dry-run preview of the import (no DB writes).
  Future<void> _computePreview() async {
    if (_preview == null) return;
    _setState(() {
      _previewing = true;
      _txPreview = null;
      _assetPreview = null;
    });

    try {
      final importer = ref.read(importServiceProvider);
      final mappings = _buildColumnMappings();

      // Get full rows only when the preview was capped. Locale mismatches
      // are handled inside ImportService.
      var fullPreview = _preview!;
      if (fullPreview.rows.length < fullPreview.totalRows) {
        fullPreview = await _loadCompletePreview();
      }

      final appLocale = ref.read(appLocaleProvider).value;
      if (_target == ImportTarget.transaction && _targetId != null) {
        final result = await importer.previewTransactionImport(
          preview: fullPreview,
          mappings: mappings,
          accountId: _targetId!,
          balanceMode: _balanceMode,
          balanceFilterColumn: _balanceFilterColumn,
          balanceFilterInclude: _balanceFilterInclude.isNotEmpty ? _balanceFilterInclude : null,
          numberLocale: _selectedNumberLocale,
          appLocale: appLocale,
        );
        if (mounted) _setState(() => _txPreview = result);
      } else if (_target == ImportTarget.assetEvent) {
        // Remove type mapping if using sign-based detection
        if (_typeMode == 'sign') {
          mappings.removeWhere((m) => m.targetField == 'type');
        }
        final result = await importer.previewAssetEventImport(
          preview: fullPreview,
          mappings: mappings,
          buyValues: _buyValues.isNotEmpty ? _buyValues : null,
          sellValues: _sellValues.isNotEmpty ? _sellValues : null,
          feeValues: _feeValues.isNotEmpty ? _feeValues : null,
          negativeIsBuy: _typeMode == 'sign' && _negativeIsBuy,
          revalueValues: _revalueValues.isNotEmpty ? _revalueValues : null,
          excludedIsins: _excludedIsins.isNotEmpty ? _excludedIsins : null,
          selectedExchanges: _selectedExchanges.isNotEmpty ? _selectedExchanges : null,
          numberLocale: _selectedNumberLocale,
          appLocale: appLocale,
          targetAssetId: _assetEventMode == 'singleAsset' ? _singleAssetTargetId : null,
          revalueAmountColumn: _revalueValues.isNotEmpty ? _revalueAmountColumn : null,
        );
        if (mounted) _setState(() => _assetPreview = result);
      }
    } catch (e) {
      _log.warning('_computePreview: $e');
    } finally {
      if (mounted) _setState(() => _previewing = false);
    }
  }
}
