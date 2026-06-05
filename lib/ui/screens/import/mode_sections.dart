part of 'import_screen.dart';

extension _ColumnMapperModeSections on _ImportScreenState {
  Widget _buildBalanceModeSection(FilePreview preview) {
    final s = ref.watch(appStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(s.balancePerRow, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(s.balancePerRowHelp, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        if (_balanceMode == 'column') _buildMappingRow('balanceAfter', preview.columns),

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
                      DropdownMenuItem(
                        value: null,
                        child: Text('— ${s.none} —', style: const TextStyle(color: Colors.grey)),
                      ),
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
              _feeValues.clear();
              _revalueValues.clear();
              _mappings.remove('orderRef');
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
              final isRevalue = _revalueValues.contains(val);
              final isFee = _feeValues.contains(val);
              final isUnmapped = !isBuy && !isSell && !isRevalue && !isFee;
              // Tagging is exclusive: picking one chip clears the others.
              // Fee maintains its orderRef-cleanup invariant.
              void tag(Set<String> target, bool currently) => _setState(() {
                _buyValues.remove(val);
                _sellValues.remove(val);
                _revalueValues.remove(val);
                _feeValues.remove(val);
                if (!currently) target.add(val);
                if (_feeValues.isEmpty) _mappings.remove('orderRef');
              });
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        val,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnmapped ? Colors.red.shade300 : null,
                          fontWeight: isUnmapped ? FontWeight.bold : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ChoiceChip(
                      label: Text(s.buyLabel, style: const TextStyle(fontSize: 11)),
                      selected: isBuy,
                      onSelected: (_) => tag(_buyValues, isBuy),
                      visualDensity: VisualDensity.compact,
                    ),
                    ChoiceChip(
                      label: Text(s.sellLabel, style: const TextStyle(fontSize: 11)),
                      selected: isSell,
                      onSelected: (_) => tag(_sellValues, isSell),
                      visualDensity: VisualDensity.compact,
                    ),
                    ChoiceChip(
                      label: Text(s.revalueLabel, style: const TextStyle(fontSize: 11)),
                      selected: isRevalue,
                      onSelected: (_) => tag(_revalueValues, isRevalue),
                      visualDensity: VisualDensity.compact,
                    ),
                    ChoiceChip(
                      label: Text(s.feeLabel, style: const TextStyle(fontSize: 11)),
                      selected: isFee,
                      onSelected: (_) => tag(_feeValues, isFee),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),
            if (uniqueVals.any(
              (v) => !_buyValues.contains(v) && !_sellValues.contains(v) && !_revalueValues.contains(v) && !_feeValues.contains(v),
            ))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.buySellAllRequired,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                ),
              ),
            // Optional join key for external fee rows. Appears only when at
            // least one Type value is bucketed as Fee. Empty = drop fees.
            if (_feeValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildMappingRow('orderRef', columns),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  s.orderRefHelp,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            // Optional amount source for Revalue rows. Appears only when at
            // least one Type value is bucketed as Revalue. Pension statements
            // keep the position-snapshot value (Saldo) in a different column
            // than per-row contributions (Entrate); a Revalue row's amount is
            // that snapshot. Empty = use the primary amount mapping.
            if (_revalueValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.revalueAmountSource, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: (_revalueAmountColumn != null && columns.contains(_revalueAmountColumn)) ? _revalueAmountColumn : null,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  hint: Text(s.revalueAmountSourceHint, style: const TextStyle(fontSize: 12)),
                  items: [
                    DropdownMenuItem<String>(value: null, child: Text(s.revalueAmountSourceNone, style: const TextStyle(fontSize: 12))),
                    ...columns.map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (v) => _setState(() => _revalueAmountColumn = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  s.revalueAmountSourceHelp,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.signBasedHelp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          // Toggle for cash-flow convention: brokers like Directa export buys
          // with a negative sign (money out). Default keeps the historical
          // "negative = sell" interpretation.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _negativeIsBuy,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => _setState(() => _negativeIsBuy = v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setState(() => _negativeIsBuy = !_negativeIsBuy),
                    child: Text(s.signBasedNegativeIsBuyLabel, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        if (_feeMode == 'column') _buildMappingRow('commission', columns, required: true),
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
      final rate = _tryResolveNumeric('exchangeRate', row);
      if (amount != null && qty != null && price != null && rate != null && rate != 0) {
        final fee = amount.abs() - qty * price / rate;
        results.add(fee.abs().toStringAsFixed(2));
      }
    }
    return results.isEmpty ? 'N/A' : results.join(', ');
  }

  /// Mode switch buttons for the amount field.
}
