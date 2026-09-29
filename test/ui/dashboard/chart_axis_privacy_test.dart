// Chart axes in privacy mode (UnifiedChart: dashboard chart cards, pillar and
// asset charts, the full-screen chart). The value axes — left, and right on a
// dual-axis chart — are position size on a money chart: masked. The date axis
// carries no magnitude and stays readable. Without privacy every amount is
// readable.
//
// The value axis is masked with the app's shared privacy mask, as the drag
// readout next to it and the card's total are, instead of a hand-rolled
// "••••" text.
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/models/dashboard_chart.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  const placeholder = '\u2022\u2022\u2022\u2022';
  final firstDate = DateTime(2026, 1, 1);
  const fundSpots = [FlSpot(0, 1000), FlSpot(30, 1500), FlSpot(60, 1200), FlSpot(90, 2000)];
  final fund = ChartSeries(key: 'asset_market:1', name: 'Fund', color: const Color(0xFF2196F3), spots: fundSpots);
  final saving = ChartSeries(key: 'cf:saving', name: 'Saving', color: const Color(0xFF2196F3), spots: fundSpots);
  final diff = ChartSeries(
    key: 'cf:diff',
    name: 'Diff',
    color: const Color(0xFFFF9800),
    spots: const [FlSpot(0, -300), FlSpot(30, 250), FlSpot(60, -120), FlSpot(90, 480)],
    rightAxis: true,
  );

  Future<ProviderContainer> pumpCard(WidgetTester tester, List<ChartSeries> series, {bool combined = false}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final card = ChartCard(
      chart: DashboardChart(
        id: 1,
        title: 'Portfolio',
        widgetType: 'chart',
        sortOrder: 0,
        seriesJson: '[]',
        sourceChartIds: combined ? 'cf' : null,
        createdAt: firstDate,
      ),
      series: series,
      allData: AllSeriesData(
        firstDate: firstDate,
        accounts: const [],
        assetInvested: const [],
        assetMarket: series,
        assetGain: const [],
        assetNet: const [],
        adjustments: const [],
        incomeAdjustments: const [],
        ephemeralInflows: const [],
        baseCurrency: 'EUR',
      ),
      hidden: const {},
      locale: 'en_US',
      language: 'en_US',
      chartHeight: 420,
      onToggle: (_) {},
      onToggleGroup: (_) {},
      onToggleHideComponents: () {},
      onZoom: (_, _, _, _) {},
      onHeightChanged: (_) {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: Scaffold(body: card)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byWidget(card)));
  }

  Future<void> setPrivate(WidgetTester tester, ProviderContainer container, bool value) async {
    container.read(privacyModeProvider.notifier).state = value;
    await tester.pump(const Duration(milliseconds: 300));
  }

  bool masked(Element e) =>
      find.ancestor(of: find.byElementPredicate((x) => x == e), matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  /// Every label the chart draws, with its element.
  List<({String text, Element element})> labels() => [
    for (final e in find.descendant(of: find.byType(LineChart), matching: find.byType(Text)).evaluate())
      if ((e.widget as Text).data != null) (text: (e.widget as Text).data!, element: e),
  ];

  bool isValue(String text) => text == placeholder || text.contains('€');
  final isDate = RegExp(r'^[A-Z][a-z]{2} \d{4}$').hasMatch;

  /// How many value labels sit on the left and on the right half of the chart.
  ({int left, int right}) sides(WidgetTester tester, Iterable<({String text, Element element})> values) {
    final middle = tester.getRect(find.byType(LineChart)).center.dx;
    var left = 0, right = 0;
    for (final v in values) {
      tester.getCenter(find.byElementPredicate((x) => x == v.element)).dx < middle ? left++ : right++;
    }
    return (left: left, right: right);
  }

  void expectValueAxesMasked(WidgetTester tester, {required bool dual}) {
    final values = labels().where((l) => isValue(l.text)).toList();
    final (:left, :right) = sides(tester, values);
    expect(left, greaterThanOrEqualTo(3), reason: 'the left value axis is drawn');
    expect(right, dual ? greaterThanOrEqualTo(3) : 0, reason: 'the right value axis is drawn on a dual-axis chart only');
    for (final v in values) {
      expect(v.text == placeholder || masked(v.element), isTrue, reason: '"${v.text}" is an amount left readable');
    }
    final dates = labels().where((l) => isDate(l.text)).toList();
    expect(dates, isNotEmpty, reason: 'the date axis is drawn');
    for (final d in dates) {
      expect(masked(d.element), isFalse, reason: 'the date "${d.text}" carries no magnitude');
    }
  }

  void expectEverythingReadable(WidgetTester tester, {required bool dual}) {
    final values = labels().where((l) => isValue(l.text)).toList();
    final (:left, :right) = sides(tester, values);
    expect(left, greaterThanOrEqualTo(3));
    expect(right, dual ? greaterThanOrEqualTo(3) : 0);
    for (final v in values) {
      expect(v.text, contains('€'));
      expect(masked(v.element), isFalse, reason: '"${v.text}": privacy mode is off');
    }
    expect(labels().where((l) => isDate(l.text)), isNotEmpty);
  }

  group('pin', () {
    testWidgets('privacy masks the value axis; the date axis stays readable', (tester) async {
      final container = await pumpCard(tester, [fund]);
      expectEverythingReadable(tester, dual: false);

      await setPrivate(tester, container, true);
      expectValueAxesMasked(tester, dual: false);

      await setPrivate(tester, container, false);
      expectEverythingReadable(tester, dual: false);
    });

    testWidgets('a dual-axis chart masks both value axes', (tester) async {
      final container = await pumpCard(tester, [saving, diff], combined: true);
      expectEverythingReadable(tester, dual: true);

      await setPrivate(tester, container, true);
      expectValueAxesMasked(tester, dual: true);
    });
  });

  testWidgets('the value axes are masked with the shared privacy mask, not a hand-rolled placeholder', (tester) async {
    final container = await pumpCard(tester, [saving, diff], combined: true);
    await setPrivate(tester, container, true);
    final values = labels().where((l) => isValue(l.text)).toList();
    final (:left, :right) = sides(tester, values);
    expect(left, greaterThanOrEqualTo(3));
    expect(right, greaterThanOrEqualTo(3));
    for (final v in values) {
      expect(v.text, isNot(placeholder));
      expect(masked(v.element), isTrue, reason: '"${v.text}" is masked like the drag readout and the total');
    }
  });
}
