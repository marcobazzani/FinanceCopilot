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
              SegmentedButton<ImportTarget>(
                segments: [
                  ButtonSegment(
                    value: ImportTarget.transaction,
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: Text(s.importTypeTransaction, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: ImportTarget.assetEvent,
                    icon: const Icon(Icons.trending_up, size: 18),
                    label: Text(s.importTypeAssetEvent, style: const TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: ImportTarget.income,
                    icon: const Icon(Icons.payments, size: 18),
                    label: Text(s.importTypeIncome, style: const TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_target},
                showSelectedIcon: false,
                onSelectionChanged: (v) async {
                  _setState(() {
                    _target = v.first;
                    _targetId = null;
                    _isQuickMode = false;
                    _savedConfig = null;
                    _mappings.clear();
                    _amountFormula.clear();
                    for (final f in _requiredFields) {
                      _mappings[f] = null;
                    }
                  });
                  // Income has no per-target key — load its single global
                  // config as soon as the user picks the Income target.
                  if (_target == ImportTarget.income && _preview != null) {
                    await _loadSavedConfig(_preview!.columns);
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
                initialValue: _singleAssetTargetId,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: s.pickAssetForImport,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: manual.isEmpty
                    ? [DropdownMenuItem<int>(value: null, enabled: false, child: Text(s.noAssetsAvailable))]
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
                          await _loadSavedConfig(_preview!.columns);
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
    if (intermediaries.isEmpty) {
      if (mounted) showInfoSnack(context, s.noIntermediariesAvailable);
      return;
    }
    int? pickedIntermediary = _selectedIntermediaryId ?? intermediaries.first.id;
    final baseCurrency = ref.read(baseCurrencyProvider).value ?? 'EUR';
    String currency = baseCurrency;
    if (!mounted) return;

    final nameCtrl = TextEditingController();
    final int? created;
    try {
      created = await showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(s.createEmptyAsset),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(labelText: s.name),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: pickedIntermediary,
                    decoration: InputDecoration(labelText: s.intermediaryName),
                    items: intermediaries.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                    onChanged: (v) => setLocal(() => pickedIntermediary = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: currency,
                    decoration: InputDecoration(labelText: s.currency),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => currency = v.trim().toUpperCase(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
              FilledButton(
                onPressed: (nameCtrl.text.trim().isNotEmpty && pickedIntermediary != null)
                    ? () async {
                        final id = await ref
                            .read(assetServiceProvider)
                            .create(
                              name: nameCtrl.text.trim(),
                              currency: currency.isEmpty ? baseCurrency : currency,
                              // Single-asset import targets are manual by
                              // definition (no feed) — create them event-driven
                              // so they appear in the picker immediately, before
                              // any revalue auto-toggles the flag.
                              valuationMethod: ValuationMethod.eventDriven,
                              instrumentType: InstrumentType.alternative,
                              assetClass: AssetClass.alternative,
                              intermediaryId: pickedIntermediary!,
                            );
                        if (ctx.mounted) Navigator.pop(ctx, id);
                      }
                    : null,
                child: Text(s.create),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
    }

    if (created != null && mounted) {
      _setState(() {
        _singleAssetTargetId = created;
        _selectedIntermediaryId = pickedIntermediary;
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
                    await _loadSavedConfig(_preview!.columns);
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

  /// The mapping UI content (skip rows, column mapping, preview table, Next button).
}
