// Verifies that the wrapper's pixel→chart math actually agrees with the
// rectangle fl_chart paints. If `kChartLeftReserved` / `kChartBottomReserved`
// / `kChartRightReservedDual` drift away from the values the chart is
// configured with, this test catches it: the wrapper's left/right/bottom
// constants must equal the on-screen offsets fl_chart applies.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('UnifiedChart dual-axis: drawing rect matches kChart constants',
      (tester) async {
    const widgetSize = Size(1000, 400);
    final firstDate = DateTime(2024, 1, 1);

    final spotsLeft = [
      const FlSpot(0, 10),
      const FlSpot(100, 20),
    ];
    final spotsRight = [
      const FlSpot(0, 1),
      const FlSpot(100, 2),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: widgetSize.width,
              height: widgetSize.height,
              child: UnifiedChart(
                firstDate: firstDate,
                visible: [
                  ChartSeries(
                    key: 'left',
                    name: 'Left',
                    color: const Color(0xFF0000FF),
                    spots: spotsLeft,
                  ),
                  ChartSeries(
                    key: 'right',
                    name: 'Right',
                    color: const Color(0xFFFF0000),
                    spots: spotsRight,
                    rightAxis: true,
                  ),
                ],
                totalSpots: spotsLeft,
                showTotal: false,
                baseCurrency: 'EUR',
                locale: 'en_US',
                language: 'en_US',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // fl_chart wraps its painter in a Container with margin =
    // titlesData.allSidesPadding (left=80, right=68 for dual, bottom=48,
    // top=0 since topTitles.showTitles=false). The container's `child`
    // (the LineChartLeaf) sits inside that margin. We find the LineChart
    // and the leaf and check their relative offset/size.
    final lineChartFinder = find.byType(LineChart);
    expect(lineChartFinder, findsOneWidget);
    final lineChartBox = tester.renderObject<RenderBox>(lineChartFinder);
    final lineChartTopLeft = lineChartBox.localToGlobal(Offset.zero);

    // Find the actual chart leaf.
    final leafFinder = find.descendant(
      of: lineChartFinder,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'LineChartLeaf',
      ),
    );
    expect(leafFinder, findsOneWidget);
    final leafBox = tester.renderObject<RenderBox>(leafFinder);
    final leafTopLeft = leafBox.localToGlobal(Offset.zero);
    final leafSize = leafBox.size;

    final dx = leafTopLeft.dx - lineChartTopLeft.dx;
    final dy = leafTopLeft.dy - lineChartTopLeft.dy;
    final rightInset = lineChartBox.size.width - leafSize.width - dx;
    final bottomInset = lineChartBox.size.height - leafSize.height - dy;

    // These offsets ARE the rectangle the wrapper must use to convert
    // pointer pixels into chart coordinates. They MUST equal our
    // wrapper constants — otherwise rectangle-zoom is wrong.
    expect(dx, closeTo(kChartLeftReserved, 0.5),
        reason: 'left inset must equal kChartLeftReserved');
    expect(rightInset, closeTo(kChartRightReservedDual, 0.5),
        reason: 'right inset must equal kChartRightReservedDual');
    expect(bottomInset, closeTo(kChartBottomReserved, 0.5),
        reason: 'bottom inset must equal kChartBottomReserved');
    expect(dy, closeTo(0, 0.5),
        reason: 'top inset must be zero (topTitles disabled)');
  });

  testWidgets('UnifiedChart single-axis: right inset is zero', (tester) async {
    final firstDate = DateTime(2024, 1, 1);
    final spotsLeft = [const FlSpot(0, 10), const FlSpot(100, 20)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              height: 400,
              child: UnifiedChart(
                firstDate: firstDate,
                visible: [
                  ChartSeries(
                    key: 'left',
                    name: 'Left',
                    color: const Color(0xFF0000FF),
                    spots: spotsLeft,
                  ),
                ],
                totalSpots: spotsLeft,
                showTotal: false,
                baseCurrency: 'EUR',
                locale: 'en_US',
                language: 'en_US',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final lineChartFinder = find.byType(LineChart);
    final lineChartBox = tester.renderObject<RenderBox>(lineChartFinder);
    final lineChartTopLeft = lineChartBox.localToGlobal(Offset.zero);

    final leafFinder = find.descendant(
      of: lineChartFinder,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'LineChartLeaf',
      ),
    );
    final leafBox = tester.renderObject<RenderBox>(leafFinder);
    final leafTopLeft = leafBox.localToGlobal(Offset.zero);
    final leafSize = leafBox.size;

    final dx = leafTopLeft.dx - lineChartTopLeft.dx;
    final rightInset = lineChartBox.size.width - leafSize.width - dx;

    expect(dx, closeTo(kChartLeftReserved, 0.5));
    expect(rightInset, closeTo(0, 0.5),
        reason: 'no dual axis → no right inset');
  });
}
