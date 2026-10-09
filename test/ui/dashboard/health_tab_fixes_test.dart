// Health tab:
//  * the price-change KPIs (Today / YTD / All Time) count the held assets they
//    leave out for want of a price or an exchange rate, as the Price Changes
//    card does, instead of dropping them without a word;
//  * "Today" compares against yesterday's local midnight — one calendar day
//    back, also on the days after a daylight-saving change (24 hours back from
//    a local midnight is 23:00 two days before, or 01:00);
//  * the SWR field pre-fills every digit of the stored rate (an untouched save
//    keeps it) and reads what is typed strictly in the display locale;
//  * privacy mode masks the amounts of the Savings Rate end-of-year
//    explanation and nothing else: its months, percentages and labels stay
//    readable.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/dashboard/dashboard_screen.dart';

import 'dashboard_harness.dart';

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  const s = AppStrings.en;
  final h = DashboardHarness();

  setUpAll(() async => initializeDateFormatting());
  setUp(h.open);
  tearDown(h.close);

  Finder inKpi(String kpi, String text) => find.descendant(of: h.kpiCard(kpi), matching: find.text(text));
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;
  Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(text));
  Finder swrField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

  Future<String?> storedSwr() async => (await (h.db.select(h.db.appConfigs)..where((c) => c.key.equals('FIRE_SWR'))).getSingleOrNull())?.value;

  /// 10 units held, no price on record at all.
  Future<void> seedUnpriced() async {
    final broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Other broker'));
    final asset = await h.db
        .into(h.db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Unpriced',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await h.db
        .into(h.db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: asset,
            date: DateTime(2025, 2, 3),
            valueDate: DateTime(2025, 2, 3),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
          ),
        );
  }

  group('price-change KPIs', () {
    testWidgets('a held asset without a price is counted under Today, YTD and All Time', (tester) async {
      await h.seed();
      await seedUnpriced();
      await h.pump(tester);
      try {
        for (final kpi in [s.kpiToday, s.kpiYtd, s.kpiAllTime]) {
          expect(inKpi(kpi, s.unpricedExcludedFromTotal(1)), findsOneWidget, reason: kpi);
        }
        // The priced fund still makes the change: 120 → 121 today.
        expect(inKpi(s.kpiToday, '0.83%'), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('every held asset priced: no footnote', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        for (final kpi in [s.kpiToday, s.kpiYtd, s.kpiAllTime]) {
          expect(
            find.descendant(of: h.kpiCard(kpi), matching: find.textContaining('excluded from the total')),
            findsNothing,
            reason: kpi,
          );
        }
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('"Today" is one calendar day back', () {
    /// The reference dates the Health tab asks price changes for, on [now].
    Future<List<DateTime>> referenceDates(WidgetTester tester, DateTime now) async {
      final asked = <DateTime>[];
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      rootBundle.clear();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(h.db),
            nowProvider.overrideWithValue(() => now),
            marketPriceServiceProvider.overrideWithValue(_OfflinePrices(h.db)),
            privacyModeProvider.overrideWith((ref) => false),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            assetDailyChangesProvider.overrideWith((ref, date) async {
              asked.add(date);
              return const <AssetDailyChange>[];
            }),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await h.settle(tester);
      return asked;
    }

    // The DST days only differ in a zone with daylight saving (e.g.
    // Europe/Rome); in UTC they are ordinary days and pass all the same.
    for (final (label, now, yesterday) in [
      ('an ordinary day', DateTime(2026, 6, 10, 12), DateTime(2026, 6, 9)),
      ('the day after spring forward', DateTime(2026, 3, 30, 12), DateTime(2026, 3, 29)),
      ('the day after fall back', DateTime(2026, 10, 26, 12), DateTime(2026, 10, 25)),
    ]) {
      testWidgets(label, (tester) async {
        final asked = await referenceDates(tester, now);
        try {
          expect(asked, contains(yesterday));
          expect(asked.where((d) => d.hour != 0 || d.minute != 0), isEmpty, reason: 'every reference date is a local midnight');
        } finally {
          await h.unmount(tester);
        }
      });
    }
  });

  group('SWR field', () {
    Future<void> storeSwr(String value) => h.db.into(h.db.appConfigs).insert(AppConfigsCompanion.insert(key: 'FIRE_SWR', value: value));

    testWidgets('a stored rate with more digits than the display is pre-filled in full; an untouched save keeps it', (tester) async {
      await h.seed();
      await storeSwr('3.125');
      await h.pump(tester);
      try {
        await h.openInfo(tester, s.kpiFireProgress);
        expect(find.descendant(of: swrField(), matching: find.text('3.125')), findsOneWidget);
        await h.tapDialogButton(tester, s.save);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await storedSwr(), '3.125', reason: 'rounded to 3.13 by an untouched save before');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Italian: the stored rate is pre-filled with a decimal comma', (tester) async {
      await h.seed();
      await storeSwr('3.125');
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, AppStrings.it.kpiFireProgress);
        expect(find.descendant(of: swrField(), matching: find.text('3,125')), findsOneWidget);
        await h.tapDialogButton(tester, AppStrings.it.cancel);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Italian: "12.5" is not a number there — flagged, nothing stored', (tester) async {
      const it = AppStrings.it;
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, it.kpiFireProgress);
        await tester.enterText(swrField(), '12.5');
        await h.tapDialogButton(tester, it.save);
        expect(find.byType(AlertDialog), findsOneWidget, reason: 'the dialog stays open on an unreadable rate');
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(it.invalidNumber)), findsOneWidget);
        expect(await storedSwr(), isNull);
        await h.tapDialogButton(tester, it.cancel);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('Italian: "2,5" is stored as 2.5 and "1.000" reads as one thousand, not 1', (tester) async {
      const it = AppStrings.it;
      await h.seed();
      await h.pump(tester, language: 'it', locale: 'it_IT');
      try {
        await h.openInfo(tester, it.kpiFireProgress);
        await tester.enterText(swrField(), '2,5');
        await h.tapDialogButton(tester, it.save);
        expect(await storedSwr(), '2.5');

        await h.openInfo(tester, it.kpiFireProgress);
        await tester.enterText(swrField(), '1.000');
        await h.tapDialogButton(tester, it.save);
        expect(await storedSwr(), '1000.0');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('English: "2,5" is flagged, not read as 2.5', (tester) async {
      await h.seed();
      await h.pump(tester);
      try {
        await h.openInfo(tester, s.kpiFireProgress);
        await tester.enterText(swrField(), '2,5');
        await h.tapDialogButton(tester, s.save);
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(s.invalidNumber)), findsOneWidget);
        expect(await storedSwr(), isNull);
        await h.tapDialogButton(tester, s.cancel);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  testWidgets('Savings Rate explanation in privacy mode: the amounts are masked, months, percentages and labels stay readable', (
    tester,
  ) async {
    await h.seed();
    await h.pump(tester, isPrivate: true);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);

      // Amounts: income totals, the same-period figures, the projections.
      final amounts = find.descendant(of: find.byType(AlertDialog), matching: find.text('36,000.00 €'));
      expect(amounts, findsWidgets);
      for (final amount in amounts.evaluate()) {
        expect(masked(find.byWidget(amount.widget)), isTrue, reason: 'an amount is position size');
      }
      expect(masked(find.descendant(of: find.byType(AlertDialog), matching: find.text('6,000.00 €')).first), isTrue);
      // The figures plugged into the formula itself are masked too.
      expect(masked(inDialog('/ 6,000 x 100')), isTrue);

      // Months, percentages, labels and the symbolic formula stay readable.
      for (final readable in [
        '(Jan–Feb)',
        '(100.0% vs 2025)',
        'the full-year total was',
        'End-of-year 2026 prediction',
        'Savings / Income x 100',
      ]) {
        expect(inDialog(readable), findsWidgets, reason: readable);
        expect(masked(inDialog(readable).first), isFalse, reason: '"$readable" carries no magnitude');
      }
      expect(inDialog('~0.0%'), findsWidgets, reason: 'the projected savings rate is a percentage');
      expect(masked(inDialog('~0.0%').first), isFalse);

      // No amount can be copied out of the dialog.
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && (w.data ?? w.textSpan!.toPlainText()).contains('36,000')).evaluate(),
        isEmpty,
      );
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });

  testWidgets('Savings Rate explanation without privacy: one selectable text, nothing masked', (tester) async {
    await h.seed();
    await h.pump(tester);
    try {
      await h.openInfo(tester, s.kpiSavingsRate);
      final text = find.byWidgetPredicate(
        (w) => w is SelectableText && (w.data ?? w.textSpan!.toPlainText()).contains('the full-year total was 36,000.00 €'),
      );
      expect(text, findsOneWidget);
      expect(masked(text), isFalse);
      await h.tapDialogButton(tester, s.close);
    } finally {
      await h.unmount(tester);
    }
  });
}
