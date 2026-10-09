import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import '../../../services/providers/providers.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import '../../../utils/dialogs.dart';
import '../../../utils/formatters.dart' as fmt;
import '../../widgets/asset_search.dart';

/// Asks, then deletes the custom [model] (its pillar associations are
/// removed); says whether it did. Behind the model dialog's trashcan and the
/// swipe of the models list.
Future<bool> confirmAndDeletePortfolioModel(BuildContext context, WidgetRef ref, PortfolioModel model) async {
  final s = ref.read(appStringsProvider);
  final service = ref.read(portfolioModelServiceProvider);
  final confirmed = await showConfirmDialog(
    context,
    title: s.delete,
    content: s.portfolioModelDeleteConfirm,
    confirmLabel: s.delete,
    cancelLabel: s.cancel,
    confirmColor: Colors.red,
  );
  if (!confirmed) return false;
  await service.deleteCustomModel(model.id);
  return true;
}

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
  bool _resolvingSearchSelection = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    if (widget.existingItems.isEmpty) {
      _rows.add(_ModelItemControllers.empty());
    } else {
      // Same locale (and fallback) the save parses the weights with.
      final locale = ref.read(appLocaleProvider).value ?? 'en';
      for (final item in widget.existingItems) {
        _rows.add(_ModelItemControllers.fromItem(item, locale));
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
      title: Row(
        children: [
          Expanded(child: Text(isEdit ? s.portfolioModelEditTitle : s.portfolioModelCreateTitle)),
          if (isEdit)
            // Filled, unlike the outlined remove button of each row: this
            // deletes the whole model.
            IconButton(
              key: const Key('portfolioModelDeleteButton'),
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: s.delete,
              onPressed: () async {
                final deleted = await confirmAndDeletePortfolioModel(context, ref, widget.existing!);
                if (deleted && context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
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
                  // The fields (their focus, selection, controllers) belong
                  // to the row: without a key, removing a row shifted the
                  // next rows' texts into the fields above them.
                  key: ValueKey(_rows[i]),
                  controllers: _rows[i],
                  s: s,
                  onChanged: () => setState(() {}),
                  onSearch: () => _pickAssetForRow(_rows[i]),
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
              Text(s.portfolioModelWeightTotal(NumberFormat('0.00', locale).format(total))),
              if (_resolvingSearchSelection) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
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
          onPressed: _saving ? null : () => _save(context, locale),
          child: Text(isEdit ? s.save : s.create),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, String locale) async {
    // A second tap while the first save is in flight must not create twice.
    if (_saving) return;
    final items = <PortfolioModelInputItem>[];
    for (final row in _rows) {
      final weight = fmt.tryParseLocalized(row.weight.text, locale: locale);
      items.add(
        PortfolioModelInputItem(
          isin: row.isin.text,
          targetWeight: weight ?? -1,
          description: row.description.text,
          preferredTicker: row.preferredTicker.text,
          preferredExchange: row.preferredExchange.text,
        ),
      );
    }
    setState(() => _saving = true);
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
      // In the UI language, the weights' total in the display locale.
      final s = ref.read(appStringsProvider);
      if (mounted) setState(() => _error = e.localizedMessages(s, locale: locale).join('\n'));
    } on PortfolioModelReadOnlyException {
      final s = ref.read(appStringsProvider);
      setState(() => _error = s.portfolioModelReadOnly);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAssetForRow(_ModelItemControllers row) async {
    var typedQuery = '';
    final selected = await showDialog<({ProviderSearchResult result, String query})>(
      context: context,
      builder: (dialogContext) {
        final s = ref.read(appStringsProvider);
        return AlertDialog(
          title: Text(s.searchAssetTitle),
          // Width is owned by AssetSearchSection: AlertDialog measures its
          // content intrinsically, so the section imposes a tight width.
          content: AssetSearchSection(
            widgetRef: ref,
            onSelect: (result) {
              Navigator.of(dialogContext).pop((
                result: result,
                query: typedQuery,
              ));
            },
            recoveryDefaultExchange: 'Milan',
            recoveryCacheKeyBuilder: isinCacheKey,
            onQueryChanged: (q) => typedQuery = q.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(s.cancel),
            ),
          ],
        );
      },
    );
    if (selected == null) return;

    setState(() {
      _error = null;
      _resolvingSearchSelection = true;
    });

    try {
      final query = selected.query.trim().toUpperCase();
      var resolvedIsin = isIsin(query) ? query : selected.result.isin;

      if (resolvedIsin == null || resolvedIsin.isEmpty) {
        final service = ref.read(marketPriceServiceProvider);
        if (service is WebMarketDataService) {
          final resolved = await service.resolveSearchResultDetails(selected.result);
          final candidate = resolved?.isin?.trim().toUpperCase();
          if (candidate != null && isIsin(candidate)) {
            resolvedIsin = candidate;
          }
        }
      }

      if (!mounted) return;
      if (resolvedIsin == null || resolvedIsin.isEmpty) {
        setState(() => _error = ref.read(appStringsProvider).portfolioModelSearchResolveFailed);
        return;
      }

      row.isin.text = resolvedIsin;
      row.description.text = selected.result.description;
      row.preferredTicker.text = selected.result.symbol;
      row.preferredExchange.text = selected.result.exchange;
      setState(() {});
    } finally {
      if (mounted) {
        setState(() => _resolvingSearchSelection = false);
      }
    }
  }
}

class _ModelItemRow extends StatelessWidget {
  final _ModelItemControllers controllers;
  final AppStrings s;
  final VoidCallback onChanged;
  final VoidCallback onSearch;
  final VoidCallback? onRemove;

  const _ModelItemRow({
    super.key,
    required this.controllers,
    required this.s,
    required this.onChanged,
    required this.onSearch,
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
            decoration: InputDecoration(
              labelText: s.portfolioModelIsin,
              suffixIcon: IconButton(
                tooltip: s.search,
                icon: const Icon(Icons.search),
                onPressed: onSearch,
              ),
            ),
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
  final TextEditingController preferredTicker;
  final TextEditingController preferredExchange;

  _ModelItemControllers({
    required this.isin,
    required this.weight,
    required this.description,
    required this.preferredTicker,
    required this.preferredExchange,
  });

  factory _ModelItemControllers.empty() => _ModelItemControllers(
    isin: TextEditingController(),
    weight: TextEditingController(),
    description: TextEditingController(),
    preferredTicker: TextEditingController(),
    preferredExchange: TextEditingController(),
  );

  /// [locale] is the one the save parses the weight back with: the locale's
  /// spelling with every digit ("12,5" in it_IT) reads back as exactly the
  /// stored value.
  factory _ModelItemControllers.fromItem(PortfolioModelItem item, String locale) => _ModelItemControllers(
    isin: TextEditingController(text: item.isin),
    weight: TextEditingController(text: fmt.editableFigure(item.targetWeight, fmt.qtyFormat(locale), locale: locale)),
    description: TextEditingController(text: item.description),
    preferredTicker: TextEditingController(text: item.preferredTicker ?? ''),
    preferredExchange: TextEditingController(text: item.preferredExchange ?? ''),
  );

  void dispose() {
    isin.dispose();
    weight.dispose();
    description.dispose();
    preferredTicker.dispose();
    preferredExchange.dispose();
  }
}
