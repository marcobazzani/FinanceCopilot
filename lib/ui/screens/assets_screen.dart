import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/asset_service.dart';
import '../../services/investing_com_service.dart';
import '../../services/market_price_service.dart' show exchangeCodeToCurrency, investingExchangeToCode, supportedExchanges;
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/formatters.dart' as fmt;
import 'asset_detail_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import '../widgets/privacy_text.dart';
import '../widgets/selection/selectable_item.dart';
import '../widgets/selection/selection_action_bar.dart';
import '../widgets/selection/selection_controller.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _selection = SelectionController<int>();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final statsAsync = ref.watch(assetStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final convertedStats = ref.watch(convertedAssetStatsProvider).value ?? {};
    final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};

    return ListenableBuilder(
      listenable: _selection,
      builder: (lbCtx, _) {
        // Build the id list in rendered order: grouped by intermediary.
        // Every asset must have an intermediary (schema v29 invariant).
        final assets = assetsAsync.value ?? const <Asset>[];
        final intermediariesNow = intermediariesAsync.value ?? const <Intermediary>[];
        final grouping = <int, List<int>>{};
        for (final a in assets) {
          (grouping[a.intermediaryId] ??= []).add(a.id);
        }
        final allAssetIds = <int>[
          for (final i in intermediariesNow) ...?grouping[i.id],
        ];
        _selection.setOrderedIds(allAssetIds);
        return Scaffold(
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty && (intermediariesAsync.value ?? []).isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(s.noAssetsYet, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => _CreateAssetDialog(ref: ref),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(s.createAsset),
                  ),
                ],
              ),
            );
          }

          final stats = statsAsync.value ?? {};
          final intermediaries = intermediariesAsync.value ?? [];

          final grouped = <int, List<Asset>>{};
          for (final asset in assets) {
            (grouped[asset.intermediaryId] ??= []).add(asset);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final i in intermediaries)
                if (grouped[i.id]?.isNotEmpty ?? false)
                  _buildGroup(
                    context, s, i.id, i,
                    grouped[i.id] ?? [],
                    stats, convertedStats, marketValues, baseCurrency, locale,
                    intermediaries,
                  ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
      ),
      bottomNavigationBar: _selection.active
          ? SelectionActionBar<int>(
              controller: _selection,
              visibleIds: allAssetIds,
              onDelete: (ids) => ref.read(assetServiceProvider).deleteMany(ids.toList()),
            )
          : null,
      floatingActionButton: _selection.active
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'add_intermediary_assets',
                  onPressed: () => _showManageIntermediariesDialog(context),
                  child: const Icon(Icons.business),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'add_asset',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => _CreateAssetDialog(ref: ref),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
    );
      },
    );
  }

  Widget _buildGroup(
    BuildContext context,
    AppStrings s,
    int groupId,
    Intermediary intermediary,
    List<Asset> assets,
    Map<int, AssetStats> stats,
    Map<int, double?> convertedStats,
    Map<int, double> marketValues,
    String baseCurrency,
    String locale,
    List<Intermediary> intermediaries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.business, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${intermediary.name} (${assets.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...assets.map((asset) {
          final stat = stats[asset.id];
          return SelectableItem<int>(
            key: ValueKey(asset.id),
            controller: _selection,
            id: asset.id,
            child: _AssetTile(
              asset: asset,
              stats: stat,
              convertedInvested: convertedStats[asset.id],
              marketValue: marketValues[asset.id],
              baseCurrency: baseCurrency,
              locale: locale,
              strings: s,
              intermediaries: intermediaries,
              onMove: (newId) {
                if (newId != asset.intermediaryId) {
                  ref.read(intermediaryServiceProvider).moveAsset(asset.id, newId);
                }
              },
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
              ),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showIntermediaryDialog(BuildContext context, {Intermediary? intermediary}) async {
    final s = ref.read(appStringsProvider);
    final nameCtrl = TextEditingController(text: intermediary?.name ?? '');
    final isEdit = intermediary != null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? s.editIntermediary : s.addIntermediary),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: s.intermediaryName),
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () async {
                      final svc = ref.read(intermediaryServiceProvider);
                      if (isEdit) {
                        await svc.update(intermediary.id, IntermediariesCompanion(name: Value(nameCtrl.text.trim())));
                      } else {
                        await svc.create(name: nameCtrl.text.trim());
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  : null,
              child: Text(isEdit ? s.save : s.create),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteIntermediary(BuildContext context, Intermediary intermediary) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteIntermediary),
        content: Text(s.deleteIntermediaryConfirm(intermediary.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(intermediaryServiceProvider).delete(intermediary.id);
    }
  }

  Future<void> _showManageIntermediariesDialog(BuildContext context) async {
    final s = ref.read(appStringsProvider);

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final intermediaries = ref.watch(intermediariesProvider).value ?? [];
          return AlertDialog(
            title: Text(s.intermediaries),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: intermediaries.isEmpty
                          ? Center(child: Text(s.selectIntermediaryEmpty, style: TextStyle(color: Colors.grey)))
                          : ReorderableListView.builder(
                              shrinkWrap: true,
                              buildDefaultDragHandles: false,
                              itemCount: intermediaries.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                final reordered = List<Intermediary>.from(intermediaries);
                                final item = reordered.removeAt(oldIndex);
                                reordered.insert(newIndex, item);
                                ref.read(intermediaryServiceProvider)
                                    .reorder(reordered.map((i) => i.id).toList());
                              },
                              itemBuilder: (ctx, i) {
                                final inter = intermediaries[i];
                                return ListTile(
                                  key: ValueKey(inter.id),
                                  leading: ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                                  ),
                                  title: Text(inter.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _showIntermediaryDialog(context, intermediary: inter);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _confirmDeleteIntermediary(context, inter);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showIntermediaryDialog(context);
                },
                child: Text(s.addIntermediary),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.close),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final AssetStats? stats;
  final double? convertedInvested;
  final double? marketValue;
  final String baseCurrency;
  final String locale;
  final VoidCallback onTap;
  final AppStrings strings;
  final List<Intermediary> intermediaries;
  final void Function(int newIntermediaryId) onMove;

  const _AssetTile({
    required this.asset,
    required this.stats,
    this.convertedInvested,
    this.marketValue,
    required this.baseCurrency,
    required this.locale,
    required this.onTap,
    required this.strings,
    required this.intermediaries,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amtFormat = fmt.amountFormat(locale);
    final qtyFormat = fmt.qtyFormat(locale);
    final dateFormat = fmt.monthYearFormat(locale);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(width: 28), // indent under group header
            // Asset icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: asset.isActive
                    ? theme.colorScheme.primaryContainer
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.pie_chart,
                size: 20,
                color: asset.isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + ticker
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asset.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: asset.isActive ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (asset.ticker != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          asset.ticker!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Stats line
                  _buildStatsLine(context, dateFormat),
                ],
              ),
            ),
            // Right side: market value, gain/loss, invested
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (marketValue != null) ...[
                  PrivacyText(
                    '${amtFormat.format(marketValue!)} ${currencySymbol(baseCurrency)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: asset.isActive ? null : Colors.grey,
                    ),
                  ),
                  if (convertedInvested != null && convertedInvested! > 0) ...[
                    const SizedBox(height: 2),
                    _buildGainLoss(theme, amtFormat),
                  ],
                ] else if (stats != null && stats!.totalInvested > 0)
                  PrivacyText(
                    '${amtFormat.format(stats!.totalInvested)} ${asset.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: asset.isActive
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      asset.currency,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (stats != null && stats!.totalQuantity != 0) ...[
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (marketValue != null) ...[
                          TextSpan(
                            text: amtFormat.format(marketValue! / stats!.totalQuantity),
                            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                          ),
                          if (asset.currency != baseCurrency)
                            TextSpan(
                              text: ' ${asset.currency}→${currencySymbol(baseCurrency)}',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade400, fontSize: 10),
                            ),
                          TextSpan(
                            text: '  ×  ',
                            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade400),
                          ),
                        ],
                        TextSpan(
                          text: qtyFormat.format(stats!.totalQuantity),
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!asset.isActive) ...[
                  const SizedBox(height: 2),
                  Text(strings.inactive,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              tooltip: strings.selectIntermediary,
              itemBuilder: (_) => <PopupMenuEntry<int>>[
                PopupMenuItem<int>(
                  enabled: false,
                  child: Text(
                    strings.selectIntermediary,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const PopupMenuDivider(),
                for (final i in intermediaries)
                  PopupMenuItem<int>(
                    value: i.id,
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(i.name)),
                        if (asset.intermediaryId == i.id)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
              ],
              onSelected: onMove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGainLoss(ThemeData theme, NumberFormat amtFormat) {
    final invested = convertedInvested!;
    final gain = marketValue! - invested;
    final pct = (gain / invested) * 100;
    final isPositive = gain >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final arrow = isPositive ? '\u25B2' : '\u25BC'; // ▲ ▼
    return PrivacyText(
      '$arrow ${amtFormat.format(gain.abs())} (${pct.abs().toStringAsFixed(1)}%)',
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }

  Widget _buildStatsLine(BuildContext context, DateFormat dateFormat) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 12,
    );

    if (stats == null || stats!.eventCount == 0) {
      return Text(strings.noEventsYetShort, style: style);
    }

    final parts = <InlineSpan>[];

    // Event count
    parts.add(TextSpan(
      text: strings.nEvents(stats!.eventCount),
      style: style,
    ));

    // Date range
    if (stats!.firstDate != null) {
      parts.add(TextSpan(
        text: '  ·  ${strings.sinceDate(dateFormat.format(stats!.firstDate!))}',
        style: style,
      ));
    }
    if (stats!.lastDate != null) {
      parts.add(TextSpan(
        text: '  ·  ${strings.lastDate(dateFormat.format(stats!.lastDate!))}',
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: parts),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

// ──────────────────────────────────────────────
// Create Asset Dialog — two-step search flow
// ──────────────────────────────────────────────

class _CreateAssetDialog extends StatefulWidget {
  final WidgetRef ref;
  const _CreateAssetDialog({required this.ref});

  @override
  State<_CreateAssetDialog> createState() => _CreateAssetDialogState();
}

class _CreateAssetDialogState extends State<_CreateAssetDialog> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<InvestingSearchResult> _results = [];
  bool _searching = false;
  bool _manual = false;

  // Step 2: selected result
  InvestingSearchResult? _selected;
  String? _selectedExchange;

  // Manual entry
  final _manualNameCtrl = TextEditingController();
  InstrumentType? _instrumentType;
  AssetClass? _assetClass;
  int? _selectedIntermediaryId;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _manualNameCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final service = widget.ref.read(marketPriceServiceProvider) as InvestingComService;
      try {
        final results = await service.search(query.trim());
        if (mounted && _searchCtrl.text.trim() == query.trim()) {
          setState(() {
            _results = results;
            _searching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectResult(InvestingSearchResult result) {
    final code = investingExchangeToCode[result.exchange];
    final (instrument, assetCls) = _classifyFromType(result.type);
    setState(() {
      _selected = result;
      _selectedExchange = code ?? 'MIL';
      _instrumentType = instrument;
      _assetClass = assetCls;
    });
  }

  /// Derive instrument type + asset class from investing.com's typeName.
  /// The `type` field looks like "Stocks - Milano" or "ETFs - Milano".
  static (InstrumentType, AssetClass) _classifyFromType(String type) {
    final prefix = type.toLowerCase().split(' ').first.replaceAll(RegExp(r's$'), '');
    return classifyFromInvestingType(prefix);
  }

  void _backToSearch() {
    setState(() {
      _selected = null;
      _manual = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_manual) return _buildManualDialog();
    if (_selected != null) return _buildConfirmDialog();
    return _buildSearchDialog();
  }

  Widget _buildSearchDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.newAssetTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          height: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: s.search,
                  hintText: s.searchAssetsHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                autofocus: true,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_results.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = _results[i];
                      return ListTile(
                        dense: true,
                        title: Text(r.description, overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Text(
                          '${r.symbol}  ·  ${r.type}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(r.flag, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        onTap: () => _selectResult(r),
                      );
                    },
                  ),
                )
              else if (_searchCtrl.text.trim().length >= 3)
                Expanded(
                  child: Center(
                    child: Text(s.noResultsFound, style: const TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(s.typeAtLeast3Chars, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _manual = true),
          child: Text(s.enterManually),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
      ],
    );
  }

  Widget _buildConfirmDialog() {
    final s = widget.ref.read(appStringsProvider);
    final r = _selected!;
    return AlertDialog(
      title: Text(s.createAssetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Text(s.symbolLabel(r.symbol), style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(s.typeLabel(r.type), style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedExchange,
            decoration: InputDecoration(
              labelText: s.stockExchange,
              isDense: true,
            ),
            items: supportedExchanges.entries
                .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedExchange = v);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<InstrumentType>(
                  initialValue: _instrumentType,
                  decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                  hint: const Text('-', style: TextStyle(fontSize: 13)),
                  items: InstrumentType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _instrumentType = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<AssetClass>(
                  initialValue: _assetClass,
                  decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                  hint: const Text('-', style: TextStyle(fontSize: 13)),
                  items: AssetClass.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _assetClass = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildIntermediaryPicker(s),
        ],
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: _selectedIntermediaryId != null
              ? () async {
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final exchange = _selectedExchange ?? 'MIL';
                  final currency = exchangeCodeToCurrency[exchange] ?? baseCurrency;
                  await widget.ref.read(assetServiceProvider).create(
                        name: r.description,
                        ticker: r.symbol.isNotEmpty ? r.symbol : null,
                        exchange: exchange,
                        currency: currency,
                        instrumentType: _instrumentType,
                        assetClass: _assetClass,
                        intermediaryId: _selectedIntermediaryId!,
                      );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(s.create),
        ),
      ],
    );
  }

  Widget _buildIntermediaryPicker(AppStrings s) {
    final intermediariesAsync = widget.ref.watch(intermediariesProvider);
    final list = intermediariesAsync.value ?? const <Intermediary>[];
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.selectIntermediaryEmpty, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(s.addIntermediary),
            onPressed: _createIntermediaryInline,
          ),
        ],
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _selectedIntermediaryId,
      decoration: InputDecoration(labelText: s.selectIntermediary, isDense: true),
      items: list
          .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedIntermediaryId = v);
      },
    );
  }

  Future<void> _createIntermediaryInline() async {
    final s = widget.ref.read(appStringsProvider);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.addIntermediary),
          content: TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: s.intermediaryName),
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, nameCtrl.text.trim())
                  : null,
              child: Text(s.create),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    final svc = widget.ref.read(intermediaryServiceProvider);
    final id = await svc.create(name: name);
    if (mounted) setState(() => _selectedIntermediaryId = id);
  }

  Widget _buildManualDialog() {
    final s = widget.ref.read(appStringsProvider);
    return AlertDialog(
      title: Text(s.newAssetManualTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _manualNameCtrl,
            decoration: InputDecoration(labelText: s.name),
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<InstrumentType>(
                  initialValue: _instrumentType,
                  decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
                  hint: const Text('-', style: TextStyle(fontSize: 13)),
                  items: InstrumentType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(s.instrumentTypeLabel(t), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _instrumentType = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<AssetClass>(
                  initialValue: _assetClass,
                  decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
                  hint: const Text('-', style: TextStyle(fontSize: 13)),
                  items: AssetClass.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(s.assetClassLabel(c), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _assetClass = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildIntermediaryPicker(s),
        ],
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: (_manualNameCtrl.text.trim().isNotEmpty && _selectedIntermediaryId != null)
              ? () async {
                  final name = _manualNameCtrl.text.trim();
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  await widget.ref.read(assetServiceProvider).create(
                        name: name,
                        currency: baseCurrency,
                        valuationMethod: ValuationMethod.eventDriven,
                        instrumentType: _instrumentType,
                        assetClass: _assetClass,
                        intermediaryId: _selectedIntermediaryId!,
                      );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(s.create),
        ),
      ],
    );
  }
}
