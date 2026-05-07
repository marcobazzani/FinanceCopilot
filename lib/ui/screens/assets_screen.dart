import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../database/tables.dart';
import '../../services/asset_service.dart';
import '../../services/web_market_data_service.dart';
import '../../services/market_price_service.dart' show exchangeCurrency, isKnownExchange, supportedExchanges;
import '../../services/providers/providers.dart';
import '../../l10n/app_strings.dart';
import '../../utils/dialogs.dart';
import '../../utils/formatters.dart' as fmt;
import 'asset_detail_screen.dart';
import 'dashboard/dashboard_screen.dart' show currencySymbol;
import '../widgets/asset_search.dart';
import '../widgets/global_app_bar_actions.dart';
import '../widgets/mobile_pull_to_refresh.dart';
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
    final noMarketData =
        ref.watch(assetsWithoutMarketPriceProvider).value ?? const <int>{};

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
      appBar: AppBar(actions: globalAppBarActions(context, ref)),
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

          return MobilePullToRefresh(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final i in intermediaries)
                  if (grouped[i.id]?.isNotEmpty ?? false)
                    _buildGroup(
                      context, s, i.id, i,
                      grouped[i.id] ?? [],
                      stats, convertedStats, marketValues, noMarketData,
                      baseCurrency, locale,
                      intermediaries,
                    ),
              ],
            ),
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
    Set<int> noMarketData,
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
              hasNoMarketData: noMarketData.contains(asset.id),
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

  Future<void> _showManageIntermediariesDialog(BuildContext context) =>
      showManageIntermediariesDialog(context, ref);
}

class _AssetTile extends StatelessWidget {
  final Asset asset;
  final AssetStats? stats;
  final double? convertedInvested;
  final double? marketValue;
  final bool hasNoMarketData;
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
    this.hasNoMarketData = false,
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
                  if (hasNoMarketData) ...[
                    const SizedBox(height: 2),
                    _buildNoMarketDataBadge(theme),
                  ] else if (convertedInvested != null &&
                      convertedInvested! > 0) ...[
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

  Widget _buildNoMarketDataBadge(ThemeData theme) {
    return Tooltip(
      message: strings.noMarketData,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 12,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            strings.noMarketData,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
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

/// Pure helper extracted for testability.
///
/// Given the full set of search [results] returned for the user's query and
/// the [picked] result, return every other result describing the same
/// instrument (same description) whose exchange we know how to map to an
/// internal code. Falls back to `[picked]` when no siblings exist so the
/// caller always has at least one listing to render.
List<ProviderSearchResult> exchangeListingsFor(
  List<ProviderSearchResult> results,
  ProviderSearchResult picked,
) {
  final siblings = results
      .where((x) =>
          x.description.isNotEmpty &&
          x.description == picked.description &&
          isKnownExchange(x.exchange))
      .toList();
  return siblings.isNotEmpty ? siblings : [picked];
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
  bool _manual = false;
  bool _unlocked = false;

  /// Apply the dialog's shared overrides (ter, taxRate, valuationMethod,
  /// assetType, isActive, includeInNetWorth — all gated on `_unlocked`)
  /// to a single create call. Caller passes the per-flow fields (name,
  /// intermediary, currency, optional ticker/isin/exchange).
  Future<int> _createAsset({
    required String name,
    required int intermediaryId,
    required String currency,
    String? ticker,
    String? isin,
    String? exchange,
  }) {
    return widget.ref.read(assetServiceProvider).create(
      name: name,
      ticker: ticker,
      isin: isin,
      exchange: exchange,
      currency: currency,
      intermediaryId: intermediaryId,
      instrumentType: _instrumentType,
      assetClass: _assetClass,
      valuationMethod: _unlocked && _valuationMethodOverride != null
          ? _valuationMethodOverride!
          : ValuationMethod.marketPrice,
      assetType: _unlocked ? _assetType : AssetType.stockEtf,
      ter: _unlocked ? fmt.tryParseLocalized(_terCtrl.text, locale: _locale) : null,
      taxRate: _unlocked ? (() {
        final v = fmt.tryParseLocalized(_taxRateCtrl.text, locale: _locale);
        return v == null ? null : v / 100;
      })() : null,
      isActive: _unlocked ? _isActive : null,
      includeInNetWorth: _unlocked ? _includeInNetWorth : null,
    );
  }

  // Step 1: search state mirrored from AssetSearchSection so step 2 can
  // derive sibling exchange listings and capture the user's typed query
  // (used to persist a pasted ISIN as the asset's price-sync cache key).
  String _typedQuery = '';
  List<ProviderSearchResult> _allResults = const [];

  // Step 2: selected result
  ProviderSearchResult? _selected;
  String? _selectedExchange;

  /// Exchange listings discovered for the same instrument (same description).
  /// Drives the exchange dropdown so users can only pick exchanges where the
  /// instrument actually trades. Each entry has a distinct cid.
  List<ProviderSearchResult> _listings = const [];

  // Manual entry
  final _manualNameCtrl = TextEditingController();
  InstrumentType? _instrumentType;
  AssetClass? _assetClass;
  int? _selectedIntermediaryId;

  // Advanced (unlocked) entry — header attributes only. Composition
  // (geographic / sector / asset class breakdown) is edited inline on the
  // Composition panel of the asset detail screen.
  AssetType _assetType = AssetType.stockEtf;
  ValuationMethod? _valuationMethodOverride;
  final _currencyCtrl = TextEditingController();
  final _terCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  bool _includeInNetWorth = true;
  bool _isActive = true;

  String get _locale =>
      widget.ref.read(appLocaleProvider).value ?? Platform.localeName;

  @override
  void dispose() {
    _manualNameCtrl.dispose();
    _currencyCtrl.dispose();
    _terCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Widget _buildLockToggle(AppStrings s) => IconButton(
        icon: Icon(_unlocked ? Icons.lock_open : Icons.lock_outline, size: 20),
        tooltip: _unlocked ? s.assetLockEdit : s.assetUnlockEdit,
        onPressed: () => setState(() => _unlocked = !_unlocked),
      );

  List<Widget> _buildAdvancedFields(AppStrings s, {required bool showValuation}) {
    return [
      const Divider(height: 24),
      DropdownButtonFormField<AssetType>(
        initialValue: _assetType,
        decoration: InputDecoration(labelText: s.assetTypeFieldLabel, isDense: true),
        items: AssetType.values
            .map((t) => DropdownMenuItem(value: t, child: Text(s.assetTypeLabel(t), style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _assetType = v);
        },
      ),
      if (showValuation) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<ValuationMethod>(
          initialValue: _valuationMethodOverride,
          decoration: InputDecoration(labelText: s.valuationMethodFieldLabel, isDense: true),
          items: ValuationMethod.values
              .map((m) => DropdownMenuItem(value: m, child: Text(s.valuationMethodLabel(m), style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _valuationMethodOverride = v);
          },
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _currencyCtrl,
        decoration: InputDecoration(
          labelText: s.currencyFieldLabel,
          isDense: true,
          counterText: '',
        ),
        textCapitalization: TextCapitalization.characters,
        maxLength: 3,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _terCtrl,
        decoration: InputDecoration(
          labelText: '${s.healthTer} (%)',
          // Locale-aware hint: "0,22" in it_IT, "0.22" in en_US.
          hintText: NumberFormat.decimalPattern(_locale).format(0.22),
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _taxRateCtrl,
        decoration: InputDecoration(
          labelText: s.taxRateOverrideLabel,
          // Accepts percentage (26 → stored as 0.26 by create call).
          hintText: '26',
          isDense: true,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: Text(s.active),
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
        contentPadding: EdgeInsets.zero,
      ),
      SwitchListTile(
        title: Text(s.includeInNetWorthLabel),
        value: _includeInNetWorth,
        onChanged: (v) => setState(() => _includeInNetWorth = v),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  void _selectResult(ProviderSearchResult result) {
    final (instrument, assetCls) = _classifyFromType(result.type);
    setState(() {
      _selected = result;
      _selectedExchange = result.exchange;
      _instrumentType = instrument;
      _assetClass = assetCls;
      _listings = exchangeListingsFor(_allResults, result);
    });
  }

  /// Derive instrument type + asset class from the provider's typeName.
  /// The `type` field looks like "Stocks - Milano" or "ETFs - Milano".
  static (InstrumentType, AssetClass) _classifyFromType(String type) {
    final prefix = type.toLowerCase().split(' ').first.replaceAll(RegExp(r's$'), '');
    return classifyFromProviderType(prefix);
  }

  static final _kIsinRegex = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$');
  static bool _isinShaped(String s) => _kIsinRegex.hasMatch(s.toUpperCase());

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
        child: AssetSearchSection(
          widgetRef: widget.ref,
          onSelect: _selectResult,
          recoveryDefaultExchange: _selectedExchange ?? 'Milan',
          recoveryCacheKeyBuilder: (q) =>
              _isinShaped(q) ? q.toUpperCase() : q,
          onQueryChanged: (q) => _typedQuery = q,
          onResultsChanged: (rs) => _allResults = rs,
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
      title: Row(
        children: [
          Expanded(child: Text(s.createAssetTitle)),
          _buildLockToggle(s),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Text(s.symbolLabel(r.symbol), style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(s.typeLabel(r.type), style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          _buildExchangeDropdown(s),
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
          if (_unlocked) ..._buildAdvancedFields(s, showValuation: true),
        ],
      ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: _selectedIntermediaryId != null
              ? () async {
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final exchange = _selectedExchange ?? 'Milan';
                  final defaultCurrency = exchangeCurrency[exchange] ?? baseCurrency;
                  final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
                  final currency = (_unlocked && overrideCurrency.length == 3)
                      ? overrideCurrency
                      : defaultCurrency;
                  // If the user searched by an ISIN-shaped string, persist it
                  // so price sync can use it as the cache key (otherwise the
                  // ticker — e.g. a bond's "BE000035160=MI" — is not a valid
                  // search term and price sync silently fails).
                  final typed = _typedQuery.trim().toUpperCase();
                  final isin = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(typed) ? typed : null;
                  await _createAsset(
                    name: r.description,
                    intermediaryId: _selectedIntermediaryId!,
                    currency: currency,
                    ticker: r.symbol.isNotEmpty ? r.symbol : null,
                    isin: isin,
                    exchange: exchange,
                  );
                  if (mounted) Navigator.pop(context);
                }
              : null,
          child: Text(s.create),
        ),
      ],
    );
  }

  Widget _buildExchangeDropdown(AppStrings s) {
    // Discovered listings drive the dropdown so the user can only pick
    // exchanges where the instrument actually trades. Falls back to the
    // global supportedExchanges list when no listings were discovered.
    final byName = <String, ProviderSearchResult>{};
    for (final l in _listings) {
      if (!isKnownExchange(l.exchange)) continue;
      byName.putIfAbsent(l.exchange, () => l);
    }

    if (byName.isEmpty) {
      final initial = supportedExchanges.contains(_selectedExchange)
          ? _selectedExchange
          : supportedExchanges.first;
      return DropdownButtonFormField<String>(
        initialValue: initial,
        decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
        items: supportedExchanges
            .map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _selectedExchange = v);
        },
      );
    }

    if (byName.length == 1) {
      final entry = byName.entries.first;
      return InputDecorator(
        decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
        child: Text(entry.key, style: const TextStyle(fontSize: 13)),
      );
    }

    final initial = byName.containsKey(_selectedExchange) ? _selectedExchange : byName.keys.first;
    return DropdownButtonFormField<String>(
      initialValue: initial,
      decoration: InputDecoration(labelText: s.stockExchange, isDense: true),
      items: byName.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.key, style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        final pair = byName[v];
        if (pair == null) return;
        setState(() {
          _selectedExchange = v;
          _selected = pair; // swap to the listing that matches the chosen exchange
        });
      },
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
      title: Row(
        children: [
          Expanded(child: Text(s.newAssetManualTitle)),
          _buildLockToggle(s),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
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
          if (_unlocked) ..._buildAdvancedFields(s, showValuation: true),
        ],
      ),
      ),
      actions: [
        TextButton(onPressed: _backToSearch, child: Text(s.back)),
        FilledButton(
          onPressed: (_manualNameCtrl.text.trim().isNotEmpty && _selectedIntermediaryId != null)
              ? () async {
                  final name = _manualNameCtrl.text.trim();
                  final baseCurrency = widget.ref.read(baseCurrencyProvider).value ?? 'EUR';
                  final overrideCurrency = _currencyCtrl.text.trim().toUpperCase();
                  final currency = (_unlocked && overrideCurrency.length == 3)
                      ? overrideCurrency
                      : baseCurrency;
                  await _createAsset(
                    name: name,
                    intermediaryId: _selectedIntermediaryId!,
                    currency: currency,
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
