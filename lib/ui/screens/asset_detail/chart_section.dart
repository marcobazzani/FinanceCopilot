part of '../asset_detail_screen.dart';

class _AssetChartSection extends ConsumerWidget {
  final int assetId;
  const _AssetChartSection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(singleAssetChartDataProvider(assetId));
    return chartDataAsync.when(
      data: (data) {
        if (data == null || data.marketSeries.spots.length < 2) {
          return const SizedBox.shrink();
        }
        final s = ref.watch(appStringsProvider);
        final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
        final baseSymbol = currencySymbol(data.baseCurrency);
        final baseFmt = fmt.currencyFormat(locale, baseSymbol, decimalDigits: 0);
        final assetSymbol = currencySymbol(data.assetCurrency);
        final assetFmt = fmt.currencyFormat(locale, assetSymbol);
        return Column(
          children: [
            _AssetChartCard(
              title: s.colAsset,
              titleValue: baseFmt.format(data.marketSeries.spots.last.y),
              series: [data.investedSeries, data.marketSeries],
              firstDate: data.firstDate,
              currency: data.baseCurrency,
            ),
            if (data.priceSeries.spots.length >= 2)
              _AssetChartCard(
                title: s.colPrice,
                titleValue: assetFmt.format(data.priceSeries.spots.last.y),
                series: [data.priceSeries],
                firstDate: data.firstDate,
                currency: data.assetCurrency,
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Reusable collapsible chart card. Uses show/hide instead of ExpansionTile
/// children list to avoid animating the chart widget (which causes jank).
class _AssetChartCard extends ConsumerStatefulWidget {
  final String title;
  final String titleValue;
  final List<ChartSeries> series;
  final DateTime firstDate;
  final String currency; // for axis labels

  const _AssetChartCard({
    required this.title,
    required this.titleValue,
    required this.series,
    required this.firstDate,
    required this.currency,
  });

  @override
  ConsumerState<_AssetChartCard> createState() => _AssetChartCardState();
}

class _AssetChartCardState extends ConsumerState<_AssetChartCard> {
  bool _expanded = false;
  double? _zoomMinX, _zoomMaxX, _zoomMinY, _zoomMaxY;

  void _onZoom(double? minX, double? maxX, double? minY, double? maxY) {
    setState(() {
      _zoomMinX = minX;
      _zoomMaxX = maxX;
      _zoomMinY = minY;
      _zoomMaxY = maxY;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSpots = widget.series.expand((s) => s.spots).toList();
    if (allSpots.length < 2) return const SizedBox.shrink();

    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final language = locale.split('_').first;
    final isPrivate = ref.watch(privacyModeProvider);
    final s = ref.watch(appStringsProvider);
    final hasZoom = _zoomMinX != null || _zoomMinY != null;

    // X range from all series
    final lastX = allSpots.map((s) => s.x).reduce(max);

    // Y range from all series
    final allY = allSpots.map((s) => s.y).toList();
    final autoMinY = allY.reduce(min);
    final autoMaxY = allY.reduce(max);
    final autoRange = autoMaxY - autoMinY;
    final effectiveMinY = _zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
    final effectiveMaxY = _zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  if (isPrivate)
                    const Text('****', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                  else
                    Text(widget.titleValue,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded ? Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    DragZoomWrapper(
                      xMin: _zoomMinX ?? 0,
                      xMax: _zoomMaxX ?? lastX,
                      yMin: effectiveMinY,
                      yMax: effectiveMaxY,
                      totalDays: lastX,
                      firstDate: widget.firstDate,
                      baseCurrency: widget.currency,
                      locale: locale,
                      onZoom: _onZoom,
                      zoomedY: _zoomMinY != null || _zoomMaxY != null,
                      child: UnifiedChart(
                        firstDate: widget.firstDate,
                        visible: widget.series,
                        totalSpots: widget.series.first.spots,
                        showTotal: false,
                        baseCurrency: widget.currency,
                        locale: locale,
                        language: language,
                        zoomMinX: _zoomMinX,
                        zoomMaxX: _zoomMaxX,
                        zoomMinY: _zoomMinY,
                        zoomMaxY: _zoomMaxY,
                        isPrivate: isPrivate,
                      ),
                    ),
                    if (hasZoom)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.zoom_out_map, size: 18),
                          onPressed: () => _onZoom(null, null, null, null),
                          tooltip: s.resetZoom,
                        ),
                      ),
                  ],
                ),
              ),
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Composition breakdown section
// ──────────────────────────────────────────────
