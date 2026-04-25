part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Chart editor + combine dialogs — user-created charts
// ════════════════════════════════════════════════════

class _ChartEditorResult {
  final String title;
  final List<Map<String, dynamic>> selectedSeries;
  _ChartEditorResult({required this.title, required this.selectedSeries});
}

class _ChartEditorDialog extends ConsumerStatefulWidget {
  final AllSeriesData allData;
  final DashboardChart? existing;

  const _ChartEditorDialog({required this.allData, this.existing});

  @override
  ConsumerState<_ChartEditorDialog> createState() => _ChartEditorDialogState();
}

class _ChartEditorDialogState extends ConsumerState<_ChartEditorDialog> {
  late final TextEditingController _titleCtrl;
  final _selected = <String>{}; // "type:id" keys, any polarity
  final _inverted = <String>{}; // subset of _selected that uses sign = -1

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    if (widget.existing != null) {
      try {
        final configs = (jsonDecode(widget.existing!.seriesJson) as List)
            .cast<Map<String, dynamic>>();
        for (final c in configs) {
          final type = c['type'] as String?;
          final id = c['id'] as int?;
          if (type == null || id == null) continue;
          final key = '$type:$id';
          _selected.add(key);
          final sign = (c['sign'] as num?)?.toInt() ?? 1;
          if (sign == -1) _inverted.add(key);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _toggleKey(String key) => setState(() {
        if (_selected.contains(key)) {
          _selected.remove(key);
          _inverted.remove(key);
        } else {
          _selected.add(key);
        }
      });

  /// Tri-state cycle used for adjustments only: off → positive → negative → off.
  void _cycleSign(String key) => setState(() {
        if (!_selected.contains(key)) {
          _selected.add(key);
        } else if (!_inverted.contains(key)) {
          _inverted.add(key);
        } else {
          _selected.remove(key);
          _inverted.remove(key);
        }
      });

  void _toggleGroup(Set<String> keys) => setState(() {
        if (keys.every(_selected.contains)) {
          _selected.removeAll(keys);
          _inverted.removeAll(keys);
        } else {
          _selected.addAll(keys);
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final d = widget.allData;

    final assetIds = <int>{};
    for (final ser in [...d.assetInvested, ...d.assetMarket, ...d.assetGain]) {
      final parts = ser.key.split(':');
      if (parts.length == 2) {
        final id = int.tryParse(parts[1]);
        if (id != null) assetIds.add(id);
      }
    }

    return AlertDialog(
      title: Text(widget.existing != null ? s.chartEditTitle : s.chartNewTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: s.chartTitleLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              if (d.accounts.isNotEmpty) ...[
                _ChartEditorSectionHeader(
                  label: s.chartSectionAccounts,
                  allSelected:
                      d.accounts.every((s) => _selected.contains(s.key)),
                  s: s,
                  onToggleAll: () =>
                      _toggleGroup(d.accounts.map((s) => s.key).toSet()),
                ),
                for (final ser in d.accounts)
                  CheckboxListTile(
                    dense: true,
                    title:
                        Text(ser.name, style: const TextStyle(fontSize: 13)),
                    value: _selected.contains(ser.key),
                    onChanged: (_) => _toggleKey(ser.key),
                  ),
              ],

              if (assetIds.isNotEmpty) ...[
                _AssetsGrid(
                  allData: d,
                  assetIds: assetIds.toList(),
                  selected: _selected,
                  onToggle: _toggleKey,
                  onToggleGroup: _toggleGroup,
                  s: s,
                ),
              ],

              _EventAdjustmentsGrid(
                label: s.chartSectionOutflowAdj,
                series: d.adjustments,
                valuePrefix: 'adjustment_value',
                eventsPrefix: 'adjustment_events',
                selected: _selected,
                inverted: _inverted,
                onCycle: _cycleSign,
                onToggleGroup: _toggleGroup,
                s: s,
              ),

              _EventAdjustmentsGrid(
                label: s.chartSectionInflowAdj,
                series: d.incomeAdjustments,
                valuePrefix: 'income_adj_value',
                eventsPrefix: 'income_adj_events',
                selected: _selected,
                inverted: _inverted,
                onCycle: _cycleSign,
                onToggleGroup: _toggleGroup,
                s: s,
              ),

              _EventAdjustmentsGrid(
                label: s.chartSectionEphemeralAdj,
                series: d.ephemeralInflows,
                valuePrefix: 'ephemeral_inflow_value',
                eventsPrefix: 'ephemeral_inflow_events',
                selected: _selected,
                inverted: _inverted,
                onCycle: _cycleSign,
                onToggleGroup: _toggleGroup,
                s: s,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty || _titleCtrl.text.trim().isEmpty
              ? null
              : () {
                  final seriesList = _selected.map((key) {
                    final parts = key.split(':');
                    return {
                      'type': parts[0],
                      'id': int.parse(parts[1]),
                      // Only emit `sign` when non-default so legacy consumers
                      // and human-readable JSON stay terse.
                      if (_inverted.contains(key)) 'sign': -1,
                    };
                  }).toList();
                  Navigator.pop(
                    context,
                    _ChartEditorResult(
                      title: _titleCtrl.text.trim(),
                      selectedSeries: seriesList,
                    ),
                  );
                },
          child: Text(s.save),
        ),
      ],
    );
  }
}

/// Compact assets grid: one row per asset, three checkbox columns
/// (Invested / Market / Gain) with tap-to-select-all column headers.
/// Scales down cleanly on mobile because every column has a fixed width
/// and the asset name column flexes.
class _AssetsGrid extends StatelessWidget {
  final AllSeriesData allData;
  final List<int> assetIds;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;
  final AppStrings s;

  const _AssetsGrid({
    required this.allData,
    required this.assetIds,
    required this.selected,
    required this.onToggle,
    required this.onToggleGroup,
    required this.s,
  });

  static const double _colWidth = 64;

  bool _has(int id, String type) {
    final key = '$type:$id';
    final source = switch (type) {
      'asset_invested' => allData.assetInvested,
      'asset_market' => allData.assetMarket,
      'asset_gain' => allData.assetGain,
      _ => const <ChartSeries>[],
    };
    return source.any((ser) => ser.key == key);
  }

  String _name(int id) {
    for (final src in [allData.assetMarket, allData.assetInvested, allData.assetGain]) {
      final hit = src.where((ser) {
        final parts = ser.key.split(':');
        return parts.length == 2 && int.tryParse(parts[1]) == id;
      });
      if (hit.isNotEmpty) return hit.first.name;
    }
    return 'Asset $id';
  }

  Set<String> _columnKeys(String type) => {
        for (final id in assetIds)
          if (_has(id, type)) '$type:$id',
      };

  bool _columnAllSelected(String type) {
    final keys = _columnKeys(type);
    if (keys.isEmpty) return false;
    return keys.every(selected.contains);
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = <String>{
      ..._columnKeys('asset_invested'),
      ..._columnKeys('asset_market'),
      ..._columnKeys('asset_gain'),
    };
    final allSelected = allKeys.isNotEmpty && allKeys.every(selected.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartEditorSectionHeader(
          label: s.chartSectionAssets,
          s: s,
          allSelected: allSelected,
          onToggleAll: () => onToggleGroup(allKeys),
        ),
        // Column header row with per-column select-all.
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4, top: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              _ColumnHeader(
                label: s.chartAssetInvested,
                width: _colWidth,
                allSelected: _columnAllSelected('asset_invested'),
                onTap: () => onToggleGroup(_columnKeys('asset_invested')),
              ),
              _ColumnHeader(
                label: s.chartAssetMarket,
                width: _colWidth,
                allSelected: _columnAllSelected('asset_market'),
                onTap: () => onToggleGroup(_columnKeys('asset_market')),
              ),
              _ColumnHeader(
                label: s.chartAssetGain,
                width: _colWidth,
                allSelected: _columnAllSelected('asset_gain'),
                onTap: () => onToggleGroup(_columnKeys('asset_gain')),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // One row per asset.
        for (final id in assetIds)
          _AssetRow(
            id: id,
            name: _name(id),
            hasInvested: _has(id, 'asset_invested'),
            hasMarket: _has(id, 'asset_market'),
            hasGain: _has(id, 'asset_gain'),
            selected: selected,
            onToggle: onToggle,
            colWidth: _colWidth,
          ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String label;
  final double width;
  final bool allSelected;
  final VoidCallback onTap;

  const _ColumnHeader({
    required this.label,
    required this.width,
    required this.allSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  final int id;
  final String name;
  final bool hasInvested;
  final bool hasMarket;
  final bool hasGain;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final double colWidth;

  const _AssetRow({
    required this.id,
    required this.name,
    required this.hasInvested,
    required this.hasMarket,
    required this.hasGain,
    required this.selected,
    required this.onToggle,
    required this.colWidth,
  });

  Widget _cell(bool present, String key) {
    if (!present) return SizedBox(width: colWidth);
    return SizedBox(
      width: colWidth,
      child: Checkbox(
        value: selected.contains(key),
        onChanged: (_) => onToggle(key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _cell(hasInvested, 'asset_invested:$id'),
          _cell(hasMarket, 'asset_market:$id'),
          _cell(hasGain, 'asset_gain:$id'),
        ],
      ),
    );
  }
}

/// Renders a section for extraordinary events (outflow = Outflow Adjustments,
/// inflow = Inflow Adjustments). Each event gets a row with two tri-state
/// cells — Value (anchor at eventDate) and Events (entries + reimbursements
/// over time). Tap cycles off → + → − → off so each half can be added or
/// subtracted independently.
class _EventAdjustmentsGrid extends StatelessWidget {
  final String label;
  final List<ChartSeries> series;
  final String valuePrefix;
  final String eventsPrefix;
  final Set<String> selected;
  final Set<String> inverted;
  final ValueChanged<String> onCycle;
  final ValueChanged<Set<String>> onToggleGroup;
  final AppStrings s;

  const _EventAdjustmentsGrid({
    required this.label,
    required this.series,
    required this.valuePrefix,
    required this.eventsPrefix,
    required this.selected,
    required this.inverted,
    required this.onCycle,
    required this.onToggleGroup,
    required this.s,
  });

  static const double _colWidth = 72;

  ({int id, String name}) _identify(ChartSeries s) {
    final parts = s.key.split(':');
    final id = parts.length == 2 ? int.tryParse(parts[1]) : null;
    return (id: id ?? -1, name: s.name);
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicate by event id (each event contributes both _value and _events).
    final byId = <int, String>{};
    for (final ser in series) {
      final info = _identify(ser);
      byId.putIfAbsent(info.id, () => info.name);
    }
    if (byId.isEmpty) return const SizedBox.shrink();

    final ids = byId.keys.toList();
    Set<String> colKeys(String prefix) => {for (final id in ids) '$prefix:$id'};
    bool colAll(String prefix) {
      final keys = colKeys(prefix);
      return keys.isNotEmpty && keys.every(selected.contains);
    }

    final allKeys = {...colKeys(valuePrefix), ...colKeys(eventsPrefix)};
    final allOn = allKeys.isNotEmpty && allKeys.every(selected.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartEditorSectionHeader(
          label: label,
          s: s,
          allSelected: allOn,
          onToggleAll: () => onToggleGroup(allKeys),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4, top: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              _ColumnHeader(
                label: s.chartAdjValue,
                width: _colWidth,
                allSelected: colAll(valuePrefix),
                onTap: () => onToggleGroup(colKeys(valuePrefix)),
              ),
              _ColumnHeader(
                label: s.chartAdjEvents,
                width: _colWidth,
                allSelected: colAll(eventsPrefix),
                onTap: () => onToggleGroup(colKeys(eventsPrefix)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    byId[id] ?? 'Event $id',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                _TriStateCell(
                  width: _colWidth,
                  selected: selected.contains('$valuePrefix:$id'),
                  inverted: inverted.contains('$valuePrefix:$id'),
                  onTap: () => onCycle('$valuePrefix:$id'),
                ),
                _TriStateCell(
                  width: _colWidth,
                  selected: selected.contains('$eventsPrefix:$id'),
                  inverted: inverted.contains('$eventsPrefix:$id'),
                  onTap: () => onCycle('$eventsPrefix:$id'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Adjustment cell widget: cycles off → + → − → off on tap. Icon indicates
/// the current state — colored check for positive, red minus-box for
/// negative, blank outline for off.
class _TriStateCell extends StatelessWidget {
  final double width;
  final bool selected;
  final bool inverted;
  final VoidCallback onTap;

  const _TriStateCell({
    required this.width,
    required this.selected,
    required this.inverted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final IconData icon;
    final Color color;
    if (!selected) {
      icon = Icons.check_box_outline_blank;
      color = theme.colorScheme.onSurfaceVariant;
    } else if (!inverted) {
      icon = Icons.check_box;
      color = theme.colorScheme.primary;
    } else {
      icon = Icons.indeterminate_check_box;
      color = theme.colorScheme.error;
    }
    return SizedBox(
      width: width,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 22, color: color),
        onPressed: onTap,
        tooltip: !selected
            ? null
            : (inverted ? '−' : '+'),
      ),
    );
  }
}

class _ChartEditorSectionHeader extends StatelessWidget {
  final String label;
  final bool allSelected;
  final VoidCallback onToggleAll;
  final AppStrings s;

  const _ChartEditorSectionHeader({
    required this.label,
    required this.allSelected,
    required this.onToggleAll,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          TextButton(
            onPressed: onToggleAll,
            child: Text(
              allSelected ? s.chartDeselectAll : s.chartSelectAll,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Combine charts dialog
// ────────────────────────────────────────────────────

class _CombineChartsResult {
  final String title;
  final List<int> selectedChartIds;
  final bool autoAll; // when true, the chart's sourceChartIds is saved as "*"
  _CombineChartsResult({
    required this.title,
    required this.selectedChartIds,
    this.autoAll = false,
  });
}

class _CombineChartsDialog extends ConsumerStatefulWidget {
  final List<DashboardChart> charts; // non-combined, non-widget charts only
  final DashboardChart? existing;

  const _CombineChartsDialog({required this.charts, this.existing});

  @override
  ConsumerState<_CombineChartsDialog> createState() =>
      _CombineChartsDialogState();
}

class _CombineChartsDialogState extends ConsumerState<_CombineChartsDialog> {
  late final TextEditingController _titleCtrl;
  final _selectedIds = <int>{};
  bool _autoAll = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    final src = widget.existing?.sourceChartIds;
    if (src == '*') {
      _autoAll = true;
    } else if (src != null) {
      try {
        final ids = (jsonDecode(src) as List).cast<int>();
        _selectedIds.addAll(ids);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return AlertDialog(
      title: Text(widget.existing != null
          ? s.chartCombineEditTitle
          : s.chartCombineNewTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration:
                    InputDecoration(labelText: s.chartCombineTitleLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                dense: true,
                title: Text(s.chartCombineAutoAll),
                subtitle: Text(s.chartCombineAutoAllHint,
                    style: const TextStyle(fontSize: 11)),
                value: _autoAll,
                onChanged: (v) => setState(() => _autoAll = v ?? false),
              ),
              const Divider(height: 16),
              Text(s.chartCombinePickHint,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _autoAll
                        ? Theme.of(context).disabledColor
                        : null,
                  )),
              const SizedBox(height: 8),
              for (final chart in widget.charts)
                CheckboxListTile(
                  dense: true,
                  enabled: !_autoAll,
                  title: Text(chart.title,
                      style: const TextStyle(fontSize: 13)),
                  value: _autoAll || _selectedIds.contains(chart.id),
                  onChanged: _autoAll
                      ? null
                      : (_) => setState(() {
                            _selectedIds.contains(chart.id)
                                ? _selectedIds.remove(chart.id)
                                : _selectedIds.add(chart.id);
                          }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _titleCtrl.text.trim().isEmpty ||
                  (!_autoAll && _selectedIds.length < 2)
              ? null
              : () => Navigator.pop(
                    context,
                    _CombineChartsResult(
                      title: _titleCtrl.text.trim(),
                      selectedChartIds: _selectedIds.toList(),
                      autoAll: _autoAll,
                    ),
                  ),
          child: Text(s.save),
        ),
      ],
    );
  }
}
