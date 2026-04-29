part of 'dashboard_screen.dart';

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter(this.color);

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
// Zoom math helpers (file-local, unit-tested)
// ════════════════════════════════════════════════════

/// Compute a new X window after zooming and/or panning, anchored at the
/// focal pixel. Result is clamped to `[0, totalDays]`. When the resulting
/// span would meet or exceed `totalDays`, the full data range is returned.
({double minX, double maxX}) computeZoomedXRange({
  required double currentMinX,
  required double currentMaxX,
  required double focalPx,
  required double leftReserved,
  required double chartWidth,
  required double scaleFactor,
  required double panPx,
  required double totalDays,
}) {
  final currentRange = currentMaxX - currentMinX;
  final pxFromLeft = focalPx - leftReserved;
  final focalChartX = currentMinX + pxFromLeft / chartWidth * currentRange;

  var newRange = currentRange / scaleFactor;
  if (newRange >= totalDays) return (minX: 0, maxX: totalDays);
  if (newRange < 1) newRange = 1;

  var newMinX = focalChartX - pxFromLeft / chartWidth * newRange - panPx * (newRange / chartWidth);
  var newMaxX = newMinX + newRange;

  if (newMinX < 0) {
    newMinX = 0;
    newMaxX = newRange;
  }
  if (newMaxX > totalDays) {
    newMaxX = totalDays;
    newMinX = totalDays - newRange;
  }
  return (minX: newMinX, maxX: newMaxX);
}

/// Compute a new Y window after zooming and/or panning, anchored at the
/// focal pixel. Y axis is inverted vs pixels (pixel 0 = top = max Y).
/// Y has no clamping — chart data may legitimately extend beyond the
/// current zoom window.
({double minY, double maxY}) computeZoomedYRange({
  required double currentMinY,
  required double currentMaxY,
  required double focalPy,
  required double chartHeight,
  required double scaleFactor,
  required double panPy,
}) {
  final currentRange = currentMaxY - currentMinY;
  final fractionFromBottom = 1.0 - focalPy / chartHeight;
  final focalChartY = currentMinY + fractionFromBottom * currentRange;

  final newRange = currentRange / scaleFactor;
  final dyUnits = panPy * (newRange / chartHeight);
  final newMinY = focalChartY - fractionFromBottom * newRange + dyUnits;
  final newMaxY = newMinY + newRange;
  return (minY: newMinY, maxY: newMaxY);
}

// ════════════════════════════════════════════════════
// Drag/pinch/pan/wheel zoom wrapper
// ════════════════════════════════════════════════════

class DragZoomWrapper extends StatefulWidget {
  final Widget child;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double totalDays;
  final double leftReserved = 60;
  final double bottomReserved = 28;
  final DateTime firstDate;
  final String baseCurrency;
  final String locale;
  /// True when the parent has explicitly zoomed Y (rectangle zoom set
  /// non-null `zoomMinY`/`zoomMaxY`). Used to skip Y panning when Y is
  /// just auto-fit — otherwise Shift+drag would jolt the auto-fit window.
  final bool zoomedY;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;

  const DragZoomWrapper({super.key,
    required this.child,
    required this.xMin,
    required this.xMax,
    this.yMin = 0,
    this.yMax = 1,
    required this.totalDays,
    required this.firstDate,
    required this.baseCurrency,
    required this.locale,
    required this.onZoom,
    this.zoomedY = false,
  });

  @override
  State<DragZoomWrapper> createState() => _DragZoomWrapperState();
}

class _DragZoomWrapperState extends State<DragZoomWrapper> {
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;
  bool _panning = false;
  PointerDeviceKind? _activeKind;

  double? _scaleStartMinX;
  double? _scaleStartMaxX;
  double? _scaleStartFocalChartX;

  double _pixelToChartX(double px, double chartWidth) {
    final fraction = (px - widget.leftReserved) / chartWidth;
    return widget.xMin + fraction * (widget.xMax - widget.xMin);
  }

  double _pixelToChartY(double py, double chartHeight) {
    // Y is inverted: top of widget = max Y, bottom of chart area = min Y
    final fraction = 1.0 - (py / chartHeight);
    return widget.yMin + fraction * (widget.yMax - widget.yMin);
  }

  bool get _isZoomedY => widget.zoomedY;

  void _resetTransientState() {
    _dragStart = null;
    _dragCurrent = null;
    _isDragging = false;
    _panning = false;
    _activeKind = null;
  }

  void _handleMousePan(PointerMoveEvent e, double chartWidth, double chartHeight) {
    final xRange = widget.xMax - widget.xMin;
    final yRange = widget.yMax - widget.yMin;
    if (xRange <= 0 || chartWidth <= 0) return;

    final dxUnits = e.delta.dx * xRange / chartWidth;
    var newMinX = widget.xMin - dxUnits;
    var newMaxX = widget.xMax - dxUnits;
    if (newMinX < 0) {
      newMinX = 0;
      newMaxX = xRange;
    }
    if (newMaxX > widget.totalDays) {
      newMaxX = widget.totalDays;
      newMinX = widget.totalDays - xRange;
    }

    double? newMinY, newMaxY;
    if (widget.zoomedY && yRange > 0 && chartHeight > 0) {
      // Y is inverted: dragging the mouse down should shift the visible
      // window DOWN as well, so we add dy. Only pan Y when the user has
      // explicitly zoomed Y; otherwise the auto-fit Y window must stay put.
      final dyUnits = e.delta.dy * yRange / chartHeight;
      newMinY = widget.yMin + dyUnits;
      newMaxY = widget.yMax + dyUnits;
    }
    widget.onZoom(newMinX, newMaxX, newMinY, newMaxY);
  }

  void _handleWheelZoom(PointerScrollEvent sig, double chartWidth, double chartHeight) {
    if (chartWidth <= 0) return;
    // Plain wheel must scroll the parent page; only zoom when the user
    // explicitly opts in with Cmd (macOS) or Ctrl (Win/Linux) — same
    // convention as Google Maps / Mapbox / Excel.
    final cmdOrCtrl = HardwareKeyboard.instance.isControlPressed
        || HardwareKeyboard.instance.isMetaPressed;
    if (!cmdOrCtrl) return;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final factor = exp(-sig.scrollDelta.dy * 0.0015);

    if (!shift) {
      final r = computeZoomedXRange(
        currentMinX: widget.xMin,
        currentMaxX: widget.xMax,
        focalPx: sig.localPosition.dx,
        leftReserved: widget.leftReserved,
        chartWidth: chartWidth,
        scaleFactor: factor,
        panPx: 0,
        totalDays: widget.totalDays,
      );
      final stillZoomedY = _isZoomedY;
      if (r.minX <= 0 && r.maxX >= widget.totalDays - 1e-6) {
        widget.onZoom(null, null, stillZoomedY ? widget.yMin : null, stillZoomedY ? widget.yMax : null);
      } else {
        widget.onZoom(r.minX, r.maxX, stillZoomedY ? widget.yMin : null, stillZoomedY ? widget.yMax : null);
      }
      return;
    }

    if (!_isZoomedY || chartHeight <= 0) return;
    final r = computeZoomedYRange(
      currentMinY: widget.yMin,
      currentMaxY: widget.yMax,
      focalPy: sig.localPosition.dy,
      chartHeight: chartHeight,
      scaleFactor: factor,
      panPy: 0,
    );
    widget.onZoom(widget.xMin, widget.xMax, r.minY, r.maxY);
  }

  void _onScaleStart(ScaleStartDetails d, double chartWidth) {
    if (_activeKind == PointerDeviceKind.mouse || chartWidth <= 0) return;
    _scaleStartMinX = widget.xMin;
    _scaleStartMaxX = widget.xMax;
    final pxToUnits = (widget.xMax - widget.xMin) / chartWidth;
    _scaleStartFocalChartX =
        widget.xMin + (d.localFocalPoint.dx - widget.leftReserved) * pxToUnits;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double chartWidth) {
    if (_scaleStartMinX == null || chartWidth <= 0) return;

    final startRange = _scaleStartMaxX! - _scaleStartMinX!;
    var newRange = startRange / d.scale;
    if (newRange >= widget.totalDays) {
      widget.onZoom(null, null, null, null);
      return;
    }
    if (newRange < 1) newRange = 1;

    final focalPxFromLeft = d.localFocalPoint.dx - widget.leftReserved;
    var newMinX = _scaleStartFocalChartX! - focalPxFromLeft / chartWidth * newRange;
    var newMaxX = newMinX + newRange;

    if (newMinX < 0) {
      newMinX = 0;
      newMaxX = newRange;
    }
    if (newMaxX > widget.totalDays) {
      newMaxX = widget.totalDays;
      newMinX = newMaxX - newRange;
    }
    widget.onZoom(newMinX, newMaxX, null, null);
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _scaleStartMinX = null;
    _scaleStartMaxX = null;
    _scaleStartFocalChartX = null;
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
            _activeKind = e.kind;
            if (e.kind != PointerDeviceKind.mouse) return;
            final shift = HardwareKeyboard.instance.isShiftPressed;
            setState(() {
              _dragStart = e.localPosition;
              _dragCurrent = e.localPosition;
              _isDragging = false;
              _panning = shift;
            });
          },
          onPointerMove: (e) {
            if (_activeKind != PointerDeviceKind.mouse || _dragStart == null) return;
            if (_panning) {
              _handleMousePan(e, chartWidth, chartHeight);
              return;
            }
            final dist = (e.localPosition - _dragStart!).distance;
            if (dist > 5) _isDragging = true;
            if (_isDragging) {
              setState(() => _dragCurrent = e.localPosition);
            }
          },
          onPointerUp: (e) {
            if (_activeKind != PointerDeviceKind.mouse) {
              setState(_resetTransientState);
              return;
            }
            if (_panning) {
              setState(_resetTransientState);
              return;
            }
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
            setState(_resetTransientState);
          },
          onPointerCancel: (_) {
            setState(_resetTransientState);
          },
          onPointerSignal: (sig) {
            if (sig is PointerScrollEvent) {
              _handleWheelZoom(sig, chartWidth, chartHeight);
            }
          },
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              ScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                () => ScaleGestureRecognizer(
                  supportedDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                ),
                (r) => r
                  ..onStart = (d) { _onScaleStart(d, chartWidth); }
                  ..onUpdate = (d) { _onScaleUpdate(d, chartWidth); }
                  ..onEnd = _onScaleEnd,
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => widget.onZoom(null, null, null, null),
              child: Stack(
                children: [
                  widget.child,
                  if (_isDragging && !_panning && _dragStart != null && _dragCurrent != null)
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
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Unified chart widget
// ════════════════════════════════════════════════════

class UnifiedChart extends StatelessWidget {
  final DateTime firstDate;
  final List<ChartSeries> visible;
  final List<FlSpot> totalSpots;
  final bool showTotal;
  final String baseCurrency;
  final String locale;
  final String language;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;
  final bool isPrivate;
  /// True when the X axis is currently zoomed in. Disables fl_chart's built-in
  /// tap/drag tooltip handling so our parent ScaleGestureRecognizer can claim
  /// single-finger pan on touch devices.
  final bool zoomedX;

  const UnifiedChart({super.key,
    required this.firstDate,
    required this.visible,
    required this.totalSpots,
    this.showTotal = true,
    required this.baseCurrency,
    required this.locale,
    required this.language,
    this.zoomMinX,
    this.zoomMaxX,
    this.zoomMinY,
    this.zoomMaxY,
    this.isPrivate = false,
    this.zoomedX = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(baseCurrency);

    final totalDays = totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;
    final dateFmt = fmt.monthYearFormat(language);
    final fullFmt = fmt.fullDateFormat(language);
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
                return Text(label, style: TextStyle(fontSize: 11, color: textColor));
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
                      style: TextStyle(fontSize: 12, color: textColor)),
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
                final label = isPrivate ? '\u2022\u2022\u2022\u2022' : currFmt.format(value);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(label,
                      style: TextStyle(fontSize: 12, color: textColor)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: !isPrivate,
          handleBuiltInTouches: !zoomedX,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipHorizontalAlignment: FLHorizontalAlignment.left,
            tooltipHorizontalOffset: -60,
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
                    const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ));
                } else if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  final displayY = s.rightAxis ? unscaleRight(spot.y) : spot.y;
                  items.add(LineTooltipItem(
                    '$datePrefix${s.name}: ${currFmt.format(displayY)}${s.rightAxis ? ' (\u2192)' : ''}',
                    TextStyle(color: s.color, fontSize: 12),
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
