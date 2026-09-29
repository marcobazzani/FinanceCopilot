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
// Chart layout constants
// ════════════════════════════════════════════════════
// Single source of truth for `SideTitles.reservedSize`. The drag/zoom
// wrapper uses these to map pointer pixels to chart coordinates, so
// any change here MUST be matched in the chart's `titlesData`. They
// must equal the value passed to `SideTitles.reservedSize` for the
// matching axis — fl_chart reserves exactly this many pixels for axis
// labels, and the chart drawing area is what's left over.
const double kChartLeftReserved = 80;
const double kChartBottomReserved = 48;
const double kChartRightReservedDual = 68;

// ════════════════════════════════════════════════════
// Zoom math helpers (file-local, unit-tested)
// ════════════════════════════════════════════════════

/// Convert a pointer pixel X (in widget-local coords) to chart X.
/// `drawWidth` is the width of the chart drawing area (widget width
/// minus left- and right-axis reserved space).
double pixelToChartX({
  required double px,
  required double drawWidth,
  required double leftReserved,
  required double xMin,
  required double xMax,
}) {
  if (drawWidth <= 0) return xMin;
  final fraction = (px - leftReserved) / drawWidth;
  return xMin + fraction * (xMax - xMin);
}

/// Convert a pointer pixel Y to chart Y. Y is inverted: pixel 0 (top)
/// maps to `yMax`, pixel `drawHeight` (bottom of drawing area) maps to
/// `yMin`. `drawHeight` is the widget height minus the bottom-axis
/// reserved space.
double pixelToChartY({
  required double py,
  required double drawHeight,
  required double yMin,
  required double yMax,
}) {
  if (drawHeight <= 0) return yMin;
  final fraction = 1.0 - (py / drawHeight);
  return yMin + fraction * (yMax - yMin);
}

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

/// Min/max of the y-values of [spots] whose x falls within the visible
/// `[xMin, xMax]` window. To keep a line that enters/leaves the window
/// bounded sensibly, the points immediately straddling each edge are also
/// considered (so the visible segment — which may cross an edge between two
/// far-apart samples — is fully contained).
///
/// Returns null when there is nothing to bound (no spots, or none near the
/// window). Callers fall back to the full-range or a default in that case.
///
/// This is the fix for "the chart is squeezed by an old spike that's no
/// longer visible": the y-axis must reflect the data in view, not the whole
/// dataset.
({double minY, double maxY})? autoYBoundsInVisibleX(
  Iterable<FlSpot> spots,
  double xMin,
  double xMax,
) {
  double? lo, hi;
  // Track the nearest sample just outside each edge so a segment spanning the
  // edge is included.
  FlSpot? leftEdge, rightEdge;
  for (final s in spots) {
    if (s.x < xMin) {
      if (leftEdge == null || s.x > leftEdge.x) leftEdge = s;
      continue;
    }
    if (s.x > xMax) {
      if (rightEdge == null || s.x < rightEdge.x) rightEdge = s;
      continue;
    }
    lo = lo == null ? s.y : min(lo, s.y);
    hi = hi == null ? s.y : max(hi, s.y);
  }
  for (final e in [leftEdge, rightEdge]) {
    if (e == null) continue;
    lo = lo == null ? e.y : min(lo, e.y);
    hi = hi == null ? e.y : max(hi, e.y);
  }
  if (lo == null || hi == null) return null;
  return (minY: lo, maxY: hi);
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
  // These MUST match the corresponding `SideTitles.reservedSize` in
  // [UnifiedChart]. fl_chart reserves these pixels for axis labels;
  // the drawing area is what's left over. Using mismatched values
  // makes pointer→chart math drift (off-by-N pixels per click).
  final double leftReserved = kChartLeftReserved;
  final double bottomReserved = kChartBottomReserved;

  /// Pixels reserved on the right edge for a right-axis ruler. Pass
  /// [kChartRightReservedDual] when the wrapped chart has any
  /// right-axis series; otherwise leave at 0.
  final double rightReserved;
  final DateTime firstDate;
  final String baseCurrency;
  final String locale;

  /// Decimal places for the drag-selection value label. Matches the wrapped
  /// [UnifiedChart]'s valueDecimals (0 for money magnitudes, 2 for unit price).
  final int valueDecimals;

  /// True when the parent has explicitly zoomed Y (rectangle zoom set
  /// non-null `zoomMinY`/`zoomMaxY`). Used to skip Y panning when Y is
  /// just auto-fit — otherwise Shift+drag would jolt the auto-fit window.
  final bool zoomedY;

  /// Full-screen / immersive mode. On touch, pinch zooms BOTH axes
  /// (anchored at the focal point) and a single-finger drag pans both.
  /// Use for a dedicated full-screen chart — not for the dashboard
  /// mini-charts where a 2-finger pinch fights the parent TabBarView
  /// page-swipe.
  final bool fullPinch;

  /// Privacy mode for the drag-selection readout: its value range is masked
  /// (on a money chart it is position size), its date range stays readable.
  /// Leave false on a chart of public market data, such as the unit price of
  /// a listed instrument.
  final bool isPrivate;
  final void Function(double? minX, double? maxX, double? minY, double? maxY) onZoom;

  const DragZoomWrapper({
    super.key,
    required this.child,
    required this.xMin,
    required this.xMax,
    this.yMin = 0,
    this.yMax = 1,
    required this.totalDays,
    required this.firstDate,
    required this.baseCurrency,
    required this.locale,
    this.valueDecimals = 0,
    required this.onZoom,
    this.rightReserved = 0,
    this.zoomedY = false,
    this.fullPinch = false,
    this.isPrivate = false,
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
  // Full-pinch (Y) state — only populated when widget.fullPinch is true.
  double? _scaleStartMinY;
  double? _scaleStartMaxY;
  double? _scaleStartFocalChartY;

  double _pixelToChartX(double px, double drawWidth) => pixelToChartX(
    px: px,
    drawWidth: drawWidth,
    leftReserved: widget.leftReserved,
    xMin: widget.xMin,
    xMax: widget.xMax,
  );

  double _pixelToChartY(double py, double drawHeight) => pixelToChartY(
    py: py,
    drawHeight: drawHeight,
    yMin: widget.yMin,
    yMax: widget.yMax,
  );

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
    final cmdOrCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
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

  void _onScaleStart(ScaleStartDetails d, double chartWidth, double chartHeight) {
    if (_activeKind == PointerDeviceKind.mouse || chartWidth <= 0) return;
    _scaleStartMinX = widget.xMin;
    _scaleStartMaxX = widget.xMax;
    final pxToUnitsX = (widget.xMax - widget.xMin) / chartWidth;
    _scaleStartFocalChartX = widget.xMin + (d.localFocalPoint.dx - widget.leftReserved) * pxToUnitsX;
    if (widget.fullPinch && chartHeight > 0) {
      _scaleStartMinY = widget.yMin;
      _scaleStartMaxY = widget.yMax;
      final yRange = widget.yMax - widget.yMin;
      // Y is inverted: pixel 0 = top = max Y.
      final fractionFromBottom = 1.0 - d.localFocalPoint.dy / chartHeight;
      _scaleStartFocalChartY = widget.yMin + fractionFromBottom * yRange;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double chartWidth, double chartHeight) {
    if (_scaleStartMinX == null || chartWidth <= 0) return;

    // Per-axis scale factors so a horizontal-dominant pinch widens X
    // without compressing Y, and vice versa. `d.scale` is the geometric
    // mean — using it would force aspect-ratio-locked zoom, which is
    // not how typical financial chart UIs behave.
    final xScale = widget.fullPinch ? d.horizontalScale : d.scale;
    final yScale = widget.fullPinch ? d.verticalScale : d.scale;

    final startRange = _scaleStartMaxX! - _scaleStartMinX!;
    var newRange = startRange / xScale;
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

    double? newMinY, newMaxY;
    if (widget.fullPinch && _scaleStartMinY != null && chartHeight > 0) {
      // Y zoom uses verticalScale, anchored on focal Y. No clamp on Y —
      // data may legitimately extend beyond the visible window.
      final startYRange = _scaleStartMaxY! - _scaleStartMinY!;
      final newYRange = startYRange / yScale;
      final fractionFromBottom = 1.0 - d.localFocalPoint.dy / chartHeight;
      newMinY = _scaleStartFocalChartY! - fractionFromBottom * newYRange;
      newMaxY = newMinY + newYRange;
    }
    widget.onZoom(newMinX, newMaxX, newMinY, newMaxY);
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _scaleStartMinX = null;
    _scaleStartMaxX = null;
    _scaleStartFocalChartX = null;
    _scaleStartMinY = null;
    _scaleStartMaxY = null;
    _scaleStartFocalChartY = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth - widget.leftReserved - widget.rightReserved;
        final chartHeight = constraints.maxHeight - widget.bottomReserved;
        final dateFmt = fmt.fullDateFormat(widget.locale);
        final currFmt = fmt.currencyFormat(widget.locale, currencySymbol(widget.baseCurrency), decimalDigits: widget.valueDecimals);

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
              ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                () => ScaleGestureRecognizer(
                  supportedDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                  },
                ),
                (r) => r
                  ..onStart = (d) {
                    _onScaleStart(d, chartWidth, chartHeight);
                  }
                  ..onUpdate = (d) {
                    _onScaleUpdate(d, chartWidth, chartHeight);
                  }
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${dateFmt.format(chart_math.dateAddDays(widget.firstDate, _pixelToChartX(min(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt()))} \u2013 '
                                    '${dateFmt.format(chart_math.dateAddDays(widget.firstDate, _pixelToChartX(max(_dragStart!.dx, _dragCurrent!.dx), chartWidth).toInt()))}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                  PrivacyMask(
                                    isPrivate: widget.isPrivate,
                                    child: Text(
                                      '${currFmt.format(_pixelToChartY(max(_dragStart!.dy, _dragCurrent!.dy), chartHeight))} \u2013 '
                                      '${currFmt.format(_pixelToChartY(min(_dragStart!.dy, _dragCurrent!.dy), chartHeight))}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
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

  /// Display language (e.g. `it_IT`): the date labels and the tooltip's words.
  final String language;
  final double? zoomMinX;
  final double? zoomMaxX;
  final double? zoomMinY;
  final double? zoomMaxY;

  /// Privacy mode: the value axes are masked (on a money chart they are
  /// position size) and the tooltip is off; the dates stay readable. Leave
  /// false on a chart of public market data.
  final bool isPrivate;

  /// Decimal places for value formatting (Y-axis labels + tooltip). 0 suits
  /// money magnitudes (net worth in the thousands); 2 is needed for a
  /// unit-price series so e.g. 108.57 is not rounded to "109".
  final int valueDecimals;

  /// True for the immersive full-screen view, where zoom updates fire at
  /// pointer-frequency and the 150ms LineChart tween becomes the
  /// bottleneck. Skipping the tween makes pinch feel native.
  final bool liveZoom;

  const UnifiedChart({
    super.key,
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
    this.valueDecimals = 0,
    this.liveZoom = false,
  });

  /// Right edge of the unzoomed X window: the last day of the Total.
  double get _totalDays => totalSpots.isNotEmpty ? totalSpots.last.x : 1.0;

  /// The left-axis Y range this chart draws: the explicit Y zoom when set,
  /// else the left-axis data (the Total when shown, and every left-axis
  /// series) inside the visible X window, padded by 5%.
  ///
  /// Fitting to the window CURRENTLY IN VIEW, not the whole dataset, keeps an
  /// old out-of-view spike (e.g. the first MA point) from squeezing the
  /// recent, visible data flat. A [DragZoomWrapper] around this chart must
  /// map pixels through this same range, or a drag selects values that are
  /// not under the pointer — read it from here, never recompute it.
  ({double minY, double maxY}) get drawnYRange {
    final bounds = autoYBoundsInVisibleX(
      [
        if (showTotal) ...totalSpots,
        ...visible.where((s) => !s.rightAxis).expand((s) => s.spots),
      ],
      zoomMinX ?? 0,
      zoomMaxX ?? _totalDays,
    );
    final autoMin = bounds?.minY ?? 0.0;
    final autoMax = bounds?.maxY ?? 100.0;
    final autoRange = autoMax - autoMin;
    return (
      minY: zoomMinY ?? (autoRange > 0 ? autoMin - autoRange * 0.05 : autoMin - 100),
      maxY: zoomMaxY ?? (autoRange > 0 ? autoMax + autoRange * 0.05 : autoMax + 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark ? Colors.white54 : Colors.black54;
    final symbol = currencySymbol(baseCurrency);

    final dateFmt = fmt.monthYearFormat(language);
    final fullFmt = fmt.fullDateFormat(language);
    final currFmt = fmt.currencyFormat(locale, symbol, decimalDigits: valueDecimals);

    // ── Dual Y-axis setup ──
    final rightVisible = visible.where((s) => s.rightAxis).toList();
    final hasDualAxis = rightVisible.isNotEmpty;

    // Visible X window: both Y axes auto-fit the data in view (see
    // [drawnYRange]).
    final visXMin = zoomMinX ?? 0;
    final visXMax = zoomMaxX ?? _totalDays;

    // Left Y range (left series + total), bounded to the visible X window.
    final (minY: chartMinY, maxY: chartMaxY) = drawnYRange;
    final chartRange = chartMaxY - chartMinY;
    final yRange = chartRange;

    // Right Y range (natural scale, not zoomed), bounded to the visible X
    // window so the secondary axis also fits what's on screen.
    double rightNatMin = 0, rightNatMax = 1;
    if (hasDualAxis) {
      final rightBounds = autoYBoundsInVisibleX(
        rightVisible.expand((s) => s.spots),
        visXMin,
        visXMax,
      );
      if (rightBounds != null) {
        rightNatMin = rightBounds.minY;
        rightNatMax = rightBounds.maxY;
      }
    }
    final rightNatRange = (rightNatMax - rightNatMin).abs().clamp(1e-9, double.infinity);

    // Scale right-axis value → left pixel space
    double scaleRight(double y) => chartRange <= 0 ? chartMinY : (y - rightNatMin) / rightNatRange * chartRange + chartMinY;

    // Reverse-scale left-pixel value → actual right-axis value (for tooltip/labels)
    double unscaleRight(double scaledY) => chartRange <= 0 ? rightNatMin : (scaledY - chartMinY) / chartRange * rightNatRange + rightNatMin;

    final lineBars = <LineChartBarData>[];

    // Total line (always left axis)
    if (showTotal) {
      lineBars.add(
        LineChartBarData(
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
        ),
      );
    }

    // Visible series lines (right-axis series are scaled into left pixel space)
    for (final s in visible) {
      final spots = s.rightAxis ? s.spots.map((pt) => FlSpot(pt.x, scaleRight(pt.y))).toList() : s.spots;
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          curveSmoothness: 0.15,
          color: s.color,
          barWidth: s.rightAxis ? 1.5 : (s.isDashed ? 1.5 : 2),
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          dashArray: s.isDashed ? [6, 3] : null,
        ),
      );
    }

    final xMin = visXMin;
    final xMax = visXMax;
    final xRange = xMax - xMin;

    return LineChart(
      // In full-screen / live-zoom mode, kill the 150ms implicit tween
      // — pinch updates fire ~60Hz and each tween queues frames, which
      // is what makes the chart feel laggy. Static views still get the
      // smooth animation.
      duration: liveZoom ? Duration.zero : const Duration(milliseconds: 150),
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
          getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: hasDualAxis,
              reservedSize: hasDualAxis ? kChartRightReservedDual : 0,
              interval: yRange > 0 ? yRange / 4 : 100,
              // Masked like the drag readout: on a money chart the scale is
              // position size.
              getTitlesWidget: (scaledY, meta) => PrivacyMask(
                isPrivate: isPrivate,
                child: Text(currFmt.format(unscaleRight(scaledY)), style: TextStyle(fontSize: 11, color: textColor)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: kChartBottomReserved,
              interval: xRange > 0 ? xRange / 5 : 1,
              getTitlesWidget: (value, meta) {
                final date = chart_math.dateAddDays(firstDate, value.toInt());
                return SideTitleWidget(
                  meta: meta,
                  angle: -0.5,
                  child: Text(dateFmt.format(date), style: TextStyle(fontSize: 12, color: textColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: kChartLeftReserved,
              interval: yRange > 0 ? yRange / 4 : 100,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: PrivacyMask(
                  isPrivate: isPrivate,
                  child: Text(currFmt.format(value), style: TextStyle(fontSize: 12, color: textColor)),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: !isPrivate,
          // On touch platforms, fl_chart's built-in recognizer wins
          // the gesture arena on touch-down and would block our parent
          // ScaleGestureRecognizer from ever seeing pinch / pan — even
          // before the chart is zoomed. Disable it entirely on mobile
          // (we lose drag-tooltip on mobile in exchange for working
          // pinch + pan; tap-tooltip can be re-added later via a
          // separate TapGestureRecognizer). On desktop our mouse drag
          // is captured by the parent Listener (translucent hit-test
          // with PointerDown gating) so there's no conflict — keep
          // hover tooltips on even while zoomed.
          handleBuiltInTouches: switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.android => false,
            _ => true,
          },
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
                final date = chart_math.dateAddDays(firstDate, spot.x.toInt());
                final datePrefix = spotIdx == 0 ? '${fullFmt.format(date)}\n' : '';

                if (isTotal) {
                  items.add(
                    LineTooltipItem(
                      '${fullFmt.format(date)}\n${AppStrings.of(language).legendTotal}: ${currFmt.format(spot.y)}',
                      const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                } else if (seriesIdx >= 0 && seriesIdx < visible.length) {
                  final s = visible[seriesIdx];
                  final displayY = s.rightAxis ? unscaleRight(spot.y) : spot.y;
                  items.add(
                    LineTooltipItem(
                      '$datePrefix${s.name}: ${currFmt.format(displayY)}${s.rightAxis ? ' (\u2192)' : ''}',
                      TextStyle(color: s.color, fontSize: 12),
                    ),
                  );
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
