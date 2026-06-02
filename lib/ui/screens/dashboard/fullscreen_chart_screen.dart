import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/providers/providers.dart';
import 'dashboard_screen.dart' show ChartSeries, DragZoomWrapper, UnifiedChart, kChartRightReservedDual;

/// Immersive full-screen view of a single chart.
///
/// Pushed via a long-press or the expand icon on the dashboard chart card.
/// Allows device rotation (Apple HIG / Material 3 both recommend rotation
/// support for data-visualisation modals) and turns on full pinch X+Y +
/// drag pan via [DragZoomWrapper.fullPinch]. Restores portrait-only
/// orientation on dispose so the rest of the app stays portrait.
class FullscreenChartScreen extends ConsumerStatefulWidget {
  final String title;
  final List<ChartSeries> series;
  final List<FlSpot> totalSpots;
  final bool showTotal;
  final DateTime firstDate;
  final String baseCurrency;
  final bool isPrivate;

  const FullscreenChartScreen({
    super.key,
    required this.title,
    required this.series,
    required this.totalSpots,
    required this.showTotal,
    required this.firstDate,
    required this.baseCurrency,
    this.isPrivate = false,
  });

  @override
  ConsumerState<FullscreenChartScreen> createState() => _FullscreenChartScreenState();
}

class _FullscreenChartScreenState extends ConsumerState<FullscreenChartScreen> {
  double? _zoomMinX, _zoomMaxX, _zoomMinY, _zoomMaxY;

  @override
  void initState() {
    super.initState();
    // Allow landscape while we're in this screen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore portrait-only on the way out.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

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
    final s = ref.watch(appStringsProvider);
    final locale = ref.watch(appLocaleProvider).value ?? Platform.localeName;
    final langCode = ref.watch(portableLanguageProvider);
    final language = langCode.startsWith('it') ? 'it_IT' : 'en_US';

    final lastX = widget.totalSpots.isNotEmpty ? widget.totalSpots.last.x : 1.0;

    // Y range mirrors UnifiedChart's auto-fit so DragZoomWrapper's pixel→
    // chart math works on the same window the chart actually paints.
    final allY = [
      if (widget.showTotal) ...widget.totalSpots.map((p) => p.y),
      ...widget.series.where((s) => !s.rightAxis).expand((s) => s.spots.map((p) => p.y)),
    ];
    final autoMinY = allY.isEmpty ? 0.0 : allY.reduce(min);
    final autoMaxY = allY.isEmpty ? 100.0 : allY.reduce(max);
    final autoRange = autoMaxY - autoMinY;
    final effectiveMinY = _zoomMinY ?? (autoRange > 0 ? autoMinY - autoRange * 0.05 : autoMinY - 100);
    final effectiveMaxY = _zoomMaxY ?? (autoRange > 0 ? autoMaxY + autoRange * 0.05 : autoMaxY + 100);

    final hasZoom = _zoomMinX != null || _zoomMaxX != null || _zoomMinY != null || _zoomMaxY != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: s.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (hasZoom)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: s.resetZoom,
              onPressed: () => _onZoom(null, null, null, null),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: DragZoomWrapper(
            xMin: _zoomMinX ?? 0,
            xMax: _zoomMaxX ?? lastX,
            yMin: effectiveMinY,
            yMax: effectiveMaxY,
            totalDays: lastX,
            firstDate: widget.firstDate,
            baseCurrency: widget.baseCurrency,
            locale: locale,
            onZoom: _onZoom,
            rightReserved: widget.series.any((s) => s.rightAxis) ? kChartRightReservedDual : 0,
            zoomedY: _zoomMinY != null || _zoomMaxY != null,
            fullPinch: true,
            child: UnifiedChart(
              firstDate: widget.firstDate,
              visible: widget.series,
              totalSpots: widget.totalSpots,
              showTotal: widget.showTotal,
              baseCurrency: widget.baseCurrency,
              locale: locale,
              language: language,
              zoomMinX: _zoomMinX,
              zoomMaxX: _zoomMaxX,
              zoomMinY: _zoomMinY,
              zoomMaxY: _zoomMaxY,
              isPrivate: widget.isPrivate,
              liveZoom: true,
            ),
          ),
        ),
      ),
    );
  }
}
