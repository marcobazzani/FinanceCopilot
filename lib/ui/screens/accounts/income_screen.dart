import 'package:drift/drift.dart' hide Column;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart' show currencySymbol;
import 'package:finance_copilot/ui/screens/import/import_screen.dart';
import 'package:finance_copilot/ui/widgets/mobile_pull_to_refresh.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_action_bar.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';
import 'package:finance_copilot/utils/dialogs.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  String get _locale => ref.read(appLocaleProvider).value ?? Platform.localeName;
  final _focusNode = FocusNode();
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _focusNode.dispose();
    _selection.dispose();
    super.dispose();
  }

  String _typeLabel(AppStrings s, IncomeType type) {
    return switch (type) {
      IncomeType.income => s.incomeTypeIncome,
      IncomeType.refund => s.incomeTypeRefund,
      IncomeType.pensionContribution => s.incomeTypePensionContribution,
    };
  }

  IconData _typeIcon(IncomeType type) {
    return switch (type) {
      IncomeType.income => Icons.payments,
      IncomeType.refund => Icons.replay,
      IncomeType.pensionContribution => Icons.savings,
    };
  }

  Color _typeColor(BuildContext context, IncomeType type) {
    return switch (type) {
      IncomeType.income => Theme.of(context).colorScheme.primaryContainer,
      IncomeType.refund => Colors.orange.shade100,
      IncomeType.pensionContribution => Colors.green.shade100,
    };
  }

  Color _typeIconColor(BuildContext context, IncomeType type) {
    return switch (type) {
      IncomeType.income => Theme.of(context).colorScheme.onPrimaryContainer,
      IncomeType.refund => Colors.orange.shade800,
      IncomeType.pensionContribution => Colors.green.shade800,
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
      final parts = line.contains('\t') ? line.split('\t') : line.split(RegExp(r'[;]'));
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

      final IncomeType type;
      if (typeStr.contains('rimborso') || typeStr.contains('refund')) {
        type = IncomeType.refund;
      } else if (typeStr.contains('previdenza') || typeStr.contains('contributo') || typeStr.contains('pension')) {
        type = IncomeType.pensionContribution;
      } else {
        type = IncomeType.income;
      }

      entries.add(
        IncomesCompanion.insert(
          date: date,
          valueDate: date,
          amount: amount,
          type: Value(type),
          currency: Value(currency),
        ),
      );
    }

    if (entries.isEmpty) {
      if (mounted) {
        final s = ref.read(appStringsProvider);
        showInfoSnack(context, s.noValidRowsClipboard);
      }
      return;
    }

    await ref.read(incomeServiceProvider).bulkCreate(entries);
    if (mounted) {
      final s = ref.read(appStringsProvider);
      showInfoSnack(context, s.pastedIncomeRecords(entries.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final incomesAsync = ref.watch(incomesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final amtFormat = fmt.amountFormat(locale);
    final dateFmt = fmt.shortDateFormat(locale);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyV &&
            (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
          _handlePaste();
        }
      },
      child: ListenableBuilder(
        listenable: _selection,
        builder: (ctx, _) {
          final incomes = incomesAsync.value ?? const <Income>[];
          _selection.setOrderedIds(incomes.map((i) => i.id).toList());
          return Scaffold(
            body: incomesAsync.when(
              data: (incomes) {
                if (incomes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(s.noIncomeYet, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _showAddDialog(context, baseCurrency),
                          icon: const Icon(Icons.add),
                          label: Text(s.addIncomeTitle),
                        ),
                      ],
                    ),
                  );
                }

                return MobilePullToRefresh(
                  child: ListView.separated(
                    itemCount: incomes.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final income = incomes[i];
                      final sym = currencySymbol(income.currency);
                      return SelectableItem<int>(
                        controller: _selection,
                        id: income.id,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _typeColor(context, income.type),
                            child: Icon(
                              _typeIcon(income.type),
                              color: _typeIconColor(context, income.type),
                            ),
                          ),
                          title: PrivacyText(
                            '${amtFormat.format(income.amount)} $sym',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${dateFmt.format(income.valueDate)} · ${_typeLabel(s, income.type)}',
                          ),
                          trailing: Text(income.currency, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          onTap: () => _showEditDialog(context, income),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(s.error(e))),
            ),
            bottomNavigationBar: _selection.active
                ? SelectionActionBar<int>(
                    controller: _selection,
                    visibleIds: incomes.map((i) => i.id).toList(),
                    onDelete: (ids) => ref.read(incomeServiceProvider).deleteMany(ids.toList()),
                  )
                : null,
            floatingActionButton: _selection.active
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'import',
                        tooltip: s.importFromFileTooltip,
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
          );
        },
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
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: InputDecoration(labelText: s.dateFormatHint),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: InputDecoration(labelText: s.amount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IncomeType>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: s.incomeTypeLabel),
                  items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(s, t)))).toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: InputDecoration(labelText: s.currency),
                  items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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

    final confirmed = result == true;
    final date = confirmed ? _tryParseDate(dateCtl.text) : null;
    final amount = confirmed ? fmt.tryParseLocalized(amountCtl.text, locale: ref.read(appLocaleProvider).value ?? Platform.localeName) : null;
    dateCtl.dispose();
    amountCtl.dispose();
    if (!confirmed) return;
    if (date == null || amount == null) {
      if (context.mounted) {
        showInfoSnack(context, s.invalidDateOrAmount);
      }
      return;
    }

    await ref
        .read(incomeServiceProvider)
        .create(
          date: date,
          amount: amount,
          type: type,
          currency: currency,
        );
  }

  Future<void> _showEditDialog(BuildContext context, Income income) async {
    final s = ref.read(appStringsProvider);
    final dateFmt = fmt.shortDateFormat(_locale);
    // Display valueDate per CLAUDE.md convention (canonical "money moved" date).
    final dateCtl = TextEditingController(text: dateFmt.format(income.valueDate));
    final amountCtl = TextEditingController(text: income.amount.toString());
    var currency = income.currency;
    var type = income.type;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.editIncomeTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtl,
                  decoration: InputDecoration(labelText: s.dateFormatHint),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtl,
                  decoration: InputDecoration(labelText: s.amount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.pop(ctx, 'save'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IncomeType>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: s.incomeTypeLabel),
                  items: IncomeType.values.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(s, t)))).toList(),
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: InputDecoration(labelText: s.currency),
                  items: ExchangeRateService.allCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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

    final dateText = dateCtl.text;
    final amountText = amountCtl.text;
    dateCtl.dispose();
    amountCtl.dispose();

    if (result == 'delete') {
      if (context.mounted) {
        await _confirmDelete(context, income);
      }
      return;
    }
    if (result != 'save') return;

    final date = _tryParseDate(dateText);
    final amount = fmt.tryParseLocalized(amountText, locale: ref.read(appLocaleProvider).value ?? Platform.localeName);
    if (date == null || amount == null) {
      if (context.mounted) {
        showInfoSnack(context, s.invalidDateOrAmount);
      }
      return;
    }

    // Update both date and valueDate together — the user only sees one field
    // and editing it should not leave the two columns inconsistent.
    await ref
        .read(incomeServiceProvider)
        .update(
          income.id,
          IncomesCompanion(
            date: Value(date),
            valueDate: Value(date),
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
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteIncomeTitle,
      content: s.deleteIncomeConfirm(amtFormat.format(income.amount), income.currency, dateFmt.format(income.valueDate)),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
      confirmColor: Colors.red,
    );

    if (confirmed) {
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
