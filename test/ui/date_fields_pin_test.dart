// The date field of the four forms that pick a day — transaction, asset
// event, adjustment, adjustment entry: its label, the day it shows (the
// display locale's short date), the picker it opens (on that day, from the
// form's first year) and the day it hands back, which the form saves. The
// shared DateFormField keeps no day of its own: it shows the one its form
// passes, in the display locale.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/ui/widgets/edit_form_fields.dart';

class _NoRates extends ExchangeRateService {
  _NoRates(super.db);

  @override
  Future<double?> getRate(String from, String to, DateTime date) async => null;
}

class _NoPrices extends MarketPriceService {
  _NoPrices(super.db);

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<double?> getPrice(int assetId, DateTime date) async => null;
}

/// Opens [screen] on a push once the locale and base currency are loaded, as
/// in the app: the screens read them in initState.
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
  late StreamController<String> locale;

  setUpAll(() async => initializeDateFormatting());
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    locale = StreamController<String>();
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to completes its close only once listened to.
    unawaited(locale.close());
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Pumps [home] in [initialLocale] (the stream can move on later).
  Future<void> pump(WidgetTester tester, Widget home, {String initialLocale = 'en_US'}) async {
    locale.add(initialLocale);
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => locale.stream),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          privacyModeProvider.overrideWith((ref) => false),
          exchangeRateServiceProvider.overrideWithValue(_NoRates(db)),
          marketPriceServiceProvider.overrideWithValue(_NoPrices(db)),
        ],
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, Widget Function() screen, {String initialLocale = 'en_US'}) async {
    await pump(tester, _Launcher(screen), initialLocale: initialLocale);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }

  DatePickerDialog picker(WidgetTester tester) => tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

  /// Taps the field showing [shown], checks the picker it opens and picks
  /// [day] of the month shown.
  Future<void> pickFrom(WidgetTester tester, String shown, {required DateTime initial, required int firstYear, required int day}) async {
    await tester.ensureVisible(find.text(shown));
    await tester.tap(find.text(shown));
    await settle(tester);
    expect(picker(tester).initialDate, initial, reason: 'the picker opens on the day shown');
    expect(picker(tester).firstDate, DateTime(firstYear));
    expect(picker(tester).lastDate, DateTime(2100));
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  /// The label of the field showing [shown] ([InputDecorator] of a text
  /// field or of a tappable box).
  String? labelOf(WidgetTester tester, String shown) =>
      tester.widget<InputDecorator>(find.ancestor(of: find.text(shown), matching: find.byType(InputDecorator)).first).decoration.labelText;

  String short(String locale, DateTime d) => DateFormat.yMd(locale).format(d);

  testWidgets('transaction: "Date *" shows the day; the picker opens on it from 1990; the picked day is saved', (tester) async {
    final account = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            accountId: account,
            operationDate: DateTime(2024, 3, 10),
            valueDate: DateTime(2024, 3, 10),
            amount: -20,
          ),
        );
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    final acc = await (db.select(db.accounts)..where((a) => a.id.equals(account))).getSingle();
    await open(
      tester,
      () => TransactionEditScreen(transaction: tx, account: acc),
      initialLocale: 'it_IT',
    );
    try {
      expect(labelOf(tester, '10/03/2024'), 'Date *');
      await pickFrom(tester, '10/03/2024', initial: DateTime(2024, 3, 10), firstYear: 1990, day: 15);
      expect(find.text('15/03/2024'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await settle(tester);
      final saved = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
      expect(saved.valueDate, DateTime(2024, 3, 15));
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('asset event: "Date *" shows today; the picker opens on it from 1990', (tester) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final assetId = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
          ),
        );
    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await open(tester, () => AssetEventEditScreen(asset: asset));
    try {
      expect(labelOf(tester, short('en_US', today)), 'Date *');
      final day = now.day == 10 ? 11 : 10;
      await pickFrom(tester, short('en_US', today), initial: today, firstYear: 1990, day: day);
      expect(find.text(short('en_US', DateTime(now.year, now.month, day))), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });

  group('adjustment', () {
    Future<ExtraordinaryEvent> seed() async {
      final events = ExtraordinaryEventService(db);
      final id = await events.create(
        name: 'Bonus',
        direction: EventDirection.inflow,
        treatment: EventTreatment.instant,
        totalAmount: 5000,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 5),
      );
      return events.getById(id);
    }

    testWidgets('"Event date" shows the day; the picker opens on it from 2000; the picked day is saved', (tester) async {
      final event = await seed();
      await open(tester, () => EventEditScreen(event: event));
      try {
        expect(labelOf(tester, '1/5/2026'), 'Event date');
        await pickFrom(tester, '1/5/2026', initial: DateTime(2026, 1, 5), firstYear: 2000, day: 20);
        expect(find.text('1/20/2026'), findsOneWidget);

        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect((await ExtraordinaryEventService(db).getById(event.id)).eventDate, DateTime(2026, 1, 20));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the day is re-spelled when the display locale changes', (tester) async {
      final event = await seed();
      await open(tester, () => EventEditScreen(event: event));
      try {
        expect(find.text('1/5/2026'), findsOneWidget);
        locale.add('it_IT');
        await settle(tester);
        expect(find.text('05/01/2026'), findsOneWidget);
        expect(find.text('1/5/2026'), findsNothing);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('adjustment entry', () {
    Future<int> seed() => ExtraordinaryEventService(db).create(
      name: 'Bonus',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );

    testWidgets('"Date" shows today; the picker opens on it from 2000; the picked day is the entry\'s', (tester) async {
      final eventId = await seed();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await pump(tester, EventDetailScreen(eventId: eventId));
      try {
        await tester.tap(find.text('Add entry'));
        await settle(tester);
        expect(labelOf(tester, short('en_US', today)), 'Date');
        final day = now.day == 10 ? 11 : 10;
        await pickFrom(tester, short('en_US', today), initial: today, firstYear: 2000, day: day);
        expect(find.text(short('en_US', DateTime(now.year, now.month, day))), findsOneWidget);

        await tester.enterText(find.widgetWithText(TextField, 'Amount'), '75');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await settle(tester);
        final entry = await db.select(db.extraordinaryEventEntries).getSingle();
        expect(entry.date, DateTime(now.year, now.month, day));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the day is re-spelled when the display locale changes', (tester) async {
      final eventId = await seed();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await pump(tester, EventDetailScreen(eventId: eventId));
      try {
        await tester.tap(find.text('Add entry'));
        await settle(tester);
        expect(find.text(short('en_US', today)), findsOneWidget);
        locale.add('it_IT');
        await settle(tester);
        expect(find.text(short('it_IT', today)), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });
  });

  // The shared field itself: it keeps no day of its own.
  group('DateFormField', () {
    /// A form that keeps its day in [day] and lets the test change it.
    Future<void> pumpField(WidgetTester tester, ValueNotifier<DateTime> day, {required void Function(DateTime) onPicked}) => pump(
      tester,
      Scaffold(
        body: Form(
          child: ValueListenableBuilder<DateTime>(
            valueListenable: day,
            builder: (_, date, _) => DateFormField(date: date, onPicked: onPicked),
          ),
        ),
      ),
    );

    testWidgets('a picked day is handed back; the field shows the day its caller passes back', (tester) async {
      final day = ValueNotifier(DateTime(2024, 3, 10));
      addTearDown(day.dispose);
      final picked = <DateTime>[];
      await pumpField(tester, day, onPicked: picked.add);
      try {
        await pickFrom(tester, '3/10/2024', initial: DateTime(2024, 3, 10), firstYear: 1990, day: 15);
        expect(picked, [DateTime(2024, 3, 15)]);
        expect(find.text('3/10/2024'), findsOneWidget, reason: 'the caller has not taken the picked day');

        day.value = picked.single;
        await settle(tester);
        expect(find.text('3/15/2024'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a day the caller changes by itself is shown, and re-spelled in a new display locale', (tester) async {
      final day = ValueNotifier(DateTime(2024, 3, 10));
      addTearDown(day.dispose);
      await pumpField(tester, day, onPicked: (_) {});
      try {
        day.value = DateTime(2025, 12, 31);
        await settle(tester);
        expect(find.text('12/31/2025'), findsOneWidget);

        locale.add('it_IT');
        await settle(tester);
        expect(find.text('31/12/2025'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmount(tester);
      }
    });
  });
}
