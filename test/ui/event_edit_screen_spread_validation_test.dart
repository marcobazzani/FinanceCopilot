// EventEditScreen (adjustments), spread schedule and amount validation:
// - privacy mode masks the per-step amount of the "N steps × amount" preview
//   but keeps the step count readable (the amount was shown in the clear, and
//   N × it is the total);
// - a step count that is not a whole number from 1 is flagged, and nothing is
//   saved (it silently became 1 step);
// - an amount the locale cannot read is flagged as an invalid number, not as
//   a missing one.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';
import 'package:finance_copilot/utils/formatters.dart' as fmt;

/// Opens [screen] on a push once the locale and base currency are loaded, as
/// in the app (the shell watches them): the screen reads them in initState.
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, {bool isPrivate = false}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWith((ref) => Stream.value('EUR')),
          privacyModeProvider.overrideWith((ref) => isPrivate),
        ],
        child: MaterialApp(home: _Launcher(() => EventEditScreen(seedDate: DateTime(2026, 1, 15)))),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(EventEditScreen), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<void> fillSpread(WidgetTester tester, {required String amount, required String steps}) async {
    await tester.enterText(field('Name'), 'Car insurance');
    await tester.enterText(field('Amount'), amount);
    await tester.tap(find.text('Spread'));
    await settle(tester);
    await tester.enterText(field('Step count'), steps);
    await settle(tester);
  }

  Future<void> tapCreate(WidgetTester tester) async {
    final create = find.widgetWithText(FilledButton, 'Create');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await settle(tester);
  }

  group('spread preview', () {
    testWidgets('privacy off: the whole sentence reads in the clear', (tester) async {
      await open(tester);
      try {
        await fillSpread(tester, amount: '1.200', steps: '12');
        expect(find.text('12 steps × 100,00 €'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('privacy on: the per-step amount is masked, the step count and the window stay readable', (tester) async {
      await open(tester, isPrivate: true);
      try {
        await fillSpread(tester, amount: '1.200', steps: '12');

        final perStep = find.text('100,00 €');
        expect(perStep, findsOneWidget);
        expect(masked(perStep), isTrue, reason: 'N × the per-step amount is the total');
        final count = find.textContaining('12 steps × ', findRichText: true);
        expect(count, findsOneWidget);
        expect(masked(count), isFalse, reason: 'a count of periods is shape, not size');
        final dates = fmt.shortDateFormat('it_IT');
        final window = find.text('${dates.format(DateTime(2025, 1, 15))} → ${dates.format(DateTime(2025, 12, 15))}');
        expect(window, findsOneWidget);
        expect(masked(window), isFalse, reason: 'dates are not position sizes');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('step count', () {
    for (final typed in ['abc', '0', '2,5', '']) {
      testWidgets('"$typed" is flagged and nothing is saved', (tester) async {
        await open(tester);
        try {
          await fillSpread(tester, amount: '1.200', steps: typed);
          await tapCreate(tester);

          expect(find.byType(EventEditScreen), findsOneWidget, reason: 'the form stays open');
          expect(
            find.descendant(of: field('Step count'), matching: find.text(typed.isEmpty ? 'Required' : 'Enter a whole number from 1')),
            findsOneWidget,
          );
          expect(await db.select(db.extraordinaryEvents).get(), isEmpty, reason: 'it used to be saved as a single step');
        } finally {
          await unmount(tester);
        }
      });
    }

    testWidgets('a whole number of steps is saved as that many periods before the event', (tester) async {
      await open(tester);
      try {
        await fillSpread(tester, amount: '1.200', steps: '6');
        await tapCreate(tester);

        final saved = (await db.select(db.extraordinaryEvents).get()).single;
        expect(saved.treatment, EventTreatment.spread);
        expect(saved.totalAmount, 1200);
        expect(saved.spreadStart, DateTime(2025, 7, 15));
        expect(saved.spreadEnd, DateTime(2025, 12, 15));
      } finally {
        await unmount(tester);
      }
    });
  });

  group('amount', () {
    testWidgets('an amount the locale cannot read is an invalid number, an empty one a missing one', (tester) async {
      await open(tester);
      try {
        await tester.enterText(field('Name'), 'Car repair');
        // "1200.50" is not a number in it_IT (the dot groups thousands).
        await tester.enterText(field('Amount'), '1200.50');
        await tapCreate(tester);
        expect(find.descendant(of: field('Amount'), matching: find.text('Invalid number')), findsOneWidget);
        expect(find.descendant(of: field('Amount'), matching: find.text('Required')), findsNothing);

        await tester.enterText(field('Amount'), '');
        await tapCreate(tester);
        expect(find.descendant(of: field('Amount'), matching: find.text('Required')), findsOneWidget);
        expect(await db.select(db.extraordinaryEvents).get(), isEmpty);
      } finally {
        await unmount(tester);
      }
    });
  });
}
