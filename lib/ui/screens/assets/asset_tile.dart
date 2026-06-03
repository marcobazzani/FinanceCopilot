part of 'assets_screen.dart';

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
                color: asset.isActive ? theme.colorScheme.primaryContainer : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.pie_chart,
                size: 20,
                color: asset.isActive ? theme.colorScheme.onPrimaryContainer : Colors.grey,
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
                  ] else if (convertedInvested != null && convertedInvested! > 0) ...[
                    const SizedBox(height: 2),
                    _buildGainLoss(theme, amtFormat),
                  ],
                ] else if (stats != null && stats!.totalInvested > 0)
                  PrivacyText(
                    '${amtFormat.format(stats!.totalInvested)} ${asset.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: asset.isActive ? theme.colorScheme.primary : Colors.grey,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  // Quantity reveals position size — blur the whole
                  // price×quantity line in privacy mode.
                  PrivacyBlur(
                    child: Text.rich(
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
                  ),
                ],
                if (!asset.isActive) ...[
                  const SizedBox(height: 2),
                  Text(strings.inactive, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
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
                        if (asset.intermediaryId == i.id) const Icon(Icons.check, size: 18),
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
    parts.add(
      TextSpan(
        text: strings.nEvents(stats!.eventCount),
        style: style,
      ),
    );

    // Date range
    if (stats!.firstDate != null) {
      parts.add(
        TextSpan(
          text: '  ·  ${strings.sinceDate(dateFormat.format(stats!.firstDate!))}',
          style: style,
        ),
      );
    }
    if (stats!.lastDate != null) {
      parts.add(
        TextSpan(
          text: '  ·  ${strings.lastDate(dateFormat.format(stats!.lastDate!))}',
          style: style,
        ),
      );
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
  final siblings = results.where((x) => x.description.isNotEmpty && x.description == picked.description && isKnownExchange(x.exchange)).toList();
  return siblings.isNotEmpty ? siblings : [picked];
}

// ──────────────────────────────────────────────
// Create Asset Dialog — two-step search flow
// ──────────────────────────────────────────────
