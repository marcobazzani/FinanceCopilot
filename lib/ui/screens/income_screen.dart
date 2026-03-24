import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/import_service.dart';
import '../../services/providers.dart';
import '../../l10n/app_strings.dart';
import '../widgets/tour_keys.dart';
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

  String _typeLabel(AppStrings s, IncomeType type) {
    return switch (type) {
      IncomeType.income => s.incomeTypeIncome,
      IncomeType.refund => s.incomeTypeRefund,
    };
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
      final typeStr = parts.length > 2 ? parts[2].trim().toLowerCase() : '';
      final currency = parts.length > 3 ? parts[3].trim().toUpperCase() : baseCurrency;

      // Skip rows with empty amount
      if (amountStr.isEmpty) continue;

      final date = _tryParseDate(dateStr);
      if (date == null) continue;

      final amount = _parseItalianNumber(amountStr);
      if (amount == null) continue;

      final type = typeStr.contains('rimborso') || typeStr.contains('refund')
          ? IncomeType.refund
          : IncomeType.income;

      entries.add(IncomesCompanion.insert(
        date: date,
        amount: amount,
        type: Value(type),
        currency: Value(currency),
      ));
    }

    if (entries.isEmpty) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.noValidRowsClipboard)),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).bulkCreate(entries);
    if (mounted) {
      final s = ref.read(appStringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pastedIncomeRecords(entries.length))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
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
              return Center(
                child: Text(
                  s.noIncomeYet,
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
                final isRefund = income.type == IncomeType.refund;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRefund
                        ? Colors.orange.shade100
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      isRefund ? Icons.replay : Icons.payments,
                      color: isRefund
                          ? Colors.orange.shade800
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: PrivacyText(
                    '${amtFormat.format(income.amount)} $sym',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dateFmt.format(income.date)} · ${_typeLabel(s, income.type)}',
                  ),
                  trailing: Text(income.currency, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  onTap: () => _showEditDialog(context, income),
                  onLongPress: () => _confirmDelete(context, income),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(s.error(e))),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              key: TourKeys.incomeImportFab,
              heroTag: 'import',
              tooltip: s.importFromFileTooltip,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportScreen(
                      preselectedTarget: ImportTarget.income,
                    ),
                  ),
                );
              },
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
    final s = ref.read(appStringsProvider);
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(DateTime.now()));
    final amountCtl = TextEditingController();
    var currency = defaultCurrency;
    var type = IncomeType.income;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addIncomeTitle),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: InputDecoration(labelText: s.dateFormatHint),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: InputDecoration(labelText: s.amount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IncomeType>(
                  value: type,
                  decoration: InputDecoration(labelText: s.incomeTypeLabel),
                  items: IncomeType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(s, t))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: InputDecoration(labelText: s.currency),
                  items: ExchangeRateService.allCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => currency = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.add)),
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
          SnackBar(content: Text(s.invalidDateOrAmount)),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).create(
      date: date,
      amount: amount,
      type: type,
      currency: currency,
    );
  }

  Future<void> _showEditDialog(BuildContext context, Income income) async {
    final s = ref.read(appStringsProvider);
    final dateFmt = fmt.shortDateFormat(_locale);
    final dateCtl = TextEditingController(text: dateFmt.format(income.date));
    final amountCtl = TextEditingController(text: income.amount.toString());
    var currency = income.currency;
    var type = income.type;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.editIncomeTitle),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: InputDecoration(labelText: s.dateFormatHint),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: InputDecoration(labelText: s.amount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IncomeType>(
                  value: type,
                  decoration: InputDecoration(labelText: s.incomeTypeLabel),
                  items: IncomeType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(s, t))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: InputDecoration(labelText: s.currency),
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
                  tooltip: s.delete,
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(s.save)),
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
          SnackBar(content: Text(s.invalidDateOrAmount)),
        );
      }
      return;
    }

    await ref.read(incomeServiceProvider).update(
      income.id,
      IncomesCompanion(
        date: Value(date),
        amount: Value(amount),
        type: Value(type),
        currency: Value(currency),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Income income) async {
    final s = ref.read(appStringsProvider);
    final amtFormat = fmt.amountFormat(_locale);
    final dateFmt = fmt.shortDateFormat(_locale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteIncomeTitle),
        content: Text(s.deleteIncomeConfirm(amtFormat.format(income.amount), income.currency, dateFmt.format(income.date))),
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
