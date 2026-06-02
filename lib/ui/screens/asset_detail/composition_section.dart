part of '../asset_detail_screen.dart';

class _CompositionSection extends ConsumerWidget {
  final int assetId;
  const _CompositionSection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compositionsAsync = ref.watch(assetCompositionsProvider);
    final ss = ref.watch(appStringsProvider);
    final entries = compositionsAsync.value?[assetId] ?? const <AssetComposition>[];
    // Panel is always rendered so manual assets (no fetched composition)
    // can still get rows added via the per-section pencil icons. The
    // ExpansionTile collapses to a single line when not expanded so this
    // is cheap visual real-estate even on assets with zero rows.

    // Extract source URL and separate from display data
    String? sourceUrl;
    final byType = <String, List<AssetComposition>>{};
    for (final e in entries) {
      if (e.type == 'source_url') {
        sourceUrl = e.name;
        continue;
      }
      byType.putIfAbsent(e.type, () => []).add(e);
    }

    // Sort each group by weight descending
    for (final list in byType.values) {
      list.sort((a, b) => b.weight.compareTo(a.weight));
    }

    final typeLabels = {
      'assetclass': ss.compositionAssetClass,
      'country': ss.compositionGeographic,
      'sector': ss.compositionSector,
      'holding': ss.compositionTopHoldings,
    };
    const typeOrder = ['assetclass', 'country', 'sector', 'holding'];

    // The label is intentionally generic: per the provider-name policy,
    // we never name external data providers in user-facing UI. The link
    // still resolves to the original source.
    String? sourceLabel;
    if (sourceUrl != null) {
      sourceLabel = ss.sourceLabelGeneric;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(ss.composition, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            // Refresh: wipes rows and re-runs sync to fetch fresh market
            // data. Hidden when there's no data yet — nothing to refresh
            // and the network call would only return rows for assets that
            // a market data provider can identify (typically by ISIN).
            if (entries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: ss.compositionRefreshTooltip,
                onPressed: () => _confirmRefresh(context, ref, ss),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final type in typeOrder) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Text(
                    typeLabels[type] ?? type,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14),
                    tooltip: ss.compositionEditTooltip,
                    onPressed: () => _openEditor(context, ref, type, byType[type] ?? const []),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            if (byType[type]?.isNotEmpty ?? false)
              ...byType[type]!.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(c.name, style: const TextStyle(fontSize: 12)),
                      ),
                      SizedBox(
                        width: 80,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (c.weight / 100).clamp(0, 1),
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${c.weight.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (sourceUrl != null && sourceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(sourceUrl!)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        sourceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    String type,
    List<AssetComposition> existing,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CompositionEditorDialog(
        assetId: assetId,
        type: type,
        initial: [for (final e in existing) CompositionEntry(e.name, e.weight)],
      ),
    );
  }

  Future<void> _confirmRefresh(BuildContext context, WidgetRef ref, AppStrings ss) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ss.compositionRefreshTooltip),
        content: Text(ss.cannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ss.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ss.update),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(compositionServiceProvider).clearAndResync(assetId);
  }
}

// ──────────────────────────────────────────────
// Composition editor dialog — one section at a time
// ──────────────────────────────────────────────

class _CompositionEditorDialog extends ConsumerStatefulWidget {
  final int assetId;
  final String type;
  final List<CompositionEntry> initial;
  const _CompositionEditorDialog({
    required this.assetId,
    required this.type,
    required this.initial,
  });

  @override
  ConsumerState<_CompositionEditorDialog> createState() => _CompositionEditorDialogState();
}

class _CompositionEditorDialogState extends ConsumerState<_CompositionEditorDialog> {
  late final List<TextEditingController> _nameCtrls;
  late final List<TextEditingController> _weightCtrls;
  late final String _locale;

  @override
  void initState() {
    super.initState();
    _locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final fmt = NumberFormat.decimalPattern(_locale);
    _nameCtrls = [
      for (final e in widget.initial) TextEditingController(text: e.name),
    ];
    _weightCtrls = [
      for (final e in widget.initial) TextEditingController(text: fmt.format(e.weight)),
    ];
    if (_nameCtrls.isEmpty) {
      _nameCtrls.add(TextEditingController());
      _weightCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _weightCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _nameCtrls.add(TextEditingController());
      _weightCtrls.add(TextEditingController());
    });
  }

  void _deleteRow(int i) {
    setState(() {
      _nameCtrls.removeAt(i).dispose();
      _weightCtrls.removeAt(i).dispose();
    });
  }

  double get _sum {
    double total = 0;
    for (final c in _weightCtrls) {
      total += fmt.tryParseLocalized(c.text, locale: _locale) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    final entries = <CompositionEntry>[];
    for (var i = 0; i < _nameCtrls.length; i++) {
      final name = _nameCtrls[i].text.trim();
      final weight = fmt.tryParseLocalized(_weightCtrls[i].text, locale: _locale);
      if (name.isEmpty || weight == null || weight <= 0) continue;
      entries.add(CompositionEntry(name, weight));
    }
    await ref.read(compositionServiceProvider).setEntries(widget.assetId, widget.type, entries);
    if (mounted) Navigator.pop(context);
  }

  String _typeLabel(AppStrings ss) => switch (widget.type) {
    'assetclass' => ss.compositionAssetClass,
    'country' => ss.compositionGeographic,
    'sector' => ss.compositionSector,
    'holding' => ss.compositionTopHoldings,
    _ => widget.type,
  };

  @override
  Widget build(BuildContext context) {
    final ss = ref.read(appStringsProvider);
    final sum = _sum;
    final sumOk = (sum - 100).abs() < 0.5;
    return AlertDialog(
      title: Text('${ss.compositionEditTooltip} — ${_typeLabel(ss)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _nameCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nameCtrls[i],
                          decoration: InputDecoration(
                            labelText: ss.compositionEntryName,
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _weightCtrls[i],
                          decoration: InputDecoration(
                            labelText: ss.compositionEntryWeight,
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteRow(i),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(ss.compositionAddRow),
                    onPressed: _addRow,
                  ),
                  Text(
                    'Σ ${sum.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: sumOk ? Colors.grey : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!sumOk)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ss.compositionWeightWarning,
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(ss.cancel)),
        FilledButton(onPressed: _save, child: Text(ss.save)),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Edit Asset Dialog — search + manual, like create
// ──────────────────────────────────────────────
