import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/portfolio_model_service.dart';
import '../../../services/providers/providers.dart';
import '../../../utils/formatters.dart' as fmt;

class PortfolioModelDialog extends ConsumerStatefulWidget {
  final PortfolioModel? existing;
  final List<PortfolioModelItem> existingItems;

  const PortfolioModelDialog({
    super.key,
    this.existing,
    this.existingItems = const [],
  });

  @override
  ConsumerState<PortfolioModelDialog> createState() => _PortfolioModelDialogState();
}

class _PortfolioModelDialogState extends ConsumerState<PortfolioModelDialog> {
  late final TextEditingController _name;
  final List<_ModelItemControllers> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    if (widget.existingItems.isEmpty) {
      _rows.add(_ModelItemControllers.empty());
    } else {
      for (final item in widget.existingItems) {
        _rows.add(_ModelItemControllers.fromItem(item));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final isEdit = widget.existing != null;
    final locale = ref.watch(appLocaleProvider).value ?? 'en';
    final total = _rows.fold<double>(
      0,
      (sum, row) => sum + (fmt.tryParseLocalized(row.weight.text, locale: locale) ?? 0),
    );
    return AlertDialog(
      title: Text(isEdit ? s.portfolioModelEditTitle : s.portfolioModelCreateTitle),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: s.name),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _rows.length; i++) ...[
                _ModelItemRow(
                  controllers: _rows[i],
                  s: s,
                  onChanged: () => setState(() {}),
                  onRemove: _rows.length == 1
                      ? null
                      : () {
                          setState(() {
                            final removed = _rows.removeAt(i);
                            removed.dispose();
                          });
                        },
                ),
                const SizedBox(height: 8),
              ],
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(s.portfolioModelAddRow),
                onPressed: () => setState(() => _rows.add(_ModelItemControllers.empty())),
              ),
              const SizedBox(height: 8),
              Text(s.portfolioModelWeightTotal(total.toStringAsFixed(2))),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => _save(context, locale),
          child: Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, String locale) async {
    final items = <PortfolioModelInputItem>[];
    for (final row in _rows) {
      final weight = fmt.tryParseLocalized(row.weight.text, locale: locale);
      items.add(
        PortfolioModelInputItem(
          isin: row.isin.text,
          targetWeight: weight ?? -1,
          description: row.description.text,
        ),
      );
    }
    try {
      final service = ref.read(portfolioModelServiceProvider);
      if (widget.existing == null) {
        await service.createCustomModel(name: _name.text, items: items);
      } else {
        await service.updateCustomModel(
          widget.existing!.id,
          name: _name.text,
          items: items,
        );
      }
      if (context.mounted) Navigator.of(context).pop();
    } on PortfolioModelValidationException catch (e) {
      setState(() => _error = e.messages.join('\n'));
    } on PortfolioModelReadOnlyException {
      final s = ref.read(appStringsProvider);
      setState(() => _error = s.portfolioModelReadOnly);
    }
  }
}

class _ModelItemRow extends StatelessWidget {
  final _ModelItemControllers controllers;
  final AppStrings s;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _ModelItemRow({
    required this.controllers,
    required this.s,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: controllers.isin,
            decoration: InputDecoration(labelText: s.portfolioModelIsin),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: controllers.weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s.portfolioModelWeight),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controllers.description,
            decoration: InputDecoration(labelText: s.portfolioModelDescription),
          ),
        ),
        IconButton(
          tooltip: s.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _ModelItemControllers {
  final TextEditingController isin;
  final TextEditingController weight;
  final TextEditingController description;

  _ModelItemControllers({
    required this.isin,
    required this.weight,
    required this.description,
  });

  factory _ModelItemControllers.empty() => _ModelItemControllers(
    isin: TextEditingController(),
    weight: TextEditingController(),
    description: TextEditingController(),
  );

  factory _ModelItemControllers.fromItem(PortfolioModelItem item) => _ModelItemControllers(
    isin: TextEditingController(text: item.isin),
    weight: TextEditingController(text: item.targetWeight.toStringAsFixed(2)),
    description: TextEditingController(text: item.description),
  );

  void dispose() {
    isin.dispose();
    weight.dispose();
    description.dispose();
  }
}
