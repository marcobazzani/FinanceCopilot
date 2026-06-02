import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/portfolio_model_service.dart';
import '../../../services/providers/providers.dart';
import '../../../services/web_market_data_service.dart';
import '../../../utils/formatters.dart' as fmt;
import '../../widgets/asset_search.dart';

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
                  ref: ref,
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
              Text(s.portfolioModelWeightTotal(total.toStringAsFixed(2))),
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
          preferredTicker: row.preferredTicker.text,
          preferredExchange: row.preferredExchange.text,
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

  static final _kIsinRegex = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');

  Future<void> _pickAssetForRow(_ModelItemControllers row) async {
    var typedQuery = '';
    final selected = await showDialog<({ProviderSearchResult result, String query})>(
      context: context,
      builder: (dialogContext) {
        final s = ref.read(appStringsProvider);
        return AlertDialog(
          title: Text(s.searchAssetTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AssetSearchSection(
              widgetRef: ref,
              onSelect: (result) {
                Navigator.of(dialogContext).pop((
                  result: result,
                  query: typedQuery,
                ));
              },
              recoveryDefaultExchange: 'Milan',
              recoveryCacheKeyBuilder: (q) => _kIsinRegex.hasMatch(q.toUpperCase()) ? q.toUpperCase() : q,
              onQueryChanged: (q) => typedQuery = q.trim(),
            ),
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
      var resolvedIsin = _kIsinRegex.hasMatch(query) ? query : selected.result.isin;

      if (resolvedIsin == null || resolvedIsin.isEmpty) {
        final service = ref.read(marketPriceServiceProvider);
        if (service is WebMarketDataService) {
          final resolved = await service.resolveSearchResultDetails(selected.result);
          final candidate = resolved?.isin?.trim().toUpperCase();
          if (candidate != null && _kIsinRegex.hasMatch(candidate)) {
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
  final WidgetRef ref;
  final VoidCallback onChanged;
  final VoidCallback onSearch;
  final VoidCallback? onRemove;

  const _ModelItemRow({
    required this.controllers,
    required this.s,
    required this.ref,
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

  factory _ModelItemControllers.fromItem(PortfolioModelItem item) => _ModelItemControllers(
    isin: TextEditingController(text: item.isin),
    weight: TextEditingController(text: item.targetWeight.toStringAsFixed(2)),
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
