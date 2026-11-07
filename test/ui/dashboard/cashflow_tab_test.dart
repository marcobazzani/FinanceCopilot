// Cash Flow tab: chart titles, legends, axis labels, errors and the Yearly
// Summary follow the display language and locale; axis amounts stay masked in
// privacy mode.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/providers/providers.dart';

import 'dashboard_harness.dart';

void main() {
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  /// 3,000 of the 2025 salary stays in the account: a 2025 savings rate of
  /// 3,000 / 36,000 = 8.3%.
  Future<void> depositIn2025() async {
    final acct = (await h.db.select(h.db.accounts).get()).single.id;
    await h.db
        .into(h.db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: acct,
            operationDate: DateTime(2025, 6, 15),
            valueDate: DateTime(2025, 6, 15),
            amount: 3000,
            balanceAfter: const Value(18000),
            description: const Value('Kept'),
          ),
        );
  }

  /// Left-axis labels of the yearly Income / Expenses / Savings bar chart:
  /// the texts of the chart spelling an amount in euros.
  List<String> yearlyAxis(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(find.descendant(of: find.byType(BarChart).first, matching: find.byType(Text))))
      if (t.data != null && t.data!.contains('€')) t.data!,
  ];

  group('moving-average charts', () {
    testWidgets('Italian titles and legends', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openTab(tester, 'Flussi di cassa');
        await h.cashFlowSection(tester, 'cfTrendsTile');
        expect(find.text('Risparmi vs MM'), findsOneWidget);
        expect(find.text('Uscite vs MM e Liquidità'), findsOneWidget);
        expect(find.text('Velocità (MM)'), findsOneWidget);
        expect(find.text('MM'), findsNWidgets(2), reason: 'the moving-average series of saving and spending');
        expect(find.text('Diff. (→)'), findsOneWidget);
        expect(find.text('Risparmi vel.'), findsOneWidget);
        for (final english in ['Risparmi vs MA', 'MA', 'Diff (→)', 'Velocità (MA)']) {
          expect(find.text(english), findsNothing, reason: '"$english" is English');
        }
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('English titles and legends are unchanged', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await h.cashFlowSection(tester, 'cfTrendsTile');
        expect(find.text('Saving vs MA'), findsOneWidget);
        expect(find.text('Expenses vs MA & Cash'), findsOneWidget);
        expect(find.text('Velocity (MA)'), findsOneWidget);
        expect(find.text('MA'), findsNWidgets(2));
        expect(find.text('Diff (→)'), findsOneWidget);
        expect(find.text('Saving vel.'), findsOneWidget);
        expect(find.text('Expenses vel.'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('yearly chart axis', () {
    testWidgets('amounts are spelled with two decimals in the display locale', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openTab(tester, 'Flussi di cassa');
        final axis = yearlyAxis(tester);
        // The top of the axis (36,000 income + 15% headroom) in full, not shortened.
        expect(axis, containsAll(['0,00\u00a0€', '10.000,00\u00a0€', '20.000,00\u00a0€', '30.000,00\u00a0€', '41.400,00\u00a0€']));
        final italian = RegExp(r'^\d{1,3}(\.\d{3})*,\d{2}\u00a0€$');
        expect(
          axis.where((l) => !italian.hasMatch(l)),
          isEmpty,
          reason: 'no compact suffix, no hard-coded decimal point: dots group the thousands, a comma before the two decimals',
        );
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('English amounts are spelled with two decimals', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        expect(yearlyAxis(tester), containsAll(['€0.00', '€10,000.00', '€20,000.00', '€30,000.00', '€41,400.00']));
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('privacy mode masks the axis amounts; the years stay readable', (tester) async {
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT', isPrivate: true);
      try {
        await h.openTab(tester, 'Flussi di cassa');
        bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
        final chart = find.byType(BarChart).first;
        Finder label(String text) => find.descendant(of: chart, matching: find.text(text));
        // Blurred like the History charts' axes (PrivacyMask), not replaced
        // by a placeholder.
        for (final amount in yearlyAxis(tester)) {
          expect(masked(label(amount)), isTrue, reason: '$amount is position size');
        }
        expect(yearlyAxis(tester), isNotEmpty);
        expect(label('2025'), findsOneWidget);
        expect(masked(label('2025')), isFalse);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('a failing spending breakdown says so in the display language', (tester) async {
    await h.seed();
    await h.pump(
      tester,
      language: 'it',
      locale: 'it_IT',
      overrides: [allCategoriesProvider.overrideWith((ref) => Stream.error(StateError('boom')))],
    );
    try {
      await h.openTab(tester, 'Flussi di cassa');
      expect(find.text('Errore: Bad state: boom'), findsOneWidget);
    } finally {
      await h.unmount(tester);
    }
  });

  group('Yearly Summary savings rate', () {
    testWidgets('Italian decimal comma', (tester) async {
      await h.seed();
      await depositIn2025();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openTab(tester, 'Flussi di cassa');
        await h.cashFlowSection(tester, 'cfYearByYearTile', pick: [AppStrings.it.cfViewTable]);
        expect(find.descendant(of: find.byType(DataTable), matching: find.text('+8,3%')), findsOneWidget);
        expect(find.descendant(of: find.byType(DataTable), matching: find.text('+8.3%')), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('English decimal point', (tester) async {
      await h.seed();
      await depositIn2025();
      await h.pump(tester);
      try {
        await h.openTab(tester, 'Cash Flow');
        await h.cashFlowSection(tester, 'cfYearByYearTile', pick: [AppStrings.en.cfViewTable]);
        expect(find.descendant(of: find.byType(DataTable), matching: find.text('+8.3%')), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
