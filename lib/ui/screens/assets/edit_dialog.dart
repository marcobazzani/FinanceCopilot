part of 'asset_detail_screen.dart';

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

  /// The stored tax-rate override as the percentage the field is pre-filled
  /// with; null without an override. A percentage left alone keeps the
  /// stored rate as it is.
  late final double? _storedTaxPercent;
  late AssetType _assetType;
  late ValuationMethod _valuationMethod;
  late int _intermediaryId;
  late bool _includeInSavings;

  // TER / tax rate text the locale could not read at the last save: flagged
  // on the field until edited, and nothing was saved.
  bool _terInvalid = false;
  bool _taxRateInvalid = false;

  /// Cached app locale used for formatting initial values and parsing
  /// what the user types. Captured once in [initState] so a setState
  /// rebuild can't shift the format under us mid-edit.
  late final String _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.ref.read(appLocaleProvider).value ?? Platform.localeName;
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _tickerCtrl = TextEditingController(text: widget.asset.ticker ?? '');
    _isinCtrl = TextEditingController(text: widget.asset.isin ?? '');
    // Every digit of the stored TER: a TER the user leaves alone saves
    // unchanged (0.1234, not the three-decimal display's 0.123).
    final ter = widget.asset.ter;
    _terCtrl = TextEditingController(text: ter == null ? '' : fmt.editableFigure(ter, NumberFormat.decimalPattern(_locale), locale: _locale));
    _selectedExchange = widget.asset.exchange ?? 'Milan';
    _isActive = widget.asset.isActive;
    _instrumentType = widget.asset.instrumentType;
    _assetClass = widget.asset.assetClass;

    _currencyCtrl = TextEditingController(text: widget.asset.currency);
    // taxRate is stored as a fraction (0.26 = 26%). The field/label say
    // "(%)" so we pre-fill and accept the percentage value (26), and
    // convert on save. The percentage drops the product's float noise
    // (0.29 × 100 is 28.999999999999996) and is pre-filled with every digit
    // it has (fmt.editableFigure): 0.123456 shows as 12,3456, not rounded to
    // 12,346.
    final taxRate = widget.asset.taxRate;
    final taxPercent = taxRate == null ? null : stripFloatNoise(taxRate * 100);
    _storedTaxPercent = taxPercent;
    _taxRateCtrl = TextEditingController(
      text: taxPercent == null ? '' : fmt.editableFigure(taxPercent, NumberFormat.decimalPattern(_locale), locale: _locale),
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
    final ter = fmt.readOptionalNumber(_terCtrl.text, locale: _locale);
    // User types percent (26) — store fraction (0.26).
    final taxPercent = fmt.readOptionalNumber(_taxRateCtrl.text, locale: _locale);
    final taxRateInvalid = _unlocked && taxPercent.invalid;
    if (ter.invalid || taxRateInvalid) {
      setState(() {
        _terInvalid = ter.invalid;
        _taxRateInvalid = taxRateInvalid;
      });
      return;
    }
    _log.info('saving asset id=${widget.asset.id}, name=$name, unlocked=$_unlocked');
    final companion = AssetsCompanion(
      name: Value(name),
      ticker: Value(ticker.isNotEmpty ? ticker : null),
      isin: Value(isin.isNotEmpty ? isin : null),
      exchange: Value(_selectedExchange),
      isActive: Value(_isActive),
      instrumentType: Value(_instrumentType),
      assetClass: Value(_assetClass),
      ter: Value(ter.value),
      updatedAt: Value(DateTime.now()),
      // Advanced fields write only when the user explicitly unlocked the
      // dialog. This keeps the locked path byte-identical to the original
      // behavior and lets the pinning test stay untouched.
      assetType: _unlocked ? Value(_assetType) : const Value.absent(),
      // valuationMethod is auto-managed by revalue add/remove — never written
      // from the edit dialog (it's shown read-only).
      valuationMethod: const Value.absent(),
      intermediaryId: _unlocked ? Value(_intermediaryId) : const Value.absent(),
      currency: _unlocked
          ? Value(_currencyCtrl.text.trim().toUpperCase().isEmpty ? widget.asset.currency : _currencyCtrl.text.trim().toUpperCase())
          : const Value.absent(),
      // An override left alone is not rewritten from its percentage.
      taxRate: _unlocked && taxPercent.value != _storedTaxPercent
          ? Value(taxPercent.value == null ? null : taxPercent.value! / 100)
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
              Builder(
                builder: (_) {
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
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<InstrumentType>(
                    initialValue: _instrumentType,
                    decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                    items: InstrumentType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13)),
                          ),
                        )
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
            assetTerField(
              s,
              controller: _terCtrl,
              locale: _locale,
              invalid: _terInvalid,
              onEdited: () {
                if (_terInvalid) setState(() => _terInvalid = false);
              },
            ),
            const SizedBox(height: 8),
            assetActiveSwitch(s, value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
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

  // The TER and the Active switch are shown above, locked or not.
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
    valuationMethod: _valuationMethod,
    intermediary: (id: _intermediaryId, onChanged: (v) => setState(() => _intermediaryId = v)),
  );

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.searchAssetTitle),
      // Width is owned by AssetSearchSection: AlertDialog measures its
      // content intrinsically, so the section imposes a tight width.
      content: AssetSearchSection(
        widgetRef: widget.ref,
        onSelect: _selectResult,
        recoveryDefaultExchange: widget.asset.exchange ?? 'Milan',
        recoveryCacheKeyBuilder: (q) => widget.asset.isin?.isNotEmpty == true
            ? widget.asset.isin!
            : (widget.asset.ticker?.isNotEmpty == true ? widget.asset.ticker! : q.toUpperCase()),
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

/// The TER field of the asset Create and Edit dialogs: a percentage, hinted
/// in [locale]'s spelling ("0,22" in it_IT, "0.22" in en_US) — what the
/// parser accepts. [onEdited] runs on every edit (clearing an [invalid] flag).
Widget assetTerField(
  AppStrings s, {
  required TextEditingController controller,
  required String locale,
  required bool invalid,
  required VoidCallback onEdited,
}) => TextField(
  controller: controller,
  decoration: InputDecoration(
    labelText: '${s.healthTer} (%)',
    hintText: NumberFormat.decimalPattern(locale).format(0.22),
    isDense: true,
    errorText: invalid ? s.invalidNumber : null,
  ),
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  onChanged: (_) => onEdited(),
);

/// The Active switch of the asset Create and Edit dialogs.
Widget assetActiveSwitch(AppStrings s, {required bool value, required ValueChanged<bool> onChanged}) => SwitchListTile(
  title: Text(s.active),
  value: value,
  onChanged: onChanged,
  contentPadding: EdgeInsets.zero,
);

/// The unlock-only (advanced) header attributes of the asset Create and Edit
/// dialogs, in their order. Composition (geographic / sector / asset class
/// breakdown) is edited on the Composition panel of the asset detail screen.
///
/// Each dialog states the optional parts it renders; one left null is not
/// rendered:
/// - [valuationMethod], read-only, and the [intermediary] picker: Edit only
///   (Create starts every asset market-priced and picks the intermediary up
///   front);
/// - [ter] and [active]: Create only (Edit shows them locked or not).
///
/// [onTaxRateEdited] runs on every edit of the tax rate (clearing a
/// [taxRateInvalid] flag).
List<Widget> assetAdvancedFields(
  AppStrings s, {
  required AssetType assetType,
  required ValueChanged<AssetType> onAssetType,
  required TextEditingController currencyCtrl,
  required TextEditingController taxRateCtrl,
  required bool taxRateInvalid,
  required VoidCallback onTaxRateEdited,
  required bool includeInSavings,
  required ValueChanged<bool> onIncludeInSavings,
  ValuationMethod? valuationMethod,
  ({int id, ValueChanged<int> onChanged})? intermediary,
  ({TextEditingController controller, String locale, bool invalid, VoidCallback onEdited})? ter,
  ({bool value, ValueChanged<bool> onChanged})? active,
}) => [
  const Divider(height: 24),
  DropdownButtonFormField<AssetType>(
    initialValue: assetType,
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
      if (v != null) onAssetType(v);
    },
  ),
  const SizedBox(height: 12),
  if (valuationMethod != null) ...[
    // Valuation method is auto-managed (read-only): it flips to
    // "Event-driven (manual)" when the asset has a revalue and back to
    // "Market price" when the last revalue is removed. Shown for clarity,
    // not editable.
    InputDecorator(
      decoration: InputDecoration(
        labelText: s.valuationMethodFieldLabel,
        isDense: true,
        helperText: s.valuationMethodAutoHelp,
        helperMaxLines: 2,
        suffixIcon: const Icon(Icons.lock_outline, size: 16),
      ),
      child: Text(s.valuationMethodLabel(valuationMethod), style: const TextStyle(fontSize: 13)),
    ),
    const SizedBox(height: 12),
  ],
  if (intermediary != null) ...[
    // Watched by the dialog itself, not through the screen's ref: a change
    // to the list must rebuild this picker.
    Consumer(
      builder: (context, ref, _) {
        final intermediaries = ref.watch(intermediariesProvider).value ?? const <Intermediary>[];
        if (intermediaries.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<int>(
          initialValue: intermediaries.any((i) => i.id == intermediary.id) ? intermediary.id : intermediaries.first.id,
          decoration: InputDecoration(labelText: s.intermediary, isDense: true),
          items: intermediaries
              .map(
                (i) => DropdownMenuItem(
                  value: i.id,
                  child: Text(i.name, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) intermediary.onChanged(v);
          },
        );
      },
    ),
    const SizedBox(height: 12),
  ],
  TextField(
    controller: currencyCtrl,
    decoration: InputDecoration(
      labelText: s.currencyFieldLabel,
      isDense: true,
      counterText: '',
    ),
    textCapitalization: TextCapitalization.characters,
    maxLength: 3,
  ),
  const SizedBox(height: 12),
  if (ter != null) ...[
    assetTerField(s, controller: ter.controller, locale: ter.locale, invalid: ter.invalid, onEdited: ter.onEdited),
    const SizedBox(height: 12),
  ],
  TextField(
    controller: taxRateCtrl,
    decoration: InputDecoration(
      labelText: s.taxRateOverrideLabel,
      // The field takes the percentage, as its (%) label says: 26 is stored
      // as 0.26.
      hintText: '26',
      isDense: true,
      errorText: taxRateInvalid ? s.invalidNumber : null,
    ),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => onTaxRateEdited(),
  ),
  const SizedBox(height: 8),
  if (active != null) assetActiveSwitch(s, value: active.value, onChanged: active.onChanged),
  SwitchListTile(
    title: Text(s.includeInSavingsLabel),
    value: includeInSavings,
    onChanged: onIncludeInSavings,
    contentPadding: EdgeInsets.zero,
  ),
];
