import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../../database/database.dart';
import '../../../services/import_service.dart';
import '../../../services/isin_lookup_service.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/logger.dart';

part 'column_mapper_step.dart';
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
    final prefsDir = Directory(p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/net.bazzani.financecopilot/Data/Documents/FinanceCopilot',
    ));
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
    final prefsDir = Directory(p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/net.bazzani.financecopilot/Data/Documents/FinanceCopilot',
    ));
    await File(p.join(prefsDir.path, '.last_import_dir')).writeAsString(dir);
  } catch (_) {}
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 1; // 1=preview+map, 2=confirm, 3=result
  /// When true, render the quick-confirm view (header preview + read-only mappings + Import / Let me edit)
  /// instead of the full column mapper. Auto-enabled when a saved config is applied successfully.
  bool _isQuickMode = false;
  FilePreview? _preview;
  String? _filePath;
  String? _selectedSheet;
  int _skipRows = 0;
  final _skipRowsCtrl = TextEditingController(text: '0');
  ImportTarget _target = ImportTarget.transaction;
  int? _targetId; // accountId or assetId
  int? _selectedIntermediaryId; // for asset imports

  // Asset import mode: 'historic' (date+rate required) or 'current' (default to today, rate auto-fetched)
  String _assetImportMode = 'historic';

  // Column mappings: targetField -> sourceColumn (for simple fields)
  final Map<String, String?> _mappings = {};

  // Formula terms for amount (visual formula builder)
  final List<FormulaTerm> _amountFormula = [];

  bool _noHeader = false;
  bool _sameSettlementDate = false; // when true, valueDate = date (operation date)
  String? _balanceDiffColumn; // when set, amount = balance[i] - balance[i-1]

  // Debounce timer for skip-rows auto re-parse
  Timer? _skipRowsTimer;

  // Cached saved import config (loaded once, applied after every re-parse)
  ImportConfig? _savedConfig;

  // Cached full ISIN summary (from all rows, not capped preview)
  Map<String, int>? _fullIsinSummary;

  // ISINs excluded from import by user (unchecked in exchange picker)
  final Set<String> _excludedIsins = {};

  ImportResult? _result;
  bool _importing = false;
  bool _parsing = false;
  int _importedSoFar = 0;
  int _importTotal = 0;
  String? _error;

  List<String> get _requiredFields => switch (_target) {
    ImportTarget.transaction => ['date', 'valueDate', 'amount', 'description'],
    ImportTarget.assetEvent => _assetImportMode == 'historic'
        ? ['date', 'isin', 'quantity', 'price', 'currency', 'exchangeRate']
        : ['isin', 'quantity', 'price', 'currency'],
    ImportTarget.income => ['date', 'amount'],
  };

  List<String> get _optionalFields => switch (_target) {
    ImportTarget.transaction => ['currency', 'status'],
    ImportTarget.assetEvent => _assetImportMode == 'historic'
        ? ['description']
        : ['date', 'exchangeRate', 'description'],
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

  // Cached unique values per column (from ALL rows, not just preview)
  final Map<String, List<String>> _fullUniqueValues = {};
  bool _loadingUniqueValues = false;

  // Exchange picker for asset imports (ISIN -> all available listings, user picks one)
  Map<String, IsinLookupResult>? _isinLookupResults;
  final Map<String, IsinExchangeOption> _selectedExchanges = {};
  String? _defaultExchange; // e.g. "Milano" -- applies to all ISINs
  bool _lookingUpIsins = false;

  // ignore: invalid_use_of_protected_member
  void _setState(VoidCallback fn) => setState(fn);

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
      _preview = widget.testPreview;
      _autoMap(widget.testPreview!.columns);
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
      )),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    _log.info('_pickFile: opening file picker');
    await _loadLastDirectory();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls', 'tsv'],
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

      final preview = await importer.parseFile(path, sheetName: _selectedSheet, skipRows: _skipRows, noHeader: _noHeader);
      if (preview.rows.isEmpty) {
        _log.warning('_loadFile: file is empty after parsing');
        setState(() => _error = ref.read(appStringsProvider).fileEmpty);
        return;
      }

      _log.info('_loadFile: parsed OK - ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _preview = preview;
        _fullIsinSummary = null;
        _parsing = false;
        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(preview.columns);
      });
      // Load saved config if we have a preselected account
      await _loadSavedConfig(preview.columns);
    } catch (e, stack) {
      _log.severe('_loadFile: error reading file', e, stack);
      setState(() {
        _error = 'Error reading file: $e';
        _parsing = false;
      });
    }
  }

  Future<void> _showSheetPicker(List<String> sheets) async {
    final s = ref.read(appStringsProvider);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.selectSheetTitle),
        children: sheets
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(s),
                ))
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
      tryMap('amount', ['amount', 'controvalore', 'equivalent value', 'importo', 'total']);
      tryMap('commission', ['fee', 'commission', 'commissione', 'commissioni', 'spese']);
    }
  }

  Future<void> _reparseFile() async {
    if (_filePath == null) return;
    _log.info('_reparseFile: re-parsing with skipRows=$_skipRows, sheet=$_selectedSheet');
    try {
      final importer = ref.read(importServiceProvider);
      final preview = await importer.parseFile(_filePath!, sheetName: _selectedSheet, skipRows: _skipRows, noHeader: _noHeader);
      if (preview.rows.isEmpty) {
        _log.warning('_reparseFile: empty after skipping $_skipRows rows');
        setState(() => _error = ref.read(appStringsProvider).fileEmptyAfterSkip(_skipRows));
        return;
      }
      _log.info('_reparseFile: OK - ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _preview = preview;
        _fullIsinSummary = null;
        _error = null;
        _mappings.clear();
        _amountFormula.clear();

        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(preview.columns);
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
    setState(() { _parsing = true; _error = null; _filePath = null; });
    try {
      final importer = ref.read(importServiceProvider);
      final preview = await importer.parseClipboard(data.text!, skipRows: _skipRows, noHeader: _noHeader);
      if (preview.rows.isEmpty) {
        setState(() { _error = ref.read(appStringsProvider).noDataRowsClipboard; _parsing = false; });
        return;
      }
      setState(() {
        _preview = preview;
        _fullIsinSummary = null;
        _parsing = false;
        _mappings.clear();
        _amountFormula.clear();

        for (final f in _requiredFields) { _mappings[f] = null; }
        _autoMap(preview.columns);
      });
    } catch (e) {
      setState(() { _error = ref.read(appStringsProvider).errorParsingClipboard(e); _parsing = false; });
    }
  }

  /// Load saved import config for the preselected account and cache it.
  Future<void> _loadSavedConfig(List<String> fileColumns) async {
    final accountId = widget.preselectedAccountId ?? _targetId;
    if (accountId == null) return;

    final config = await ref.read(importConfigServiceProvider).getByAccount(accountId);
    if (config == null) return;

    _log.info('_loadSavedConfig: found config for account $accountId');
    _savedConfig = config;

    // Check if noHeader is saved -- need to set before re-parse
    final savedMappings = (jsonDecode(config.mappingsJson) as Map<String, dynamic>);
    final savedNoHeader = savedMappings['__noHeader'] == 'true';
    final needsReparse = (config.skipRows > 0 && config.skipRows != _skipRows) || (savedNoHeader != _noHeader);

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

    // Auto-enable quick mode if the saved config covers all required fields.
    // The user can still tap "Let me edit" to drop into the full mapper.
    if (_canProceedToConfirm()) {
      setState(() => _isQuickMode = true);
    }
  }

  /// Apply cached saved config mappings/formula/hash to current preview columns.
  void _applySavedConfig() {
    final config = _savedConfig;
    if (config == null || _preview == null) return;

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

      _log.info('_applySavedConfig: result - mappings=$_mappings, multiMappings=$_multiMappings, delimiters=$_multiDelimiters, formula=${_amountFormula.length} terms');
    });
  }

  /// Save current import config for the target account.
  Future<void> _saveConfig() async {
    final accountId = widget.preselectedAccountId ?? _targetId;
    if (accountId == null || _target != ImportTarget.transaction) return;

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

    await ref.read(importConfigServiceProvider).save(
          accountId: accountId,
          skipRows: _skipRows,
          mappings: mappingsToSave,
          formula: _amountFormula
              .map((t) => {'operator': t.operator, 'sourceColumn': t.sourceColumn})
              .toList(),
          hashColumns: const [],
        );
    _log.info('_saveConfig: saved config for account $accountId');
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
      final importer = ref.read(importServiceProvider);
      final full = await importer.getFullRows(_preview!);
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
    return double.tryParse(raw.replaceAll(RegExp(r'[€\$£¥\s]'), '').replaceAll(',', '.'));
  }

  /// Preview the result of combining multiple columns for a field.
  String _previewMultiMapping(String field, List<String> cols) {
    if (_preview == null || _preview!.rows.isEmpty) return '';
    final row = _preview!.rows.first;
    final values = cols.map((c) => row[c] ?? '').toList();
    final delimiter = _multiDelimiters[field] ?? ' ';

    // Try numeric sum first
    final nums = values.map((v) => double.tryParse(v.replaceAll(RegExp(r'[€\$£¥,\s]'), ''))).toList();
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
    // Asset events also require ISIN
    if (_target == ImportTarget.assetEvent && _mappings['isin'] == null) return false;
    // Asset events with "from column" type: every unique value must be mapped to Buy or Sell
    if (_target == ImportTarget.assetEvent && _typeMode == 'column' && _mappings['type'] != null) {
      final typeCol = _mappings['type']!;
      final uniqueVals = _fullUniqueValues[typeCol] ?? _uniqueColumnValues(typeCol);
      if (uniqueVals.isNotEmpty) {
        final allMapped = uniqueVals.every((v) => _buyValues.contains(v) || _sellValues.contains(v));
        if (!allMapped) return false;
        // Must have at least one Buy and one Sell value
        if (_buyValues.isEmpty || _sellValues.isEmpty) return false;
      }
    }
    return true;
  }

  void _reset() {
    _preview = null;
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
    _isinLookupResults = null;
    _selectedExchanges.clear();
    _defaultExchange = null;
  }
}
