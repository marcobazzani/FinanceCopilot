part of 'import_screen.dart';

extension _ColumnMapperMappingContent on _ImportScreenState {
  Widget _buildMappingContent(FilePreview? preview) {
    final s = ref.watch(appStringsProvider);
    final columns = preview?.columns ?? [];
    final totalRows = preview?.totalRows ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skip rows (auto re-parse after 1s or Enter)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
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
        Text(s.mapColumnsTitle(columns.length, totalRows), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              // Asset event mode toggle (Historic vs Current)
              if (_target == ImportTarget.assetEvent) ...[
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
                // Toggle changes _requiredFields so the column-mapper hides
                // ISIN/quantity/price when the user picks a single target asset.
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
                          // Drop ISIN/quantity/price mappings — single-asset
                          // mode routes everything to one pre-existing asset
                          // and synthesises qty/price for cash contributes.
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
                const SizedBox(height: 8),
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
                  Text(
                    s.hiddenRows(preview.rows.length - 10),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
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
