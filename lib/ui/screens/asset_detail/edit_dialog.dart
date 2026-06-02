part of '../asset_detail_screen.dart';

class _EditAssetDialog extends StatefulWidget {
  final WidgetRef ref;
  final Asset asset;
  const _EditAssetDialog({required this.ref, required this.asset});

  @override
  State<_EditAssetDialog> createState() => _EditAssetDialogState();
}

class _EditAssetDialogState extends State<_EditAssetDialog> {
  bool _searchMode = false;
  bool _unlocked = false;

  // Edit fields (pre-populated from asset)
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tickerCtrl;
  late final TextEditingController _isinCtrl;
  late final TextEditingController _terCtrl;
  late String _selectedExchange;
  late bool _isActive;
  late InstrumentType _instrumentType;
  late AssetClass _assetClass;

  // Advanced (unlock-only) controllers / selections.
  // Header attributes only — composition (geographic / sector / asset-class
  // breakdown) is edited inline on the Composition panel itself, not here.
  // Asset.country / Asset.sector are an internal fallback for assets
  // without composition data and are NOT user concepts; we don't surface
  // them.
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _taxRateCtrl;
  late AssetType _assetType;
  late ValuationMethod _valuationMethod;
  late int _intermediaryId;
  late bool _includeInSavings;

  /// Cached app locale used for formatting initial values and parsing
  /// what the user types. Captured once in [initState] so a setState
  /// rebuild can't shift the format under us mid-edit.
  late final String _locale;

  String _fmtDouble(double? v) =>
      v == null ? '' : NumberFormat.decimalPattern(_locale).format(v);

  @override
  void initState() {
    super.initState();
    _locale = widget.ref.read(appLocaleProvider).value ?? Platform.localeName;
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _tickerCtrl = TextEditingController(text: widget.asset.ticker ?? '');
    _isinCtrl = TextEditingController(text: widget.asset.isin ?? '');
    _terCtrl = TextEditingController(text: _fmtDouble(widget.asset.ter));
    _selectedExchange = widget.asset.exchange ?? 'Milan';
    _isActive = widget.asset.isActive;
    _instrumentType = widget.asset.instrumentType;
    _assetClass = widget.asset.assetClass;

    _currencyCtrl = TextEditingController(text: widget.asset.currency);
    // taxRate is stored as a fraction (0.26 = 26%). The field/label say
    // "(%)" so we pre-fill and accept the percentage value (26), and
    // convert on save.
    _taxRateCtrl = TextEditingController(
      text: _fmtDouble(widget.asset.taxRate == null ? null : widget.asset.taxRate! * 100),
    );
    _assetType = widget.asset.assetType;
    _valuationMethod = widget.asset.valuationMethod;
    _intermediaryId = widget.asset.intermediaryId;
    _includeInSavings = widget.asset.includeInSavings;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tickerCtrl.dispose();
    _isinCtrl.dispose();
    _terCtrl.dispose();
    _currencyCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  void _selectResult(ProviderSearchResult result) {
    setState(() {
      _nameCtrl.text = result.description;
      _tickerCtrl.text = result.symbol;
      _selectedExchange = result.exchange;
      _searchMode = false;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final isin = _isinCtrl.text.trim().toUpperCase();
    final ter = fmt.tryParseLocalized(_terCtrl.text, locale: _locale);
    _log.info('saving asset id=${widget.asset.id}, name=$name, unlocked=$_unlocked');
    final companion = AssetsCompanion(
      name: Value(name),
      ticker: Value(ticker.isNotEmpty ? ticker : null),
      isin: Value(isin.isNotEmpty ? isin : null),
      exchange: Value(_selectedExchange),
      isActive: Value(_isActive),
      instrumentType: Value(_instrumentType),
      assetClass: Value(_assetClass),
      ter: Value(ter),
      updatedAt: Value(DateTime.now()),
      // Advanced fields write only when the user explicitly unlocked the
      // dialog. This keeps the locked path byte-identical to the original
      // behavior and lets the pinning test stay untouched.
      assetType: _unlocked ? Value(_assetType) : const Value.absent(),
      valuationMethod: _unlocked ? Value(_valuationMethod) : const Value.absent(),
      intermediaryId: _unlocked ? Value(_intermediaryId) : const Value.absent(),
      currency: _unlocked
          ? Value(_currencyCtrl.text.trim().toUpperCase().isEmpty
              ? widget.asset.currency
              : _currencyCtrl.text.trim().toUpperCase())
          : const Value.absent(),
      taxRate: _unlocked
          ? Value(() {
              // User types percent (26) — store fraction (0.26).
              final v = fmt.tryParseLocalized(_taxRateCtrl.text, locale: _locale);
              return v == null ? null : v / 100;
            }())
          : const Value.absent(),
      includeInSavings: _unlocked ? Value(_includeInSavings) : const Value.absent(),
    );
    await widget.ref.read(assetServiceProvider).update(widget.asset.id, companion);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_searchMode) return _buildSearchDialog();
    return _buildEditDialog();
  }

  Widget _buildEditDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(s.editAssetTitle)),
          IconButton(
            icon: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline, size: 20),
            tooltip: _unlocked ? s.assetLockEdit : s.assetUnlockEdit,
            onPressed: () => setState(() => _unlocked = !_unlocked),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.name),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (widget.asset.valuationMethod != ValuationMethod.eventDriven) ...[
              TextField(
                controller: _tickerCtrl,
                decoration: InputDecoration(
                  labelText: s.tickerLabel,
                  hintText: s.tickerHint,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _isinCtrl,
                decoration: InputDecoration(
                  labelText: s.isinLabel,
                  hintText: s.optional,
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
            ],
            if (widget.asset.valuationMethod != ValuationMethod.eventDriven)
              Builder(builder: (_) {
                // Defensive: if the asset's stored exchange isn't one of the
                // canonical names (legacy code, provider variant, future
                // additions), include it as an extra option so the dropdown
                // can still render and the user can re-pick a canonical one.
                final values = {...supportedExchanges, _selectedExchange};
                return DropdownButtonFormField<String>(
                  initialValue: _selectedExchange,
                  decoration: InputDecoration(
                    labelText: s.stockExchange,
                    isDense: true,
                  ),
                  items: values
                      .map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedExchange = v);
                  },
                );
              }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InstrumentType>(
                    initialValue: _instrumentType,
                    decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                    items: InstrumentType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                        _instrumentType = v;
                        _assetClass = defaultAssetClassFor(v);
                      });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AssetClass>(
                    initialValue: _assetClass,
                    decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                    items: AssetClass.values
                        .map((c) => DropdownMenuItem(value: c, child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _assetClass = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _terCtrl,
              decoration: InputDecoration(
                labelText: '${s.healthTer} (%)',
                // Hint formatted in the user's locale: "0,22" in it_IT,
                // "0.22" in en_US. Matches what the parser accepts.
                hintText: _fmtDouble(0.22),
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
            if (_unlocked) ..._buildAdvancedFields(s),
          ],
        ),
      ),
      actions: [
        if (widget.asset.valuationMethod != ValuationMethod.eventDriven)
          TextButton(
            onPressed: () => setState(() => _searchMode = true),
            child: Text(s.search),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _nameCtrl.text.trim().isNotEmpty ? _save : null,
          child: Text(s.save),
        ),
      ],
    );
  }

  List<Widget> _buildAdvancedFields(AppStrings s) {
    final intermediariesAsync = widget.ref.watch(intermediariesProvider);
    final intermediaries = intermediariesAsync.value ?? const <Intermediary>[];
    return [
      const Divider(height: 24),
      DropdownButtonFormField<AssetType>(
        initialValue: _assetType,
        decoration: InputDecoration(labelText: s.assetTypeFieldLabel, isDense: true),
        items: AssetType.values
            .map((t) => DropdownMenuItem(value: t, child: Text(s.assetTypeLabel(t), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _assetType = v);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ValuationMethod>(
        initialValue: _valuationMethod,
        decoration: InputDecoration(labelText: s.valuationMethodFieldLabel, isDense: true),
        items: ValuationMethod.values
            .map((m) => DropdownMenuItem(value: m, child: Text(s.valuationMethodLabel(m), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _valuationMethod = v);
        },
      ),
      const SizedBox(height: 12),
      if (intermediaries.isNotEmpty)
        DropdownButtonFormField<int>(
          initialValue: intermediaries.any((i) => i.id == _intermediaryId)
              ? _intermediaryId
              : intermediaries.first.id,
          decoration: InputDecoration(labelText: s.intermediary, isDense: true),
          items: intermediaries
              .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _intermediaryId = v);
          },
        ),
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
        controller: _taxRateCtrl,
        decoration: InputDecoration(
          labelText: s.taxRateOverrideLabel,
          // Field accepts the percentage directly to match the (%) label.
          // 26 → stored as 0.26 by _save.
          hintText: '26',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: Text(s.includeInSavingsLabel),
        value: _includeInSavings,
        onChanged: (v) => setState(() => _includeInSavings = v),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.searchAssetTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AssetSearchSection(
          widgetRef: widget.ref,
          onSelect: _selectResult,
          recoveryDefaultExchange: widget.asset.exchange ?? 'Milan',
          recoveryCacheKeyBuilder: (q) => widget.asset.isin?.isNotEmpty == true
              ? widget.asset.isin!
              : (widget.asset.ticker?.isNotEmpty == true
                  ? widget.asset.ticker!
                  : q.toUpperCase()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _searchMode = false),
          child: Text(s.back),
        ),
      ],
    );
  }
}
