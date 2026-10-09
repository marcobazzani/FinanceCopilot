// The asset Edit dialog (asset detail → pencil):
// - a TER or tax rate the active locale cannot read is flagged on its field
//   and nothing is saved. Strict parsing returns null for such text, and the
//   dialog used to save that null — silently clearing the stored TER or the
//   tax-rate override;
// - a TER the user does not touch saves unchanged (it was pre-filled with
//   three decimals at most);
// - the intermediary picker (unlocked) follows the live intermediary list: it
//   used to watch the list through the detail screen's ref, so the open
//   dialog never rebuilt when the list changed.
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;
  late Asset asset;

  setUpAll(() async => initializeDateFormatting());
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
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
            taxRate: const Value(0.26),
          ),
        );
    asset = await (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openEditDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
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
        child: MaterialApp(home: AssetDetailScreen(asset: asset)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Edit Asset'));
    await settle(tester);
    expect(find.text('Edit Asset'), findsWidgets);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder dialogField(String label) => find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, label));

  Future<Asset> reload() => (db.select(db.assets)..where((a) => a.id.equals(asset.id))).getSingle();

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Save')));
    await settle(tester);
  }

  testWidgets('an unreadable TER is flagged and the stored TER is kept', (tester) async {
    await openEditDialog(tester);
    try {
      // "0.25" is not a number in it_IT (the dot groups thousands).
      await tester.enterText(dialogField('TER (%)'), '0.25');
      await tapSave(tester);

      expect(find.byType(AlertDialog), findsOneWidget, reason: 'the dialog stays open on invalid input');
      expect(find.text('Invalid number'), findsOneWidget);
      expect((await reload()).ter, 0.2, reason: 'the stored TER was silently cleared');

      await tester.enterText(dialogField('TER (%)'), '0,25');
      await tapSave(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).ter, 0.25);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('an unreadable tax rate is flagged and the stored override is kept', (tester) async {
    await openEditDialog(tester);
    try {
      await tester.tap(find.byIcon(Icons.lock_outline));
      await settle(tester);
      await tester.enterText(dialogField('Tax rate (%)'), '12.5');
      await tapSave(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Invalid number'), findsOneWidget);
      expect((await reload()).taxRate, 0.26, reason: 'the stored override was silently cleared');

      await tester.enterText(dialogField('Tax rate (%)'), '12,5');
      await tapSave(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).taxRate, closeTo(0.125, 1e-12));
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a name-only edit keeps every digit of the TER', (tester) async {
    await (db.update(db.assets)..where((a) => a.id.equals(asset.id))).write(const AssetsCompanion(ter: Value(0.1234)));
    asset = await reload();
    await openEditDialog(tester);
    try {
      expect(tester.widget<TextField>(dialogField('TER (%)')).controller!.text, '0,1234', reason: 'it used to be pre-filled as 0,123');
      await tester.enterText(dialogField('Name'), 'World ETF (acc)');
      await tapSave(tester);
      expect(find.byType(AlertDialog), findsNothing);
      final saved = await reload();
      expect(saved.name, 'World ETF (acc)');
      expect(saved.ter, 0.1234);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('clearing the TER still removes it', (tester) async {
    await openEditDialog(tester);
    try {
      await tester.enterText(dialogField('TER (%)'), '');
      await tapSave(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).ter, isNull);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('the unlocked intermediary picker lists an intermediary added while the dialog is open', (tester) async {
    await openEditDialog(tester);
    try {
      await tester.tap(find.byIcon(Icons.lock_outline));
      await settle(tester);
      await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Second broker'));
      await settle(tester);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await settle(tester);
      expect(find.text('Second broker'), findsWidgets);
    } finally {
      await unmount(tester);
    }
  });
}
