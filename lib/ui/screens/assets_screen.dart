import 'dart:async';

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

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _expandedGroups = <int?>{};
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final statsAsync = ref.watch(assetStatsProvider);
    final intermediariesAsync = ref.watch(intermediariesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final convertedStats = ref.watch(convertedAssetStatsProvider).value ?? {};
    final marketValues = ref.watch(assetMarketValuesProvider).value ?? {};

    return Scaffold(
      body: assetsAsync.when(
        data: (assets) {
          if (assets.isEmpty) {
            return Center(
              child: Text(s.noAssetsYet, textAlign: TextAlign.center),
            );
          }

          final stats = statsAsync.value ?? {};
          final intermediaries = intermediariesAsync.value ?? [];

          if (!_initialized) {
            _expandedGroups.addAll(intermediaries.map((i) => i.id));
            _expandedGroups.add(null);
            _initialized = true;
          }

          // Group assets by intermediaryId
          final grouped = <int?, List<Asset>>{};
          for (final asset in assets) {
            (grouped[asset.intermediaryId] ??= []).add(asset);
          }

          final groupOrder = <int?>[
            ...intermediaries.map((i) => i.id),
            if (grouped.containsKey(null)) null,
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final groupId in groupOrder) ...[
                if (grouped.containsKey(groupId))
                  _buildGroup(
                    context, s, groupId,
                    groupId == null ? null : intermediaries.firstWhere((i) => i.id == groupId),
                    grouped[groupId]!,
                    stats, convertedStats, marketValues, baseCurrency, locale,
                    intermediaries,
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.error(e))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => _CreateAssetDialog(ref: ref),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context,
    AppStrings s,
    int? groupId,
    Intermediary? intermediary,
    List<Asset> assets,
    Map<int, AssetStats> stats,
    Map<int, double?> convertedStats,
    Map<int, double> marketValues,
    String baseCurrency,
    String locale,
    List<Intermediary> allIntermediaries,
  ) {
    final isExpanded = _expandedGroups.contains(groupId);
    final title = intermediary?.name ?? s.unassigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedGroups.remove(groupId);
            } else {
              _expandedGroups.add(groupId);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Icon(
                  intermediary != null ? Icons.business : Icons.folder_open,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title (${assets.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...assets.map((asset) {
            final stat = stats[asset.id];
            return _AssetTile(
              key: ValueKey(asset.id),
              asset: asset,
              stats: stat,
              convertedInvested: convertedStats[asset.id],
              marketValue: marketValues[asset.id],
              baseCurrency: baseCurrency,
              locale: locale,
              strings: s,
              allIntermediaries: allIntermediaries,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssetDetailScreen(asset: asset),
                ),
              ),
              onMoveToIntermediary: (intId) {
                ref.read(intermediaryServiceProvider).moveAsset(asset.id, intId);
              },
            );
          }),
        const Divider(height: 1),
      ],
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
  final List<Intermediary> allIntermediaries;
  final void Function(int?) onMoveToIntermediary;

  const _AssetTile({
    super.key,
    required this.asset,
    required this.stats,
    this.convertedInvested,
    this.marketValue,
    required this.baseCurrency,
    required this.locale,
    required this.onTap,
    required this.strings,
    required this.allIntermediaries,
    required this.onMoveToIntermediary,
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
                            text: '${amtFormat.format(marketValue! / stats!.totalQuantity)}',
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
            // Move menu
            PopupMenuButton<int?>(
              iconSize: 18,
              padding: EdgeInsets.zero,
              tooltip: strings.selectIntermediary,
              itemBuilder: (_) => [
                ...allIntermediaries
                    .where((i) => i.id != asset.intermediaryId)
                    .map((i) => PopupMenuItem(value: i.id, child: Text(i.name))),
                if (asset.intermediaryId != null)
                  PopupMenuItem(value: null, child: Text(strings.unassigned)),
              ],
              onSelected: onMoveToIntermediary,
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
      color: Colors.grey.shade600,
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
  String _selectedExchange = 'MIL';

  // Manual entry
  final _manualNameCtrl = TextEditingController();
  final _manualIdCtrl = TextEditingController();
  String _manualExchange = 'MIL';
  InstrumentType _instrumentType = InstrumentType.etf;
  AssetClass _assetClass = AssetClass.equity;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualIdCtrl.dispose();
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
      content: SizedBox(
        width: 400,
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
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
            value: _selectedExchange,
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
                  value: _instrumentType,
                  decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
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
                  value: _assetClass,
                  decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
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
        ],
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: () async {
            final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
            final currency = exchangeCodeToCurrency[_selectedExchange] ?? baseCurrency;
            await widget.ref.read(assetServiceProvider).create(
                  name: r.description,
                  ticker: r.symbol.isNotEmpty ? r.symbol : null,
                  exchange: _selectedExchange,
                  currency: currency,
                  instrumentType: _instrumentType,
                  assetClass: _assetClass,
                );
            if (mounted) Navigator.pop(context);
          },
          child: Text(s.create),
        ),
      ],
    );
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
          const SizedBox(height: 12),
          TextField(
            controller: _manualIdCtrl,
            decoration: InputDecoration(
              labelText: s.identifierLabel,
              hintText: s.optional,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _manualExchange,
            decoration: InputDecoration(
              labelText: s.stockExchange,
              isDense: true,
            ),
            items: supportedExchanges.entries
                .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _manualExchange = v);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<InstrumentType>(
                  value: _instrumentType,
                  decoration: InputDecoration(labelText: s.allocInstrument, isDense: true),
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
                  value: _assetClass,
                  decoration: InputDecoration(labelText: s.allocAssetClass, isDense: true),
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
        ],
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: _manualNameCtrl.text.trim().isNotEmpty
              ? () async {
                  final name = _manualNameCtrl.text.trim();
                  final id = _manualIdCtrl.text.trim().toUpperCase();
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final currency = exchangeCodeToCurrency[_manualExchange] ?? baseCurrency;
                  await widget.ref.read(assetServiceProvider).create(
                        name: name,
                        ticker: id.isNotEmpty ? id : null,
                        isin: id.isNotEmpty ? id : null,
                        exchange: _manualExchange,
                        currency: currency,
                        instrumentType: _instrumentType,
                        assetClass: _assetClass,
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
