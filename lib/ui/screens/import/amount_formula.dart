part of 'import_screen.dart';

extension _ColumnMapperAmountFormula on _ImportScreenState {
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
      final narrow = MediaQuery.sizeOf(context).width < 500;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: narrow ? 90 : 140),
                  child: Text(
                    s.amountRequired,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: narrow ? 12 : 14),
                  ),
                ),
                _buildAmountModeButtons(columns, currentMode: mode),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: narrow ? 0 : 164, top: 6),
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
      final narrow = MediaQuery.sizeOf(context).width < 500;
      final dropdownRow = Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: narrow ? 90 : 140),
            child: Text(
              s.amountRequired,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: narrow ? 12 : 14),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 16),
          const SizedBox(width: 4),
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
                DropdownMenuItem(
                  value: null,
                  child: Text('— ${ref.watch(appStringsProvider).none} —', style: const TextStyle(color: Colors.grey)),
                ),
                ...columns.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => _setState(() => _mappings['amount'] = v),
            ),
          ),
        ],
      );
      if (narrow) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dropdownRow,
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 106),
                child: _buildAmountModeButtons(columns, currentMode: mode),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: dropdownRow),
            const SizedBox(width: 8),
            _buildAmountModeButtons(columns, currentMode: mode),
          ],
        ),
      );
    }

    // -- Formula mode --
    final narrow = MediaQuery.sizeOf(context).width < 500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: narrow ? 90 : 140),
                child: Text(
                  s.amountRequired,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: narrow ? 12 : 14),
                ),
              ),
              _buildAmountModeButtons(columns, currentMode: mode),
            ],
          ),
          // Formula terms
          for (var i = 0; i < _amountFormula.length; i++)
            Padding(
              padding: EdgeInsets.only(left: narrow ? 0 : 164, top: 4),
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
            padding: EdgeInsets.only(left: narrow ? 0 : 164, top: 6),
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
