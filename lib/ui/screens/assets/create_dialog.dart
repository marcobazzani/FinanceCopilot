part of 'assets_screen.dart';

class _CreateAssetDialog extends StatefulWidget {
  final WidgetRef ref;
  const _CreateAssetDialog({required this.ref});

  @override
  State<_CreateAssetDialog> createState() => _CreateAssetDialogState();
}

class _CreateAssetDialogState extends State<_CreateAssetDialog> {
  bool _manual = false;
  bool _unlocked = false;

  /// Apply the dialog's shared overrides (ter, taxRate, valuationMethod,
  /// assetType, isActive, includeInSavings — all gated on `_unlocked`)
  /// to a single create call. Caller passes the per-flow fields (name,
  /// intermediary, currency, optional ticker/isin/exchange).
  Future<int> _createAsset({
    required String name,
    required int intermediaryId,
    required String currency,
    String? ticker,
    String? isin,
    String? exchange,
  }) {
    return widget.ref
        .read(assetServiceProvider)
        .create(
          name: name,
          ticker: ticker,
          isin: isin,
          exchange: exchange,
          currency: currency,
          intermediaryId: intermediaryId,
          instrumentType: _instrumentType,
          assetClass: _assetClass,
          valuationMethod: ValuationMethod.marketPrice,
          assetType: _unlocked ? _assetType : AssetType.stockEtf,
          ter: _unlocked ? fmt.tryParseLocalized(_terCtrl.text, locale: _locale) : null,
          taxRate: _unlocked
              ? (() {
                  final v = fmt.tryParseLocalized(_taxRateCtrl.text, locale: _locale);
                  return v == null ? null : v / 100;
                })()
              : null,
          isActive: _unlocked ? _isActive : null,
          includeInSavings: _unlocked ? _includeInSavings : null,
        );
  }

  // Step 1: search state mirrored from AssetSearchSection so step 2 can
  // derive sibling exchange listings and capture the user's typed query
  // (used to persist a pasted ISIN as the asset's price-sync cache key).
  String _typedQuery = '';
  List<ProviderSearchResult> _allResults = const [];

  // Step 2: selected result
  ProviderSearchResult? _selected;
  String? _selectedExchange;

  /// Exchange listings discovered for the same instrument (same description).
  /// Drives the exchange dropdown so users can only pick exchanges where the
  /// instrument actually trades. Each entry has a distinct cid.
  List<ProviderSearchResult> _listings = const [];

  // Manual entry
  final _manualNameCtrl = TextEditingController();
  InstrumentType? _instrumentType;
  AssetClass? _assetClass;
  int? _selectedIntermediaryId;

  // Advanced (unlocked) entry — header attributes only. Composition
  // (geographic / sector / asset class breakdown) is edited inline on the
  // Composition panel of the asset detail screen.
  AssetType _assetType = AssetType.stockEtf;
  final _currencyCtrl = TextEditingController();
  final _terCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  bool _includeInSavings = true;
  bool _isActive = true;

  String get _locale => widget.ref.read(appLocaleProvider).value ?? Platform.localeName;

  @override
  void dispose() {
    _manualNameCtrl.dispose();
    _currencyCtrl.dispose();
    _terCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Widget _buildLockToggle(AppStrings s) => IconButton(
    icon: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline, size: 20),
    tooltip: _unlocked ? s.assetLockEdit : s.assetUnlockEdit,
    onPressed: () => setState(() => _unlocked = !_unlocked),
  );

  List<Widget> _buildAdvancedFields(AppStrings s) {
    return [
      const Divider(height: 24),
      DropdownButtonFormField<AssetType>(
        initialValue: _assetType,
        decoration: InputDecoration(labelText: s.assetTypeFieldLabel, isDense: true),
        items: AssetType.values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(s.assetTypeLabel(t), style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _assetType = v);
        },
      ),
      // Valuation method is auto-managed by revalue add/remove (new assets
      // start market-priced) — no manual control here.
      const SizedBox(height: 12),
      TextField(
        controller: _currencyCtrl,
        decoration: InputDecoration(
          labelText: s.currencyFieldLabel,
          isDense: true,
          counterText: '',
        ),
        textCapitalization: TextCapitalization.characters,
        maxLength: 3,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _terCtrl,
        decoration: InputDecoration(
          labelText: '${s.healthTer} (%)',
          // Locale-aware hint: "0,22" in it_IT, "0.22" in en_US.
          hintText: NumberFormat.decimalPattern(_locale).format(0.22),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _taxRateCtrl,
        decoration: InputDecoration(
          labelText: s.taxRateOverrideLabel,
          // Accepts percentage (26 → stored as 0.26 by create call).
          hintText: '26',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: Text(s.active),
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: Text(s.includeInSavingsLabel),
        value: _includeInSavings,
        onChanged: (v) => setState(() => _includeInSavings = v),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  void _selectResult(ProviderSearchResult result) {
    final (instrument, assetCls) = _classifyFromType(result.type);
    setState(() {
      _selected = result;
      _selectedExchange = result.exchange;
      _instrumentType = instrument;
      _assetClass = assetCls;
      _listings = exchangeListingsFor(_allResults, result);
    });
  }

  /// Derive instrument type + asset class from the provider's typeName.
  /// The `type` field looks like "Stocks - Milano" or "ETFs - Milano".
  static (InstrumentType, AssetClass) _classifyFromType(String type) {
    final prefix = type.toLowerCase().split(' ').first.replaceAll(RegExp(r's$'), '');
    return classifyFromProviderType(prefix);
  }

  static final _kIsinRegex = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');
  static bool _isinShaped(String s) => _kIsinRegex.hasMatch(s.toUpperCase());

  void _backToSearch() {
    setState(() {
      _selected = null;
      _manual = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_manual) return _buildManualDialog();
    if (_selected != null) return _buildConfirmDialog();
    return _buildSearchDialog();
  }

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.newAssetTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AssetSearchSection(
          widgetRef: widget.ref,
          onSelect: _selectResult,
          recoveryDefaultExchange: _selectedExchange ?? 'Milan',
          recoveryCacheKeyBuilder: (q) => _isinShaped(q) ? q.toUpperCase() : q,
          onQueryChanged: (q) => _typedQuery = q,
          onResultsChanged: (rs) => _allResults = rs,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _manual = true),
          child: Text(s.enterManually),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
      ],
    );
  }

  Widget _buildConfirmDialog() {
    final s = widget.ref.read(appStringsProvider);
    final r = _selected!;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(s.createAssetTitle)),
          _buildLockToggle(s),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Text(s.symbolLabel(r.symbol), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text(s.typeLabel(r.type), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            _buildExchangeDropdown(s),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InstrumentType>(
                    initialValue: _instrumentType,
                    decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                    hint: const Text('-', style: TextStyle(fontSize: 13)),
                    items: InstrumentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _instrumentType = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AssetClass>(
                    initialValue: _assetClass,
                    decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                    hint: const Text('-', style: TextStyle(fontSize: 13)),
                    items: AssetClass.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _assetClass = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildIntermediaryPicker(s),
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: _selectedIntermediaryId != null
              ? () async {
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final exchange = _selectedExchange ?? 'Milan';
                  final defaultCurrency = exchangeCurrency[exchange] ?? baseCurrency;
                  final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
                  final currency = (_unlocked && overrideCurrency.length == 3) ? overrideCurrency : defaultCurrency;
                  // If the user searched by an ISIN-shaped string, persist it
                  // so price sync can use it as the cache key (otherwise the
                  // ticker — e.g. a bond's "BE000035160=MI" — is not a valid
                  // search term and price sync silently fails).
                  final typed = _typedQuery.trim().toUpperCase();
                  final isin = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(typed) ? typed : null;
                  await _createAsset(
                    name: r.description,
                    intermediaryId: _selectedIntermediaryId!,
                    currency: currency,
                    ticker: r.symbol.isNotEmpty ? r.symbol : null,
                    isin: isin,
                    exchange: exchange,
                  );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(s.create),
        ),
      ],
    );
  }

  Widget _buildExchangeDropdown(AppStrings s) {
    // Discovered listings drive the dropdown so the user can only pick
    // exchanges where the instrument actually trades. Falls back to the
    // global supportedExchanges list when no listings were discovered.
    final byName = <String, ProviderSearchResult>{};
    for (final l in _listings) {
      if (!isKnownExchange(l.exchange)) continue;
      byName.putIfAbsent(l.exchange, () => l);
    }

    if (byName.isEmpty) {
      final initial = supportedExchanges.contains(_selectedExchange) ? _selectedExchange : supportedExchanges.first;
      return DropdownButtonFormField<String>(
        initialValue: initial,
        decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
        items: supportedExchanges
            .map(
              (name) => DropdownMenuItem(
                value: name,
                child: Text(name, style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _selectedExchange = v);
        },
      );
    }

    if (byName.length == 1) {
      final entry = byName.entries.first;
      return InputDecorator(
        decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
        child: Text(entry.key, style: const TextStyle(fontSize: 13)),
      );
    }

    final initial = byName.containsKey(_selectedExchange) ? _selectedExchange : byName.keys.first;
    return DropdownButtonFormField<String>(
      initialValue: initial,
      decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
      items: byName.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.key, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        final pair = byName[v];
        if (pair == null) return;
        setState(() {
          _selectedExchange = v;
          _selected = pair; // swap to the listing that matches the chosen exchange
        });
      },
    );
  }

  Widget _buildIntermediaryPicker(AppStrings s) {
    final intermediariesAsync = widget.ref.watch(intermediariesProvider);
    final list = intermediariesAsync.value ?? const <Intermediary>[];
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.selectIntermediaryEmpty, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.addIntermediary),
            onPressed: _createIntermediaryInline,
          ),
        ],
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _selectedIntermediaryId,
      decoration: InputDecoration(labelText: s.selectIntermediary, isDense: true),
      items: list
          .map(
            (i) => DropdownMenuItem(
              value: i.id,
              child: Text(i.name, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedIntermediaryId = v);
      },
    );
  }

  Future<void> _createIntermediaryInline() async {
    final s = widget.ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addIntermediary),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: s.intermediaryName),
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty ? () => Navigator.pop(ctx, nameCtrl.text.trim()) : null,
              child: Text(s.create),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    final svc = widget.ref.read(intermediaryServiceProvider);
    final id = await svc.create(name: name);
    if (mounted) setState(() => _selectedIntermediaryId = id);
  }

  Widget _buildManualDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(s.newAssetManualTitle)),
          _buildLockToggle(s),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _manualNameCtrl,
              decoration: InputDecoration(labelText: s.name),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InstrumentType>(
                    initialValue: _instrumentType,
                    decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                    hint: const Text('-', style: TextStyle(fontSize: 13)),
                    items: InstrumentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _instrumentType = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AssetClass>(
                    initialValue: _assetClass,
                    decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                    hint: const Text('-', style: TextStyle(fontSize: 13)),
                    items: AssetClass.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _assetClass = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildIntermediaryPicker(s),
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: (_manualNameCtrl.text.trim().isNotEmpty && _selectedIntermediaryId != null)
              ? () async {
                  final name = _manualNameCtrl.text.trim();
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
                  final currency = (_unlocked && overrideCurrency.length == 3) ? overrideCurrency : baseCurrency;
                  await _createAsset(
                    name: name,
                    intermediaryId: _selectedIntermediaryId!,
                    currency: currency,
                  );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(s.create),
        ),
      ],
    );
  }
}
