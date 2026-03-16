import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/import_service.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';

final _log = getLogger('ImportScreen');

/// The full import wizard: pick file → preview → map columns → select target → confirm.
class ImportScreen extends ConsumerStatefulWidget {
  final int? preselectedAccountId;
  const ImportScreen({super.key, this.preselectedAccountId});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

/// Remember last directory across navigations and app restarts.
String? _lastDirectory;

Future<String?> _loadLastDirectory() async {
  if (_lastDirectory != null) return _lastDirectory;
  try {
    final prefsDir = Directory(p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/com.assetmanager.assetManager/Data/Documents/AssetManager',
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
  try {
    final prefsDir = Directory(p.join(
      Platform.environment['HOME'] ?? '',
      'Library/Containers/com.assetmanager.assetManager/Data/Documents/AssetManager',
    ));
    await File(p.join(prefsDir.path, '.last_import_dir')).writeAsString(dir);
  } catch (_) {}
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 0; // 0=pick file, 1=preview+map, 2=confirm, 3=result
  FilePreview? _preview;
  String? _filePath;
  String? _selectedSheet;
  int _skipRows = 0;
  final _skipRowsCtrl = TextEditingController(text: '0');
  ImportTarget _target = ImportTarget.transaction;
  int? _targetId; // accountId or assetId

  // Column mappings: targetField → sourceColumn (for simple fields)
  final Map<String, String?> _mappings = {};

  // Formula terms for amount (visual formula builder)
  final List<FormulaTerm> _amountFormula = [];

  // Columns selected for dedup hash (empty = all columns)
  final Set<String> _hashColumns = {};

  bool _noHeader = false;
  String? _balanceDiffColumn; // when set, amount = balance[i] - balance[i-1]

  // Debounce timer for skip-rows auto re-parse
  Timer? _skipRowsTimer;

  // Cached saved import config (loaded once, applied after every re-parse)
  ImportConfig? _savedConfig;

  ImportResult? _result;
  bool _importing = false;
  bool _parsing = false;
  int _importedSoFar = 0;
  int _importTotal = 0;
  String? _error;

  List<String> get _requiredFields => _target == ImportTarget.transaction
      ? ['date', 'amount', 'description']
      : ['date', 'isin', 'type', 'amount', 'quantity', 'price', 'currency', 'exchangeRate'];

  List<String> get _optionalFields => _target == ImportTarget.transaction
      ? ['currency', 'valueDate', 'status']
      : ['description'];

  // Multi-column mappings for optional fields: field → [col1, col2, ...]
  final Map<String, List<String>> _multiMappings = {};
  // Delimiter for string concatenation in multi-column mappings (default: space)
  final Map<String, String> _multiDelimiters = {};

  // Balance computation mode: 'none' | 'column' | 'cumulative' | 'filtered'
  String _balanceMode = 'none';
  // For 'filtered' mode: which CSV column to filter on
  String? _balanceFilterColumn;
  // For 'filtered' mode: included status values
  final Set<String> _balanceFilterInclude = {};

  // Fee computation mode for asset imports: 'column' | 'computed'
  // 'column' = map from a CSV column (default)
  // 'computed' = fee = |amount| - quantity * price / exchangeRate
  String _feeMode = 'column';


  @override
  void initState() {
    super.initState();
    if (widget.preselectedAccountId != null) {
      _target = ImportTarget.transaction;
      _targetId = widget.preselectedAccountId;
    }
    // Auto-open file picker after navigation animation completes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _pickFile();
    });
  }

  @override
  void dispose() {
    _skipRowsTimer?.cancel();
    _skipRowsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import File'),
        leading: _step > 1 && _step < 3
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_step) {
          0 => _buildFilePicker(),
          1 => _buildColumnMapper(),
          2 => _buildConfirm(),
          3 => _buildResult(),
          _ => const SizedBox(),
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Step 0: Pick file
  // ──────────────────────────────────────────────

  Widget _buildFilePicker() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],
          if (_parsing)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading file...', style: TextStyle(color: Colors.grey)),
              ],
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Pick File'),
              onPressed: _pickFile,
            ),
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
      if (mounted && _filePath == null) Navigator.pop(context);
      return;
    }

    final path = result.files.single.path!;
    await _saveLastDirectory(p.dirname(path));
    _log.info('_pickFile: selected $path');
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
          _log.info('_pickFile: multi-sheet Excel, showing sheet picker');
          await _showSheetPicker(sheets);
          if (_selectedSheet == null) {
            _log.info('_pickFile: sheet selection cancelled');
            return;
          }
          _log.info('_pickFile: selected sheet=$_selectedSheet');
        }
      }

      final preview = await importer.parseFile(path, sheetName: _selectedSheet, skipRows: _skipRows, noHeader: _noHeader);
      if (preview.rows.isEmpty) {
        _log.warning('_pickFile: file is empty after parsing');
        setState(() => _error = 'File is empty or has no data rows.');
        return;
      }

      _log.info('_pickFile: parsed OK — ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _preview = preview;
        _step = 1;
        for (final f in _requiredFields) {
          _mappings[f] = null;
        }
        _autoMap(preview.columns);
      });
      // Load saved config if we have a preselected account
      await _loadSavedConfig(preview.columns);
    } catch (e, stack) {
      _log.severe('_pickFile: error reading file', e, stack);
      setState(() {
        _error = 'Error reading file: $e';
        _parsing = false;
      });
    }
  }

  Future<void> _showSheetPicker(List<String> sheets) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Sheet'),
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
    // Default: all columns in hash
    _hashColumns
      ..clear()
      ..addAll(columns);

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
    tryMap('date', ['date', 'data', 'data_operazione', 'data di inizio', 'operation_date']);
    tryMap('description', ['description', 'descrizione', 'causale', 'memo', 'note', 'notes', 'oggetto', 'dettagli']);

    if (_target == ImportTarget.transaction) {
      tryMap('amount', ['amount', 'importo', 'entrate', 'uscite', 'controvalore']);
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
        setState(() => _error = 'File is empty after skipping $_skipRows rows.');
        return;
      }
      _log.info('_reparseFile: OK — ${preview.columns.length} cols, ${preview.totalRows} rows');
      setState(() {
        _preview = preview;
        _error = null;
        _mappings.clear();
        _amountFormula.clear();
        _hashColumns.clear();
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
      setState(() => _error = 'Error re-parsing file: $e');
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

    // Check if noHeader is saved — need to set before re-parse
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
      _balanceMode = (savedMappings['__balanceMode'] as String?) ?? 'none';
      _balanceFilterColumn = savedMappings['__balanceFilterColumn'] as String?;
      if (_balanceFilterColumn != null && !currentCols.contains(_balanceFilterColumn)) {
        _balanceFilterColumn = null;
        _balanceMode = 'none';
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

      final savedFormula = (jsonDecode(config.formulaJson) as List<dynamic>);
      _amountFormula.clear();
      for (final term in savedFormula) {
        final op = term['operator'] as String;
        final col = term['sourceColumn'] as String;
        if (currentCols.contains(col)) {
          _amountFormula.add(FormulaTerm(operator: op, sourceColumn: col));
        }
      }

      final savedHash = (jsonDecode(config.hashColumnsJson) as List<dynamic>).cast<String>();
      _hashColumns.clear();
      for (final col in savedHash) {
        if (currentCols.contains(col)) {
          _hashColumns.add(col);
        }
      }

      _log.info('_applySavedConfig: result — mappings=$_mappings, multiMappings=$_multiMappings, delimiters=$_multiDelimiters, hashCols=$_hashColumns, formula=${_amountFormula.length} terms');
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
    if (_balanceMode != 'none') {
      mappingsToSave['__balanceMode'] = _balanceMode;
    }
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
          hashColumns: _hashColumns.toList(),
        );
    _log.info('_saveConfig: saved config for account $accountId');
  }

  // ──────────────────────────────────────────────
  // Step 1: Preview + Column mapping
  // ──────────────────────────────────────────────

  Widget _buildColumnMapper() {
    final preview = _preview!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target selector (hidden when preselected from account view)
        if (widget.preselectedAccountId == null) ...[
          Row(
            children: [
              const Text('Import as: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SegmentedButton<ImportTarget>(
                segments: const [
                  ButtonSegment(value: ImportTarget.transaction, label: Text('Transaction')),
                  ButtonSegment(value: ImportTarget.assetEvent, label: Text('Asset Event')),
                ],
                selected: {_target},
                onSelectionChanged: (v) => setState(() {
                  _target = v.first;
                  _mappings.clear();
                  _amountFormula.clear();
                  for (final f in _requiredFields) {
                    _mappings[f] = null;
                  }
                  _autoMap(preview.columns);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Skip rows (auto re-parse after 1s or Enter)
        Row(
          children: [
            const Text('Skip rows: ', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: _skipRowsCtrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  suffixIcon: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          _skipRows++;
                          _skipRowsCtrl.text = _skipRows.toString();
                          _skipRowsTimer?.cancel();
                          _reparseFile();
                        },
                        child: const Icon(Icons.arrow_drop_up, size: 18),
                      ),
                      InkWell(
                        onTap: () {
                          if (_skipRows > 0) {
                            _skipRows--;
                            _skipRowsCtrl.text = _skipRows.toString();
                            _skipRowsTimer?.cancel();
                            _reparseFile();
                          }
                        },
                        child: const Icon(Icons.arrow_drop_down, size: 18),
                      ),
                    ],
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  _skipRows = int.tryParse(v) ?? 0;
                  _skipRowsTimer?.cancel();
                  _skipRowsTimer = Timer(const Duration(seconds: 1), _reparseFile);
                },
                onFieldSubmitted: (_) {
                  _skipRowsTimer?.cancel();
                  _reparseFile();
                },
              ),
            ),
            const SizedBox(width: 12),
            Text('Skip N rows before the header row', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),

        // No header row checkbox
        Row(
          children: [
            SizedBox(
              height: 28,
              child: Checkbox(
                value: _noHeader,
                onChanged: (v) {
                  setState(() => _noHeader = v ?? false);
                  _reparseFile();
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _noHeader = !_noHeader);
                _reparseFile();
              },
              child: const Text('No header row (use column numbers)', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Column mapping
        Text('Map columns (${preview.columns.length} columns, ${preview.totalRows} rows)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              // Required fields
              _buildMappingRow('date', preview.columns, required: true),
              if (_target == ImportTarget.transaction)
                _buildAmountFormulaRow(preview.columns)
              else
                _buildMappingRow('amount', preview.columns, required: true),
              ..._requiredFields
                  .where((f) => f != 'date' && f != 'amount')
                  .map((f) => _buildMappingRow(f, preview.columns, required: true, multiColumn: f == 'description')),
              // Fee section for asset events
              if (_target == ImportTarget.assetEvent) ...[
                const SizedBox(height: 12),
                _buildFeeModeSection(preview.columns),
              ],
              const SizedBox(height: 12),
              // Optional fields
              const Text('Optional', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ..._optionalFields.map((f) => _buildMappingRow(f, preview.columns, multiColumn: true)),
              const SizedBox(height: 4),
              Text('Unmapped columns are stored as metadata', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (_target == ImportTarget.transaction) ...[
                const Divider(),
                _buildBalanceModeSection(preview),
                const Divider(),

                // Dedup hash column selector
                const SizedBox(height: 8),
                const Text('Dedup key columns', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Select which columns identify a unique row (duplicates will be skipped)',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  children: preview.columns.map((col) {
                    final selected = _hashColumns.contains(col);
                    return FilterChip(
                      label: Text(col, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) { _hashColumns.add(col); } else { _hashColumns.remove(col); }
                      }),
                    );
                  }).toList(),
                ),
              ],
              const Divider(),

              // Data preview table
              const SizedBox(height: 8),
              Text('Preview (${preview.totalRows} rows)', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('First 5 rows', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: preview.columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  rows: preview.rows.take(5).map((row) {
                    return DataRow(
                      cells: preview.columns.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                    );
                  }).toList(),
                ),
              ),
              if (preview.rows.length > 10) ...[
                const SizedBox(height: 8),
                Text('⋯ ${preview.rows.length - 10} rows hidden ⋯',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center),
              ],
              if (preview.rows.length > 5) ...[
                const SizedBox(height: 4),
                const Text('Last 5 rows', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: preview.columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    rows: preview.rows.skip(preview.rows.length > 5 ? preview.rows.length - 5 : 0).map((row) {
                      return DataRow(
                        cells: preview.columns.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: _canProceedToConfirm() ? () => setState(() => _step = 2) : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMappingRow(String field, List<String> columns, {bool required = false, bool multiColumn = false}) {
    final multiCols = _multiMappings[field] ?? [];
    final isMulti = multiColumn && multiCols.length > 1;
    final showAddBtn = multiColumn && !isMulti && _mappings[field] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  '$field${required ? ' *' : ''}',
                  style: TextStyle(fontWeight: required ? FontWeight.bold : FontWeight.normal),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 8),
              if (!isMulti)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _mappings[field],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                      hintText: required ? 'Required' : 'Not mapped',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— None —', style: TextStyle(color: Colors.grey))),
                      ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() => _mappings[field] = v),
                  ),
                ),
              if (isMulti)
                Expanded(
                  child: Text(
                    multiCols.join(' + '),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ),
              if (showAddBtn) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Combine multiple columns',
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _multiMappings[field] = [_mappings[field]!, columns.firstWhere((c) => c != _mappings[field], orElse: () => columns.first)];
                      _mappings[field] = null;
                    }),
                  ),
                ),
              ],
              if (isMulti) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Use single column',
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    color: Colors.red.shade300,
                    onPressed: () => setState(() {
                      _mappings[field] = multiCols.first;
                      _multiMappings.remove(field);
                    }),
                  ),
                ),
              ],
            ],
          ),
          // Multi-column term rows
          if (isMulti)
            for (var i = 0; i < multiCols.length; i++)
              Padding(
                padding: const EdgeInsets.only(left: 164, top: 4),
                child: Row(
                  children: [
                    if (i > 0)
                      Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade500))
                    else
                      const SizedBox(width: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: multiCols[i],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _multiMappings[field]![i] = v);
                        },
                      ),
                    ),
                    if (multiCols.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        color: Colors.red.shade300,
                        onPressed: () => setState(() => _multiMappings[field]!.removeAt(i)),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
          if (isMulti)
            Padding(
              padding: const EdgeInsets.only(left: 164, top: 4),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add column'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() {
                      _multiMappings[field]!.add(columns.first);
                    }),
                  ),
                  const SizedBox(width: 12),
                  const Text('Sep:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: _multiDelimiters[field] ?? ' ',
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => setState(() => _multiDelimiters[field] = v),
                    ),
                  ),
                  if (_preview != null && multiCols.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Preview: ${_previewMultiMapping(field, multiCols)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
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

  /// Build the "Balance per row" configuration section.
  Widget _buildBalanceModeSection(FilePreview preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Balance per row', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('How to compute balanceAfter for each transaction',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'none', label: Text('None')),
            ButtonSegment(value: 'column', label: Text('From column')),
            ButtonSegment(value: 'cumulative', label: Text('Cumulative sum')),
            ButtonSegment(value: 'filtered', label: Text('Filtered sum')),
          ],
          selected: {_balanceMode},
          onSelectionChanged: (v) => setState(() {
            _balanceMode = v.first;
            if (_balanceMode != 'column') {
              _mappings.remove('balanceAfter');
            }
            if (_balanceMode != 'filtered') {
              _balanceFilterColumn = null;
              _balanceFilterInclude.clear();
            }


          }),
        ),
        const SizedBox(height: 8),

        // Column mode: show dropdown to pick balance column
        if (_balanceMode == 'column')
          _buildMappingRow('balanceAfter', preview.columns),

        // Cumulative: just a description
        if (_balanceMode == 'cumulative')
          Text(
            'Balance = running sum of amount from oldest to newest transaction',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),

        // Filtered: column picker + value checkboxes
        if (_balanceMode == 'filtered') ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 140,
                  child: Text('Filter column', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _balanceFilterColumn,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                      hintText: 'Select column',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— None —', style: TextStyle(color: Colors.grey))),
                      ...preview.columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setState(() {
                      _balanceFilterColumn = v;
                      _balanceFilterInclude.clear();
                      // Auto-select all values by default
                      if (v != null) {
                        _balanceFilterInclude.addAll(_uniqueColumnValues(v));
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
          if (_balanceFilterColumn != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  const Text('Include values:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _balanceFilterInclude.addAll(_uniqueColumnValues(_balanceFilterColumn!));
                    }),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('All', style: TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _balanceFilterInclude.clear()),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('None', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: _uniqueColumnValues(_balanceFilterColumn!).map((val) {
                  final selected = _balanceFilterInclude.contains(val);
                  return FilterChip(
                    label: Text(val, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _balanceFilterInclude.add(val);
                      } else {
                        _balanceFilterInclude.remove(val);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Only transactions with included values contribute to the running sum. '
                'Excluded transactions still get the last known balance.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],

        // Fee/cost column — available for cumulative and filtered modes


      ],
    );
  }

  /// Build the fee computation mode selector for asset imports.
  Widget _buildFeeModeSection(List<String> columns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fee / Commission', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'column', label: Text('From column')),
            ButtonSegment(value: 'computed', label: Text('Computed')),
          ],
          selected: {_feeMode},
          onSelectionChanged: (v) => setState(() {
            _feeMode = v.first;
            if (_feeMode == 'computed') {
              _mappings.remove('commission');
            }
          }),
        ),
        const SizedBox(height: 8),
        if (_feeMode == 'column')
          _buildMappingRow('commission', columns, required: true),
        if (_feeMode == 'computed') ...[
          Text(
            'fee = |amount| − quantity × price / exchangeRate',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
          if (_preview != null && _preview!.rows.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Preview: ${_feeComputedPreview()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ],
    );
  }

  /// Preview first few computed fee values.
  String _feeComputedPreview() {
    if (_preview == null) return '';
    final results = <String>[];
    for (var i = 0; i < _preview!.rows.length && results.length < 3; i++) {
      final row = _preview!.rows[i];
      final amount = _tryResolveNumeric('amount', row);
      final qty = _tryResolveNumeric('quantity', row);
      final price = _tryResolveNumeric('price', row);
      final rate = _tryResolveNumeric('exchangeRate', row) ?? 1.0;
      if (amount != null && qty != null && price != null && rate != 0) {
        final fee = amount.abs() - qty * price / rate;
        results.add(fee.abs().toStringAsFixed(2));
      }
    }
    return results.isEmpty ? 'N/A' : results.join(', ');
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

  /// Mode switch buttons for the amount field.
  Widget _buildAmountModeButtons(List<String> columns, {required String currentMode}) {
    Widget modeBtn(String label, IconData icon, String mode) {
      final isActive = currentMode == mode;
      return Tooltip(
        message: switch (mode) {
          'formula' => 'Combine multiple columns (e.g. Entrate + Uscite)',
          'balance' => 'Compute amount from balance differences',
          _ => 'Direct column mapping',
        },
        child: isActive
            ? FilledButton.icon(
                icon: Icon(icon, size: 16),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: null,
              )
            : OutlinedButton.icon(
                icon: Icon(icon, size: 16),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => setState(() {
                  _amountFormula.clear();
                  _balanceDiffColumn = null;
                  _mappings['amount'] = null;
                  if (mode == 'formula') {
                    _amountFormula.add(FormulaTerm(operator: '+', sourceColumn: columns.first));
                  } else if (mode == 'balance') {
                    _balanceDiffColumn = columns.first;
                  }
                }),
              ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        modeBtn('Direct', Icons.arrow_forward, 'simple'),
        const SizedBox(width: 4),
        modeBtn('Formula', Icons.functions, 'formula'),
        const SizedBox(width: 4),
        modeBtn('Balance Δ', Icons.trending_flat, 'balance'),
      ],
    );
  }

  /// Visual formula builder for the amount field.
  Widget _buildAmountFormulaRow(List<String> columns) {
    final mode = _amountMode;

    // ── Balance-diff mode ──
    if (mode == 'balance') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 140,
                  child: Text('amount *', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 24),
                _buildAmountModeButtons(columns, currentMode: mode),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 164, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Balance column:', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _balanceDiffColumn,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _balanceDiffColumn = v),
                        ),
                      ),
                    ],
                  ),
                  if (_preview != null && _balanceDiffColumn != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Preview: amount = balance[i] − balance[i−1] → ${_balanceDiffPreview()}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Simple mode ──
    if (mode == 'simple') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 140,
              child: Text('amount *', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _mappings['amount'],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  hintText: 'Select column',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— None —', style: TextStyle(color: Colors.grey))),
                  ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _mappings['amount'] = v),
              ),
            ),
            const SizedBox(width: 8),
            _buildAmountModeButtons(columns, currentMode: mode),
          ],
        ),
      );
    }

    // ── Formula mode ──
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 140,
                child: Text('amount *', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 24),
              _buildAmountModeButtons(columns, currentMode: mode),
            ],
          ),
          // Formula terms
          for (var i = 0; i < _amountFormula.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 164, top: 4),
              child: Row(
                children: [
                  // +/- toggle button
                  InkWell(
                    onTap: () => setState(() {
                      final cur = _amountFormula[i];
                      _amountFormula[i] = FormulaTerm(
                        operator: cur.operator == '+' ? '-' : '+',
                        sourceColumn: cur.sourceColumn,
                      );
                    }),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _amountFormula[i].operator == '+' ? '+' : '−',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _amountFormula[i].operator == '+' ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _amountFormula[i].sourceColumn,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _amountFormula[i] = FormulaTerm(operator: _amountFormula[i].operator, sourceColumn: v);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    color: Colors.red.shade300,
                    onPressed: () => setState(() => _amountFormula.removeAt(i)),
                  ),
                ],
              ),
            ),
          // Add term + preview row
          Padding(
            padding: const EdgeInsets.only(left: 164, top: 6),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add column'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => setState(() {
                    _amountFormula.add(FormulaTerm(operator: '+', sourceColumn: columns.first));
                  }),
                ),
                const SizedBox(width: 16),
                if (_preview != null)
                  Expanded(
                    child: Text(
                      'Preview: ${_preview!.rows.take(3).map((row) {
                        double sum = 0;
                        for (final t in _amountFormula) {
                          final raw = row[t.sourceColumn] ?? '0';
                          final v = double.tryParse(raw.replaceAll(RegExp(r'[€\$£¥,]'), '').replaceAll(' ', '')) ?? 0;
                          sum += t.operator == '-' ? -v : v;
                        }
                        return sum.toStringAsFixed(2);
                      }).join(',  ')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Preview first few balance-diff computed values.
  String _balanceDiffPreview() {
    if (_preview == null || _balanceDiffColumn == null) return '';
    final rows = _preview!.rows;
    final results = <String>[];
    double? prev;
    for (var i = 0; i < rows.length && results.length < 4; i++) {
      final raw = rows[i][_balanceDiffColumn!] ?? '';
      final val = double.tryParse(raw.replaceAll(RegExp(r'[€\$£¥,]'), '').replaceAll(' ', ''));
      if (val != null && prev != null) {
        results.add((val - prev).toStringAsFixed(2));
      } else if (val != null) {
        results.add('${val.toStringAsFixed(2)} (first)');
      }
      prev = val;
    }
    return results.join(', ');
  }

  bool _canProceedToConfirm() {
    // date must be mapped
    if (_mappings['date'] == null) return false;
    // amount: either simple mapping, formula, or balance-diff
    if (_mappings['amount'] == null && _amountFormula.isEmpty && _balanceDiffColumn == null) return false;
    // Asset events also require ISIN
    if (_target == ImportTarget.assetEvent && _mappings['isin'] == null) return false;
    return true;
  }

  // ──────────────────────────────────────────────
  // Step 2: Select target + confirm
  // ──────────────────────────────────────────────

  /// Extract unique ISINs from preview data for the asset import summary.
  Map<String, int> _getIsinSummary() {
    if (_preview == null || _mappings['isin'] == null) return {};
    final isinCol = _mappings['isin']!;
    final counts = <String, int>{};
    for (final row in _preview!.rows) {
      final isin = (row[isinCol] ?? '').trim().toUpperCase();
      if (isin.isNotEmpty) {
        counts[isin] = (counts[isin] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildConfirm() {
    final isAssetImport = _target == ImportTarget.assetEvent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isAssetImport && widget.preselectedAccountId == null) ...[
          const Text('Select Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildAccountSelector(),
          const SizedBox(height: 24),
        ],

        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Import Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('File: ${_filePath?.split('/').last}'),
                Text('Rows: ${_preview?.totalRows}'),
                Text('Target: ${isAssetImport ? "Asset Events" : "Transactions"}'),
                const SizedBox(height: 8),
                const Text('Mappings:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._mappings.entries
                    .where((e) => e.value != null && !(e.key == 'amount' && _amountFormula.isNotEmpty))
                    .map((e) => Text('  ${e.key} ← ${e.value}')),
                if (_amountFormula.isNotEmpty)
                  Text('  amount ← ${_amountFormula.map((t) => '${t.operator} ${t.sourceColumn}').join(' ').replaceFirst('+ ', '')}'),
                if (isAssetImport) ...[
                  const SizedBox(height: 12),
                  const Text('Assets to create/update:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._getIsinSummary().entries.map((e) =>
                    Text('  ${e.key} — ${e.value} events', style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),

        const Spacer(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_importing) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Importing $_importedSoFar / $_importTotal rows...',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _importTotal > 0 ? _importedSoFar / _importTotal : null,
                ),
              ],
            ),
          ),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Import'),
                onPressed: (isAssetImport || _targetId != null) ? _executeImport : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return Column(
            children: [
              const Text('No accounts yet. Create one first.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showCreateAccountDialog(),
                child: const Text('Create Account'),
              ),
            ],
          );
        }
        return Column(
          children: [
            ...accounts.map((a) {
              final account = a as Account;
              return RadioListTile<int>(
                title: Text(account.name),
                subtitle: Text('${account.type.name} · ${account.currency}'),
                value: account.id,
                groupValue: _targetId,
                onChanged: (v) => setState(() => _targetId = v),
              );
            }),
            OutlinedButton(
              onPressed: () => _showCreateAccountDialog(),
              child: const Text('+ New Account'),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildAssetSelector() {
    final assetsAsync = ref.watch(assetsProvider);
    return assetsAsync.when(
      data: (assets) {
        if (assets.isEmpty) {
          return Column(
            children: [
              const Text('No assets yet. Create one first.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showCreateAssetDialog(),
                child: const Text('Create Asset'),
              ),
            ],
          );
        }
        return Column(
          children: [
            ...assets.map((a) {
              final asset = a as Asset;
              return RadioListTile<int>(
                title: Text(asset.name),
                subtitle: Text('${asset.assetType.name} · ${asset.currency}'),
                value: asset.id,
                groupValue: _targetId,
                onChanged: (v) => setState(() => _targetId = v),
              );
            }),
            OutlinedButton(
              onPressed: () => _showCreateAssetDialog(),
              child: const Text('+ New Asset'),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Future<void> _showCreateAccountDialog() async {
    final nameCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Account'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Fineco'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(accountServiceProvider).create(
                    name: nameCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) setState(() {});
  }

  Future<void> _showCreateAssetDialog() async {
    final isinCtrl = TextEditingController();
    String? resolvedName;
    String? resolvedTicker;
    bool looking = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Asset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: isinCtrl,
                decoration: const InputDecoration(labelText: 'ISIN', hintText: 'e.g. IE00B4L5Y983'),
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) async {
                  final isin = v.trim().toUpperCase();
                  if (isin.length == 12) {
                    setDialogState(() => looking = true);
                    final result = await ref.read(isinLookupServiceProvider).lookup(isin);
                    if (ctx.mounted) {
                      setDialogState(() {
                        resolvedName = result.name;
                        resolvedTicker = result.ticker;
                        looking = false;
                      });
                    }
                  } else {
                    setDialogState(() {
                      resolvedName = null;
                      resolvedTicker = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              if (looking)
                const Row(children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Looking up ISIN...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ])
              else if (resolvedName != null || resolvedTicker != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (resolvedName != null)
                      Text(resolvedName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (resolvedTicker != null)
                      Text('Ticker: $resolvedTicker', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                )
              else if (isinCtrl.text.trim().length == 12)
                const Text('ISIN not found', style: TextStyle(color: Colors.orange, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: isinCtrl.text.trim().length == 12 && !looking
                  ? () async {
                      final isin = isinCtrl.text.trim().toUpperCase();
                      final name = resolvedName ?? isin;
                      await ref.read(assetServiceProvider).create(
                            name: name,
                            ticker: resolvedTicker,
                            isin: isin,
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    }
                  : null,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) setState(() {});
  }

  Future<void> _executeImport() async {
    _log.info('_executeImport: starting import — target=${_target.name}, targetId=$_targetId');
    setState(() {
      _importing = true;
      _importedSoFar = 0;
      _importTotal = _preview?.totalRows ?? 0;
      _error = null;
    });

    try {
      final importer = ref.read(importServiceProvider);
      final mappings = <ColumnMapping>[];
      for (final e in _mappings.entries) {
        if (e.value == null) continue;
        if (e.key == 'amount' && (_amountFormula.isNotEmpty || _balanceDiffColumn != null)) continue;
        mappings.add(ColumnMapping(sourceColumn: e.value!, targetField: e.key));
      }
      // Multi-column mappings (override single mappings for same field)
      for (final e in _multiMappings.entries) {
        if (e.value.length < 2) continue;
        mappings.removeWhere((m) => m.targetField == e.key);
        mappings.add(ColumnMapping(targetField: e.key, multiColumns: List.of(e.value), multiDelimiter: _multiDelimiters[e.key] ?? ' '));
      }
      // Amount: balance-diff, formula, or simple mapping
      if (_balanceDiffColumn != null) {
        _log.info('_executeImport: amount from balance-diff column=$_balanceDiffColumn');
        mappings.add(ColumnMapping(targetField: 'amount', balanceDiffColumn: _balanceDiffColumn));
      } else if (_amountFormula.isNotEmpty) {
        final formulaDesc = _amountFormula.map((t) => '${t.operator}${t.sourceColumn}').join(' ');
        _log.info('_executeImport: amount formula=$formulaDesc');
        mappings.add(ColumnMapping(targetField: 'amount', formulaTerms: List.of(_amountFormula)));
      } else if (_mappings['amount'] != null) {
        mappings.add(ColumnMapping(sourceColumn: _mappings['amount']!, targetField: 'amount'));
      }

      _log.info('_executeImport: ${mappings.length} column mappings built');
      _log.fine('_executeImport: mappings=${mappings.map((m) => '${m.targetField}←${m.sourceColumn ?? "formula"}').join(', ')}');

      void onProgress(int processed, int total) {
        setState(() {
          _importedSoFar = processed;
          _importTotal = total;
        });
      }

      final ImportResult result;
      if (_target == ImportTarget.transaction) {
        result = await importer.importTransactions(
          preview: _preview!,
          mappings: mappings,
          accountId: _targetId!,
          hashColumns: _hashColumns.isNotEmpty ? _hashColumns : null,
          onProgress: onProgress,
          balanceMode: _balanceMode,
          balanceFilterColumn: _balanceFilterColumn,
          balanceFilterInclude: _balanceFilterInclude.isNotEmpty ? _balanceFilterInclude : null,
        );
      } else {
        final assetResult = await importer.importAssetEventsGrouped(
          preview: _preview!,
          mappings: mappings,
          onProgress: onProgress,
          computeFee: _feeMode == 'computed',
          isinLookup: ref.read(isinLookupServiceProvider),
        );
        result = assetResult.result;
      }

      _log.info('_executeImport: complete — imported=${result.importedRows}, duplicates=${result.skippedDuplicates}, errors=${result.errorRows}');
      if (result.errors.isNotEmpty) {
        _log.warning('_executeImport: first error: ${result.errors.first}');
      }

      // Save import config for this account
      await _saveConfig();

      setState(() {
        _result = result;
        _step = 3;
        _importing = false;
      });
    } catch (e, stack) {
      _log.severe('_executeImport: failed', e, stack);
      setState(() {
        _error = 'Import failed: $e';
        _importing = false;
      });
    }
  }

  // ──────────────────────────────────────────────
  // Step 3: Result
  // ──────────────────────────────────────────────

  Widget _buildResult() {
    final r = _result!;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                r.errorRows == 0 ? Icons.check_circle : Icons.warning,
                size: 64,
                color: r.errorRows == 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              Text('Import Complete', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _resultRow('Total rows', '${r.totalRows}'),
              _resultRow('Imported', '${r.importedRows}', color: Colors.green),
              _resultRow('Skipped (duplicates)', '${r.skippedDuplicates}', color: Colors.grey),
              if (r.errorRows > 0) _resultRow('Errors', '${r.errorRows}', color: Colors.red),
              if (r.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...r.errors.take(5).map((e) => Text(e, style: const TextStyle(fontSize: 12, color: Colors.red))),
                if (r.errors.length > 5) Text('... and ${r.errors.length - 5} more', style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _reset();
                      _step = 0;
                    }),
                    child: const Text('Import Another'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 180, child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
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
    _mappings.clear();
    _result = null;
    _error = null;
    _parsing = false;
    _importedSoFar = 0;
    _importTotal = 0;
    _hashColumns.clear();
    _multiMappings.clear();
    _multiDelimiters.clear();
    _noHeader = false;
    _balanceDiffColumn = null;
    _savedConfig = null;
    _balanceMode = 'none';
    _balanceFilterColumn = null;
    _balanceFilterInclude.clear();
    _feeMode = 'column';
  }
}
