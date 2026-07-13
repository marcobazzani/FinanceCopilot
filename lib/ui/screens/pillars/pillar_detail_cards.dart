part of 'pillar_detail_screen.dart';

class _AssetSliderRow extends StatelessWidget {
  final _AssetRowState row;
  final Asset? asset;
  final double assetMarketValue;
  final String baseCurrency;
  final String locale;
  final double? targetWeight;
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
    final pf = NumberFormat.percentPattern(locale)..maximumFractionDigits = 1;
    final sliceValue = row.total <= 0 ? 0.0 : assetMarketValue * (row.current / row.total);
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
                '${amf.format(assetMarketValue)} $baseCurrency',
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
            child: PrivacyText(
              '${s.pillarUnitsOf(qf.format(row.current), qf.format(row.total))} · ${amf.format(sliceValue)} $baseCurrency · ${s.pillarMaxPercent(maxPct.round())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (targetWeight != null && currentWeight != null) ...[
            const SizedBox(height: 4),
            PrivacyText(
              '${s.portfolioDivergenceTarget}: ${targetWeight!.toStringAsFixed(2)}% · '
              '${s.portfolioDivergenceCurrent}: ${currentWeight!.toStringAsFixed(2)}% · '
              '${s.portfolioDivergenceDelta}: ${(currentWeight! - targetWeight!).toStringAsFixed(2)}%',
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
  final targetIsins = targetWeightByIsin.keys.toSet();
  final heldIsins = <String>{};
  final extraRows = <Widget>[];
  final missingRows = <Widget>[];

  for (final row in visibleRows) {
    final asset = assetById[row.assetId];
    final isin = asset?.isin?.trim();
    final assetValue = marketValues[row.assetId] ?? 0;
    final sliceValue = row.total <= 0 ? 0.0 : assetValue * (row.current / row.total);
    if (isin == null || isin.isEmpty) {
      extraRows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(asset?.name ?? '#${row.assetId}'),
          subtitle: Text(s.rebalanceMissingIsin),
          trailing: Text('${amountFormat.format(sliceValue)} $baseCurrency'),
        ),
      );
      continue;
    }
    final key = _normaliseIsin(isin);
    heldIsins.add(key);
    if (!targetIsins.contains(key)) {
      extraRows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.add_circle_outline),
          title: Text(asset?.name ?? '#${row.assetId}'),
          subtitle: Text(isin),
          trailing: Text('${amountFormat.format(sliceValue)} $baseCurrency'),
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
        subtitle: Text('${s.portfolioDivergenceTarget}: ${entry.value.toStringAsFixed(2)}%'),
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

String _normaliseIsin(String value) => value.trim().toUpperCase();

class _ObjectiveCard extends ConsumerWidget {
  final Pillar pillar;
  final double value;
  final PillarPerformanceSnapshot? performance;
  final String locale;
  final String baseCurrency;
  const _ObjectiveCard({
    required this.pillar,
    required this.value,
    required this.performance,
    required this.locale,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final hasTarget = pillar.targetValue != null && pillar.targetValue! > 0;
    final amountFormat = fmt.amountFormat(locale);
    final percentFormat = NumberFormat.percentPattern(locale)
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
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
            PrivacyText(s.pillarValue('${fmt.amountFormat(locale).format(value)} $baseCurrency')),
            if (hasTarget) ...[
              const SizedBox(height: 4),
              PrivacyText(s.pillarTarget('${fmt.amountFormat(locale).format(pillar.targetValue)} ${pillar.targetCurrency}')),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (value / pillar.targetValue!).clamp(0.0, 1.0),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _PerformanceRow(
              label: s.pillarAbsoluteReturn,
              value: _formatAbsoluteReturn(
                amountFormat: amountFormat,
                percentFormat: percentFormat,
                baseCurrency: baseCurrency,
                snapshot: performance,
              ),
            ),
            const SizedBox(height: 8),
            _PerformanceRow(
              label: s.pillarTwrr,
              value: _formatPercent(
                performance?.twrr,
                percentFormat,
              ),
            ),
            const SizedBox(height: 8),
            _PerformanceRow(
              label: s.pillarCagr,
              value: _formatPercent(
                performance?.cagr,
                percentFormat,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PerformanceRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        PrivacyText(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

String _formatAbsoluteReturn({
  required NumberFormat amountFormat,
  required NumberFormat percentFormat,
  required String baseCurrency,
  required PillarPerformanceSnapshot? snapshot,
}) {
  if (snapshot == null || (snapshot.marketValue == 0 && snapshot.netInvested == 0)) {
    return '—';
  }
  final amount = '${amountFormat.format(snapshot.absoluteReturnAmount)} $baseCurrency';
  final pct = _formatPercent(snapshot.absoluteReturnPct, percentFormat);
  return '$amount · $pct';
}

String _formatPercent(double? value, NumberFormat percentFormat) {
  if (value == null || !value.isFinite) return '—';
  return percentFormat.format(value);
}
