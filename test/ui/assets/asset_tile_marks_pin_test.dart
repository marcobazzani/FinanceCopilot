// Pins the two marks an asset tile can show under its value: "No market data"
// (no price or exchange rate) and "Cost basis unknown" (a buy without a rate
// for its day). Each is an icon and a short label side by side, with the
// explanation as its tooltip: the first in the error colour and bold, the
// second muted. They carry no amount, so privacy mode leaves them readable
// while the value beside them is masked.
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
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  const s = AppStrings.en;
  final today = DateTime(2026, 3, 10);
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// 10 units bought for 1,000 in [buyCurrency]; closing at [close] today.
  Future<int> seedFund(String name, {String buyCurrency = 'EUR', double? close}) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: '$name broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: name,
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: id,
            date: DateTime(2025, 1, 10),
            valueDate: DateTime(2025, 1, 10),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
            currency: Value(buyCurrency),
          ),
        );
    if (close != null) {
      await db.into(db.marketPrices).insert(MarketPricesCompanion.insert(assetId: id, date: today, closePrice: close, currency: 'EUR'));
    }
    return id;
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('the no-market-data badge and the cost-basis mark', (tester) async {
    final unpriced = await seedFund('Unpriced');
    final boughtInUsd = await seedFund('Bought in USD', buyCurrency: 'USD', close: 121);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => today.add(const Duration(hours: 12))),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    try {
      Finder inTile(int id, Finder f) => find.descendant(of: find.byKey(ValueKey(id)), matching: f);
      final theme = Theme.of(tester.element(find.byType(AssetsScreen)));

      void expectMark(int asset, {required String tooltip, required String label, required IconData icon, required TextStyle style}) {
        final mark = inTile(asset, find.byTooltip(tooltip));
        expect(mark, findsOneWidget, reason: label);
        final row = tester.widget<Row>(find.descendant(of: mark, matching: find.byType(Row)).first);
        expect(row.mainAxisSize, MainAxisSize.min, reason: label);
        expect(row.children, hasLength(3), reason: '$label: icon, gap, text');
        final iconWidget = row.children[0] as Icon;
        expect(iconWidget.icon, icon, reason: label);
        expect(iconWidget.size, 12, reason: label);
        expect(iconWidget.color, style.color, reason: label);
        expect((row.children[1] as SizedBox).width, 4, reason: label);
        final text = row.children[2] as Text;
        expect(text.data, label);
        expect(text.style, style, reason: label);
        expect(
          masked(find.descendant(of: mark, matching: find.text(label))),
          isFalse,
          reason: '$label: no amount in it',
        );
      }

      expectMark(
        unpriced,
        tooltip: s.noMarketData,
        label: s.noMarketData,
        icon: Icons.error_outline,
        style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600, fontSize: 11),
      );
      expectMark(
        boughtInUsd,
        tooltip: s.costBasisUnknownHint,
        label: s.costBasisUnknown,
        icon: Icons.info_outline,
        style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
      );
      expect(masked(inTile(boughtInUsd, find.text('1,210.00 €'))), isTrue, reason: 'the value beside the mark is position size');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
