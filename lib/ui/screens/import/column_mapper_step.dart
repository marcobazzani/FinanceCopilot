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
        // Re-run from stored data: the source is the account itself.
        if (_fromStoredRows)
          Card(
            key: const Key('rerunImportBanner'),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(s.rerunImportFromStored),
              subtitle: Text(s.rerunImportBanner(preview?.totalRows ?? 0)),
            ),
          )
        else
          // Data source toolbar FIRST — pick the file (or paste) up front.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.folder_open),
                label: Text(s.openFile),
                onPressed: _parsing ? null : _pickFile,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste),
                label: Text(s.pasteFromClipboard),
                onPressed: _parsing ? null : _pasteFromClipboard,
              ),
              if (_filePath != null) Chip(label: Text(_filePath!.split('/').last)),
              if (_filePath == null && _preview != null) Chip(label: Text(s.clipboardData)),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(s.importAs, style: const TextStyle(fontWeight: FontWeight.bold)),
              ImportTargetSelector(
                selected: _target,
                onChanged: (target) async {
                  _setState(() {
                    _target = target;
                    _targetId = null;
                    _isQuickMode = false;
                    _savedConfig = null;
                    _mappings.clear();
                    _amountFormula.clear();
                    _seedMappingKeys();
                  });
                  // Income has no per-target key — load its single global
                  // config as soon as the user picks the Income target.
                  if (_target == ImportTarget.income && _preview != null) {
                    await _loadSavedConfig();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Account selector (transactions only, when no preselected account)
        if (_target == ImportTarget.transaction && widget.preselectedAccountId == null) ...[
          _buildInlineAccountSelector(),
          const SizedBox(height: 12),
        ],

        // Asset-event Mode + Group/Single selectors. Picking the single-asset
        // target loads its saved config (and applies it to the already-loaded
        // file when one is present).
        if (_target == ImportTarget.assetEvent) ...[
          _buildAssetModeSelectors(),
          const SizedBox(height: 12),
        ],

        // Body: quick-confirm view OR full mapping UI
        Expanded(
          child: IgnorePointer(
            ignoring: preview == null,
            child: Opacity(
              opacity: preview == null ? 0.4 : 1.0,
              child: _isQuickMode && preview != null ? _buildQuickConfirm(preview) : _buildMappingContent(preview),
            ),
          ),
        ),
      ],
    );
  }

  /// Compact asset picker for `singleAsset` mode. Shown beside the
  /// "Import into single asset" toggle when target = assetEvent.
  ///
  /// Filter: excludes any asset that already has rows in `market_prices`
  /// (i.e. is being priced by the market data provider). The single-asset import path is
  /// for assets the user values themselves through events; assets with an
  /// external feed should use the ISIN-grouped path or simply rely on the
  /// market-price flow without an event-import at all.
  ///
  /// Includes an inline "Create empty asset" affordance so the user can
  /// spin up a fresh import target without leaving the wizard.
  Widget _buildSingleAssetPicker(AppStrings s) {
    final assetsAsync = ref.watch(assetsProvider);
    return assetsAsync.when(
      data: (assets) {
        // Manual assets = event-driven valuation. The market_prices table
        // is NOT a reliable signal here: pension/contribute imports write
        // synthetic close_price snapshots derived from contributions, so
        // a previously-imported pension asset has rows there even though
        // it has no external feed. valuation_method is the source of
        // truth ('eventDriven' vs 'marketPrice').
        final manual = assets.where((a) => a.valuationMethod == ValuationMethod.eventDriven).toList();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                // Long names are ellipsized within the 260 px, not overflowing it.
                isExpanded: true,
                initialValue: _singleAssetTargetId,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: s.pickAssetForImport,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: manual.isEmpty
                    ? [
                        DropdownMenuItem<int>(
                          value: null,
                          enabled: false,
                          child: Text(s.noAssetsAvailable, overflow: TextOverflow.ellipsis),
                        ),
                      ]
                    : manual
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                onChanged: manual.isEmpty
                    ? null
                    : (v) async {
                        _setState(() {
                          _singleAssetTargetId = v;
                          if (v != null) {
                            final picked = manual.firstWhere((a) => a.id == v);
                            _selectedIntermediaryId = picked.intermediaryId;
                          }
                          _savedConfig = null;
                        });
                        // Load any saved single-asset config for this target.
                        if (v != null && _preview != null) {
                          await _loadSavedConfig();
                        }
                      },
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(s.createEmptyAsset, style: const TextStyle(fontSize: 12)),
              onPressed: _showCreateEmptyAssetDialog,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        );
      },
      loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Inline dialog: create a fresh manual asset without leaving the
  /// import wizard. Minimal fields — name, intermediary, currency. Type
  /// defaults to `alternative` since the picker filters by "no market
  /// data" rather than by instrument type. After insert, auto-selects
  /// the new asset as the import target.
  Future<void> _showCreateEmptyAssetDialog() async {
    final s = ref.read(appStringsProvider);
    final intermediaries = await ref.read(intermediaryServiceProvider).getAll();
    if (!mounted) return;
    if (intermediaries.isEmpty) {
      showInfoSnack(context, s.noIntermediariesAvailable);
      return;
    }
    final created = await showDialog<({int assetId, int intermediaryId})>(
      context: context,
      builder: (_) => _CreateEmptyAssetDialog(
        intermediaries: intermediaries,
        initialIntermediaryId: _selectedIntermediaryId ?? intermediaries.first.id,
      ),
    );

    if (created != null && mounted) {
      _setState(() {
        _singleAssetTargetId = created.assetId;
        _selectedIntermediaryId = created.intermediaryId;
      });
    }
  }

  /// Compact account selector (DropdownButtonFormField) shown above the file picker
  /// when the user is importing transactions without a preselected account.
  Widget _buildInlineAccountSelector() {
    final s = ref.watch(appStringsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return Row(
            children: [
              Expanded(child: Text(s.noAccountsCreate, style: const TextStyle(fontSize: 13))),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showCreateAccountDialog(),
                child: Text(s.createAccount),
              ),
            ],
          );
        }
        return Row(
          children: [
            Text(s.selectAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _targetId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) async {
                  _setState(() {
                    _targetId = v;
                    _isQuickMode = false;
                    _savedConfig = null;
                  });
                  // Reload saved config for the newly chosen account if a file is already loaded.
                  if (v != null && _preview != null) {
                    await _loadSavedConfig();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: s.newAccount,
              onPressed: () => _showCreateAccountDialog(),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 24, child: LinearProgressIndicator()),
      error: (e, _) => Text(s.error(e)),
    );
  }
}

/// Name, intermediary and currency of a new manual asset; creates it and pops
/// its id with the chosen intermediary. The currency is pre-filled with the
/// stored base currency once it has loaded — never with a guess — and Create
/// stays off without one, and while the asset is being created. Owns its text
/// controllers and disposes them only once the dialog is gone: disposing them
/// as soon as the dialog returned broke the closing animation, which still
/// rebuilds the focused field.
class _CreateEmptyAssetDialog extends ConsumerStatefulWidget {
  const _CreateEmptyAssetDialog({required this.intermediaries, required this.initialIntermediaryId});

  final List<Intermediary> intermediaries;
  final int initialIntermediaryId;

  @override
  ConsumerState<_CreateEmptyAssetDialog> createState() => _CreateEmptyAssetDialogState();
}

class _CreateEmptyAssetDialogState extends ConsumerState<_CreateEmptyAssetDialog> {
  final _name = TextEditingController();
  final _currency = TextEditingController();
  late int? _intermediaryId = widget.initialIntermediaryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency.text = ref.read(baseCurrencyProvider).value ?? '';
    // A base currency that loads once the dialog is open fills the field,
    // unless the user already typed one.
    ref.listenManual(baseCurrencyProvider, (_, next) {
      final base = next.value;
      if (base != null && _currency.text.trim().isEmpty) setState(() => _currency.text = base);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _create(int intermediaryId) async {
    final currency = _currency.text.trim().toUpperCase();
    if (_saving || currency.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(assetServiceProvider)
          .create(
            name: _name.text.trim(),
            currency: currency,
            // Single-asset import targets are manual by definition (no feed) —
            // create them event-driven so they appear in the picker immediately,
            // before any revalue auto-toggles the flag.
            valuationMethod: ValuationMethod.eventDriven,
            instrumentType: InstrumentType.alternative,
            assetClass: AssetClass.alternative,
            intermediaryId: intermediaryId,
          );
      if (mounted) Navigator.pop(context, (assetId: id, intermediaryId: intermediaryId));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final intermediaryId = _intermediaryId;
    final canCreate = !_saving && _name.text.trim().isNotEmpty && _currency.text.trim().isNotEmpty && intermediaryId != null;
    return AlertDialog(
      title: Text(s.createEmptyAsset),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: s.name),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _intermediaryId,
              decoration: InputDecoration(labelText: s.intermediaryName),
              items: widget.intermediaries.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
              onChanged: (v) => setState(() => _intermediaryId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currency,
              decoration: InputDecoration(labelText: s.currency),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: canCreate ? () => _create(intermediaryId) : null,
          child: Text(s.create),
        ),
      ],
    );
  }
}
