// The chart tooltip names the Total line in the display language: it used to
// read "Total:" whatever the language.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  const spots = [FlSpot(0, 1000), FlSpot(10, 1200)];

  Future<String> totalTooltip(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 400,
            child: UnifiedChart(
              firstDate: DateTime(2026, 1, 1),
              visible: const [ChartSeries(key: 'account:1', name: 'Main', color: Color(0xFF2196F3), spots: spots)],
              totalSpots: spots,
              baseCurrency: 'EUR',
              locale: language,
              language: language,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final totalLine = data.lineBarsData.first;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([LineBarSpot(totalLine, 0, totalLine.spots.last)]);
    return items.single!.text;
  }

  testWidgets('Italian: "Totale"', (tester) async {
    final text = await totalTooltip(tester, 'it_IT');
    expect(text, contains('${AppStrings.it.legendTotal}: '));
    expect(text, isNot(contains('Total: ')));
  });

  testWidgets('English: "Total"', (tester) async {
    expect(await totalTooltip(tester, 'en_US'), contains('${AppStrings.en.legendTotal}: '));
  });
}
