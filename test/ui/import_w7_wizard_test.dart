// Import wizard:
//  * an income or asset import records its amounts in the stored base
//    currency (and quotes asset FX rates against it): its Import button waits
//    until that has loaded — the import used to run in a guessed 'EUR'
//    meanwhile. A transaction import records the account's currency and does
//    not wait;
//  * an asset import with no currency column records the events, and the
//    assets it creates, in the base currency: the dry run says so, and the
//    wizard now tells the user (confirm step and quick confirm);
//  * the computed-fee preview values a bond's units per 100 of face value, as
//    the import does: the single asset imported into, the ISIN's asset at the
//    chosen intermediary, or the listing picked for a new ISIN. It used to
//    ignore the bond divisor (a 10 fee previewed as 975,140).
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/import/import_config_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

/// Answers every search with one bond listing, which the exchange picker picks.
class _BondListings extends WebMarketDataService {
  _BondListings(super.db);

  @override
  Future<List<ProviderSearchResult>> search(String query) async => [
    ProviderSearchResult(cid: 1, description: 'BTP 2030', symbol: 'BTP', exchange: 'Milan', flag: 'IT', type: 'Bonds', isin: query),
  ];
}

void main() {
  const en = AppStrings.en;
  const it = AppStrings.it;
  final h = ImportHarness();
  late StreamController<String> base;
  late int broker;

  setUpAll(ImportHarness.initLocales);
  setUp(() async {
    h.open();
    base = StreamController<String>();
    broker = await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to completes its close only once listened to.
    unawaited(base.close());
    await h.close();
  });

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Finder importButton(AppStrings s) => find.widgetWithText(FilledButton, s.importButton);
  bool enabled(WidgetTester tester, Finder button) => tester.widget<FilledButton>(button).onPressed != null;

  // A 10,000 face-value BTP bought at 98.50 (9,850) with a 10 commission.
  const bondTrade = FilePreview(
    columns: ['Day', 'Code', 'Units', 'Unit price', 'FX', 'Gross', 'Ccy'],
    rows: [
      {'Day': '11/05/2022', 'Code': 'IT0005383309', 'Units': '10000', 'Unit price': '98.5', 'FX': '1', 'Gross': '-9860', 'Ccy': 'EUR'},
    ],
    totalRows: 1,
    numberLocale: 'en_US',
  );

  /// Maps an ISIN-grouped asset import of [bondTrade] and continues to the
  /// confirm step (field labels in [s]).
  Future<void> mapTrades(WidgetTester tester, AppStrings s, {bool currency = false}) async {
    await h.mapColumn(tester, '${s.fieldLabel('date')} *', 'Day');
    await h.mapColumn(tester, '${s.fieldLabel('isin')} *', 'Code');
    await h.mapColumn(tester, s.fieldLabel('amount'), 'Gross');
    await h.mapColumn(tester, s.fieldLabel('quantity'), 'Units');
    if (currency) await h.mapColumn(tester, s.fieldLabel('currency'), 'Ccy');
  }

  Future<int> bond({ValuationMethod valuation = ValuationMethod.marketPrice, String? isin = 'IT0005383309'}) => h.db
      .into(h.db.assets)
      .insert(
        AssetsCompanion.insert(
          name: 'BTP 2030',
          assetType: AssetType.stockEtf,
          instrumentType: const Value(InstrumentType.bond),
          valuationMethod: valuation,
          isin: Value(isin),
          intermediaryId: broker,
        ),
      );

  group('the Import waits for the stored base currency', () {
    List<Override> pending() => [baseCurrencyProvider.overrideWith((ref) => base.stream)];

    testWidgets('an income import: nothing is imported before it loads; then the incomes are recorded in it', (tester) async {
      const incomes = FilePreview(
        columns: ['Day', 'Gross'],
        rows: [
          {'Day': '11/05/2022', 'Gross': '2500'},
        ],
        totalRows: 1,
        numberLocale: 'en_US',
      );
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.income, testPreview: incomes),
        overrides: pending(),
      );
      try {
        await h.mapColumn(tester, 'Operation Date *', 'Day');
        await h.mapColumn(tester, 'Amount *', 'Gross');
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        expect(enabled(tester, importButton(en)), isFalse, reason: 'the base currency is not known yet');
        await tester.tap(importButton(en), warnIfMissed: false);
        await h.settle(tester);
        expect(await h.db.select(h.db.incomes).get(), isEmpty, reason: 'no income in a guessed currency');

        base.add('CHF');
        await h.settle(tester, frames: 4);
        expect(enabled(tester, importButton(en)), isTrue);
        await tap(tester, importButton(en));
        expect(find.text(en.importComplete), findsOneWidget);
        expect((await h.db.select(h.db.incomes).getSingle()).currency, 'CHF');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('an asset import: nothing is imported before it loads; then events and assets are recorded in it', (tester) async {
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade),
        overrides: pending(),
      );
      try {
        await mapTrades(tester, en);
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        await tap(tester, find.text('Broker'));
        expect(enabled(tester, importButton(en)), isFalse, reason: 'the base currency is not known yet');

        base.add('CHF');
        await h.settle(tester, frames: 4);
        expect(enabled(tester, importButton(en)), isTrue);
        await tap(tester, importButton(en));
        expect(find.text(en.importComplete), findsOneWidget);
        expect((await h.db.select(h.db.assetEvents).getSingle()).currency, 'CHF');
        expect((await h.db.select(h.db.assets).getSingle()).currency, 'CHF');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a transaction import does not wait: it records the account currency', (tester) async {
      final acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main', currency: const Value('USD')));
      await ImportConfigService(h.db).save(
        accountId: acct,
        skipRows: 0,
        mappings: {'date': 'Day', 'amount': 'Gross', '__balanceMode': 'cumulative'},
        formula: const [],
        hashColumns: const [],
        numberLocale: 'en_US',
      );
      const statement = FilePreview(
        columns: ['Day', 'Gross'],
        rows: [
          {'Day': '11/05/2022', 'Gross': '100'},
        ],
        totalRows: 1,
        numberLocale: 'en_US',
      );
      await h.pump(
        tester,
        ImportScreen(preselectedAccountId: acct, testPreview: statement),
        overrides: pending(),
      );
      try {
        expect(enabled(tester, importButton(en)), isTrue, reason: 'the quick confirm needs no base currency');
        await tap(tester, importButton(en));
        expect(find.text(en.importComplete), findsOneWidget);
        expect((await h.db.select(h.db.transactions).getSingle()).currency, 'USD');
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('an asset import without a currency column says so', () {
    List<Override> chf() => [baseCurrencyProvider.overrideWith((ref) => Stream.value('CHF'))];

    for (final (s, language) in [(en, 'en'), (it, 'it')]) {
      testWidgets('confirm step ($language)', (tester) async {
        await h.pump(
          tester,
          const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade),
          language: language,
          overrides: chf(),
        );
        try {
          await mapTrades(tester, s);
          await tap(tester, find.widgetWithText(FilledButton, s.next));
          expect(find.text(s.importBaseCurrencyAssumed('CHF')), findsOneWidget);
        } finally {
          await h.unmount(tester);
        }
      });
    }

    testWidgets('nothing is said when a currency column is mapped', (tester) async {
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade),
        overrides: chf(),
      );
      try {
        await mapTrades(tester, en, currency: true);
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        expect(find.text(en.importPreviewTitle), findsOneWidget, reason: 'the dry run is shown');
        expect(find.text(en.importBaseCurrencyAssumed('CHF')), findsNothing);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('quick confirm of a saved single-asset config', (tester) async {
      final target = await bond(valuation: ValuationMethod.eventDriven, isin: null);
      await ImportConfigService(h.db).saveScoped(
        scope: ImportConfigScope.assetSingle,
        assetId: target,
        skipRows: 0,
        mappings: {'date': 'Day', 'amount': 'Gross'},
        formula: const [],
        hashColumns: const [],
        numberLocale: 'en_US',
      );
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade),
        overrides: chf(),
      );
      try {
        await tap(tester, find.text(en.importIntoSingleAsset));
        await tap(tester, find.byType(DropdownButtonFormField<int>));
        await tap(tester, find.text('BTP 2030').last);
        expect(find.text(en.savedConfigDetected), findsOneWidget, reason: 'the quick confirm');
        expect(find.text(en.importBaseCurrencyAssumed('CHF')), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('the computed-fee preview values a bond per 100 of face value', () {
    // With the rate column mapped the old preview showed |-9,860| - 10,000 x
    // 98.50 / 1 = 975,140.00.
    const fee = 'Preview: 10.00';

    Future<void> computedFee(WidgetTester tester, {bool rate = true}) async {
      await h.mapColumn(tester, en.fieldLabel('price'), 'Unit price');
      if (rate) await h.mapColumn(tester, en.fieldLabel('exchangeRate'), 'FX');
      await tap(tester, find.text(en.computedLabel).first);
    }

    testWidgets('the single asset imported into', (tester) async {
      final target = await bond(valuation: ValuationMethod.eventDriven, isin: null);
      // A single-asset import maps quantity and price through its saved config.
      await ImportConfigService(h.db).saveScoped(
        scope: ImportConfigScope.assetSingle,
        assetId: target,
        skipRows: 0,
        mappings: {
          'date': 'Day',
          'amount': 'Gross',
          'quantity': 'Units',
          'price': 'Unit price',
          'exchangeRate': 'FX',
          '__feeMode': 'computed',
        },
        formula: const [],
        hashColumns: const [],
        numberLocale: 'en_US',
      );
      await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade));
      try {
        await tap(tester, find.text(en.importIntoSingleAsset));
        await tap(tester, find.byType(DropdownButtonFormField<int>));
        await tap(tester, find.text('BTP 2030').last);
        await tap(tester, find.widgetWithText(OutlinedButton, en.letMeEdit));
        expect(find.text(fee), findsOneWidget, reason: '|-9,860| - 10,000 x 98.50 / 100 / 1');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the asset of the ISIN at the chosen intermediary', (tester) async {
      await bond();
      await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade));
      try {
        await mapTrades(tester, en);
        await computedFee(tester);
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        await tap(tester, find.text('Broker'));
        await tap(tester, find.byIcon(Icons.arrow_back));
        expect(find.text(fee), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('no exchange-rate column: the value is not converted, as in the import', (tester) async {
      await bond();
      await h.pump(tester, const ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade));
      try {
        await mapTrades(tester, en);
        await computedFee(tester, rate: false);
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        await tap(tester, find.text('Broker'));
        await tap(tester, find.byIcon(Icons.arrow_back));
        expect(find.text(fee), findsOneWidget, reason: 'it used to need a rate even with no rate column: N/A');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the listing picked for a new ISIN', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(h.db),
            importServiceProvider.overrideWithValue(h.importer),
            marketPriceServiceProvider.overrideWithValue(_BondListings(h.db)),
            privacyModeProvider.overrideWith((ref) => false),
            portableLanguageProvider.overrideWith((ref) => 'en'),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          ],
          child: const MaterialApp(
            home: ImportScreen(preselectedTarget: ImportTarget.assetEvent, testPreview: bondTrade),
          ),
        ),
      );
      await h.settle(tester);
      try {
        await mapTrades(tester, en);
        await computedFee(tester);
        await tap(tester, find.widgetWithText(FilledButton, en.next));
        expect(find.text('BTP — Milan'), findsOneWidget, reason: 'the listing is picked');
        await tap(tester, find.byIcon(Icons.arrow_back));
        expect(find.text(fee), findsOneWidget);
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
