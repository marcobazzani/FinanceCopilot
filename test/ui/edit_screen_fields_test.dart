// The transaction and the asset-event edit screens share two fields: the
// read-only date field that opens the date picker (and spells the picked day
// in the display locale), and the required amount (a number the locale reads).
// The asset-event screen also looks the FX rate and the unit price up again
// for a newly picked day.
import 'dart:async';

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
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/market/market_price_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/assets/asset_event_edit_screen.dart';
import 'package:finance_copilot/ui/screens/events/transaction_edit_screen.dart';
import 'package:finance_copilot/ui/widgets/edit_form_fields.dart';

/// Records the day of every FX-rate lookup; answers none.
class _Rates extends ExchangeRateService {
  _Rates(super.db);
  final days = <DateTime>[];

  @override
  Future<double?> getRate(String from, String to, DateTime date) async {
    days.add(date);
    return null;
  }
}

/// Records the day of every unit-price lookup; answers none.
class _Prices extends MarketPriceService {
  _Prices(super.db);
  final days = <DateTime>[];

  @override
  Future<Map<DateTime, double>> fetchHistoricalPrices(String ticker, String currency, DateTime from) async => const {};

  @override
  Future<double?> getPrice(int assetId, DateTime date) async {
    days.add(date);
    return null;
  }
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
  late _Rates rates;
  late _Prices prices;

  setUpAll(() async => initializeDateFormatting());
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    rates = _Rates(db);
    prices = _Prices(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, Widget Function() screen) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          portableLanguageProvider.overrideWith((ref) => 'en'),
          privacyModeProvider.overrideWith((ref) => false),
          marketPriceServiceProvider.overrideWithValue(prices),
          exchangeRateServiceProvider.overrideWithValue(rates),
        ],
        child: MaterialApp(home: _Launcher(screen)),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  String text(WidgetTester tester, String label) => tester.widget<TextFormField>(field(label)).controller!.text;
  TextField inner(WidgetTester tester, String label) =>
      tester.widget<TextField>(find.descendant(of: field(label), matching: find.byType(TextField)));

  Future<void> pickDay(WidgetTester tester, int day) async {
    await tester.tap(field('Date *'));
    await settle(tester);
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  Future<Account> insertAccount() async {
    final id = await db.into(db.accounts).insert(AccountsCompanion.insert(name: 'Main'));
    return (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<Asset> insertAsset(String currency) async {
    final broker = await db.into(db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Broker'));
    final id = await db
        .into(db.assets)
        .insert(
          AssetsCompanion.insert(
            name: 'World ETF',
            assetType: AssetType.stockEtf,
            valuationMethod: ValuationMethod.marketPrice,
            intermediaryId: broker,
            currency: Value(currency),
          ),
        );
    return (db.select(db.assets)..where((a) => a.id.equals(id))).getSingle();
  }

  group('shared fields', () {
    test('a required number: empty is required, an unreadable one invalid, in the display language', () {
      const en = AppStrings.en;
      expect(requiredNumberError(null, en, locale: 'en_US'), 'Required');
      expect(requiredNumberError('', en, locale: 'en_US'), 'Required');
      expect(requiredNumberError('abc', en, locale: 'en_US'), 'Invalid number');
      expect(requiredNumberError('12.50', en, locale: 'en_US'), isNull);
      expect(requiredNumberError('-12,50', AppStrings.it, locale: 'it_IT'), isNull);
      expect(requiredNumberError('', AppStrings.it, locale: 'it_IT'), 'Obbligatorio');
      expect(requiredNumberError('abc', AppStrings.it, locale: 'it_IT'), 'Numero non valido');
    });

    testWidgets('the date field always holds its day: the form validates', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appLocaleProvider.overrideWith((ref) => Stream.value('it_IT'))],
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DateFormField(date: DateTime(2024, 3, 10), onPicked: (_) {}),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('10/03/2024'), findsOneWidget);
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    });
  });

  group('transaction', () {
    testWidgets('the date field is read-only and spells the picked day in the display locale', (tester) async {
      final account = await insertAccount();
      final id = await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: account.id,
              operationDate: DateTime(2024, 3, 10),
              valueDate: DateTime(2024, 3, 10),
              amount: -20,
            ),
          );
      final tx = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
      await open(tester, () => TransactionEditScreen(transaction: tx, account: account));
      try {
        expect(text(tester, 'Date *'), '10/03/2024');
        expect(inner(tester, 'Date *').readOnly, isTrue);
        expect(find.descendant(of: field('Date *'), matching: find.byIcon(Icons.calendar_today)), findsOneWidget);

        await pickDay(tester, 15);
        expect(text(tester, 'Date *'), '15/03/2024');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the amount is required and must be a number the locale reads', (tester) async {
      final account = await insertAccount();
      await open(tester, () => TransactionEditScreen(account: account));
      try {
        await tester.tap(find.widgetWithText(FilledButton, 'Create Transaction'));
        await settle(tester);
        expect(find.text('Required'), findsOneWidget);

        await tester.enterText(field('Amount *'), 'abc');
        await tester.tap(find.widgetWithText(FilledButton, 'Create Transaction'));
        await settle(tester);
        expect(find.text('Required'), findsNothing);
        expect(find.text('Invalid number'), findsOneWidget);
        expect(await db.select(db.transactions).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('asset event', () {
    testWidgets('a picked day is spelled in the display locale; the rate and the price are looked up for it', (tester) async {
      final asset = await insertAsset('USD');
      await open(tester, () => AssetEventEditScreen(asset: asset));
      try {
        final now = DateTime.now();
        expect(inner(tester, 'Date *').readOnly, isTrue);
        expect(find.descendant(of: field('Date *'), matching: find.byIcon(Icons.calendar_today)), findsOneWidget);
        expect(rates.days, hasLength(1), reason: 'create mode looks the rate up for today');
        expect(prices.days, hasLength(1), reason: 'and the price');

        final day = now.day == 10 ? 11 : 10;
        await pickDay(tester, day);
        expect(text(tester, 'Date *'), '$day/${now.month.toString().padLeft(2, '0')}/${now.year}');
        expect(rates.days.last, DateTime(now.year, now.month, day));
        expect(prices.days.last, DateTime(now.year, now.month, day));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a direct amount is required and must be a number the locale reads', (tester) async {
      final asset = await insertAsset('EUR');
      await open(tester, () => AssetEventEditScreen(asset: asset));
      try {
        await tester.tap(find.byType(DropdownButtonFormField<EventType>));
        await settle(tester);
        await tester.tap(find.byWidgetPredicate((w) => w is DropdownMenuItem<EventType> && w.value == EventType.revalue).last);
        await settle(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
        await settle(tester);
        expect(find.text('Required'), findsOneWidget);

        await tester.enterText(field('Current Value'), 'abc');
        await tester.tap(find.widgetWithText(FilledButton, 'Create Event'));
        await settle(tester);
        expect(find.text('Required'), findsNothing);
        expect(find.text('Invalid number'), findsOneWidget);
        expect(await db.select(db.assetEvents).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });
}
