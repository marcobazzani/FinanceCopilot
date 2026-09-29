part of 'pillar_detail_screen.dart';

class _AssetSliderRow extends StatelessWidget {
  final _AssetRowState row;
  final Asset? asset;

  /// Value of the whole holding; null without a price or exchange rate, shown
  /// as a dash and never as 0.
  final double? assetMarketValue;
  final String baseCurrency;
  final String locale;
  final double? targetWeight;

  /// Null when the asset has no value to weigh.
  final double? currentWeight;
  final void Function(double newQty) onChanged;
  final VoidCallback onChangeEnd;
  final AppStrings s;
  const _AssetSliderRow({
    super.key,
    required this.row,
    required this.asset,
    required this.assetMarketValue,
    required this.baseCurrency,
    required this.locale,
    required this.targetWeight,
    required this.currentWeight,
    required this.onChanged,
    required this.onChangeEnd,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final qf = fmt.qtyFormat(locale);
    final amf = fmt.amountFormat(locale);
    final percent = row.currentPercent;
    final maxPct = row.maxPercent;
    final disabled = maxPct <= 0;
    // A cap below 100% means other STANDARD pillars already hold part of the
    // position (they partition it; virtual portfolios overlap and always cap at
    // 100%). Say how much is elsewhere, otherwise the slider just looks stuck.
    final elsewhere = row.total - row.available;
    // The units held elsewhere are a quantity: masked in privacy mode, since
    // next to the cap they give the whole position away. The cap itself is a
    // share of the holding and stays readable.
    final maxLabel = elsewhere > 1e-9 ? s.pillarMaxPercentElsewhere(maxPct.round(), privacySlot(0)) : s.pillarMaxPercent(maxPct.round());
    final pf = NumberFormat.percentPattern(locale)..maximumFractionDigits = 1;
    final marketValue = assetMarketValue;
    final sliceValue = marketValue == null ? null : (row.total <= 0 ? 0.0 : marketValue * (row.current / row.total));
    String money(double? v) => v == null ? '—' : '${amf.format(v)} $baseCurrency';
    final weightFormat = NumberFormat('0.00', locale);
    String weight(double? v) => v == null ? '—' : '${weightFormat.format(v)}%';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset == null ? '#${row.assetId}' : (asset!.ticker == null ? asset!.name : '${asset!.ticker}  ·  ${asset!.name}'),
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PrivacyText(
                money(marketValue),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                pf.format(percent / 100),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: percent.clamp(0.0, maxPct.clamp(0.001, 100.0)),
                  min: 0,
                  max: maxPct <= 0 ? 100 : maxPct,
                  divisions: maxPct <= 0 ? null : (maxPct.round().clamp(1, 100)),
                  onChanged: disabled
                      ? null
                      : (newPct) {
                          final newQty = row.total * newPct / 100.0;
                          onChanged(_round(newQty));
                        },
                  onChangeEnd: disabled ? null : (_) => onChangeEnd(),
                ),
              ),
              IconButton(
                tooltip: '0%',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: row.current <= 1e-9
                    ? null
                    : () {
                        onChanged(0);
                        onChangeEnd();
                      },
              ),
              IconButton(
                tooltip: '${maxPct.round()}%',
                icon: const Icon(Icons.last_page, size: 18),
                onPressed: disabled
                    ? null
                    : () {
                        onChanged(_round(row.maxAvailable));
                        onChangeEnd();
                      },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 0),
            // Units held and the slice value are position size (masked); the
            // "max N%" cap is a share of the holding, not its magnitude, so it
            // stays readable.
            // Wrap, not Row: the max-label can carry the "units in other
            // pillars" explanation, and a fixed row would overflow on narrow
            // cards, hiding the very text that explains the cap.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PrivacyText(
                  '${s.pillarUnitsOf(qf.format(row.current), qf.format(row.total))} · ${money(sliceValue)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                PrivacySentence(' · $maxLabel', figures: [qf.format(elsewhere)], style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (targetWeight != null) ...[
            const SizedBox(height: 4),
            // Target / current / delta weights are all percentages: composition,
            // not magnitude. Masking them told the user nothing about their
            // position and hid the only thing the screen is for. An asset with
            // no value has no current weight: a dash, not 0%.
            Text(
              '${s.portfolioDivergenceTarget}: ${weight(targetWeight)} · '
              '${s.portfolioDivergenceCurrent}: ${weight(currentWeight)} · '
              '${s.portfolioDivergenceDelta}: ${weight(currentWeight == null ? null : currentWeight! - targetWeight!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  double _round(double v) {
    final r = (v * 10000).round() / 10000;
    return r < 0 ? 0 : r;
  }
}

List<Widget> _divergenceFooterRows({
  required BuildContext context,
  required AppStrings s,
  required String locale,
  required String baseCurrency,
  required Map<int, double> marketValues,
  required List<_AssetRowState> visibleRows,
  required Map<int, Asset> assetById,
  required Map<String, double> targetWeightByIsin,
}) {
  final amountFormat = fmt.amountFormat(locale);
  final weightFormat = NumberFormat('0.00', locale);
  final targetIsins = targetWeightByIsin.keys.toSet();
  final heldIsins = <String>{};
  final extraRows = <Widget>[];
  final missingRows = <Widget>[];

  for (final row in visibleRows) {
    final asset = assetById[row.assetId];
    final isin = asset?.isin?.trim();
    // Without a price or exchange rate there is no slice value: a dash.
    final assetValue = marketValues[row.assetId];
    final slice = assetValue == null
        ? '—'
        : '${amountFormat.format(row.total <= 0 ? 0.0 : assetValue * (row.current / row.total))} $baseCurrency';
    if (isin == null || isin.isEmpty) {
      extraRows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(asset?.name ?? '#${row.assetId}'),
          subtitle: Text(s.rebalanceMissingIsin),
          trailing: PrivacyText(slice),
        ),
      );
      continue;
    }
    final key = normaliseIsin(isin);
    heldIsins.add(key);
    if (!targetIsins.contains(key)) {
      extraRows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(asset?.name ?? '#${row.assetId}'),
          subtitle: Text(isin),
          trailing: PrivacyText(slice),
        ),
      );
    }
  }

  for (final entry in targetWeightByIsin.entries) {
    if (heldIsins.contains(entry.key)) continue;
    missingRows.add(
      ListTile(
        dense: true,
        leading: const Icon(Icons.link_off),
        title: Text(entry.key),
        subtitle: Text('${s.portfolioDivergenceTarget}: ${weightFormat.format(entry.value)}%'),
      ),
    );
  }

  final widgets = <Widget>[];
  if (extraRows.isNotEmpty) {
    widgets.add(const SizedBox(height: 4));
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Text(s.portfolioExtraHoldings, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    widgets.addAll(extraRows);
  }
  if (missingRows.isNotEmpty) {
    widgets.add(const SizedBox(height: 4));
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Text(s.portfolioUnmatchedRows, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
    widgets.addAll(missingRows);
  }
  if (widgets.isEmpty) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Text(s.portfolioDivergenceTitle),
      ),
    );
  }
  return widgets;
}

class _ObjectiveCard extends ConsumerWidget {
  final Pillar pillar;

  /// Null when every asset of the pillar is left out of it (see
  /// [unpricedCount]): unknown, shown as a dash and never as 0.
  final double? value;

  /// Assets in the pillar left out of [value]: no price or exchange rate.
  final int unpricedCount;
  final PillarPerformanceSnapshot? performance;
  final String locale;
  final String baseCurrency;
  const _ObjectiveCard({
    required this.pillar,
    required this.value,
    this.unpricedCount = 0,
    required this.performance,
    required this.locale,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final value = this.value;
    final hasTarget = pillar.targetValue != null && pillar.targetValue! > 0;
    // The target lives in its own currency: the progress needs it in the base
    // currency of [value], and there is none without an exchange rate.
    final targetInBase = pillarTargetInBase(ref, pillar, baseCurrency);
    final amountFormat = fmt.amountFormat(locale);
    final percentFormat = NumberFormat.percentPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    final excludedFromPerformance = performance?.excludedAssetCount ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: "Objective" for standard pillars; "Value & Performance"
            // for virtual portfolios (which have no target).
            Text(
              pillar.kind == PillarKind.virtual ? s.pillarValueAndPerformance : s.pillarObjective,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // An unknown value reads "—", which carries no magnitude: only a
            // real value is masked.
            if (value == null)
              Text(s.pillarValue('—'))
            else
              PrivacyText(s.pillarValue('${fmt.amountFormat(locale).format(value)} $baseCurrency')),
            if (unpricedCount > 0) Footnote(s.pillarUnpricedExcluded(unpricedCount)),
            if (hasTarget) ...[
              const SizedBox(height: 4),
              PrivacyText(s.pillarTarget('${fmt.amountFormat(locale).format(pillar.targetValue)} ${pillar.targetCurrency}')),
              const SizedBox(height: 8),
              if (targetInBase == null || value == null)
                const Text('—')
              else
                LinearProgressIndicator(
                  value: (value / targetInBase).clamp(0.0, 1.0),
                ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _PerformanceRow(
              label: s.pillarAbsoluteReturn,
              maskedValue: _formatReturnAmount(
                amountFormat: amountFormat,
                baseCurrency: baseCurrency,
                snapshot: performance,
              ),
              plainValue: _hasPerformance(performance) ? _formatPercent(performance?.absoluteReturnPct, percentFormat) : '—',
            ),
            const SizedBox(height: 8),
            _PerformanceRow(
              label: s.pillarTwrr,
              plainValue: _formatPercent(performance?.twrr, percentFormat),
            ),
            const SizedBox(height: 8),
            _PerformanceRow(
              label: s.pillarCagr,
              plainValue: _formatPercent(performance?.cagr, percentFormat),
            ),
            if (excludedFromPerformance > 0) ...[
              const SizedBox(height: 8),
              Footnote(s.pillarPerformanceExcluded(excludedFromPerformance)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One performance line, split along the privacy boundary.
///
/// [maskedValue] is position size (a return in currency) and is blurred in
/// privacy mode; [plainValue] is shape (a percentage) and always stays
/// readable. TWRR and CAGR pass only [plainValue]: blurring them with the rest
/// would hide the very numbers privacy mode is meant to preserve.
class _PerformanceRow extends StatelessWidget {
  final String label;
  final String? maskedValue;
  final String? plainValue;

  const _PerformanceRow({
    required this.label,
    this.maskedValue,
    this.plainValue,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        if (maskedValue != null)
          Flexible(
            child: PrivacyText(maskedValue!, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (maskedValue != null && plainValue != null) Text(' · ', style: style),
        if (plainValue != null) Text(plainValue!, style: style),
      ],
    );
  }
}

bool _hasPerformance(PillarPerformanceSnapshot? snapshot) => snapshot != null && !(snapshot.marketValue == 0 && snapshot.netInvested == 0);

/// The currency half of the absolute return. Kept separate from the percentage
/// so the amount can be masked while the percentage stays readable.
String _formatReturnAmount({
  required NumberFormat amountFormat,
  required String baseCurrency,
  required PillarPerformanceSnapshot? snapshot,
}) {
  if (!_hasPerformance(snapshot)) return '—';
  return '${amountFormat.format(snapshot!.absoluteReturnAmount)} $baseCurrency';
}

String _formatPercent(double? value, NumberFormat percentFormat) {
  if (value == null || !value.isFinite) return '—';
  return percentFormat.format(value);
}
