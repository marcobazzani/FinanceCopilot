import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers/providers.dart';
import '../../utils/formatters.dart' as fmt;
import '../../utils/logger.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;

final _log = getLogger('AssetEventEditScreen');

/// Event types where amount = quantity × price.
const _qtyPriceTypes = {
  EventType.buy,
  EventType.sell,
  EventType.vest,
  EventType.split,
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
  late TextEditingController _dateCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _exchangeRateCtrl;
  late TextEditingController _notesCtrl;
  late EventType _eventType;
  late DateTime _selectedDate;
  late String _currency;

  bool get _isEditing => widget.event != null;
  bool get _usesQtyPrice => _qtyPriceTypes.contains(_eventType);

  String get _baseCurrency =>
      ref.read(baseCurrencyProvider).value ?? 'EUR';

  bool get _needsConversion => _currency != _baseCurrency;

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

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    final locale = ref.read(appLocaleProvider).value ?? Platform.localeName;
    final dateFmt = fmt.shortDateFormat(locale);

    _selectedDate = ev?.date ?? DateTime.now();
    _dateCtrl = TextEditingController(text: dateFmt.format(_selectedDate));
    _amountCtrl = TextEditingController(text: _fmtNum(ev?.amount));
    _quantityCtrl = TextEditingController(text: _fmtNum(ev?.quantity, decimals: 4));
    _priceCtrl = TextEditingController(text: _fmtNum(ev?.price, decimals: 4));
    _commissionCtrl = TextEditingController(text: _fmtNum(ev?.commission));
    _exchangeRateCtrl = TextEditingController(text: _fmtNum(ev?.exchangeRate, decimals: 4));
    _notesCtrl = TextEditingController(text: ev?.notes ?? '');
    _eventType = ev?.type ?? EventType.buy;
    _currency = ev?.currency ?? widget.asset.currency;

    _quantityCtrl.addListener(_onFieldChanged);
    _priceCtrl.addListener(_onFieldChanged);
    _amountCtrl.addListener(_onRateOrAmountChanged);
    _exchangeRateCtrl.addListener(_onRateOrAmountChanged);

    // Auto-populate exchange rate and asset price for new events
    if (!_isEditing) {
      _fetchExchangeRate();
      _fetchAssetPrice();
    }
  }

  @override
  void dispose() {
    _quantityCtrl.removeListener(_onFieldChanged);
    _priceCtrl.removeListener(_onFieldChanged);
    _amountCtrl.removeListener(_onRateOrAmountChanged);
    _exchangeRateCtrl.removeListener(_onRateOrAmountChanged);
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _commissionCtrl.dispose();
    _exchangeRateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isBond => widget.asset.instrumentType == InstrumentType.bond;

  void _onFieldChanged() {
    if (!_usesQtyPrice) return;
    final qty = fmt.tryParseLocalized(_quantityCtrl.text, locale: locale);
    final price = fmt.tryParseLocalized(_priceCtrl.text, locale: locale);
    if (qty != null && price != null) {
      final raw = qty * price;
      final amount = _isBond ? raw / 100 : raw;
      _log.info('_onFieldChanged: qty=$qty, price=$price, isBond=$_isBond, amount=$amount');
      _amountCtrl.text = _fmtNum(amount);
    }
    // setState triggered by _onRateOrAmountChanged via _amountCtrl listener
  }

  void _onRateOrAmountChanged() {
    // Trigger rebuild so the converted equivalent updates live.
    setState(() {});
  }

  Future<void> _fetchExchangeRate() async {
    if (_currency == _baseCurrency) {
      _exchangeRateCtrl.text = '';
      return;
    }
    final svc = ref.read(exchangeRateServiceProvider);
    final rate = await svc.getRate(_baseCurrency, _currency, _selectedDate);
    if (rate != null && mounted) {
      setState(() {
        _exchangeRateCtrl.text = rate.toStringAsFixed(6);
      });
    }
  }

  Future<void> _fetchAssetPrice() async {
    if (!_usesQtyPrice) return;
    // Only auto-fill if price field is empty or was auto-filled previously
    if (_priceCtrl.text.isNotEmpty && _isEditing) return;

    final priceService = ref.read(marketPriceServiceProvider);
    final price = await priceService.getPrice(widget.asset.id, _selectedDate);
    if (price != null && mounted) {
      setState(() {
        _priceCtrl.text = _fmtNum(price, decimals: 4);
      });
      _onFieldChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final baseSym = currencySymbol(_baseCurrency);
    final converted = _convertedAmount;

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
            // Event type
            DropdownButtonFormField<EventType>(
              initialValue: _eventType,
              decoration: InputDecoration(
                labelText: s.eventTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: EventType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                setState(() => _eventType = v!);
                _onFieldChanged();
                _fetchAssetPrice();
              },
            ),
            const SizedBox(height: 12),

            // Date picker
            TextFormField(
              controller: _dateCtrl,
              decoration: InputDecoration(
                labelText: s.dateRequired,
                suffixIcon: const Icon(Icons.calendar_today),
                border: const OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _pickDate,
              validator: (v) => (v == null || v.isEmpty) ? s.required : null,
            ),
            const SizedBox(height: 12),

            // Currency + Exchange Rate row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: s.currency,
                      border: const OutlineInputBorder(),
                    ),
                    items: ExchangeRateService.allCurrencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _currency = v!);
                      _fetchExchangeRate();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _exchangeRateCtrl,
                    decoration: InputDecoration(
                      labelText: _needsConversion
                          ? s.rateLabel2(_baseCurrency, _currency)
                          : s.exchangeRate,
                      border: const OutlineInputBorder(),
                      hintText: _needsConversion ? s.rateHint : s.notApplicable,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity + Price row (for buy/sell/vest/split)
            if (_usesQtyPrice) ...[
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return s.required;
                        if (fmt.tryParseLocalized(v, locale: locale) == null) return s.invalid;
                        return null;
                      },
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
                      validator: (v) {
                        if (v == null || v.isEmpty) return s.required;
                        if (fmt.tryParseLocalized(v, locale: locale) == null) return s.invalid;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Auto-calculated total (read-only) + converted equivalent
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: s.totalAutoLabel(_needsConversion ? ' ($_currency)' : ''),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  suffixText: converted != null
                      ? '≈ ${converted.toStringAsFixed(2)} $baseSym'
                      : null,
                ),
                readOnly: true,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Direct amount entry for dividend, interest, etc.
              TextFormField(
                controller: _amountCtrl,
                decoration: InputDecoration(
                  labelText: s.amountLabel(_needsConversion ? ' ($_currency)' : ''),
                  border: const OutlineInputBorder(),
                  hintText: '1000.00',
                  suffixText: converted != null
                      ? '≈ ${converted.toStringAsFixed(2)} $baseSym'
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return s.required;
                  if (fmt.tryParseLocalized(v, locale: locale) == null) return s.invalidNumber;
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Commission
            TextFormField(
              controller: _commissionCtrl,
              decoration: InputDecoration(
                labelText: s.commissionLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

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
              const Divider(),
              Text(s.rawImportData, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.event!.rawMetadata!,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? s.saveChanges : s.createEvent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = fmt.shortDateFormat(ref.read(appLocaleProvider).value ?? Platform.localeName).format(picked);
      });
      _fetchExchangeRate();
      _fetchAssetPrice();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = _quantityCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_quantityCtrl.text, locale: locale) : null;
    final price = _priceCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_priceCtrl.text, locale: locale) : null;
    final commission = _commissionCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_commissionCtrl.text, locale: locale) : null;
    final exchangeRate = _exchangeRateCtrl.text.isNotEmpty ? fmt.tryParseLocalized(_exchangeRateCtrl.text, locale: locale) : null;

    // For qty×price types, compute amount; otherwise use the text field directly.
    // Bond prices: user enters quoted price (per 100), we store per-unit and compute amount accordingly.
    final double amount;
    if (_usesQtyPrice && quantity != null && price != null) {
      amount = _isBond ? quantity * price / 100 : quantity * price;
    } else {
      amount = fmt.tryParseLocalized(_amountCtrl.text, locale: locale)!;
    }

    final svc = ref.read(assetEventServiceProvider);

    if (_isEditing) {
      _log.info('saving event id=${widget.event!.id}, type=${_eventType.name}, '
          'currency=$_currency');
      await svc.update(
        widget.event!.id,
        AssetEventsCompanion(
          date: drift.Value(_selectedDate),
          type: drift.Value(_eventType),
          amount: drift.Value(amount),
          quantity: drift.Value(quantity),
          price: drift.Value(price),
          currency: drift.Value(_currency),
          exchangeRate: drift.Value(exchangeRate),
          commission: drift.Value(commission),
          notes: drift.Value(_notesCtrl.text.isNotEmpty ? _notesCtrl.text : null),
        ),
      );
    } else {
      _log.info('creating event for asset=${widget.asset.id}, type=${_eventType.name}, '
          'currency=$_currency');
      await svc.create(
        assetId: widget.asset.id,
        date: _selectedDate,
        type: _eventType,
        amount: amount,
        quantity: quantity,
        price: price,
        currency: _currency,
        exchangeRate: exchangeRate,
        commission: commission,
        notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteEventTitle),
        content: Text(s.cannotBeUndone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _log.warning('deleting event id=${widget.event!.id}');
      await ref.read(assetEventServiceProvider).delete(widget.event!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
