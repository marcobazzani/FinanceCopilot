import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/import_service.dart';
import '../../services/providers.dart';
import '../../utils/formatters.dart' as fmt;
import 'dashboard_screen.dart' show currencySymbol;
import 'import_screen.dart';
import '../widgets/privacy_text.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  String get _locale => ref.read(appLocaleProvider).value ?? 'en_US';
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) return;

    final baseCurrency = ref.read(baseCurrencyProvider).value ?? 'EUR';
    final lines = data.text!.trim().split('\n');
    final entries = <IncomesCompanion>[];

    // Skip header row if it looks like one
    final startIdx = lines.isNotEmpty && _isHeaderRow(lines.first) ? 1 : 0;

    for (var idx = startIdx; idx < lines.length; idx++) {
      final line = lines[idx];
      // Support both tab-separated and semicolon-separated
      final parts = line.contains('\t')
          ? line.split('\t')
          : line.split(RegExp(r'[;]'));
      if (parts.length < 2) continue;

      final dateStr = parts[0].trim();
      final amountStr = parts[1].trim();
      final description = parts.length > 2 ? parts[2].trim() : '';
      final currency = parts.length > 3 ? parts[3].trim().toUpperCase() : baseCurrency;

      // Skip rows with empty amount
      if (amountStr.isEmpty) continue;

      final date = _tryParseDate(dateStr);
      if (date == null) continue;

      final amount = _parseItalianNumber(amountStr);
      if (amount == null) continue;

      entries.add(IncomesCompanion.insert(
        date: date,
        amount: amount,
        description: Value(description),
        currency: Value(currency),
      ));
    }

    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid rows found in clipboard')),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).bulkCreate(entries);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pasted ${entries.length} income records')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomesAsync = ref.watch(incomesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
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
        body: incomesAsync.when(
          data: (incomes) {
            if (incomes.isEmpty) {
              return const Center(
                child: Text(
                  'No income records yet.\nAdd entries or paste from Excel (Ctrl/⌘+V).',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              itemCount: incomes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final income = incomes[i];
                final sym = currencySymbol(income.currency);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.payments, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: PrivacyText(
                    '${amtFormat.format(income.amount)} $sym',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dateFmt.format(income.date)}${income.description.isNotEmpty ? ' · ${income.description}' : ''}',
                  ),
                  trailing: Text(income.currency, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  onTap: () => _showEditDialog(context, income),
                  onLongPress: () => _confirmDelete(context, income),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'import',
              tooltip: 'Import from file',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen(preselectedTarget: ImportTarget.income)),
              ),
              child: const Icon(Icons.file_upload),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _showAddDialog(context, baseCurrency),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, String defaultCurrency) async {
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(DateTime.now()));
    final amountCtl = TextEditingController();
    final descCtl = TextEditingController();
    var currency = defaultCurrency;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Income'),
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
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: ExchangeRateService.allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => currency = v!),
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

    final date = _tryParseDate(dateCtl.text);
    final amount = double.tryParse(amountCtl.text.replaceAll(',', '.'));
    if (date == null || amount == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date or amount')),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).create(
      date: date,
      amount: amount,
      description: descCtl.text.trim(),
      currency: currency,
    );
  }

  Future<void> _showEditDialog(BuildContext context, Income income) async {
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(income.date));
    final amountCtl = TextEditingController(text: income.amount.toString());
    final descCtl = TextEditingController(text: income.description);
    var currency = income.currency;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Income'),
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
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: ExchangeRateService.allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => currency = v!),
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
      await _confirmDelete(context, income);
      return;
    }
    if (result != 'save') return;

    final date = _tryParseDate(dateCtl.text);
    final amount = double.tryParse(amountCtl.text.replaceAll(',', '.'));
    if (date == null || amount == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid date or amount')),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).update(
      income.id,
      IncomesCompanion(
        date: Value(date),
        amount: Value(amount),
        description: Value(descCtl.text.trim()),
        currency: Value(currency),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Income income) async {
    final amtFormat = fmt.amountFormat(_locale);
    final dateFmt = fmt.shortDateFormat(_locale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income'),
        content: Text('Delete ${amtFormat.format(income.amount)} ${income.currency} from ${dateFmt.format(income.date)}?'),
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
      await ref.read(incomeServiceProvider).delete(income.id);
    }
  }

  DateTime? _tryParseDate(String text) => fmt.parseFlexibleDate(text);

  double? _parseItalianNumber(String text) => fmt.parseFlexibleNumber(text);

  bool _isHeaderRow(String line) {
    final lower = line.toLowerCase();
    return lower.contains('data') && (lower.contains('stipend') || lower.contains('amount') || lower.contains('tipo'));
  }
}
