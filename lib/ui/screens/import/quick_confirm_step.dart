part of 'import_screen.dart';

// ──────────────────────────────────────────────
// Quick-confirm view (rendered inside step 1 when a saved import config is detected)
// Shows a condensed, read-only summary of the saved mappings + a small header preview
// so the user can verify skipRows is still aligned, then commit with one tap.
// "Let me edit" toggles back into the full column mapper.
// ──────────────────────────────────────────────

extension _QuickConfirmStep on _ImportScreenState {

  Widget _buildQuickConfirm(FilePreview preview) {
    final s = ref.watch(appStringsProvider);

    // Trigger preview computation once when entering quick confirm
    if (_txPreview == null && _assetPreview == null && !_previewing &&
        _target != ImportTarget.income) {
      Future.microtask(() => _computePreview());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved-config banner
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.bookmark, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(s.savedConfigDetected, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Header preview (verify skipRows alignment)
          Text(s.headerPreviewTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.headerPreviewHelp, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          _buildHeaderPreviewTable(preview),
          const SizedBox(height: 16),

          // Mappings summary
          Text(s.mappingsLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          _buildMappingsSummary(),
          const SizedBox(height: 16),

          Text(s.rowCount(preview.totalRows), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),

          // Import preview (balance / asset quantities)
          if (_target != ImportTarget.income)
            _buildImportPreview(),
          const SizedBox(height: 16),

          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: Text(s.letMeEdit),
                onPressed: () => _setState(() => _isQuickMode = false),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(s.importButton),
                onPressed: _executeImport,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Small DataTable showing the first 5 rows of the file (header + sample rows).
  /// Read-only, horizontal scroll, used to verify skipRows is still correct.
  Widget _buildHeaderPreviewTable(FilePreview preview) {
    final cols = preview.columns;
    final rows = preview.rows.take(5).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columnSpacing: 16,
        columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
        rows: rows.map((row) => DataRow(
          cells: cols.map((c) => DataCell(Text(row[c] ?? '', style: const TextStyle(fontSize: 11)))).toList(),
        )).toList(),
      ),
    );
  }

  /// Read-only list of `field ← column` lines (same format as the existing confirm step).
  Widget _buildMappingsSummary() {
    final lines = <String>[];
    for (final entry in _mappings.entries) {
      if (entry.value == null) continue;
      if (entry.key == 'amount' && _amountFormula.isNotEmpty) continue;
      lines.add('${entry.key} ← ${entry.value}');
    }
    if (_amountFormula.isNotEmpty) {
      lines.add('amount ← ${_amountFormula.map((t) => '${t.operator} ${t.sourceColumn}').join(' ').replaceFirst('+ ', '')}');
    }
    if (_balanceDiffColumn != null) {
      lines.add('amount ← Δ $_balanceDiffColumn');
    }
    for (final entry in _multiMappings.entries) {
      lines.add('${entry.key} ← ${entry.value.join(' + ')}');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((l) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          )).toList(),
        ),
      ),
    );
  }
}
