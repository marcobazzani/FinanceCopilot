part of 'dashboard_screen.dart';

// ════════════════════════════════════════════════════
// Unified chart card widget
// ════════════════════════════════════════════════════

class _ChartCard extends ConsumerWidget {
  final DashboardChart chart;
  final List<ChartSeries> series;
  final AllSeriesData allData;
  final Set<String> hidden;
  final bool hideComponents;
  final String locale;
  final String language;
  final double chartHeight;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;
  final VoidCallback onToggleHideComponents;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;
  final ValueChanged<double> onHeightChanged;
  final Widget? headerExtra; // optional trailing widget in title bar (e.g. MA window input)
  final VoidCallback? onEdit;     // optional — shows edit icon when non-null (user charts)
  final VoidCallback? onDelete;   // optional — shows delete icon when non-null (user charts)
  final VoidCallback? onMoveUp;   // optional — shows up-arrow when non-null (reorderable)
  final VoidCallback? onMoveDown; // optional — shows down-arrow when non-null (reorderable)

  const _ChartCard({
    required this.chart,
    required this.series,
    required this.allData,
    required this.hidden,
    this.hideComponents = false,
    required this.locale,
    required this.language,
    required this.chartHeight,
    this.zoomMinX,
    this.zoomMaxX,
    this.zoomMinY,
    this.zoomMaxY,
    required this.onToggle,
    required this.onToggleGroup,
    required this.onToggleHideComponents,
    required this.onZoom,
    required this.onHeightChanged,
    this.headerExtra,
    this.onEdit,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  /// Build total spots with smart asset handling:
  /// If both invested and market are visible for the same asset, only sum market.
  List<FlSpot> _buildSmartTotalSpots(List<ChartSeries> visible) {
    // Find asset IDs that have both invested AND market visible
    final visibleInvestedIds = <int>{};
    final visibleMarketIds = <int>{};
    for (final s in visible) {
      final parts = s.key.split(':');
      if (parts.length != 2) continue;
      final id = int.tryParse(parts[1]);
      if (id == null) continue;
      if (parts[0] == 'asset_invested') visibleInvestedIds.add(id);
      if (parts[0] == 'asset_market') visibleMarketIds.add(id);
    }
    // Exclude invested series where market is also visible
    final excludeFromTotal = <String>{};
    for (final id in visibleInvestedIds) {
      if (visibleMarketIds.contains(id)) {
        excludeFromTotal.add('asset_invested:$id');
      }
    }
    final spotsForTotal = visible
        .where((s) => !excludeFromTotal.contains(s.key) && !s.rightAxis)
        .map((s) => s.spots)
        .toList();
    return buildTotalSpots(spotsForTotal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStringsProvider);
    final isPrivate = ref.watch(privacyModeProvider);
    final visible = series.where((s) => !hidden.contains(s.key)).toList();
    final totalSpots = _buildSmartTotalSpots(visible);
    final symbol = currencySymbol(allData.baseCurrency);
    final currentTotal = totalSpots.isNotEmpty ? totalSpots.last.y : 0.0;
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);

    // Series to actually draw (empty if hideComponents, but total is unaffected)
    final drawnSeries = hideComponents ? <ChartSeries>[] : visible;

    // Group series by type for legend
    final accountSeries = series.where((s) => s.key.startsWith('account:')).toList();
    final investedSeries = series.where((s) => s.key.startsWith('asset_invested:')).toList();
    final marketSeries = series.where((s) => s.key.startsWith('asset_market:')).toList();
    final adjustmentSeries = series.where((s) => s.key.startsWith('adjustment:')).toList();
    final incomeAdjSeries = series.where((s) => s.key.startsWith('income_adj:')).toList();
    final gainSeries = series.where((s) => s.key.startsWith('asset_gain:')).toList();
    final cfSeries = series.where((s) => s.key.startsWith('cf:')).toList();
    final combinedSeries = series.where((s) => s.key.startsWith('combined_src:')).toList();

    final hasZoom = zoomMinX != null || zoomMinY != null;

    return SizedBox(
      height: chartHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Row(
            children: [
              Expanded(
                child: Text(chart.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (chart.sourceChartIds == null)
                isPrivate
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Text(currFmt.format(currentTotal),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      )
                    : Text(currFmt.format(currentTotal),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              // Hide components toggle (not for combined charts — they only show contributors)
              if (chart.sourceChartIds == null)
                IconButton(
                  icon: Icon(hideComponents ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: onToggleHideComponents,
                  tooltip: hideComponents ? s.showComponents : s.hideComponents,
                ),
              if (hasZoom)
                IconButton(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  onPressed: () => onZoom(null, null, null, null),
                  tooltip: s.resetZoom,
                ),
              if (onMoveUp != null)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: onMoveUp,
                  tooltip: s.moveUp,
                ),
              if (onMoveDown != null)
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: onMoveDown,
                  tooltip: s.moveDown,
                ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: s.edit,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  tooltip: s.delete,
                ),
              ?headerExtra,
            ],
          ),
          const SizedBox(height: 4),

          // Legend
          if (!hideComponents) ...[
            _ChartLegend(
              accountSeries: cfSeries.isEmpty && combinedSeries.isEmpty ? accountSeries : [],
              investedSeries: cfSeries.isEmpty && combinedSeries.isEmpty ? investedSeries : [],
              marketSeries: cfSeries.isEmpty && combinedSeries.isEmpty ? marketSeries : [],
              adjustmentSeries: cfSeries.isEmpty && combinedSeries.isEmpty ? adjustmentSeries : [],
              incomeAdjSeries: cfSeries.isEmpty && combinedSeries.isEmpty ? incomeAdjSeries : [],
              otherSeries: combinedSeries.isNotEmpty ? combinedSeries : (cfSeries.isNotEmpty ? cfSeries : gainSeries),
              showTotalItem: chart.sourceChartIds == null && cfSeries.isEmpty,
              hidden: hidden,
              onToggle: onToggle,
              onToggleGroup: onToggleGroup,
              accountsLabel: s.legendAccounts,
              spreadAdjLabel: s.legendSpreadAdj,
              incomeAdjLabel: s.legendIncomeAdj,
              assetsLabel: s.dashAssets,
              totalLabel: s.legendTotal,
            ),
            const SizedBox(height: 8),
          ],

          // Chart
          Expanded(
            child: totalSpots.length >= 2
                ? Builder(builder: (context) {
                    // Compute Y range so _DragZoomWrapper can map pixels to chart Y
                    // Must match _UnifiedChart's Y range: include total only when shown
                    final showTotal = chart.sourceChartIds == null && !hidden.contains('_total');
                    final allY = [
                      if (showTotal) ...totalSpots.map((s) => s.y),
                      ...drawnSeries.where((s) => !s.rightAxis).expand((s) => s.spots.map((p) => p.y)),
                    ];
                    final autoMinY = allY.isEmpty ? 0.0 : allY.reduce(min);
                    final autoMaxY = allY.isEmpty ? 100.0 : allY.reduce(max);
                    final autoRange = autoMaxY - autoMinY;
                    final effectiveMinY = zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
                    final effectiveMaxY = zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);

                    return DragZoomWrapper(
                      xMin: zoomMinX ?? 0,
                      xMax: zoomMaxX ?? (totalSpots.isNotEmpty ? totalSpots.last.x : 1),
                      yMin: effectiveMinY,
                      yMax: effectiveMaxY,
                      totalDays: totalSpots.isNotEmpty ? totalSpots.last.x : 1,
                      firstDate: allData.firstDate,
                      baseCurrency: allData.baseCurrency,
                      locale: locale,
                      onZoom: onZoom,
                      zoomedY: zoomMinY != null || zoomMaxY != null,
                      child: UnifiedChart(
                        firstDate: allData.firstDate,
                        visible: drawnSeries,
                        totalSpots: totalSpots,
                        showTotal: chart.sourceChartIds == null && !hidden.contains('_total'),
                        baseCurrency: allData.baseCurrency,
                        locale: locale,
                        language: language,
                        zoomMinX: zoomMinX,
                        zoomMaxX: zoomMaxX,
                        zoomMinY: zoomMinY,
                        zoomMaxY: zoomMaxY,
                        isPrivate: isPrivate,
                        zoomedX: zoomMinX != null || zoomMaxX != null,
                      ),
                    );
                  })
                : Center(child: Text(s.dashNotEnoughData, style: const TextStyle(color: Colors.grey))),
          ),

          // Resize handle
          GestureDetector(
            onVerticalDragUpdate: (d) {
              onHeightChanged(chartHeight + d.delta.dy);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: Center(
                child: Container(
                  width: 40,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Chart legend (grouped)
// ════════════════════════════════════════════════════

class _ChartLegend extends StatelessWidget {
  final List<ChartSeries> accountSeries;
  final List<ChartSeries> investedSeries;
  final List<ChartSeries> marketSeries;
  final List<ChartSeries> adjustmentSeries;
  final List<ChartSeries> incomeAdjSeries;
  final List<ChartSeries> otherSeries; // e.g. cash-flow series with cf: prefix
  final bool showTotalItem;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<Set<String>> onToggleGroup;
  final String accountsLabel;
  final String spreadAdjLabel;
  final String incomeAdjLabel;
  final String assetsLabel;
  final String totalLabel;

  const _ChartLegend({
    required this.accountSeries,
    required this.investedSeries,
    required this.marketSeries,
    required this.adjustmentSeries,
    required this.incomeAdjSeries,
    this.otherSeries = const [],
    this.showTotalItem = true,
    required this.hidden,
    required this.onToggle,
    required this.onToggleGroup,
    required this.accountsLabel,
    required this.spreadAdjLabel,
    required this.incomeAdjLabel,
    required this.assetsLabel,
    required this.totalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (accountSeries.isNotEmpty)
          ..._buildGroup(context, accountsLabel, accountSeries),
        if (investedSeries.isNotEmpty || marketSeries.isNotEmpty)
          ..._buildAssetGroup(context),
        if (adjustmentSeries.isNotEmpty)
          ..._buildGroup(context, spreadAdjLabel, adjustmentSeries),
        if (incomeAdjSeries.isNotEmpty)
          ..._buildGroup(context, incomeAdjLabel, incomeAdjSeries),
        for (final s in otherSeries)
          _ToggleLegendItem(
            color: s.color,
            label: s.rightAxis ? '${s.name} (\u2192)' : s.name,
            dashed: s.isDashed,
            enabled: !hidden.contains(s.key),
            onTap: () => onToggle(s.key),
          ),
        if (showTotalItem)
          _ToggleLegendItem(
            color: Colors.white,
            label: totalLabel,
            bold: true,
            enabled: !hidden.contains('_total'),
            onTap: () => onToggle('_total'),
          ),
      ],
    );
  }

  List<Widget> _buildGroup(BuildContext context, String label, List<ChartSeries> series) {
    final keys = series.map((s) => s.key).toSet();
    final allHidden = keys.every(hidden.contains);

    return [
      GestureDetector(
        onTap: () => onToggleGroup(keys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: !allHidden
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: !allHidden
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              decoration: !allHidden ? null : TextDecoration.lineThrough,
            )),
          ),
        ),
      ),
      for (final s in series)
        _ToggleLegendItem(
          color: s.color,
          label: s.name,
          dashed: s.isDashed,
          enabled: !hidden.contains(s.key),
          onTap: () => onToggle(s.key),
        ),
      const SizedBox(width: 4),
    ];
  }

  List<Widget> _buildAssetGroup(BuildContext context) {
    // Combine invested + market keys for group toggle
    final allKeys = {...investedSeries.map((s) => s.key), ...marketSeries.map((s) => s.key)};
    final allHidden = allKeys.isNotEmpty && allKeys.every(hidden.contains);

    final widgets = <Widget>[
      GestureDetector(
        onTap: () => onToggleGroup(allKeys),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: !allHidden
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Text(assetsLabel, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: !allHidden
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              decoration: !allHidden ? null : TextDecoration.lineThrough,
            )),
          ),
        ),
      ),
    ];

    // Show each unique asset with one legend item per series type present
    final shownAssets = <int>{};
    for (final s in [...marketSeries, ...investedSeries]) {
      final id = int.tryParse(s.key.split(':').last);
      if (id == null || !shownAssets.add(id)) continue;
      final inv = investedSeries.where((s) => s.key == 'asset_invested:$id');
      final mkt = marketSeries.where((s) => s.key == 'asset_market:$id');

      // Show market value (solid) if present
      if (mkt.isNotEmpty) {
        widgets.add(_ToggleLegendItem(
          color: mkt.first.color,
          label: mkt.first.name,
          enabled: !hidden.contains(mkt.first.key),
          onTap: () => onToggle(mkt.first.key),
        ));
      }
      // Show invested (dashed) if present
      if (inv.isNotEmpty) {
        widgets.add(_ToggleLegendItem(
          color: inv.first.color,
          label: inv.first.name,
          dashed: true,
          enabled: !hidden.contains(inv.first.key),
          onTap: () => onToggle(inv.first.key),
        ));
      }
    }

    widgets.add(const SizedBox(width: 4));
    return widgets;
  }
}

// ════════════════════════════════════════════════════
// Legend item with tap-to-toggle
// ════════════════════════════════════════════════════

class _ToggleLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final bool bold;
  final bool enabled;
  final VoidCallback? onTap;

  const _ToggleLegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
    this.bold = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dashed)
              SizedBox(
                width: 12,
                height: 3,
                child: CustomPaint(painter: DashedLinePainter(effectiveColor)),
              )
            else
              Container(width: 12, height: 3, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                decoration: enabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
