import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';
import 'dashboard_screen.dart' show currencySymbol;

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
      ref.read(baseCurrencyProvider).valueOrNull ?? 'EUR';

  bool get _needsConversion => _currency != _baseCurrency;

  /// Compute the base-currency equivalent, or null if not applicable.
  double? get _convertedAmount {
    if (!_needsConversion) return null;
    final amount = double.tryParse(_amountCtrl.text);
    final rate = double.tryParse(_exchangeRateCtrl.text);
    if (amount == null || rate == null || rate == 0) return null;
    return amount / rate;
  }

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    final dateFmt = DateFormat('dd/MM/yyyy');

    _selectedDate = ev?.date ?? DateTime.now();
    _dateCtrl = TextEditingController(text: dateFmt.format(_selectedDate));
    _amountCtrl = TextEditingController(text: ev?.amount.toString() ?? '');
    _quantityCtrl = TextEditingController(text: ev?.quantity?.toString() ?? '');
    _priceCtrl = TextEditingController(text: ev?.price?.toString() ?? '');
    _commissionCtrl = TextEditingController(text: ev?.commission?.toString() ?? '');
    _exchangeRateCtrl = TextEditingController(text: ev?.exchangeRate?.toString() ?? '');
    _notesCtrl = TextEditingController(text: ev?.notes ?? '');
    _eventType = ev?.type ?? EventType.buy;
    _currency = ev?.currency ?? widget.asset.currency;

    _quantityCtrl.addListener(_onFieldChanged);
    _priceCtrl.addListener(_onFieldChanged);
    _amountCtrl.addListener(_onRateOrAmountChanged);
    _exchangeRateCtrl.addListener(_onRateOrAmountChanged);

    // Auto-populate exchange rate for new events
    if (!_isEditing) {
      _fetchExchangeRate();
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

  void _onFieldChanged() {
    if (!_usesQtyPrice) return;
    final qty = double.tryParse(_quantityCtrl.text);
    final price = double.tryParse(_priceCtrl.text);
    if (qty != null && price != null) {
      _amountCtrl.text = (qty * price).toStringAsFixed(2);
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

  @override
  Widget build(BuildContext context) {
    final baseSym = currencySymbol(_baseCurrency);
    final converted = _convertedAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'New Event'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
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
              value: _eventType,
              decoration: const InputDecoration(
                labelText: 'Event Type *',
                border: OutlineInputBorder(),
              ),
              items: EventType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                setState(() => _eventType = v!);
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 12),

            // Date picker
            TextFormField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: 'Date *',
                suffixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _pickDate,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Currency + Exchange Rate row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
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
                          ? 'Rate $_baseCurrency/$_currency'
                          : 'Exchange Rate',
                      border: const OutlineInputBorder(),
                      hintText: _needsConversion ? 'e.g. 1.085000' : 'N/A',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price${_needsConversion ? ' ($_currency)' : ''} *',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
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
                  labelText: 'Total${_needsConversion ? ' ($_currency)' : ''} (auto)',
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
                  labelText: 'Amount${_needsConversion ? ' ($_currency)' : ''} *',
                  border: const OutlineInputBorder(),
                  hintText: '1000.00',
                  suffixText: converted != null
                      ? '≈ ${converted.toStringAsFixed(2)} $baseSym'
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Commission
            TextFormField(
              controller: _commissionCtrl,
              decoration: const InputDecoration(
                labelText: 'Commission',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            // Raw metadata (read-only if imported)
            if (_isEditing && widget.event!.rawMetadata != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Text('Raw Import Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              child: Text(_isEditing ? 'Save Changes' : 'Create Event'),
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
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _fetchExchangeRate();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = _quantityCtrl.text.isNotEmpty ? double.tryParse(_quantityCtrl.text) : null;
    final price = _priceCtrl.text.isNotEmpty ? double.tryParse(_priceCtrl.text) : null;
    final commission = _commissionCtrl.text.isNotEmpty ? double.tryParse(_commissionCtrl.text) : null;
    final exchangeRate = _exchangeRateCtrl.text.isNotEmpty ? double.tryParse(_exchangeRateCtrl.text) : null;

    // For qty×price types, compute amount; otherwise use the text field directly.
    final double amount;
    if (_usesQtyPrice && quantity != null && price != null) {
      amount = quantity * price;
    } else {
      amount = double.parse(_amountCtrl.text);
    }

    final svc = ref.read(assetEventServiceProvider);

    if (_isEditing) {
      _log.info('saving event id=${widget.event!.id}, type=${_eventType.name}, '
          'amount=$amount, currency=$_currency, rate=$exchangeRate');
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
          'amount=$amount, currency=$_currency, rate=$exchangeRate');
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
