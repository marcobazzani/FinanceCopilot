import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/widgets/sankey_chart.dart';

void main() {
  const c = Color(0xFF000000);
  SankeyNodeSpec n(String id, int layer, double v) => SankeyNodeSpec(id: id, layer: layer, value: v, color: c);
  SankeyLinkSpec l(String a, String b, double v) => SankeyLinkSpec(from: a, to: b, value: v, color: c);

  test('one scale for all columns, bands stacked by the other end, columns centred', () {
    final layout = computeSankeyLayout(
      nodes: [n('a', 0, 60), n('b', 0, 40), n('t', 1, 100), n('x', 2, 30), n('y', 2, 70)],
      links: [l('a', 't', 60), l('b', 't', 40), l('t', 'y', 70), l('t', 'x', 30)],
      width: 212,
      valueHeight: 100,
      nodeWidth: 12,
      nodeGap: 10,
    );
    final r = layout.nodeRects;
    expect(layout.size.height, 110, reason: 'tallest column: 100 px of value + one gap');
    expect(r['t']!.height, 100);
    expect(r['t']!.top, 5, reason: 'single-node column centred on the tallest');
    expect(r['a']!.top, 0);
    expect(r['b']!.top, 70);
    expect([r['a']!.left, r['t']!.left, r['x']!.left], [0, 100, 200]);

    final byLink = {for (final b in layout.bands) '${b.link.from}${b.link.to}': b};
    // Into t: a (upper) stacks above b.
    expect(byLink['at']!.targetTop, 5);
    expect(byLink['bt']!.targetTop, 65);
    // Out of t: ordered by target position (x above y) regardless of link order.
    expect(byLink['tx']!.sourceTop, 5);
    expect(byLink['ty']!.sourceTop, 35);
    expect(byLink['ty']!.thickness, 70);
    expect(byLink['at']!.x0, 12);
    expect(byLink['at']!.x1, 100);
  });

  test('minSlot reserves label room for tiny nodes without changing the scale', () {
    final layout = computeSankeyLayout(
      nodes: [n('big', 0, 99), n('tiny', 0, 1), n('t', 1, 100)],
      links: [l('big', 't', 99), l('tiny', 't', 1)],
      width: 100,
      valueHeight: 100,
      nodeGap: 0,
      minSlot: 20,
    );
    expect(layout.nodeRects['tiny']!.height, closeTo(1, 1e-9));
    expect(layout.nodeRects['tiny']!.top, closeTo(99 + 9.5, 1e-9), reason: 'bar centred in its 20 px slot');
    expect(layout.size.height, 119);
  });

  test('empty input', () {
    expect(computeSankeyLayout(nodes: const [], links: const [], width: 100).size.height, 0);
  });
}
