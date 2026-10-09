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

  /// A create is running: Create is off, and a second tap that lands before
  /// the rebuild creates nothing.
  bool _saving = false;

  /// Apply the dialog's shared overrides (ter, taxRate, valuationMethod,
  /// assetType, isActive, includeInSavings — all gated on `_unlocked`)
  /// to a single create call. Caller passes the per-flow fields (name,
  /// intermediary, currency, optional ticker/isin/exchange).
  ///
  /// False, with nothing created, when an unlocked TER or tax rate is text
  /// the locale cannot read: it is flagged on its field instead. False too
  /// while another create is running.
  Future<bool> _createAsset({
    required String name,
    required int intermediaryId,
    required String currency,
    String? ticker,
    String? isin,
    String? exchange,
  }) async {
    if (_saving) return false;
    final ter = fmt.readOptionalNumber(_terCtrl.text, locale: _locale);
    // Accepts percentage (26 → stored as 0.26).
    final taxPercent = fmt.readOptionalNumber(_taxRateCtrl.text, locale: _locale);
    if (_unlocked && (ter.invalid || taxPercent.invalid)) {
      setState(() {
        _terInvalid = ter.invalid;
        _taxRateInvalid = taxPercent.invalid;
      });
      return false;
    }
    setState(() => _saving = true);
    try {
      await widget.ref
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
            ter: _unlocked ? ter.value : null,
            taxRate: _unlocked && taxPercent.value != null ? taxPercent.value! / 100 : null,
            isActive: _unlocked ? _isActive : null,
            includeInSavings: _unlocked ? _includeInSavings : null,
          );
      return true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  // TER / tax rate text the locale could not read at the last create
  // attempt: flagged on the field until edited, and nothing was created.
  bool _terInvalid = false;
  bool _taxRateInvalid = false;

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

  // A new asset starts market-priced (the valuation method is then
  // auto-managed by revalue add/remove) and its intermediary is picked above;
  // the TER and the Active switch are unlock-only here.
  List<Widget> _buildAdvancedFields(AppStrings s) => assetAdvancedFields(
    s,
    assetType: _assetType,
    onAssetType: (v) => setState(() => _assetType = v),
    currencyCtrl: _currencyCtrl,
    taxRateCtrl: _taxRateCtrl,
    taxRateInvalid: _taxRateInvalid,
    onTaxRateEdited: () {
      if (_taxRateInvalid) setState(() => _taxRateInvalid = false);
    },
    includeInSavings: _includeInSavings,
    onIncludeInSavings: (v) => setState(() => _includeInSavings = v),
    ter: (
      controller: _terCtrl,
      locale: _locale,
      invalid: _terInvalid,
      onEdited: () {
        if (_terInvalid) setState(() => _terInvalid = false);
      },
    ),
    active: (value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
  );

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

  /// Derive instrument type + asset class from the provider's `type` field
  /// (e.g. "Equities", "etf", or the legacy "Stocks - Milano").
  static (InstrumentType, AssetClass) _classifyFromType(String type) => classifyFromProviderType(type);

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
      // Width is owned by AssetSearchSection: AlertDialog measures its
      // content intrinsically, so the section imposes a tight width.
      content: AssetSearchSection(
        widgetRef: widget.ref,
        onSelect: _selectResult,
        recoveryDefaultExchange: _selectedExchange ?? 'Milan',
        recoveryCacheKeyBuilder: isinCacheKey,
        onQueryChanged: (q) => _typedQuery = q,
        onResultsChanged: (rs) => _allResults = rs,
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
            _buildClassificationRow(s),
            const SizedBox(height: 16),
            _buildIntermediaryPicker(s),
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        _buildCreateButton(
          s,
          enabled: _selectedIntermediaryId != null,
          onCreate: (baseCurrency) async {
            final exchange = _selectedExchange ?? 'Milan';
            final defaultCurrency = exchangeCurrency[exchange] ?? baseCurrency;
            final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
            final currency = (_unlocked && overrideCurrency.length == 3) ? overrideCurrency : defaultCurrency;
            // If the user searched by an ISIN-shaped string, persist it
            // so price sync can use it as the cache key (otherwise the
            // ticker — e.g. a bond's "BE000035160=MI" — is not a valid
            // search term and price sync silently fails).
            final typed = _typedQuery.trim().toUpperCase();
            final isin = isIsin(typed) ? typed : null;
            final created = await _createAsset(
              name: r.description,
              intermediaryId: _selectedIntermediaryId!,
              currency: currency,
              ticker: r.symbol.isNotEmpty ? r.symbol : null,
              isin: isin,
              exchange: exchange,
            );
            if (created && mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  /// The Create button of both flows. It hands [onCreate] the stored base
  /// currency, the fallback currency of a new asset: until that has loaded
  /// the button is off, so nothing is created with a guessed one. It is off
  /// while a create runs, too.
  Widget _buildCreateButton(AppStrings s, {required bool enabled, required Future<void> Function(String baseCurrency) onCreate}) {
    // Watched by the dialog itself: the button turns on once it has loaded.
    return Consumer(
      builder: (context, ref, _) {
        final baseCurrency = ref.watch(baseCurrencyProvider).value;
        return FilledButton(
          onPressed: enabled && baseCurrency != null && !_saving ? () => onCreate(baseCurrency) : null,
          child: Text(s.create),
        );
      },
    );
  }

  /// Instrument type + asset class pickers, shared by the search-result and
  /// the manual flow.
  Widget _buildClassificationRow(AppStrings s) {
    return Row(
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
    // Watched by the dialog itself, not through the Assets screen's ref: the
    // list changing (e.g. an intermediary added inline) must rebuild this.
    return Consumer(
      builder: (context, ref, _) {
        final list = ref.watch(intermediariesProvider).value ?? const <Intermediary>[];
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
          initialValue: list.any((i) => i.id == _selectedIntermediaryId) ? _selectedIntermediaryId : null,
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
      },
    );
  }

  /// Adds an intermediary through the app's one intermediary form (which owns
  /// its text field) and selects the intermediary it created.
  Future<void> _createIntermediaryInline() async {
    final created = await showIntermediaryEditDialog(context, widget.ref);
    if (mounted && created != null) setState(() => _selectedIntermediaryId = created);
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
            _buildClassificationRow(s),
            const SizedBox(height: 16),
            _buildIntermediaryPicker(s),
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        _buildCreateButton(
          s,
          enabled: _manualNameCtrl.text.trim().isNotEmpty && _selectedIntermediaryId != null,
          onCreate: (baseCurrency) async {
            final name = _manualNameCtrl.text.trim();
            final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
            final currency = (_unlocked && overrideCurrency.length == 3) ? overrideCurrency : baseCurrency;
            final created = await _createAsset(
              name: name,
              intermediaryId: _selectedIntermediaryId!,
              currency: currency,
            );
            if (created && mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
