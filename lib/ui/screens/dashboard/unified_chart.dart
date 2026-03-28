part of 'dashboard_screen.dart';

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 3.0;
    const gap = 2.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + dashWidth, size.width), size.height / 2),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════
// Drag-to-zoom wrapper (CloudWatch style)
// ════════════════════════════════════════════════════

class _DragZoomWrapper extends StatefulWidget {
  final Widget child;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double leftReserved;
  final double bottomReserved;
  final DateTime firstDate;
  final String baseCurrency;
  final String locale;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;

  const _DragZoomWrapper({
    required this.child,
    required this.xMin,
    required this.xMax,
    this.yMin = 0,
    this.yMax = 1,
    this.leftReserved = 60,
    this.bottomReserved = 28,
    required this.firstDate,
    required this.baseCurrency,
    required this.locale,
    required this.onZoom,
  });

  @override
  State<_DragZoomWrapper> createState() => _DragZoomWrapperState();
}

class _DragZoomWrapperState extends State<_DragZoomWrapper> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;

  double _pixelToChartX(double px, double chartWidth) {
    final fraction = (px - widget.leftReserved) / chartWidth;
    return widget.xMin + fraction * (widget.xMax - widget.xMin);
  }

  double _pixelToChartY(double py, double chartHeight) {
    // Y is inverted: top of widget = max Y, bottom of chart area = min Y
    final fraction = 1.0 - (py / chartHeight);
    return widget.yMin + fraction * (widget.yMax - widget.yMin);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - widget.leftReserved;
        final chartHeight = constraints.maxHeight - widget.bottomReserved;
        final dateFmt = fmt.fullDateFormat(widget.locale);
        final currFmt = fmt.currencyFormat(widget.locale, currencySymbol(widget.baseCurrency), decimalDigits: 0);

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            setState(() {
              _dragStart = e.localPosition;
              _dragCurrent = e.localPosition;
              _isDragging = false;
            });
          },
          onPointerMove: (e) {
            if (_dragStart == null) return;
            final dist = (e.localPosition - _dragStart!).distance;
            if (dist > 5) _isDragging = true;
            if (_isDragging) {
              setState(() => _dragCurrent = e.localPosition);
            }
          },
          onPointerUp: (e) {
            if (_isDragging && _dragStart != null && _dragCurrent != null) {
              final x1 = _pixelToChartX(_dragStart!.dx, chartWidth);
              final x2 = _pixelToChartX(_dragCurrent!.dx, chartWidth);
              final y1 = _pixelToChartY(_dragStart!.dy, chartHeight);
              final y2 = _pixelToChartY(_dragCurrent!.dy, chartHeight);
              final xLo = min(x1, x2);
              final xHi = max(x1, x2);
              final yLo = min(y1, y2);
              final yHi = max(y1, y2);

              final xSpan = xHi - xLo;
              final ySpan = yHi - yLo;
              final yRange = widget.yMax - widget.yMin;

              double? newMinX, newMaxX, newMinY, newMaxY;
              if (xSpan > 10) {
                newMinX = max(0, xLo);
                newMaxX = min(widget.xMax, xHi);
              }
              if (yRange > 0 && ySpan > yRange * 0.05) {
                newMinY = yLo;
                newMaxY = yHi;
              }
              if (newMinX != null || newMinY != null) {
                widget.onZoom(newMinX ?? widget.xMin, newMaxX ?? widget.xMax, newMinY, newMaxY);
              }
            }
            setState(() {
              _dragStart = null;
              _dragCurrent = null;
              _isDragging = false;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () => widget.onZoom(null, null, null, null),
            child: Stack(
              children: [
                widget.child,
                if (_isDragging && _dragStart != null && _dragCurrent != null)
                  Positioned(
                    left: min(_dragStart!.dx, _dragCurrent!.dx),
                    top: min(_dragStart!.dy, _dragCurrent!.dy),
                    width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                    height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.blue.withValues(alpha: 0.7),
                            child: Text(
                              '${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(min(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt())))} \u2013 '
                              '${dateFmt.format(widget.firstDate.add(Duration(days: _pixelToChartX(max(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt())))}\n'
                              '${currFmt.format(_pixelToChartY(max(_dragStart!.dy, _dragCurrent!.dy), chartHeight))} \u2013 '
                              '${currFmt.format(_pixelToChartY(min(_dragStart!.dy, _dragCurrent!.dy), chartHeight))}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Unified chart widget
// ════════════════════════════════════════════════════

class _UnifiedChart extends StatelessWidget {
  final DateTime firstDate;
  final List<_Series> visible;
  final List<FlSpot> totalSpots;
  final bool showTotal;
  final String baseCurrency;
  final String locale;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;
  final bool isPrivate;

  const _UnifiedChart({
    required this.firstDate,
    required this.visible,
    required this.totalSpots,
    this.showTotal = true,
    required this.baseCurrency,
    required this.locale,
    this.zoomMinX,
    this.zoomMaxX,
    this.zoomMinY,
    this.zoomMaxY,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(baseCurrency);

    final totalDays = totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;
    final dateFmt = fmt.monthYearFormat(locale);
    final fullFmt = fmt.fullDateFormat(locale);
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: 0);

    // ── Dual Y-axis setup ──
    final leftVisible  = visible.where((s) => !s.rightAxis).toList();
    final rightVisible = visible.where((s) =>  s.rightAxis).toList();
    final hasDualAxis  = rightVisible.isNotEmpty;

    // Left Y range (left series + total)
    final leftY = [
      if (showTotal) ...totalSpots.map((s) => s.y),
      ...leftVisible.expand((s) => s.spots.map((p) => p.y)),
    ];
    final leftAutoMin = leftY.isEmpty ? 0.0  : leftY.reduce(min);
    final leftAutoMax = leftY.isEmpty ? 100.0 : leftY.reduce(max);
    final leftAutoRange = leftAutoMax - leftAutoMin;
    final chartMinY = zoomMinY ?? (leftAutoRange > 0 ? leftAutoMin - leftAutoRange * 0.05 : leftAutoMin - 100);
    final chartMaxY = zoomMaxY ?? (leftAutoRange > 0 ? leftAutoMax + leftAutoRange * 0.05 : leftAutoMax + 100);
    final chartRange = chartMaxY - chartMinY;
    final yRange = chartRange;

    // Right Y range (natural scale, not zoomed — always shows full range)
    double rightNatMin = 0, rightNatMax = 1;
    if (hasDualAxis) {
      final rightY = rightVisible.expand((s) => s.spots.map((p) => p.y)).toList();
      if (rightY.isNotEmpty) {
        rightNatMin = rightY.reduce(min);
        rightNatMax = rightY.reduce(max);
      }
    }
    final rightNatRange = (rightNatMax - rightNatMin).abs().clamp(1e-9, double.infinity);

    // Scale right-axis value → left pixel space
    double scaleRight(double y) =>
        chartRange <= 0 ? chartMinY : (y - rightNatMin) / rightNatRange * chartRange + chartMinY;

    // Reverse-scale left-pixel value → actual right-axis value (for tooltip/labels)
    double unscaleRight(double scaledY) =>
        chartRange <= 0 ? rightNatMin : (scaledY - chartMinY) / chartRange * rightNatRange + rightNatMin;

    final lineBars = <LineChartBarData>[];

    // Total line (always left axis)
    if (showTotal) {
      lineBars.add(LineChartBarData(
        spots: totalSpots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: isDark ? Colors.white : theme.colorScheme.primary,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.08),
        ),
      ));
    }

    // Visible series lines (right-axis series are scaled into left pixel space)
    for (final s in visible) {
      final spots = s.rightAxis
          ? s.spots.map((pt) => FlSpot(pt.x, scaleRight(pt.y))).toList()
          : s.spots;
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: s.rightAxis ? 1.5 : (s.isDashed ? 1.5 : 2),
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        dashArray: s.isDashed ? [6, 3] : null,
      ));
    }

    final xMin = zoomMinX ?? 0;
    final xMax = zoomMaxX ?? totalDays;
    final xRange = xMax - xMin;

    return LineChart(
      LineChartData(
        minX: xMin,
        maxX: xMax,
        minY: chartMinY,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yRange > 0 ? yRange / 4 : 100,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: hasDualAxis,
              reservedSize: hasDualAxis ? 68 : 0,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (scaledY, meta) {
                final actualY = unscaleRight(scaledY);
                final label = isPrivate ? '\u2022\u2022\u2022\u2022' : currFmt.format(actualY);
                return Text(label, style: TextStyle(fontSize: 9, color: textColor));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: xRange > 0 ? xRange / 5 : 1,
              getTitlesWidget: (value, meta) {
                final date = firstDate.add(Duration(days: value.toInt()));
                return SideTitleWidget(
                  meta: meta,
                  angle: -0.5,
                  child: Text(dateFmt.format(date),
                      style: TextStyle(fontSize: 10, color: textColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (value, meta) {
                final label = this.isPrivate ? '\u2022\u2022\u2022\u2022' : currFmt.format(value);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label,
                      style: TextStyle(fontSize: 10, color: textColor)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipMargin: 16,
            maxContentWidth: 200,
            getTooltipItems: (spots) {
              final items = <LineTooltipItem?>[];
              for (int spotIdx = 0; spotIdx < spots.length; spotIdx++) {
                final spot = spots[spotIdx];
                final barIndex = spot.barIndex;
                final isTotal = showTotal && barIndex == 0;
                final seriesIdx = barIndex - (showTotal ? 1 : 0);
                final date = firstDate.add(Duration(days: spot.x.toInt()));
                final datePrefix = spotIdx == 0 ? '${fullFmt.format(date)}\n' : '';

                if (isTotal) {
                  items.add(LineTooltipItem(
                    '${fullFmt.format(date)}\nTotal: ${currFmt.format(spot.y)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ));
                } else if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  final displayY = s.rightAxis ? unscaleRight(spot.y) : spot.y;
                  items.add(LineTooltipItem(
                    '$datePrefix${s.name}: ${currFmt.format(displayY)}${s.rightAxis ? ' (\u2192)' : ''}',
                    TextStyle(color: s.color, fontSize: 11),
                  ));
                } else {
                  items.add(null);
                }
              }
              return items;
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}
