// A row created from a form without opening its date picker is dated on the
// calendar day, never at the clock time the form was opened: the forms used
// to default to DateTime.now(), so a transaction, an asset event (and the
// market price a revalue materialises), an adjustment or an adjustment entry
// were stored at e.g. 15:42 instead of on the day the money moved.
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
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/utils/visualization_clock.dart';

class _OfflinePrices extends MarketPriceService {
  _OfflinePrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};
}

class _NoRates extends ExchangeRateService {
  _NoRates(super.db);

  @override
  Future<double?> getRate(String from, String to, DateTime date) async => null;
}

/// Opens [screen] on a push once the locale and base currency are loaded, as
/// in the app (the shell watches them): the screens read them in initState.
class _Launcher extends ConsumerWidget {
  const _Launcher(this.screen);
  final Widget Function() screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue && ref.watch(baseCurrencyProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen())),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home, {String locale = 'it_IT'}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          privacyModeProvider.overrideWith((ref) => false),
          marketPriceServiceProvider.overrideWithValue(_OfflinePrices(db)),
          exchangeRateServiceProvider.overrideWithValue(_NoRates(db)),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, Widget Function() screen) async {
    await pump(tester, _Launcher(screen));
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets('a new transaction is dated on today\'s calendar day', (tester) async {
    final accountId = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    final account = await (db.select(db.accounts)..where((a) => a.id.equals(accountId))).getSingle();
    final today = dateOnly(DateTime.now());
    await open(tester, () => TransactionEditScreen(account: account));
    try {
      await tester.enterText(find.byType(TextFormField).at(1), '-12,50');
      await tapButton(tester, 'Create Transaction');

      final saved = await db.select(db.transactions).getSingle();
      expect(saved.valueDate, today, reason: 'the value date is a calendar day, not the clock time the form opened');
      expect(saved.operationDate, today);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a new revalue is dated on today\'s calendar day, and so is the market price it materialises', (tester) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'Pension fund',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    // Units held before the revalue: its total value becomes a unit price.
    await db
        .into(db.assetEvents)
        .insert(
          AssetEventsCompanion.insert(
            assetId: assetId,
            date: DateTime(2024, 1, 2),
            valueDate: DateTime(2024, 1, 2),
            type: EventType.buy,
            amount: 1000,
            quantity: const Value(10),
            price: const Value(100),
          ),
        );
    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    final today = dateOnly(DateTime.now());
    await open(tester, () => AssetEventEditScreen(asset: asset));
    try {
      await tester.tap(find.byType(DropdownButtonFormField<EventType>));
      await settle(tester);
      await tester.tap(find.text(AppStrings.en.revalueLabel).last);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Current Value'), '1500');
      await tapButton(tester, 'Create Event');

      final revalue = (await db.select(db.assetEvents).get()).singleWhere((e) => e.type == EventType.revalue);
      expect(revalue.valueDate, today, reason: 'the value date is a calendar day, not the clock time the form opened');
      expect(revalue.date, today);
      final price = await db.select(db.marketPrices).getSingle();
      expect(price.date, today, reason: 'the revalue used to create a market price row at the clock time');
      expect(price.closePrice, 150);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a new adjustment is dated on today\'s calendar day', (tester) async {
    final today = dateOnly(DateTime.now());
    await open(tester, () => const EventEditScreen());
    try {
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Car repair');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1.200');
      await settle(tester);
      await tapButton(tester, 'Create');

      final saved = await db.select(db.extraordinaryEvents).getSingle();
      expect(saved.eventDate, today, reason: 'the event date is a calendar day, not the clock time the form opened');
    } finally {
      await unmount(tester);
    }
  });

  group('event detail', () {
    Future<void> addThroughDialog(WidgetTester tester, Finder opener, String amount) async {
      await tester.tap(opener);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);
    }

    testWidgets('a new manual entry is dated on today\'s calendar day', (tester) async {
      final eventId = await ExtraordinaryEventService(db).create(
        name: 'Bonus',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 5000,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 5),
      );
      final today = dateOnly(DateTime.now());
      await pump(tester, EventDetailScreen(eventId: eventId), locale: 'en_US');
      try {
        await addThroughDialog(tester, find.text('Add entry'), '75.25');

        final entry = await db.select(db.extraordinaryEventEntries).getSingle();
        expect(entry.amount, 75.25);
        expect(entry.date, today, reason: 'the entry date is a calendar day, not the clock time the dialog opened');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a new reimbursement is dated on today\'s calendar day', (tester) async {
      final events = ExtraordinaryEventService(db);
      final eventId = await events.create(
        name: 'Car',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 1),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2025, 1, 1),
        spreadEnd: DateTime(2025, 12, 1),
      );
      await events.createLinkedBuffer(eventId);
      final today = dateOnly(DateTime.now());
      await pump(tester, EventDetailScreen(eventId: eventId), locale: 'en_US');
      try {
        await addThroughDialog(tester, find.byTooltip('Add Reimbursement'), '100');

        final reimbursement = await db.select(db.bufferTransactions).getSingle();
        expect(reimbursement.amount, 100);
        expect(reimbursement.valueDate, today, reason: 'the value date is a calendar day, not the clock time the dialog opened');
        expect(reimbursement.operationDate, today);
      } finally {
        await unmount(tester);
      }
    });
  });
}
