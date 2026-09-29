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

    // The dry run shown below is started when the saved config enables quick
    // mode (_loadSavedConfig), not from here: work started from build would
    // rerun on every rebuild, forever when it fails.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved-config banner
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.bookmark, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.savedConfigDetected, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
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
          if (_target != ImportTarget.income) _buildImportPreview(),
          const SizedBox(height: 16),

          // Action buttons. Import has the same gate as the full Confirm step
          // (_canImport): the mapping check alone says nothing about the
          // import target, and an asset import needs its intermediary. Off
          // while an import runs: a second tap would start another.
          WizardNavBar(
            secondaryIcon: Icons.edit,
            secondaryLabel: s.letMeEdit,
            onSecondary: () => _setState(() => _isQuickMode = false),
            primaryIcon: Icons.check,
            primaryLabel: s.importButton,
            onPrimary: !_importing && _canImport(_target == ImportTarget.assetEvent, _target == ImportTarget.income) ? _executeImport : null,
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
    final positionSize = _positionSizeColumns;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columnSpacing: 16,
        columns: cols
            .map(
              (c) => DataColumn(
                label: Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: cols
                    .map((c) => DataCell(_previewCell(c, row[c] ?? '', style: const TextStyle(fontSize: 11), positionSize: positionSize)))
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  /// The mappings summary card of the quick confirm.
  Widget _buildMappingsSummary() {
    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: _buildMappingLines()),
    );
  }

  /// The `field ← column` lines of the current mappings: the one summary of
  /// both the quick confirm and the confirm step. The value date the import
  /// defaults to is listed too, dimmed, so a forgotten mapping is visible.
  Widget _buildMappingLines() {
    final s = ref.watch(appStringsProvider);
    final amountDerived = _amountFormula.isNotEmpty || _balanceDiffColumn != null;
    final lines = [
      for (final entry in _mappings.entries)
        if (entry.value != null && !(entry.key == 'amount' && amountDerived)) '${entry.key} ← ${entry.value}',
      if (_amountFormula.isNotEmpty) 'amount ← ${_amountFormula.map((t) => '${t.operator} ${t.sourceColumn}').join(' ').replaceFirst('+ ', '')}',
      if (_balanceDiffColumn != null) 'amount ← Δ $_balanceDiffColumn',
      for (final entry in _multiMappings.entries)
        if (entry.value.length > 1) '${entry.key} ← ${entry.value.join(' + ')}',
    ];
    const style = TextStyle(fontSize: 12, fontFamily: 'monospace');
    Widget line(String text, {TextStyle style = style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: style),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines) line(l),
        if (_target == ImportTarget.transaction && _mappings['valueDate'] == null)
          line('valueDate ← ${s.fieldLabel('date')}', style: style.copyWith(color: Theme.of(context).colorScheme.tertiary)),
      ],
    );
  }
}
