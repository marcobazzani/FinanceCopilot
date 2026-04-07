part of 'import_screen.dart';

// ──────────────────────────────────────────────
// Step 1: Preview + Column mapping
// ──────────────────────────────────────────────

extension _ColumnMapperStep on _ImportScreenState {

  Widget _buildColumnMapper() {
    final s = ref.watch(appStringsProvider);
    final preview = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Data source toolbar
        Row(
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(s.openFile),
              onPressed: _parsing ? null : _pickFile,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.content_paste),
              label: Text(s.pasteFromClipboard),
              onPressed: _parsing ? null : _pasteFromClipboard,
            ),
            if (_filePath != null) ...[
              const SizedBox(width: 16),
              Chip(label: Text(_filePath!.split('/').last)),
            ],
            if (_filePath == null && _preview != null) ...[
              const SizedBox(width: 16),
              Chip(label: Text(s.clipboardData)),
            ],
            const Spacer(),
            if (_parsing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 12),

        // Target selector (hidden when preselected from account view)
        if (widget.preselectedAccountId == null && widget.preselectedTarget == null) ...[
          Row(
            children: [
              Text(s.importAs, style: const TextStyle(fontWeight: FontWeight.bold)),
              SegmentedButton<ImportTarget>(
                segments: [
                  ButtonSegment(value: ImportTarget.transaction, label: Text(s.importTypeTransaction)),
                  ButtonSegment(value: ImportTarget.assetEvent, label: Text(s.importTypeAssetEvent)),
                  ButtonSegment(value: ImportTarget.income, label: Text(s.importTypeIncome)),
                ],
                selected: {_target},
                onSelectionChanged: (v) => _setState(() {
                  _target = v.first;
                  _mappings.clear();
                  _amountFormula.clear();
                  for (final f in _requiredFields) {
                    _mappings[f] = null;
                  }
                  if (preview != null) _autoMap(preview.columns);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Disable mapping UI when no data loaded
        Expanded(
          child: IgnorePointer(
            ignoring: preview == null,
            child: Opacity(
              opacity: preview == null ? 0.4 : 1.0,
              child: _buildMappingContent(preview),
            ),
          ),
        ),
      ],
    );
  }

  /// The mapping UI content (skip rows, column mapping, preview table, Next button).
  Widget _buildMappingContent(FilePreview? preview) {
    final s = ref.watch(appStringsProvider);
    final columns = preview?.columns ?? [];
    final totalRows = preview?.totalRows ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skip rows (auto re-parse after 1s or Enter)
        Row(
          children: [
            Text(s.skipRows, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text(s.skipRowsHelp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                  _setState(() => _noHeader = v ?? false);
                  _reparseFile();
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                _setState(() => _noHeader = !_noHeader);
                _reparseFile();
              },
              child: Text(s.noHeaderRow, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Column mapping
        Text(s.mapColumnsTitle(columns.length, totalRows),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              // Asset event mode toggle (Historic vs Current)
              if (_target == ImportTarget.assetEvent) ...[
                Row(
                  children: [
                    Text(s.modeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
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
                    const SizedBox(width: 12),
                    Text(
                      _assetImportMode == 'historic'
                          ? s.dateExchangeRequired
                          : s.dateDefaultsToday,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Required fields -- date required except for asset events in current mode
              if (_target != ImportTarget.assetEvent || _assetImportMode == 'historic')
                _buildMappingRow('date', columns, required: true),
              if (_target == ImportTarget.transaction)
                _buildAmountFormulaRow(columns, s)
              else if (_target == ImportTarget.assetEvent) ...[
                // Amount: either from column or auto-calculated
                Row(
                  children: [
                    Expanded(child: _autoCalcAmount
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              SizedBox(width: 100, child: Text(s.amount, style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ))),
                              const Icon(Icons.arrow_forward, size: 16),
                              const SizedBox(width: 8),
                              Text(s.qtyTimesPrice, style: TextStyle(
                                fontSize: 13, fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              )),
                            ]),
                          )
                        : _buildMappingRow('amount', columns)),
                    const SizedBox(width: 8),
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
                Row(
                  children: [
                    Expanded(
                      child: _sameSettlementDate
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                SizedBox(width: 140, child: Text(
                                  '${s.fieldLabel('valueDate')} *',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )),
                                const Icon(Icons.arrow_forward, size: 16),
                                const SizedBox(width: 8),
                                Text('= ${s.fieldLabel('date')}', style: TextStyle(
                                  fontSize: 13, fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                )),
                              ]),
                            )
                          : _buildMappingRow('valueDate', columns, required: true),
                    ),
                    const SizedBox(width: 8),
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
              const Divider(),

              // Data preview table
              if (preview != null) ...[
                const SizedBox(height: 8),
                Text(s.previewRows(totalRows), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(s.first5Rows, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    rows: preview.rows.take(5).map((row) {
                      return DataRow(
                        cells: columns.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                      );
                    }).toList(),
                  ),
                ),
                if (preview.rows.length > 10) ...[
                  const SizedBox(height: 8),
                  Text(s.hiddenRows(preview.rows.length - 10),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center),
                ],
                if (preview.rows.length > 5) ...[
                  const SizedBox(height: 4),
                  Text(s.last5Rows, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      rows: preview.rows.skip(preview.rows.length > 5 ? preview.rows.length - 5 : 0).map((row) {
                        return DataRow(
                          cells: columns.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: _canProceedToConfirm() ? () {
                _setState(() => _step = 2);
                if (_target == ImportTarget.assetEvent) _lookupIsins();
              } : null,
              child: Text(s.next),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMappingRow(String field, List<String> columns, {bool required = false, bool multiColumn = false}) {
    final s = ref.watch(appStringsProvider);
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
                  '${s.fieldLabel(field)}${required ? ' *' : ''}',
                  style: TextStyle(fontWeight: required ? FontWeight.bold : FontWeight.normal),
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16),
              const SizedBox(width: 8),
              if (!isMulti)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mappings[field],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                      hintText: required ? s.required
                          : field == 'date' ? '${s.notMapped} (→ ${DateTime.now().toIso8601String().substring(0, 10)})'
                          : s.notMapped,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text('— ${s.none} —', style: const TextStyle(color: Colors.grey))),
                      ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => _setState(() => _mappings[field] = v),
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
              padding: const EdgeInsets.only(left: 164, top: 4),
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
  Widget _buildBalanceModeSection(FilePreview preview) {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(s.balancePerRow, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(s.balancePerRowHelp,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'cumulative', label: Text(s.recalcCumulative)),
            ButtonSegment(value: 'column', label: Text(s.balanceFromColumn)),
            ButtonSegment(value: 'filtered', label: Text(s.recalcFiltered)),
          ],
          selected: {_balanceMode},
          onSelectionChanged: (v) => _setState(() {
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
                SizedBox(
                  width: 140,
                  child: Text(s.filterColumn, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _balanceFilterColumn,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                      hintText: s.selectColumn,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text('— ${s.none} —', style: const TextStyle(color: Colors.grey))),
                      ...preview.columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => _setState(() {
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
                  Text(s.includeValues, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _setState(() {
                      _balanceFilterInclude.addAll(_uniqueColumnValues(_balanceFilterColumn!));
                    }),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(s.all, style: const TextStyle(fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () => _setState(() => _balanceFilterInclude.clear()),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(s.none, style: const TextStyle(fontSize: 11)),
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
                    onSelected: (v) => _setState(() {
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

        // Fee/cost column -- available for cumulative and filtered modes


      ],
    );
  }

  /// Build the buy/sell type detection section for asset imports.
  Widget _buildTypeDetectionSection(List<String> columns) {
    final s = ref.watch(appStringsProvider);
    // Gather unique values from the mapped type column (all rows, not just preview)
    final typeCol = _mappings['type'];
    if (typeCol != null && !_fullUniqueValues.containsKey(typeCol)) {
      _loadFullUniqueValues(typeCol);
    }
    final uniqueVals = typeCol != null ? (_fullUniqueValues[typeCol] ?? _uniqueColumnValues(typeCol)) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.buySellDetection, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'column', label: Text(s.fromColumn)),
            ButtonSegment(value: 'sign', label: Text(s.fromSign)),
          ],
          selected: {_typeMode},
          onSelectionChanged: (v) => _setState(() {
            _typeMode = v.first;
            if (_typeMode == 'sign') {
              _mappings['type'] = null;
              _buyValues.clear();
              _sellValues.clear();
              _fullUniqueValues.remove(_mappings['type']);
            }
          }),
        ),
        if (_typeMode == 'column') ...[
          const SizedBox(height: 4),
          _buildMappingRow('type', columns),
          if (typeCol != null && uniqueVals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.mapBuySell, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            ...uniqueVals.map((val) {
              final isBuy = _buyValues.contains(val);
              final isSell = _sellValues.contains(val);
              final isUnmapped = !isBuy && !isSell;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(val, style: TextStyle(
                        fontSize: 13,
                        color: isUnmapped ? Colors.red.shade300 : null,
                        fontWeight: isUnmapped ? FontWeight.bold : null,
                      ), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(s.buyLabel, style: const TextStyle(fontSize: 11)),
                      selected: isBuy,
                      onSelected: (_) => _setState(() {
                        _sellValues.remove(val);
                        if (isBuy) { _buyValues.remove(val); } else { _buyValues.add(val); }
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: Text(s.sellLabel, style: const TextStyle(fontSize: 11)),
                      selected: isSell,
                      onSelected: (_) => _setState(() {
                        _buyValues.remove(val);
                        if (isSell) { _sellValues.remove(val); } else { _sellValues.add(val); }
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
            if (uniqueVals.any((v) => !_buyValues.contains(v) && !_sellValues.contains(v)))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.buySellAllRequired,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                ),
              ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.signBasedHelp,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
      ],
    );
  }

  /// Build the fee computation mode selector for asset imports.
  Widget _buildFeeModeSection(List<String> columns) {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.feeCommission, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'column', label: Text(s.fromColumn)),
            ButtonSegment(value: 'computed', label: Text(s.computedLabel)),
          ],
          selected: {_feeMode},
          onSelectionChanged: (v) => _setState(() {
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
                onPressed: () => _setState(() {
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
  Widget _buildAmountFormulaRow(List<String> columns, AppStrings s) {
    final mode = _amountMode;

    // -- Balance-diff mode --
    if (mode == 'balance') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(s.amountRequired, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      Text(s.balanceColumn, style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _balanceDiffColumn,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => _setState(() => _balanceDiffColumn = v),
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

    // -- Simple mode --
    if (mode == 'simple') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(s.amountRequired, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _mappings['amount'],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: const OutlineInputBorder(),
                  hintText: ref.watch(appStringsProvider).selectColumn,
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text('— ${ref.watch(appStringsProvider).none} —', style: const TextStyle(color: Colors.grey))),
                  ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => _setState(() => _mappings['amount'] = v),
              ),
            ),
            const SizedBox(width: 8),
            _buildAmountModeButtons(columns, currentMode: mode),
          ],
        ),
      );
    }

    // -- Formula mode --
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(s.amountRequired, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    onTap: () => _setState(() {
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
                      initialValue: _amountFormula[i].sourceColumn,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: columns.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _setState(() {
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
                    onPressed: () => _setState(() => _amountFormula.removeAt(i)),
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
                  label: Text(ref.watch(appStringsProvider).addColumn),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _setState(() {
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
}
