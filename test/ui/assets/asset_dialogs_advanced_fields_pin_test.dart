// Pins what the asset Create and Edit dialogs render once unlocked: the
// advanced (unlock-only) fields, in order, with their hints, and what each
// of them saves. The two dialogs render different advanced fields — Create
// also unlocks the TER and the Active switch (always shown by Edit), Edit
// also shows the read-only valuation method and the intermediary picker
// (Create picks the intermediary up front) — from one shared builder.
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;
  late int broker;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The dialog's form, top to bottom: one line per child of its content
  /// column — a gap, a divider, or the fields it holds (label, hint, helper).
  List<String> layout(WidgetTester tester) {
    final scroll = find.descendant(of: find.byType(AlertDialog), matching: find.byType(SingleChildScrollView)).first;
    final column = tester.element(find.descendant(of: scroll, matching: find.byType(Column)).first);
    String field(InputDecoration d) => [
      d.labelText,
      if (d.hintText != null) 'hint=${d.hintText}',
      if (d.helperText != null) 'helper=${d.helperText}',
      if (d.suffixIcon case Icon(icon: Icons.lock_outline)) 'locked',
    ].join(' ');
    String describe(Element child) {
      final w = child.widget;
      if (w is SizedBox && w.child == null) return 'gap ${w.height}';
      if (w is Divider) return 'divider ${w.height}';
      final parts = <String>[];
      void visit(Element e) {
        final v = e.widget;
        if (v is InputDecorator) {
          parts.add(field(v.decoration));
        } else if (v is SwitchListTile) {
          parts.add('switch ${(v.title! as Text).data}');
        } else {
          e.visitChildElements(visit);
        }
      }

      visit(child);
      return parts.join(' | ');
    }

    final lines = <String>[];
    column.visitChildElements((child) => lines.add(describe(child)));
    return lines;
  }

  Finder dialogField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  Future<void> pick<T>(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<T>));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(SwitchListTile, title)));
    await settle(tester);
  }

  Future<void> tapDialogButton(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, label)));
    await settle(tester);
  }

  group('Create Asset (manual) unlocked', () {
    Future<void> openUnlocked(WidgetTester tester) async {
      await pump(tester, const AssetsScreen());
      final fab = find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'add_asset');
      await tester.tap(fab.evaluate().isNotEmpty ? fab : find.text('Create Asset'));
      await settle(tester);
      await tester.tap(find.text('Enter manually'));
      await settle(tester);
      await tester.enterText(dialogField('Name'), 'Fund');
      await pick<int>(tester, 'Broker');
      await tester.tap(find.byIcon(Icons.lock_outline));
      await settle(tester);
    }

    testWidgets('renders the advanced fields after the intermediary, TER and Active included', (tester) async {
      await openUnlocked(tester);
      try {
        expect(layout(tester), [
          'Name',
          'gap 16.0',
          'Instrument Type | Asset Class',
          'gap 16.0',
          'Select Intermediary',
          'divider 24.0',
          'Asset type',
          'gap 12.0',
          'Currency (3 letters)',
          'gap 12.0',
          'TER (%) hint=0,22',
          'gap 12.0',
          'Tax rate (%) hint=26',
          'gap 8.0',
          'switch Active',
          'switch Include in savings',
        ]);
        final currency = tester.widget<TextField>(dialogField('Currency (3 letters)'));
        expect(currency.maxLength, 3);
        expect(currency.textCapitalization, TextCapitalization.characters);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('creates the asset with every advanced field as set', (tester) async {
      await openUnlocked(tester);
      try {
        await pick<AssetType>(tester, 'Bond ETF');
        await tester.enterText(dialogField('Currency (3 letters)'), 'usd');
        await tester.enterText(dialogField('TER (%)'), '0,3');
        await tester.enterText(dialogField('Tax rate (%)'), '12,5');
        await toggle(tester, 'Active');
        await toggle(tester, 'Include in savings');
        await tapDialogButton(tester, 'Create');

        final asset = (await db.select(db.assets).get()).single;
        expect(asset.name, 'Fund');
        expect(asset.assetType, AssetType.bondEtf);
        expect(asset.currency, 'USD');
        expect(asset.ter, 0.3);
        expect(asset.taxRate, closeTo(0.125, 1e-12));
        expect(asset.isActive, isFalse);
        expect(asset.includeInSavings, isFalse);
        expect(asset.valuationMethod, ValuationMethod.marketPrice);
        expect(asset.intermediaryId, broker);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('Edit Asset unlocked', () {
    late Asset asset;
    late int second;

    setUp(() async {
      second = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Second broker'));
      final id = await db
          .into(db.assets)
          .insert(
            AssetsCompanion.insert(
              name: 'World ETF',
              assetType: AssetType.stockEtf,
              instrumentType: const Value(InstrumentType.etf),
              assetClass: const Value(AssetClass.equity),
              valuationMethod: ValuationMethod.marketPrice,
              intermediaryId: broker,
              ter: const Value(0.2),
            ),
          );
      asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
    });

    Future<void> openUnlocked(WidgetTester tester) async {
      await pump(tester, AssetDetailScreen(asset: asset));
      await tester.tap(find.byTooltip('Edit Asset'));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.lock_outline));
      await settle(tester);
    }

    testWidgets('renders the advanced fields after Active, valuation method and intermediary included', (tester) async {
      await openUnlocked(tester);
      try {
        expect(layout(tester), [
          'Name',
          'gap 12.0',
          'Ticker hint=e.g. SWDA',
          'gap 12.0',
          'Identifier (ISIN, fund ID, etc.) hint=Optional',
          'gap 16.0',
          'Stock Exchange',
          'gap 16.0',
          'Instrument Type | Asset Class',
          'gap 16.0',
          'TER (%) hint=0,22',
          'gap 8.0',
          'switch Active',
          'divider 24.0',
          'Asset type',
          'gap 12.0',
          'Valuation method helper=Automatic: becomes "Event-driven (manual)" when the asset has a revalue, reverts to "Market price" when all are removed. locked',
          'gap 12.0',
          'Intermediary',
          'gap 12.0',
          'Currency (3 letters)',
          'gap 12.0',
          'Tax rate (%) hint=26',
          'gap 8.0',
          'switch Include in savings',
        ]);
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Market price')), findsOneWidget);
        final currency = tester.widget<TextField>(dialogField('Currency (3 letters)'));
        expect(currency.maxLength, 3);
        expect(currency.textCapitalization, TextCapitalization.characters);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('saves every advanced field as set', (tester) async {
      await openUnlocked(tester);
      try {
        await pick<AssetType>(tester, 'Bond ETF');
        await pick<int>(tester, 'Second broker');
        await tester.enterText(dialogField('Currency (3 letters)'), 'gbp');
        await tester.enterText(dialogField('Tax rate (%)'), '12,5');
        await toggle(tester, 'Include in savings');
        await tapDialogButton(tester, 'Save');

        expect(find.byType(AlertDialog), findsNothing);
        final saved = await (db.select(db.assets)..where((a) => a.id.equals(asset.id))).getSingle();
        expect(saved.assetType, AssetType.bondEtf);
        expect(saved.intermediaryId, second);
        expect(saved.currency, 'GBP');
        expect(saved.taxRate, closeTo(0.125, 1e-12));
        expect(saved.includeInSavings, isFalse);
        expect(saved.isActive, isTrue);
        expect(saved.ter, 0.2);
        expect(saved.valuationMethod, ValuationMethod.marketPrice);
      } finally {
        await unmount(tester);
      }
    });
  });
}
