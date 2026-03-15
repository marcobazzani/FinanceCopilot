import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers.dart';
import '../../utils/logger.dart';

final _log = getLogger('AssetEventEditScreen');

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
  late TextEditingController _notesCtrl;
  late EventType _eventType;
  late DateTime _selectedDate;

  bool get _isEditing => widget.event != null;

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
    _notesCtrl = TextEditingController(text: ev?.notes ?? '');
    _eventType = ev?.type ?? EventType.buy;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _commissionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              onChanged: (v) => setState(() => _eventType = v!),
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

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                border: OutlineInputBorder(),
                hintText: '1000.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Quantity + Price row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text);
    final quantity = _quantityCtrl.text.isNotEmpty ? double.tryParse(_quantityCtrl.text) : null;
    final price = _priceCtrl.text.isNotEmpty ? double.tryParse(_priceCtrl.text) : null;
    final commission = _commissionCtrl.text.isNotEmpty ? double.tryParse(_commissionCtrl.text) : null;
    final svc = ref.read(assetEventServiceProvider);

    if (_isEditing) {
      _log.info('saving event id=${widget.event!.id}, type=${_eventType.name}, amount=$amount');
      await svc.update(
        widget.event!.id,
        AssetEventsCompanion(
          date: drift.Value(_selectedDate),
          type: drift.Value(_eventType),
          amount: drift.Value(amount),
          quantity: drift.Value(quantity),
          price: drift.Value(price),
          commission: drift.Value(commission),
          notes: drift.Value(_notesCtrl.text.isNotEmpty ? _notesCtrl.text : null),
        ),
      );
    } else {
      _log.info('creating event for asset=${widget.asset.id}, type=${_eventType.name}, amount=$amount');
      await svc.create(
        assetId: widget.asset.id,
        date: _selectedDate,
        type: _eventType,
        amount: amount,
        quantity: quantity,
        price: price,
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
