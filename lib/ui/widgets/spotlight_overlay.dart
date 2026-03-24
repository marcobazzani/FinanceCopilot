import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A dark overlay with a rounded-rect cutout around [targetRect] and a tooltip
/// balloon with an arrow pointing to the target.
class SpotlightOverlay extends StatelessWidget {
  const SpotlightOverlay({
    super.key,
    required this.targetRect,
    required this.message,
    this.onSkip,
    this.skipLabel = 'Skip Tour',
    this.noScrim = false,
    this.onContinue,
    this.continueLabel,
    this.onBack,
  });

  final Rect targetRect;
  final String message;
  final VoidCallback? onSkip;
  final String skipLabel;
  final bool noScrim;
  final VoidCallback? onContinue;
  final String? continueLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final padded = targetRect.inflate(8);
      final tooltipPlacement = _computePlacement(padded, size);

      return Stack(
        children: [
          // Dark scrim with cutout — absorbs taps outside the cutout
          if (!noScrim)
            Positioned.fill(
              child: _ScrimHitTest(
                cutout: padded,
                child: CustomPaint(
                  painter: _ScrimPainter(cutout: padded),
                ),
              ),
            ),

          // Tooltip balloon
          Positioned(
            left: tooltipPlacement.left,
            top: tooltipPlacement.top,
            child: _TooltipBalloon(
              message: message,
              arrowSide: tooltipPlacement.arrowSide,
              arrowOffset: tooltipPlacement.arrowOffset,
              onSkip: onSkip,
              skipLabel: skipLabel,
              onContinue: onContinue,
              continueLabel: continueLabel,
              onBack: onBack,
            ),
          ),
        ],
      );
    });
  }

  _TooltipPlacement _computePlacement(Rect target, Size screen) {
    const tooltipWidth = 280.0;
    const tooltipHeight = 140.0; // approximate max height with buttons
    const gap = 12.0;

    // Try right first — keeps the target visible
    if (target.right + gap + tooltipWidth < screen.width) {
      final top = (target.center.dy - tooltipHeight / 2)
          .clamp(16.0, screen.height - tooltipHeight - 16.0);
      return _TooltipPlacement(
        left: target.right + gap,
        top: top,
        arrowSide: _ArrowSide.left,
        arrowOffset: target.center.dy - top,
      );
    }

    // Try left
    if (target.left - gap - tooltipWidth > 0) {
      final top = (target.center.dy - tooltipHeight / 2)
          .clamp(16.0, screen.height - tooltipHeight - 16.0);
      return _TooltipPlacement(
        left: target.left - gap - tooltipWidth,
        top: top,
        arrowSide: _ArrowSide.right,
        arrowOffset: target.center.dy - top,
      );
    }

    // Try below
    final anchorX = target.width > screen.width * 0.5
        ? target.left + 60
        : target.center.dx;
    if (target.bottom + gap + tooltipHeight < screen.height) {
      final left = (anchorX - tooltipWidth / 2)
          .clamp(16.0, screen.width - tooltipWidth - 16.0);
      return _TooltipPlacement(
        left: left,
        top: target.bottom + gap,
        arrowSide: _ArrowSide.top,
        arrowOffset: anchorX - left,
      );
    }

    // Try above
    if (target.top - gap - tooltipHeight > 0) {
      final left = (anchorX - tooltipWidth / 2)
          .clamp(16.0, screen.width - tooltipWidth - 16.0);
      return _TooltipPlacement(
        left: left,
        top: target.top - gap - tooltipHeight,
        arrowSide: _ArrowSide.bottom,
        arrowOffset: anchorX - left,
      );
    }

    // Fallback: below, forced
    final left = (anchorX - tooltipWidth / 2)
        .clamp(16.0, screen.width - tooltipWidth - 16.0);
    return _TooltipPlacement(
      left: left,
      top: target.bottom + gap,
      arrowSide: _ArrowSide.top,
      arrowOffset: anchorX - left,
    );
  }
}

// ── Scrim hit-test: absorbs taps outside cutout, passes through inside ──

class _ScrimHitTest extends SingleChildRenderObjectWidget {
  const _ScrimHitTest({required this.cutout, required super.child});

  final Rect cutout;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScrimHitTest(cutout);

  @override
  void updateRenderObject(BuildContext context, _RenderScrimHitTest renderObject) {
    renderObject.cutout = cutout;
  }
}

class _RenderScrimHitTest extends RenderProxyBox {
  _RenderScrimHitTest(this._cutout);

  Rect _cutout;
  set cutout(Rect value) {
    if (_cutout != value) {
      _cutout = value;
      markNeedsPaint();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // If tap is inside the cutout, don't intercept — let it pass through to the button
    if (_cutout.contains(position)) return false;
    // Outside the cutout, absorb the tap
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

// ── Scrim painter ──

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.cutout});

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, Paint()..color = const Color(0xBB000000));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutout, const Radius.circular(8)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.cutout != cutout;
}

// ── Tooltip balloon ──

enum _ArrowSide { top, bottom, left, right }

class _TooltipPlacement {
  final double left;
  final double top;
  final _ArrowSide arrowSide;
  final double arrowOffset;

  const _TooltipPlacement({
    required this.left,
    required this.top,
    required this.arrowSide,
    required this.arrowOffset,
  });
}

class _TooltipBalloon extends StatelessWidget {
  const _TooltipBalloon({
    required this.message,
    required this.arrowSide,
    required this.arrowOffset,
    this.onSkip,
    this.skipLabel = 'Skip Tour',
    this.onContinue,
    this.continueLabel,
    this.onBack,
  });

  final String message;
  final _ArrowSide arrowSide;
  final double arrowOffset;
  final VoidCallback? onSkip;
  final String skipLabel;
  final VoidCallback? onContinue;
  final String? continueLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: CustomPaint(
        painter: _ArrowPainter(
          side: arrowSide,
          offset: arrowOffset,
          color: theme.colorScheme.inverseSurface,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: arrowSide == _ArrowSide.top ? 10 : 0,
            bottom: arrowSide == _ArrowSide.bottom ? 10 : 0,
            left: arrowSide == _ArrowSide.left ? 10 : 0,
            right: arrowSide == _ArrowSide.right ? 10 : 0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onSkip != null || onContinue != null || onBack != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onSkip != null)
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onInverseSurface.withAlpha(180),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(skipLabel, style: const TextStyle(fontSize: 12)),
                      ),
                    const Spacer(),
                    if (onBack != null)
                      TextButton(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onInverseSurface.withAlpha(180),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('←', style: TextStyle(fontSize: 14)),
                      ),
                    if (onContinue != null) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onContinue,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(continueLabel ?? 'Continue', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.side,
    required this.offset,
    required this.color,
  });

  final _ArrowSide side;
  final double offset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const arrowSize = 10.0;
    final clampedOffset = offset.clamp(20.0, (side == _ArrowSide.top || side == _ArrowSide.bottom ? size.width : size.height) - 20.0);

    final path = Path();
    switch (side) {
      case _ArrowSide.top:
        path.moveTo(clampedOffset - arrowSize, arrowSize);
        path.lineTo(clampedOffset, 0);
        path.lineTo(clampedOffset + arrowSize, arrowSize);
      case _ArrowSide.bottom:
        final y = size.height - arrowSize;
        path.moveTo(clampedOffset - arrowSize, y);
        path.lineTo(clampedOffset, size.height);
        path.lineTo(clampedOffset + arrowSize, y);
      case _ArrowSide.left:
        path.moveTo(arrowSize, clampedOffset - arrowSize);
        path.lineTo(0, clampedOffset);
        path.lineTo(arrowSize, clampedOffset + arrowSize);
      case _ArrowSide.right:
        final x = size.width - arrowSize;
        path.moveTo(x, clampedOffset - arrowSize);
        path.lineTo(size.width, clampedOffset);
        path.lineTo(x, clampedOffset + arrowSize);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.side != side || old.offset != offset || old.color != color;
}
