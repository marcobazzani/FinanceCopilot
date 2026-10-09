import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A node of a [SankeyChart]. Nodes are laid out in columns ([layer], left to
/// right) and, within a column, top to bottom in the order given.
class SankeyNodeSpec {
  final String id;
  final int layer;
  final double value;
  final Color color;
  const SankeyNodeSpec({required this.id, required this.layer, required this.value, required this.color});
}

class SankeyLinkSpec {
  final String from;
  final String to;
  final double value;
  final Color color;
  const SankeyLinkSpec({required this.from, required this.to, required this.value, required this.color});
}

/// A link's band: it leaves its source at [sourceTop] and reaches its target
/// at [targetTop], [thickness] pixels thick all along.
class SankeyBand {
  final SankeyLinkSpec link;
  final double x0;
  final double sourceTop;
  final double x1;
  final double targetTop;
  final double thickness;
  const SankeyBand({
    required this.link,
    required this.x0,
    required this.sourceTop,
    required this.x1,
    required this.targetTop,
    required this.thickness,
  });
}

class SankeyLayout {
  final Map<String, Rect> nodeRects;
  final List<SankeyBand> bands;
  final Size size;
  const SankeyLayout({required this.nodeRects, required this.bands, required this.size});
}

/// Pure geometry of a Sankey diagram.
///
/// One scale for the whole chart — [valueHeight] pixels for the fullest
/// column — so band thickness is comparable across columns. Each node takes
/// a slot of at least [minSlot] pixels (room for its label) and slots are
/// [nodeGap] apart; every column is centred on the tallest one. Bands are
/// stacked inside their nodes in the order of the node at the other end, so
/// they do not cross within a node.
SankeyLayout computeSankeyLayout({
  required List<SankeyNodeSpec> nodes,
  required List<SankeyLinkSpec> links,
  required double width,
  double valueHeight = 320,
  double nodeWidth = 12,
  double nodeGap = 8,
  double minSlot = 0,
  double leftInset = 0,
  double rightInset = 0,
}) {
  if (nodes.isEmpty) return SankeyLayout(nodeRects: const {}, bands: const [], size: Size(width, 0));
  final layers = <int, List<SankeyNodeSpec>>{};
  for (final n in nodes) {
    (layers[n.layer] ??= []).add(n);
  }
  final layerIds = layers.keys.toList()..sort();
  final maxTotal = layers.values.map((l) => l.fold(0.0, (a, n) => a + n.value)).reduce(math.max);
  final scale = maxTotal <= 0 ? 0.0 : valueHeight / maxTotal;

  double slot(SankeyNodeSpec n) => math.max(n.value * scale, minSlot);
  double columnHeight(List<SankeyNodeSpec> l) => l.fold(0.0, (a, n) => a + slot(n)) + nodeGap * (l.length - 1);
  final height = layerIds.map((id) => columnHeight(layers[id]!)).reduce(math.max);

  final span = width - leftInset - rightInset - nodeWidth;
  double xOf(int layerIndex) => leftInset + (layerIds.length == 1 ? 0 : span * layerIndex / (layerIds.length - 1));

  final rects = <String, Rect>{};
  for (var i = 0; i < layerIds.length; i++) {
    final col = layers[layerIds[i]]!;
    var y = (height - columnHeight(col)) / 2;
    for (final n in col) {
      final s = slot(n);
      final h = n.value * scale;
      // The bar sits in the middle of its slot, aligned with its label.
      rects[n.id] = Rect.fromLTWH(xOf(i), y + (s - h) / 2, nodeWidth, h);
      y += s + nodeGap;
    }
  }

  // Stack bands inside each node by the vertical position of the other end.
  final outgoing = <String, List<SankeyLinkSpec>>{};
  final incoming = <String, List<SankeyLinkSpec>>{};
  for (final l in links) {
    if (!rects.containsKey(l.from) || !rects.containsKey(l.to)) continue;
    (outgoing[l.from] ??= []).add(l);
    (incoming[l.to] ??= []).add(l);
  }
  final sourceTop = <SankeyLinkSpec, double>{};
  final targetTop = <SankeyLinkSpec, double>{};
  outgoing.forEach((id, ls) {
    ls.sort((a, b) => rects[a.to]!.top.compareTo(rects[b.to]!.top));
    var y = rects[id]!.top;
    for (final l in ls) {
      sourceTop[l] = y;
      y += l.value * scale;
    }
  });
  incoming.forEach((id, ls) {
    ls.sort((a, b) => rects[a.from]!.top.compareTo(rects[b.from]!.top));
    var y = rects[id]!.top;
    for (final l in ls) {
      targetTop[l] = y;
      y += l.value * scale;
    }
  });

  final bands = [
    for (final l in links)
      if (sourceTop.containsKey(l))
        SankeyBand(
          link: l,
          x0: rects[l.from]!.right,
          sourceTop: sourceTop[l]!,
          x1: rects[l.to]!.left,
          targetTop: targetTop[l]!,
          thickness: l.value * scale,
        ),
  ];
  return SankeyLayout(nodeRects: rects, bands: bands, size: Size(width, height));
}

/// Sankey diagram: painted bars and bands, with widget labels so callers can
/// use privacy-aware text and tap targets.
///
/// Labels of the first column sit left of their bar, all others right of it.
class SankeyChart extends StatelessWidget {
  final List<SankeyNodeSpec> nodes;
  final List<SankeyLinkSpec> links;
  final Widget Function(BuildContext context, SankeyNodeSpec node) labelBuilder;
  final ValueChanged<String>? onNodeTap;
  final double valueHeight;
  final double labelWidth;
  final double minWidth;
  final double minSlot;

  const SankeyChart({
    required this.nodes,
    required this.links,
    required this.labelBuilder,
    this.onNodeTap,
    this.valueHeight = 320,
    this.labelWidth = 130,
    this.minWidth = 720,
    this.minSlot = 34,
    super.key,
  });

  static const _nodeWidth = 12.0;
  static const _labelGap = 6.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.max(box.maxWidth.isFinite ? box.maxWidth : minWidth, minWidth);
        final layout = computeSankeyLayout(
          nodes: nodes,
          links: links,
          width: width,
          valueHeight: valueHeight,
          nodeWidth: _nodeWidth,
          minSlot: minSlot,
          leftInset: labelWidth + _labelGap,
          rightInset: labelWidth + _labelGap,
        );
        final firstLayer = nodes.map((n) => n.layer).reduce(math.min);
        final chart = SizedBox(
          width: width,
          height: layout.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _SankeyPainter(layout, nodes))),
              for (final n in nodes)
                if (layout.nodeRects[n.id] case final r?)
                  Positioned(
                    key: ValueKey('sankeyNode:${n.id}'),
                    left: n.layer == firstLayer ? r.left - _labelGap - labelWidth : r.left,
                    top: r.center.dy - minSlot / 2,
                    width: labelWidth + _nodeWidth + _labelGap,
                    height: minSlot,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onNodeTap == null ? null : () => onNodeTap!(n.id),
                      child: Row(
                        textDirection: n.layer == firstLayer ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          const SizedBox(width: _nodeWidth + _labelGap),
                          Expanded(
                            child: Align(
                              alignment: n.layer == firstLayer ? Alignment.centerRight : Alignment.centerLeft,
                              child: labelBuilder(context, n),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
        if (width <= box.maxWidth) return chart;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart);
      },
    );
  }
}

class _SankeyPainter extends CustomPainter {
  final SankeyLayout layout;
  final List<SankeyNodeSpec> nodes;
  _SankeyPainter(this.layout, this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in layout.bands) {
      final mid = (b.x0 + b.x1) / 2;
      final path = Path()
        ..moveTo(b.x0, b.sourceTop)
        ..cubicTo(mid, b.sourceTop, mid, b.targetTop, b.x1, b.targetTop)
        ..lineTo(b.x1, b.targetTop + b.thickness)
        ..cubicTo(mid, b.targetTop + b.thickness, mid, b.sourceTop + b.thickness, b.x0, b.sourceTop + b.thickness)
        ..close();
      canvas.drawPath(path, Paint()..color = b.link.color.withValues(alpha: 0.35));
    }
    for (final n in nodes) {
      final r = layout.nodeRects[n.id];
      if (r == null) continue;
      // Keep hairline nodes visible.
      final bar = r.height < 1 ? Rect.fromLTWH(r.left, r.center.dy - 0.5, r.width, 1) : r;
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2)), Paint()..color = n.color);
    }
  }

  @override
  bool shouldRepaint(_SankeyPainter old) => old.layout != layout || old.nodes != nodes;
}
