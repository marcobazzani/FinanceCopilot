part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Financial Health Tab
// ════════════════════════════════════════════════════

class _FinancialHealthTab extends ConsumerWidget {
  const _FinancialHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final assetsAsync = ref.watch(assetsProvider);
    final marketValuesAsync = ref.watch(assetMarketValuesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider).value ?? 'EUR';
    final locale = ref.watch(appLocaleProvider).value ?? 'en_US';
    final isPrivate = ref.watch(privacyModeProvider);

    final symbol = currencySymbol(baseCurrency);
    final amtFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);
    final pctFmt = NumberFormat('0.00', locale);

    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.error(e))),
      data: (assets) {
        final marketValues = marketValuesAsync.value ?? {};
        final activeAssets = assets.where((a) => a.isActive).toList();

        // Build cost rows for assets with TER
        final rows = <_CostRow>[];
        double totalValue = 0;
        double totalCost = 0;

        for (final asset in activeAssets) {
          final mv = marketValues[asset.id];
          if (mv == null || mv <= 0) continue;
          totalValue += mv;
          if (asset.ter != null && asset.ter! > 0) {
            final annualCost = mv * asset.ter! / 100;
            rows.add(_CostRow(
              name: asset.ticker ?? asset.name,
              fullName: asset.name,
              ter: asset.ter!,
              marketValue: mv,
              annualCost: annualCost,
            ));
            totalCost += annualCost;
          } else {
            rows.add(_CostRow(
              name: asset.ticker ?? asset.name,
              fullName: asset.name,
              ter: null,
              marketValue: mv,
              annualCost: 0,
            ));
          }
        }

        // Sort by annual cost descending
        rows.sort((a, b) => b.annualCost.compareTo(a.annualCost));

        final weightedTer = totalValue > 0 ? totalCost / totalValue * 100 : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Investment Costs Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.healthInvestmentCosts,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      if (rows.isEmpty)
                        Text(s.healthNoTer, style: TextStyle(color: Colors.grey))
                      else ...[
                        // Header row
                        _buildHeaderRow(context, s),
                        const Divider(height: 1),
                        // Data rows
                        ...rows.map((row) => _buildCostRow(context, row, amtFmt, pctFmt, isPrivate)),
                        // Total row
                        const Divider(height: 16, thickness: 2),
                        _buildTotalRow(context, s, totalValue, totalCost, weightedTer, amtFmt, pctFmt, isPrivate),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow(BuildContext context, AppStrings s) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.grey,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(s.healthAsset, style: style)),
          Expanded(flex: 2, child: Text(s.healthTer, style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(s.healthMarketValue, style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(s.healthAnnualCost, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildCostRow(BuildContext context, _CostRow row, NumberFormat amtFmt, NumberFormat pctFmt, bool isPrivate) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 13);
    final valueStyle = theme.textTheme.bodySmall?.copyWith(fontSize: 13);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Tooltip(
              message: row.fullName,
              child: Text(row.name, style: nameStyle, overflow: TextOverflow.ellipsis),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.ter != null ? '${pctFmt.format(row.ter)}%' : '-',
              style: valueStyle?.copyWith(
                color: row.ter != null ? _terColor(row.ter!) : Colors.grey,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: PrivacyText(
              amtFmt.format(row.marketValue),
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: PrivacyText(
              row.ter != null ? amtFmt.format(row.annualCost) : '-',
              style: valueStyle?.copyWith(
                color: row.ter != null ? Colors.red.shade300 : Colors.grey,
                fontWeight: row.ter != null ? FontWeight.w600 : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context, AppStrings s, double totalValue,
      double totalCost, double weightedTer, NumberFormat amtFmt, NumberFormat pctFmt, bool isPrivate) {
    final theme = Theme.of(context);
    final boldStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(s.healthWeightedTer, style: boldStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${pctFmt.format(weightedTer)}%',
              style: boldStyle?.copyWith(color: _terColor(weightedTer)),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: PrivacyText(
              amtFmt.format(totalValue),
              style: boldStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: PrivacyText(
              amtFmt.format(totalCost),
              style: boldStyle?.copyWith(color: Colors.red.shade400),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Color TER values: green (low cost) → yellow → red (high cost)
  static Color _terColor(double ter) {
    if (ter <= 0.20) return Colors.green.shade400;
    if (ter <= 0.50) return Colors.lightGreen;
    if (ter <= 1.00) return Colors.orange;
    return Colors.red.shade400;
  }
}

class _CostRow {
  final String name;
  final String fullName;
  final double? ter;
  final double marketValue;
  final double annualCost;
  const _CostRow({
    required this.name,
    required this.fullName,
    required this.ter,
    required this.marketValue,
    required this.annualCost,
  });
}
