// The Create Asset dialog's inline "Add intermediary" action leaves no text
// controller behind: the name prompt used to create a TextEditingController
// in a local variable that nothing ever disposed.
//
// Controllers are tracked through the framework's memory-allocation events
// (on in debug builds): every one created while the screen is used must be
// disposed once it is gone.
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/assets_screen.dart';

class _OfflineMarketPriceService extends MarketPriceService {
  _OfflineMarketPriceService(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('adding an intermediary inline leaves no undisposed text controller', (tester) async {
    expect(kFlutterMemoryAllocationsEnabled, isTrue, reason: 'allocation events are what this test observes');
    final live = Set<TextEditingController>.identity();
    void track(ObjectEvent event) {
      final object = event.object;
      if (object is! TextEditingController) return;
      if (event is ObjectCreated) live.add(object);
      if (event is ObjectDisposed) live.remove(object);
    }

    FlutterMemoryAllocations.instance.addListener(track);
    addTearDown(() => FlutterMemoryAllocations.instance.removeListener(track));

    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          marketPriceServiceProvider.overrideWithValue(_OfflineMarketPriceService(db)),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: AssetsScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Create Asset'));
    await settle(tester);
    await tester.tap(find.text('Enter manually'));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Intermediary'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Intermediary Name'), 'Broker');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create').last);
    await settle(tester);
    expect((await db.select(db.intermediaries).get()).single.name, 'Broker');

    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    expect(live.map((c) => c.text), isEmpty, reason: 'text controllers created and never disposed');
  });
}
