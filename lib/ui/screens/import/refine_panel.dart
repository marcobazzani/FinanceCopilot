part of 'import_screen.dart';

/// The collapsible "Refine rows & columns" panel rendered above the preview
/// table. Hosts skip-rows + no-header (relocated here) plus the new row
/// filters and column splits. All edits rebuild [_preview] from the raw
/// parser output via [_rebuildPreviewFromTransforms] — no file re-parse.
extension _RefinePanel on _ImportScreenState {
  String _filterOpLabel(AppStrings s, FilterOp op) => switch (op) {
    FilterOp.contains => s.filterOpContains,
    FilterOp.notContains => s.filterOpNotContains,
    FilterOp.equals => s.filterOpEquals,
    FilterOp.notEquals => s.filterOpNotEquals,
    FilterOp.matches => s.filterOpMatches,
    FilterOp.notMatches => s.filterOpNotMatches,
  };

  void _updateTransforms({List<RowFilter>? filters, List<ColumnSplit>? splits, FilterCombine? combine}) {
    _transforms = PreviewTransforms(
      filters: filters ?? _transforms.filters,
      splits: splits ?? _transforms.splits,
      combine: combine ?? _transforms.combine,
    );
    _rebuildPreviewFromTransforms();
  }

  Widget _buildRefinePanel(List<String> columns) {
    final s = ref.watch(appStringsProvider);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(s.refineRowsColumns, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(s.refineRowsColumnsHelp, style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          // Skip-rows / no-header are raw-line concepts that don't apply to
          // PDFs (those go through the table reconstructor). Hide them for
          // PDF sources; row filters are the right tool there.
          if (!_isPdf) ...[
            _buildSkipRowsControl(s),
            const SizedBox(height: 4),
            _buildNoHeaderControl(s),
            const Divider(),
          ],
          _buildColumnSplitsSection(s, columns),
          const Divider(),
          _buildRowFiltersSection(s, columns),
        ],
      ),
    );
  }

  Widget _buildSkipRowsControl(AppStrings s) {
    return Wrap(
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
    );
  }

  Widget _buildNoHeaderControl(AppStrings s) {
    return Row(
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
    );
  }

  // ── Column splits ──────────────────────────────────────────────

  Widget _buildColumnSplitsSection(AppStrings s, List<String> columns) {
    // Only offer the original (pre-split) columns as split sources, so a
    // split source can't be a column produced by another split.
    final baseColumns = _rawPreview?.columns ?? columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.columnSplits, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.addSplit),
              onPressed: baseColumns.isEmpty
                  ? null
                  : () => _updateTransforms(
                      splits: [
                        ..._transforms.splits,
                        ColumnSplit(sourceColumn: baseColumns.first, newColumns: const []),
                      ],
                    ),
            ),
          ],
        ),
        Text(s.columnSplitsHelp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        for (var i = 0; i < _transforms.splits.length; i++) _buildSplitRow(s, baseColumns, i),
      ],
    );
  }

  Widget _buildSplitRow(AppStrings s, List<String> baseColumns, int index) {
    final split = _transforms.splits[index];
    final mode = split.byRegex ? 'regex' : (split.delimiter.trim().isEmpty ? 'ws' : 'delim');

    void replace(ColumnSplit next) {
      final list = [..._transforms.splits];
      list[index] = next;
      _updateTransforms(splits: list);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: baseColumns.contains(split.sourceColumn) ? split.sourceColumn : null,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: baseColumns
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => v == null
                      ? null
                      : replace(
                          ColumnSplit(
                            sourceColumn: v,
                            newColumns: split.newColumns,
                            byRegex: split.byRegex,
                            delimiter: split.delimiter,
                            pattern: split.pattern,
                          ),
                        ),
                ),
              ),
              SegmentedButton<String>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(
                    value: 'ws',
                    label: Text(s.splitByWhitespace, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'delim',
                    label: Text(s.splitByDelimiter, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'regex',
                    label: Text(s.splitByRegex, style: const TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (sel) {
                  final m = sel.first;
                  replace(
                    ColumnSplit(
                      sourceColumn: split.sourceColumn,
                      newColumns: split.newColumns,
                      byRegex: m == 'regex',
                      delimiter: m == 'delim' ? (split.delimiter.trim().isEmpty ? ',' : split.delimiter) : '',
                      pattern: split.pattern,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  final list = [..._transforms.splits]..removeAt(index);
                  _updateTransforms(splits: list);
                },
              ),
            ],
          ),
          if (mode == 'delim')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 200,
                child: TextFormField(
                  initialValue: split.delimiter,
                  decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: s.splitDelimiter),
                  onChanged: (v) => replace(
                    ColumnSplit(
                      sourceColumn: split.sourceColumn,
                      newColumns: split.newColumns,
                      delimiter: v,
                    ),
                  ),
                ),
              ),
            ),
          if (mode == 'regex')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextFormField(
                initialValue: split.pattern,
                decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: s.splitPattern),
                onChanged: (v) => replace(
                  ColumnSplit(
                    sourceColumn: split.sourceColumn,
                    newColumns: split.newColumns,
                    byRegex: true,
                    pattern: v,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextFormField(
              initialValue: split.newColumns.join(', '),
              decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: s.newColumnNames),
              onChanged: (v) {
                // Preserve positions: blank entries (e.g. ",,period") skip
                // that positional part. Trailing blanks are trimmed.
                final names = v.split(',').map((e) => e.trim()).toList();
                while (names.isNotEmpty && names.last.isEmpty) {
                  names.removeLast();
                }
                replace(
                  ColumnSplit(
                    sourceColumn: split.sourceColumn,
                    newColumns: names,
                    byRegex: split.byRegex,
                    delimiter: split.delimiter,
                    pattern: split.pattern,
                  ),
                );
              },
            ),
          ),
          _buildSplitPreview(s, split),
        ],
      ),
    );
  }

  /// Live "what you'll get" line: take the first sample cell of the source
  /// column that this split actually applies to, and show how it maps to the
  /// named output columns. When no sample row matches (e.g. a delimiter not
  /// present in any row), say so instead of showing a misleading empty split.
  Widget _buildSplitPreview(AppStrings s, ColumnSplit split) {
    final rows = _rawPreview?.rows ?? const [];
    if (rows.isEmpty || split.newColumns.where((c) => c.isNotEmpty).isEmpty) {
      return const SizedBox.shrink();
    }
    // Prefer the first row this split actually matches; fall back to the
    // first non-empty source cell so the line still renders something.
    Map<String, String> sample = const {};
    for (final r in rows) {
      final v = (r[split.sourceColumn] ?? '').trim();
      if (v.isNotEmpty && split.matches(v)) {
        sample = r;
        break;
      }
    }
    final matched = sample.isNotEmpty;
    if (!matched) {
      sample = rows.firstWhere(
        (r) => (r[split.sourceColumn] ?? '').trim().isNotEmpty,
        orElse: () => const {},
      );
    }
    final cell = sample[split.sourceColumn] ?? '';
    if (cell.isEmpty) return const SizedBox.shrink();
    if (!matched) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${s.splitPreviewLabel}: ${s.splitNoMatch}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ),
      );
    }
    final parts = split.splitCell(cell);
    final pairs = <String>[];
    for (var i = 0; i < split.newColumns.length; i++) {
      final name = split.newColumns[i];
      if (name.isEmpty) continue;
      pairs.add('$name="${parts[i]}"');
    }
    if (pairs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${s.splitPreviewLabel}: ${pairs.join('  ·  ')}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
      ),
    );
  }

  // ── Row filters ────────────────────────────────────────────────

  Widget _buildRowFiltersSection(AppStrings s, List<String> columns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.rowFilters, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (_transforms.filters.length > 1)
              SegmentedButton<FilterCombine>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(
                    value: FilterCombine.all,
                    label: Text(s.matchAll, style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: FilterCombine.any,
                    label: Text(s.matchAny, style: const TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_transforms.combine},
                onSelectionChanged: (sel) => _updateTransforms(combine: sel.first),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.addFilter),
              onPressed: columns.isEmpty
                  ? null
                  : () => _updateTransforms(
                      filters: [
                        ..._transforms.filters,
                        RowFilter(column: columns.first, op: FilterOp.contains, value: ''),
                      ],
                    ),
            ),
          ],
        ),
        Text(s.rowFiltersHelp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        for (var i = 0; i < _transforms.filters.length; i++) _buildFilterRow(s, columns, i),
      ],
    );
  }

  Widget _buildFilterRow(AppStrings s, List<String> columns, int index) {
    final filter = _transforms.filters[index];

    void replace(RowFilter next) {
      final list = [..._transforms.filters];
      list[index] = next;
      _updateTransforms(filters: list);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: columns.contains(filter.column) ? filter.column : null,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: columns
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => v == null ? null : replace(RowFilter(column: v, op: filter.op, value: filter.value)),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<FilterOp>(
              isExpanded: true,
              initialValue: filter.op,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: FilterOp.values
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(_filterOpLabel(s, o), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => v == null ? null : replace(RowFilter(column: filter.column, op: v, value: filter.value)),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: filter.value,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => replace(RowFilter(column: filter.column, op: filter.op, value: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              final list = [..._transforms.filters]..removeAt(index);
              _updateTransforms(filters: list);
            },
          ),
        ],
      ),
    );
  }
}
