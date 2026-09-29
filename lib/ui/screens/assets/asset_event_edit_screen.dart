import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/utils/asset_value_math.dart' show bondPriceDivisor;
import 'package:finance_copilot/utils/dialogs.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/utils/logger.dart';
import 'package:finance_copilot/utils/visualization_clock.dart' show dateOnly, editedDates;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/widgets/edit_form_fields.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/raw_import_data_panel.dart';

final _log = getLogger('AssetEventEditScreen');

/// Event types where amount = quantity × price.
const _qtyPriceTypes = {
  EventType.buy,
  EventType.sell,
};

/// Edit an existing asset event or create a new one.
class AssetEventEditScreen extends ConsumerStatefulWidget {
  final AssetEvent? event; // null = create new
  final Asset asset;

  const AssetEventEditScreen({
    super.key,
    this.event,
    required this.asset,
  });

  @override
  ConsumerState<AssetEventEditScreen> createState() => _AssetEventEditScreenState();
}

class _AssetEventEditScreenState extends ConsumerState<AssetEventEditScreen> {
  String get locale => ref.read(appLocaleProvider).value ?? Platform.localeName;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _exchangeRateCtrl;
  late TextEditingController _notesCtrl;
  late EventType _eventType;
  late DateTime _selectedDate;
  late String _currency;
  bool _saving = false;

  bool get _isEditing => widget.event != null;
  bool get _usesQtyPrice => _qtyPriceTypes.contains(_eventType);
  bool get _isRevalue => _eventType == EventType.revalue;

  /// The stored base currency; null until it has loaded. Nothing is fetched
  /// against, nor saved with, a guessed one: Save stays off meanwhile.
  String? get _baseCurrency => ref.read(baseCurrencyProvider).value;

  bool get _needsConversion {
    final base = _baseCurrency;
    return base != null && _currency != base;
  }

  /// Compute the base-currency equivalent, or null if not applicable.
  double? get _convertedAmount {
    if (!_needsConversion) return null;
    final amount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale);
    final rate = fmt.tryParseLocalized(_exchangeRateCtrl.text, locale: locale);
    if (amount == null || rate == null || rate == 0) return null;
    return amount / rate;
  }

  /// Format a number for display in text fields using the user's locale.
  String _fmtNum(double? value, {int decimals = 2}) {
    if (value == null) return '';
    return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals).format(value);
  }

  /// A stored figure pre-filled as [_fmtNum] spells it, or with every digit
  /// when that would round it ([fmt.editableFigure]): an untouched field then
  /// saves exactly what is stored.
  String _storedNum(double? value, {int decimals = 2}) {
    if (value == null) return '';
    return fmt.editableFigure(
      value,
      NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: decimals),
      locale: locale,
    );
  }

  /// Validator of an optional number field: empty is fine, but a typed value
  /// the locale cannot read is flagged instead of being dropped on save.
  String? _optionalNumber(String? v) =>
      fmt.readOptionalNumber(v ?? '', locale: locale).invalid ? ref.read(appStringsProvider).invalidNumber : null;

  @override
  void initState() {
    super.initState();
    final ev = widget.event;

    // Initialize from valueDate per AGENTS.md (canonical "money moved" date).
    // A new event defaults to today's calendar day, never the clock time (a
    // revalue would materialise its market price at that time).
    _selectedDate = ev?.valueDate ?? dateOnly(DateTime.now());
    _amountCtrl = TextEditingController(text: _storedNum(ev?.amount));
    _quantityCtrl = TextEditingController(text: _storedNum(ev?.quantity, decimals: 4));
    _priceCtrl = TextEditingController(text: _storedNum(ev?.price, decimals: 4));
    _commissionCtrl = TextEditingController(text: _storedNum(ev?.commission));
    _exchangeRateCtrl = TextEditingController(text: _storedNum(ev?.exchangeRate, decimals: 4));
    _notesCtrl = TextEditingController(text: ev?.notes ?? '');
    _eventType = ev?.type ?? EventType.buy;
    _currency = ev?.currency ?? widget.asset.currency;

    _quantityCtrl.addListener(_onFieldChanged);
    _priceCtrl.addListener(_onFieldChanged);
    _amountCtrl.addListener(_onRateOrAmountChanged);
    _exchangeRateCtrl.addListener(_onRateOrAmountChanged);

    // Auto-populate exchange rate and asset price for new events. Neither is
    // awaited: each fills its field when it answers, and drops an answer
    // for inputs the user has changed meanwhile.
    if (!_isEditing) {
      unawaited(_fetchExchangeRate());
      unawaited(_fetchAssetPrice());
      // A base currency that loads (or changes) once the form is open: the
      // rate is looked up against it then.
      ref.listenManual(baseCurrencyProvider, (previous, next) {
        if (next.value != previous?.value) unawaited(_fetchExchangeRate());
      });
    }
  }

  @override
  void dispose() {
    _quantityCtrl.removeListener(_onFieldChanged);
    _priceCtrl.removeListener(_onFieldChanged);
    _amountCtrl.removeListener(_onRateOrAmountChanged);
    _exchangeRateCtrl.removeListener(_onRateOrAmountChanged);
    _amountCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _commissionCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Turns a quoted price into a per-unit money value: a bond is quoted per
  /// 100 of face value.
  double get _priceDivisor => bondPriceDivisor(widget.asset.instrumentType);

  void _onFieldChanged() {
    if (!_usesQtyPrice) return;
    final qty = fmt.tryParseLocalized(_quantityCtrl.text, locale: locale);
    final price = fmt.tryParseLocalized(_priceCtrl.text, locale: locale);
    if (qty != null && price != null) {
      final amount = qty * price / _priceDivisor;
      _log.fine('_onFieldChanged: qty=$qty, price=$price, divisor=$_priceDivisor, amount=$amount');
      _amountCtrl.text = _fmtNum(amount);
    }
    // setState triggered by _onRateOrAmountChanged via _amountCtrl listener
  }

  void _onRateOrAmountChanged() {
    // Trigger rebuild so the converted equivalent updates live.
    setState(() {});
  }

  Future<void> _fetchExchangeRate() async {
    // Captured at request time: the answer is dropped if any of them changed
    // meanwhile, so a rate for another currency or day never lands here.
    final base = _baseCurrency;
    final currency = _currency;
    final date = _selectedDate;
    // Looked up once the base currency has loaded (see initState).
    if (base == null) return;
    if (currency == base) {
      _exchangeRateCtrl.text = '';
      return;
    }
    final svc = ref.read(exchangeRateServiceProvider);
    final rate = await svc.getRate(base, currency, date);
    if (!mounted || currency != _currency || date != _selectedDate || base != _baseCurrency) return;
    if (rate != null) {
      setState(() {
        // The locale's own spelling: the save parses it back with the same locale.
        _exchangeRateCtrl.text = _fmtNum(rate, decimals: 6);
      });
    }
  }

  Future<void> _fetchAssetPrice() async {
    if (!_usesQtyPrice) return;
    // Only auto-fill if price field is empty or was auto-filled previously
    if (_priceCtrl.text.isNotEmpty && _isEditing) return;

    // Captured at request time: an answer for a day the user has since
    // changed (or once the event no longer takes a price) is dropped.
    final date = _selectedDate;
    final priceService = ref.read(marketPriceServiceProvider);
    final price = await priceService.getPrice(widget.asset.id, date);
    if (!mounted || date != _selectedDate || !_usesQtyPrice) return;
    if (price != null) {
      setState(() {
        _priceCtrl.text = _fmtNum(price, decimals: 4);
      });
      _onFieldChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    // Rebuilds once the base currency has loaded, which turns Save on.
    final base = ref.watch(baseCurrencyProvider).value;
    final baseSym = base == null ? '' : currencySymbol(base);
    final converted = _convertedAmount;
    final amountFormat = fmt.amountFormat(locale);
    // The base-currency equivalent of the amount (a position size).
    final convertedText = converted == null ? null : '≈ ${amountFormat.format(converted)} $baseSym';
    // The read-only total, styled as the text of an input.
    final totalStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editEventTitle : s.newEventTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: s.delete,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Event type — show only relevant types.
            // Locked when editing: an event's type defines its semantics
            // (buy/sell = qty×price, revalue = total position value).
            // Switching it in place corrupts the position (stale qty/price
            // get reinterpreted as a revalue amount). To change type, delete
            // and recreate. Passing onChanged=null disables the dropdown.
            DropdownButtonFormField<EventType>(
              initialValue: _eventType,
              decoration: InputDecoration(
                labelText: s.eventTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: const [
                EventType.buy,
                EventType.sell,
                EventType.revalue,
              ].map((t) => DropdownMenuItem(value: t, child: Text(s.eventTypeName(t)))).toList(),
              onChanged: _isEditing
                  ? null
                  : (v) {
                      setState(() => _eventType = v!);
                      _onFieldChanged();
                      // Fills the price when it answers (see initState).
                      if (!_isRevalue) unawaited(_fetchAssetPrice());
                    },
            ),
            const SizedBox(height: 12),

            // Date picker: a new day needs its own FX rate and unit price.
            DateFormField(
              date: _selectedDate,
              onPicked: (picked) {
                setState(() => _selectedDate = picked);
                // Not awaited: each fills its field when it answers, and an
                // answer for a day no longer picked is dropped.
                unawaited(_fetchExchangeRate());
                unawaited(_fetchAssetPrice());
              },
            ),
            const SizedBox(height: 12),

            // Currency + Exchange Rate row (hidden for revalue)
            if (!_isRevalue) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: s.currency,
                        border: const OutlineInputBorder(),
                      ),
                      items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v == null || v == _currency) return;
                        // The rate in the field was quoted for the previous currency.
                        _exchangeRateCtrl.clear();
                        setState(() => _currency = v);
                        // Fills the rate when it answers; an answer for a
                        // currency no longer selected is dropped.
                        unawaited(_fetchExchangeRate());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _exchangeRateCtrl,
                      decoration: InputDecoration(
                        labelText: _needsConversion ? s.rateLabel2(base!, _currency) : s.exchangeRate,
                        border: const OutlineInputBorder(),
                        hintText: _needsConversion ? s.rateHint(_fmtNum(1.085, decimals: 6)) : s.notApplicable,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: _optionalNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Quantity + Price row (for buy/sell/vest/split — not for revalue)
            if (_usesQtyPrice && !_isRevalue) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(
                        labelText: s.quantityLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) => requiredNumberError(v, s, locale: locale),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: s.priceLabel(_needsConversion ? ' ($_currency)' : ''),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) => requiredNumberError(v, s, locale: locale),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Auto-calculated total (read-only) + converted equivalent:
              // derived position sizes, masked in privacy mode.
              InputDecorator(
                decoration: InputDecoration(
                  labelText: s.totalAutoLabel(_needsConversion ? ' ($_currency)' : ''),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  suffix: convertedText == null ? null : PrivacyText(convertedText),
                ),
                baseStyle: totalStyle,
                isEmpty: _amountCtrl.text.isEmpty,
                child: PrivacyText(_amountCtrl.text, style: totalStyle),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Direct amount entry for dividend, interest, revalue, etc.
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: _isRevalue ? s.currentValue : s.amountLabel(_needsConversion ? ' ($_currency)' : ''),
                  border: const OutlineInputBorder(),
                  // An example the locale parser reads back: "1.000,00" in it_IT.
                  hintText: _fmtNum(1000),
                  // The field is typed (left as it is); its converted
                  // equivalent is a derived position size.
                  suffix: convertedText == null ? null : PrivacyText(convertedText),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textInputAction: TextInputAction.next,
                validator: (v) => requiredNumberError(v, s, locale: locale),
              ),
              const SizedBox(height: 12),
            ],

            // Commission (hidden for revalue)
            if (!_isRevalue) ...[
              TextFormField(
                controller: _commissionCtrl,
                decoration: InputDecoration(
                  labelText: s.commissionLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: _optionalNumber,
              ),
              const SizedBox(height: 12),
            ],

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: s.notes,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              maxLines: 3,
            ),

            // Raw metadata (read-only if imported)
            if (_isEditing && widget.event!.rawMetadata != null) ...[
              const SizedBox(height: 16),
              RawImportDataPanel(widget.event!.rawMetadata!),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || base == null ? null : _save,
              child: Text(_isEditing ? s.saveChanges : s.createEvent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    // A second tap while the first save is in flight must not insert twice.
    // The base currency stamps the rate: none is saved against a guessed one.
    final base = _baseCurrency;
    if (_saving || base == null || !_formKey.currentState!.validate()) return;

    final quantity = _quantityCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_quantityCtrl.text, locale: locale) : null;
    final price = _priceCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_priceCtrl.text, locale: locale) : null;
    final commission = _commissionCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_commissionCtrl.text, locale: locale) : null;
    final exchangeRate = _exchangeRateCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_exchangeRateCtrl.text, locale: locale) : null;

    // For qty×price types, compute amount; otherwise use the text field directly.
    // Bond prices: user enters quoted price (per 100), we store per-unit and compute amount accordingly.
    // An edit that leaves quantity and price alone keeps the stored amount:
    // an imported event's amount is what the broker booked, which is not
    // always quantity × price to the last digit.
    final ev = widget.event;
    final double amount;
    if (ev != null && _usesQtyPrice && quantity == ev.quantity && price == ev.price) {
      amount = ev.amount;
    } else if (_usesQtyPrice && quantity != null && price != null) {
      amount = quantity * price / _priceDivisor;
    } else {
      amount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!;
    }

    final svc = ref.read(assetEventServiceProvider);
    setState(() => _saving = true);
    try {
      if (ev != null) {
        // The user sees one date: the value date. The booking date keys the
        // import dedup: see editedDates.
        final dates = editedDates(edited: _selectedDate, valueDate: ev.valueDate, bookingDate: ev.date);
        _log.info(
          'saving event id=${ev.id}, type=${_eventType.name}, '
          'currency=$_currency',
        );
        await svc.update(
          ev.id,
          AssetEventsCompanion(
            date: drift.Value.absentIfNull(dates.bookingDate),
            valueDate: drift.Value.absentIfNull(dates.valueDate),
            type: drift.Value(_eventType),
            amount: drift.Value(amount),
            quantity: drift.Value(quantity),
            price: drift.Value(price),
            currency: drift.Value(_currency),
            exchangeRate: drift.Value(exchangeRate),
            // A rate the user typed is quoted against the base currency shown
            // next to the field: stamp it, so a later base-currency change
            // keeps the value without reusing it for the new base. A rate
            // left alone keeps the base it was quoted against.
            exchangeRateBase: exchangeRate == ev.exchangeRate ? const drift.Value.absent() : drift.Value(exchangeRate == null ? null : base),
            commission: drift.Value(commission),
            notes: drift.Value(_notesCtrl.text.isNotEmpty ? _notesCtrl.text : null),
          ),
        );
      } else {
        _log.info(
          'creating event for asset=${widget.asset.id}, type=${_eventType.name}, '
          'currency=$_currency',
        );
        await svc.create(
          assetId: widget.asset.id,
          date: _selectedDate,
          type: _eventType,
          amount: amount,
          quantity: quantity,
          price: price,
          currency: _currency,
          exchangeRate: exchangeRate,
          exchangeRateBase: base,
          commission: commission,
          notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (await confirmAndDeleteAssetEvent(context, ref, widget.event!) && mounted) Navigator.pop(context);
  }
}

/// Asks, then deletes [event] — the service resyncs its asset's revalue
/// prices — and says whether it did. Behind the edit screen's trashcan and
/// the swipe of the asset's event list.
Future<bool> confirmAndDeleteAssetEvent(BuildContext context, WidgetRef ref, AssetEvent event) async {
  final s = ref.read(appStringsProvider);
  final events = ref.read(assetEventServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.deleteEventTitle,
    content: s.cannotBeUndone,
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    confirmColor: Colors.red,
  );
  if (!confirmed) return false;
  _log.warning('deleting event id=${event.id}');
  await events.delete(event.id);
  return true;
}
