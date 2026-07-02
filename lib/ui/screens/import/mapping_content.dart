part of 'import_screen.dart';

extension _ColumnMapperMappingContent on _ImportScreenState {
  Widget _buildMappingContent(FilePreview? preview) {
    final s = ref.watch(appStringsProvider);
    final columns = preview?.columns ?? [];
    final totalRows = preview?.totalRows ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column mapping
        Text(s.mapColumnsTitle(columns.length, totalRows), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              // Preview table + Refine panel: see the data and shape
              // rows/columns before mapping individual fields. (The asset-event
              // Mode + Group/Single selectors live above the file picker so
              // they can be chosen before a file is loaded.)
              if (preview != null) ...[
                _buildPreviewTable(preview, columns, totalRows),
                _buildRefinePanel(columns),
                const Divider(),
              ],
              // Required fields -- date required except for asset events in current mode
              if (_target != ImportTarget.assetEvent || _assetImportMode == 'historic') _buildMappingRow('date', columns, required: true),
              if (_target == ImportTarget.transaction)
                _buildAmountFormulaRow(columns, s)
              else if (_target == ImportTarget.assetEvent) ...[
                // Amount: either from column or auto-calculated
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_autoCalcAmount)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                s.amount,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                s.qtyTimesPrice,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildMappingRow('amount', columns),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _autoCalcAmount,
                          onChanged: (v) => _setState(() {
                            _autoCalcAmount = v ?? false;
                            if (_autoCalcAmount) _mappings['amount'] = null;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(s.autoCalc, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ] else
                _buildMappingRow('amount', columns, required: true),
              // Value date: either mapped or same as operation date (transactions only)
              if (_target == ImportTarget.transaction) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_sameSettlementDate)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width < 400 ? 90 : 140),
                              child: Text(
                                '${s.fieldLabel('valueDate')} *',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '= ${s.fieldLabel('date')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildMappingRow('valueDate', columns, required: true),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _sameSettlementDate,
                          onChanged: (v) => _setState(() {
                            _sameSettlementDate = v ?? false;
                            if (_sameSettlementDate) _mappings['valueDate'] = null;
                          }),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(s.sameAsOperationDate, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
              ..._requiredFields
                  .where((f) => f != 'date' && f != 'amount' && f != 'valueDate')
                  .map((f) => _buildMappingRow(f, columns, required: true, multiColumn: f == 'description')),
              // Type detection + Fee section for asset events
              if (_target == ImportTarget.assetEvent) ...[
                const SizedBox(height: 12),
                _buildTypeDetectionSection(columns),
                const SizedBox(height: 12),
                _buildFeeModeSection(columns),
              ],
              // Income-type tagging section
              if (_target == ImportTarget.income) ...[
                const SizedBox(height: 12),
                _buildIncomeTypeSection(columns),
              ],
              const SizedBox(height: 12),
              // Optional fields
              Text(s.optional, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ..._optionalFields.map((f) => _buildMappingRow(f, columns, multiColumn: true)),
              const SizedBox(height: 4),
              Text(s.unmappedHelp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (_target == ImportTarget.transaction && preview != null) ...[
                const Divider(),
                _buildBalanceModeSection(preview),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: _canProceedToConfirm()
                  ? () {
                      _setState(() => _step = 2);
                      if (_target == ImportTarget.assetEvent) _lookupIsins();
                      _computePreview();
                    }
                  : null,
              child: Text(s.next),
            ),
          ],
        ),
      ],
    );
  }

  /// Asset-event Mode (historic/current) + Group-by-ISIN / Single-asset
  /// selectors. Rendered above the file picker (NOT gated on a loaded preview)
  /// so the user sets the import shape — and picks the single-asset target,
  /// which loads any saved config — before choosing the file.
  Widget _buildAssetModeSelectors() {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s.modeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'historic', label: Text(s.modeHistoric)),
                ButtonSegment(value: 'current', label: Text(s.modeCurrent)),
              ],
              selected: {_assetImportMode},
              onSelectionChanged: (v) {
                _setState(() {
                  _assetImportMode = v.first;
                  if (_assetImportMode == 'current') {
                    _mappings.remove('date');
                    _mappings.remove('exchangeRate');
                  }
                });
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            Text(
              _assetEventMode == 'singleAsset'
                  ? s.singleAssetHelp
                  : (_assetImportMode == 'historic' ? s.dateExchangeRequired : s.dateDefaultsToday),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ByIsin (multi-asset) vs SingleAsset (pension/manual) toggle.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'byIsin', label: Text(s.importByIsin)),
                ButtonSegment(value: 'singleAsset', label: Text(s.importIntoSingleAsset)),
              ],
              selected: {_assetEventMode},
              onSelectionChanged: (v) => _setState(() {
                _assetEventMode = v.first;
                if (_assetEventMode == 'singleAsset') {
                  _mappings.remove('isin');
                } else {
                  _singleAssetTargetId = null;
                }
              }),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            if (_assetEventMode == 'singleAsset') _buildSingleAssetPicker(s),
          ],
        ),
      ],
    );
  }

  /// The read-only data preview. A SINGLE [DataTable] (so column widths stay
  /// consistent and text never breaks) inside a fixed-height, scrollable box
  /// (so refine edits that change the row set don't make the panel jump in
  /// height). Shows first-5 + last-5 with an ellipsis separator by default, or
  /// every parsed row when "Show all" is toggled.
  Widget _buildPreviewTable(FilePreview preview, List<String> columns, int totalRows) {
    final s = ref.watch(appStringsProvider);

    // The set of rows the preview reflects. When transforms (filters/splits)
    // are active and the complete transformed set has been loaded, use it —
    // filters/splits must be evaluated over EVERY row, not the parser's capped
    // first-5/last-5 sample (otherwise middle rows silently vanish). Otherwise
    // fall back to the capped preview already in memory.
    final usingFull = !_transforms.isEmpty && _transformedFullRows != null;
    final source = usingFull ? _transformedFullRows! : preview.rows;
    // Effective total: the real (filtered) count when we have the full set;
    // the parser's total otherwise.
    final effectiveTotal = usingFull ? source.length : totalRows;
    // The collapsed view shows everything only when the source IS the whole
    // set AND it's small (≤10). Otherwise the middle is hidden: either the
    // parser capped to first-5/last-5 (source.length 10, effectiveTotal more)
    // or we're slicing a >10 full set.
    final collapsedShowsAll = source.length <= 10 && effectiveTotal <= source.length;
    final hasMore = !_showAllPreviewRows && (!collapsedShowsAll || _loadingTransformedFull);
    final hiddenCount = effectiveTotal - 10;

    // Build the displayed row list. null entries are the separator band.
    final List<Map<String, String>?> display;
    if (_showAllPreviewRows) {
      // Showing every row. Prefer the lazily-loaded _showAllRows (capped path),
      // else the full transformed set, else the in-memory source.
      final all = _showAllRows ?? (usingFull ? source : null) ?? source;
      display = List<Map<String, String>?>.from(all);
    } else if (collapsedShowsAll) {
      // Small, complete set: show every row, no separator.
      display = List<Map<String, String>?>.from(source);
    } else {
      // Middle hidden: first 5 + separator band + last 5. For the capped
      // sample `source` is already exactly the first-5 + last-5 of the file.
      display = [
        ...source.take(5),
        null, // separator band
        ...source.skip(source.length - 5),
      ];
    }

    DataRow buildRow(Map<String, String>? row) {
      if (row == null) {
        // Separator: a tinted band spanning the table, labelled with the
        // hidden-row count, so it clearly reads as a divider (not a row).
        final label = '⋯  ${s.hiddenRows(hiddenCount)}  ⋯';
        return DataRow(
          color: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.12)),
          cells: List.generate(
            columns.length,
            (i) => DataCell(
              // Repeat the centred label in the middle column for visibility;
              // other cells stay empty so the band reads as one divider.
              i == (columns.length ~/ 2)
                  ? Center(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      }
      return DataRow(
        cells: columns.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.previewRows(effectiveTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (_loadingShowAll || _loadingTransformedFull)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (hasMore)
              TextButton.icon(
                icon: Icon(_showAllPreviewRows ? Icons.unfold_less : Icons.unfold_more, size: 18),
                label: Text(_showAllPreviewRows ? s.showLessRows : s.showAllRows),
                onPressed: _loadingShowAll ? null : _toggleShowAllPreview,
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Natural height (no inner vertical scroll → no scroll-in-scroll).
        // Only horizontal scroll for tables wider than the viewport. The
        // table grows with its rows; the outer mapper ListView scrolls.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
            rows: display.map(buildRow).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMappingRow(String field, List<String> columns, {bool required = false, bool multiColumn = false}) {
    final s = ref.watch(appStringsProvider);
    final multiCols = _multiMappings[field] ?? [];
    final isMulti = multiColumn && multiCols.length > 1;
    final showAddBtn = multiColumn && !isMulti && _mappings[field] != null;
    final narrow = MediaQuery.sizeOf(context).width < 500;
    final multiIndent = narrow ? 0.0 : 164.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width < 400 ? 90 : 140),
                child: Text(
                  '${s.fieldLabel(field)}${required ? ' *' : ''}',
                  style: TextStyle(
                    fontWeight: required ? FontWeight.bold : FontWeight.normal,
                    fontSize: MediaQuery.sizeOf(context).width < 400 ? 12 : 14,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 4),
              if (!isMulti)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mappings[field],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                      hintText: required
                          ? s.required
                          : field == 'date'
                          ? '${s.notMapped} (→ ${DateTime.now().toIso8601String().substring(0, 10)})'
                          : s.notMapped,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('— ${s.none} —', style: const TextStyle(color: Colors.grey)),
                      ),
                      ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => _setState(() {
                      _mappings[field] = v;
                      // Mapping an explicit amount column and "Auto calc"
                      // (amount = qty × price) are mutually exclusive — turn
                      // auto-calc off so they can't silently conflict.
                      if (field == 'amount' && v != null) _autoCalcAmount = false;
                    }),
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
                  message: s.combineMultipleColumns,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _setState(() {
                      _multiMappings[field] = [_mappings[field]!, columns.firstWhere((c) => c != _mappings[field], orElse: () => columns.first)];
                      _mappings[field] = null;
                    }),
                  ),
                ),
              ],
              if (isMulti) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: s.useSingleColumn,
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    visualDensity: VisualDensity.compact,
                    color: Colors.red.shade300,
                    onPressed: () => _setState(() {
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
                padding: EdgeInsets.only(left: multiIndent, top: 4),
                child: Row(
                  children: [
                    if (i > 0)
                      Text(
                        '+',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                      )
                    else
                      const SizedBox(width: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: multiCols[i],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _setState(() => _multiMappings[field]![i] = v);
                        },
                      ),
                    ),
                    if (multiCols.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        color: Colors.red.shade300,
                        onPressed: () => _setState(() => _multiMappings[field]!.removeAt(i)),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
          if (isMulti)
            Padding(
              padding: EdgeInsets.only(left: multiIndent, top: 4),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.addColumn),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _setState(() {
                      _multiMappings[field]!.add(columns.first);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Text(s.sepLabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      onChanged: (v) => _setState(() => _multiDelimiters[field] = v),
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

  /// Build the "Balance per row" configuration section.
}
