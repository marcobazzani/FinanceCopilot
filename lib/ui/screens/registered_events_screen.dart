import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'dashboard_screen.dart' show currencySymbol;

class RegisteredEventsScreen extends ConsumerStatefulWidget {
  const RegisteredEventsScreen({super.key});

  @override
  ConsumerState<RegisteredEventsScreen> createState() => _RegisteredEventsScreenState();
}

class _RegisteredEventsScreenState extends ConsumerState<RegisteredEventsScreen> {
  String get _locale => ref.read(appLocaleProvider).valueOrNull ?? 'en_US';
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) return;

    final lines = data.text!.trim().split('\n');
    final service = ref.read(registeredEventServiceProvider);
    var count = 0;

    // Skip header row if it looks like one
    final startIdx = lines.isNotEmpty && _isHeaderRow(lines.first) ? 1 : 0;

    for (var idx = startIdx; idx < lines.length; idx++) {
      final line = lines[idx];
      final parts = line.contains('\t') ? line.split('\t') : line.split(';');
      if (parts.length < 3) continue;

      final date = fmt.parseFlexibleDate(parts[0].trim());
      if (date == null) continue;

      final typeStr = parts[1].trim().toLowerCase();
      final matchedType = RegisteredEventType.values.where((t) => t.name == typeStr);
      if (matchedType.isEmpty) continue;

      final amount = fmt.parseFlexibleNumber(parts[2].trim());
      if (amount == null) continue;

      final description = parts.length > 3 ? parts[3].trim() : '';
      final isPersonal = parts.length > 4 ? parts[4].trim().toLowerCase() != 'false' : true;

      await service.create(
        date: date,
        type: matchedType.first,
        amount: amount,
        description: description,
        isPersonal: isPersonal,
      );
      count++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count > 0 ? 'Pasted $count events' : 'No valid rows found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(registeredEventsProvider);
    final locale = ref.watch(appLocaleProvider).valueOrNull ?? 'en_US';
    final baseCurrency = ref.watch(baseCurrencyProvider).valueOrNull ?? 'EUR';
    final amtFormat = fmt.amountFormat(locale);
    final dateFmt = fmt.shortDateFormat(locale);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _handlePaste();
        }
      },
      child: Scaffold(
        body: eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return const Center(
                child: Text(
                  'No registered events yet.\nAdd entries or paste from Excel (Ctrl/⌘+V).',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final ev = events[i];
                final symbol = currencySymbol(baseCurrency);
                final icon = _iconForType(ev.type.name);
                final color = _colorForType(ev.type.name);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '${amtFormat.format(ev.amount)} $symbol',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: color.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          ev.type.name,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!ev.isPersonal) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.business, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${dateFmt.format(ev.date)}${ev.description.isNotEmpty ? ' · ${ev.description}' : ''}',
                  ),
                  onTap: () => _showEditDialog(context, ev),
                  onLongPress: () => _confirmDelete(context, ev),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'stipendio' => Icons.work,
    'entrata' => Icons.arrow_downward,
    'incasso' => Icons.receipt_long,
    'vendita' => Icons.sell,
    'donazione' => Icons.card_giftcard,
    'rimborso' => Icons.replay,
    _ => Icons.event,
  };

  Color _colorForType(String type) => switch (type) {
    'stipendio' => Colors.green,
    'entrata' => Colors.blue,
    'incasso' => Colors.teal,
    'vendita' => Colors.orange,
    'donazione' => Colors.purple,
    'rimborso' => Colors.amber.shade700,
    _ => Colors.grey,
  };

  Future<void> _showAddDialog(BuildContext context) async {
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(DateTime.now()));
    final amountCtl = TextEditingController();
    final descCtl = TextEditingController();
    var selectedType = RegisteredEventType.stipendio;
    var isPersonal = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Event'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RegisteredEventType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: RegisteredEventType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Personal'),
                  value: isPersonal,
                  onChanged: (v) => setDialogState(() => isPersonal = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result != true) return;

    final date = fmt.parseFlexibleDate(dateCtl.text);
    final amount = double.tryParse(amountCtl.text.replaceAll(',', '.'));
    if (date == null || amount == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date or amount')),
        );
      }
      return;
    }

    await ref.read(registeredEventServiceProvider).create(
      date: date,
      type: selectedType,
      amount: amount,
      description: descCtl.text.trim(),
      isPersonal: isPersonal,
    );
  }

  Future<void> _showEditDialog(BuildContext context, RegisteredEvent ev) async {
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(ev.date));
    final amountCtl = TextEditingController(text: ev.amount.toString());
    final descCtl = TextEditingController(text: ev.description);
    var selectedType = ev.type;
    var isPersonal = ev.isPersonal;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Event'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: const InputDecoration(labelText: 'Date (dd/MM/yyyy)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RegisteredEventType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: RegisteredEventType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Personal'),
                  value: isPersonal,
                  onChanged: (v) => setDialogState(() => isPersonal = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == 'delete') {
      await _confirmDelete(context, ev);
      return;
    }
    if (result != 'save') return;

    final date = fmt.parseFlexibleDate(dateCtl.text);
    final amount = double.tryParse(amountCtl.text.replaceAll(',', '.'));
    if (date == null || amount == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date or amount')),
        );
      }
      return;
    }

    await ref.read(registeredEventServiceProvider).update(
      ev.id,
      RegisteredEventsCompanion(
        date: Value(date),
        type: Value(selectedType),
        amount: Value(amount),
        description: Value(descCtl.text.trim()),
        isPersonal: Value(isPersonal),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, RegisteredEvent ev) async {
    final amtFormat = fmt.amountFormat(_locale);
    final dateFmt = fmt.shortDateFormat(_locale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete ${ev.type.name} ${amtFormat.format(ev.amount)} from ${dateFmt.format(ev.date)}?'),
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
      await ref.read(registeredEventServiceProvider).delete(ev.id);
    }
  }

  bool _isHeaderRow(String line) {
    final lower = line.toLowerCase();
    return lower.contains('data') && (lower.contains('tipo') || lower.contains('type') || lower.contains('amount'));
  }
}
