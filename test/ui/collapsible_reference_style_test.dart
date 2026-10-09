// Collapsible sections follow the Cash Flow tab's ExpansionTile (the
// reference, lib/ui/screens/dashboard/cashflow_tab.dart): a w600 title at the
// tile's own size, a bodySmall subtitle, the tile's default rotating chevron
// (no custom trailing) and no card of its own around the tile.
//
// The header texts and what each header does are pinned first, so restyling
// the composition panel, the import "Refine rows & columns" panel and the
// classification card's samples cannot change them.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/market/composition_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/classification/transaction_classify_card.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<void> syncPrices({bool forceToday = false}) async {}
}

/// Never fetches composition data.
class _OfflineCompositionService extends CompositionService {
  _OfflineCompositionService(super.db);

  @override
  Future<void> clearAndResync(int assetId) async {}

  @override
  Future<void> syncCompositions() async {}
}

void main() {
  const s = AppStrings.en;

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });

  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder tileOf(Finder title) => find.ancestor(of: title, matching: find.byType(ExpansionTile)).first;

  /// The header matches the reference: the default chevron, a w600 title at
  /// the tile's own size and, when given, a bodySmall [subtitle].
  void expectReferenceHeader(WidgetTester tester, String title, {String? subtitle}) {
    final tile = tester.widget<ExpansionTile>(tileOf(find.text(title)));
    expect(tile.trailing, isNull, reason: '"$title": the tile keeps its own rotating chevron');
    expect(tile.showTrailingIcon, isTrue, reason: '"$title": the chevron is shown');
    expect(tile.dense, isNot(isTrue), reason: '"$title": a dense tile shrinks the title below the reference size');
    final style = tester.widget<Text>(find.text(title)).style;
    expect(style?.fontWeight, FontWeight.w600, reason: '"$title": the reference title weight');
    expect(style?.fontSize, isNull, reason: '"$title": the title keeps the tile\'s own size');
    if (subtitle != null) {
      final context = tester.element(find.text(subtitle));
      expect(
        tester.widget<Text>(find.text(subtitle)).style,
        Theme.of(context).textTheme.bodySmall,
        reason: '"$subtitle": the reference subtitle',
      );
    }
  }

  group('asset composition panel', () {
    late AppDatabase db;
    late Asset asset;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
      final id = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'World fund',
              assetType: AssetType.stockEtf,
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
            ),
          );
      await db.into(db.assetCompositions).insert(AssetCompositionsCompanion.insert(assetId: id, type: 'country', name: 'USA', weight: 60));
      asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    });
    tearDown(() => db.close());

    Future<void> pumpDetail(WidgetTester tester, Asset shown) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            nowProvider.overrideWithValue(() => DateTime(2026, 3, 10, 12)),
            marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
            compositionServiceProvider.overrideWithValue(_OfflineCompositionService(db)),
            portableLanguageProvider.overrideWith((ref) => 'en'),
            appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(home: AssetDetailScreen(asset: shown)),
        ),
      );
      await settle(tester);
    }

    testWidgets('pin: the title and the refresh action sit in the header; the sections open under it', (tester) async {
      await pumpDetail(tester, asset);
      try {
        expect(find.text(s.composition), findsOneWidget);
        final refresh = find.byTooltip(s.compositionRefreshTooltip);
        expect(refresh, findsOneWidget, reason: 'the refresh action is in the collapsed header');
        expect(find.descendant(of: tileOf(find.text(s.composition)), matching: refresh), findsOneWidget);
        expect(find.text(s.compositionGeographic), findsNothing, reason: 'collapsed at first');

        await tester.ensureVisible(find.text(s.composition));
        await tester.tap(find.text(s.composition));
        await settle(tester);
        for (final label in [s.compositionAssetClass, s.compositionGeographic, s.compositionSector, s.compositionTopHoldings]) {
          expect(find.text(label), findsOneWidget, reason: 'section "$label"');
        }
        expect(find.text('USA'), findsOneWidget);
        expect(find.text(s.composition), findsOneWidget, reason: 'the header is unchanged once open');
        expect(refresh, findsOneWidget, reason: 'the header is unchanged once open');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('pin: an asset without composition data shows the title but no refresh action', (tester) async {
      await (db.delete(db.assetCompositions)).go();
      await pumpDetail(tester, asset);
      try {
        expect(find.text(s.composition), findsOneWidget);
        expect(find.byTooltip(s.compositionRefreshTooltip), findsNothing);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the header matches the reference and the tile has no card of its own', (tester) async {
      await pumpDetail(tester, asset);
      try {
        expectReferenceHeader(tester, s.composition);
        expect(find.ancestor(of: tileOf(find.text(s.composition)), matching: find.byType(Card)), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('import "Refine rows & columns" panel', () {
    final h = ImportHarness();
    late int acct;

    setUp(() async {
      h.open();
      acct = await h.db.into(h.db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
      h.importer.onParseFile = (path, skip) async => FilePreview(
        columns: const ['Date', 'Description', 'Amount'],
        rows: const [
          {'Date': '11/05/2022', 'Description': 'Salary', 'Amount': '100'},
        ],
        totalRows: 1,
        filePath: path,
        skipRows: skip,
        numberLocale: 'en_US',
      );
    });
    tearDown(() => h.close());

    testWidgets('pin: its title and help line; the row and column controls open under it', (tester) async {
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
      try {
        expect(find.text(s.refineRowsColumns), findsOneWidget);
        expect(find.text(s.refineRowsColumnsHelp), findsOneWidget);
        expect(find.text(s.columnSplits), findsNothing, reason: 'collapsed at first');

        await tester.ensureVisible(find.text(s.refineRowsColumns));
        await tester.tap(find.text(s.refineRowsColumns));
        await h.settle(tester);
        expect(find.text(s.skipRows), findsOneWidget);
        expect(find.text(s.columnSplits), findsOneWidget);
        expect(find.text(s.rowFilters), findsOneWidget);
        expect(find.text(s.refineRowsColumns), findsOneWidget, reason: 'the header is unchanged once open');
        expect(find.text(s.refineRowsColumnsHelp), findsOneWidget, reason: 'the header is unchanged once open');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('the header matches the reference', (tester) async {
      await h.pump(tester, ImportScreen(preselectedAccountId: acct, initialFilePath: '/tmp/statement.csv'));
      try {
        expectReferenceHeader(tester, s.refineRowsColumns, subtitle: s.refineRowsColumnsHelp);
      } finally {
        await h.unmount(tester);
      }
    });
  });

  group('classification card samples', () {
    late AppDatabase db;
    late int acct;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      acct = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    });
    tearDown(() => db.close());

    Future<Transaction> tx(String desc, double amount, DateTime date) async {
      final n = TransactionClassifierService.normalize(description: desc, amount: amount);
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: acct,
              operationDate: date,
              valueDate: date,
              amount: amount,
              description: Value(desc),
              merchantKey: Value(n.merchantKey),
              counterparty: Value(n.counterparty),
              entryKind: Value(n.entryKind),
            ),
          );
      return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    }

    Future<void> pumpCard(WidgetTester tester) async {
      final first = await tx('Esselunga Milano', -20, DateTime(2024, 3, 10));
      final second = await tx('Esselunga Torino', -30, DateTime(2024, 4, 1));
      final group = MerchantGroup(
        merchantKey: first.merchantKey!,
        counterparty: first.counterparty,
        entryKind: null,
        count: 2,
        totalByCurrency: {first.currency: 50},
        firstDate: first.valueDate,
        lastDate: second.valueDate,
        accountIds: {acct},
        latestTransactionId: second.id,
      );
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TransactionClassifyCard(group: group, samples: [first, second]),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('pin: the samples header lists the other rows when opened', (tester) async {
      await pumpCard(tester);
      try {
        expect(find.text(s.wizardSamples), findsOneWidget);
        expect(find.text('Esselunga Torino'), findsNothing, reason: 'collapsed at first');

        await tester.tap(find.text(s.wizardSamples));
        await settle(tester);
        expect(find.text('Esselunga Torino'), findsOneWidget);
        expect(find.text(s.wizardSamples), findsOneWidget, reason: 'the header is unchanged once open');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the samples header matches the reference', (tester) async {
      await pumpCard(tester);
      try {
        expectReferenceHeader(tester, s.wizardSamples);
      } finally {
        await unmount(tester);
      }
    });
  });
}
