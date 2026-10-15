// EventEditScreen (adjustments), the window of a spread:
// - a window saved from a start date (a saving plan years before the
//   purchase) is shown as stored: the form used to show the N periods before
//   the event date instead, and saving it moved the whole plan there;
// - saved untouched it keeps its window and its entries;
// - a new step count keeps its start and moves its end;
// - a new event date does not move it;
// - a window of the N periods before the event still follows the event date;
// - a start date picked on a new spread pins its window;
// - the per-step amount previewed is the one written: the total less what the
//   buffer reimbursed (the form used to divide the whole total), the
//   reimbursed figure masked in privacy mode like the per-step one.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/events/event_edit_screen.dart';

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
  late ExtraordinaryEventService events;

  setUpAll(() async => initializeDateFormatting());
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    events = ExtraordinaryEventService(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, Widget Function() screen, {bool isPrivate = false}) async {
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
        child: MaterialApp(home: _Launcher(screen)),
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

  /// Taps the date field showing [shown] and picks [day] of the month the
  /// picker opens on.
  Future<void> pick(WidgetTester tester, String shown, int day) async {
    await tester.ensureVisible(find.text(shown));
    await tester.tap(find.text(shown));
    await settle(tester);
    await tester.tap(find.text('$day'));
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  /// A car bought on 26/03/2025 for 20.400, 3.000 + 5.000 of it reimbursed
  /// to its buffer afterwards, its cost saved monthly from 26/04/2017 to
  /// 26/09/2019: a window that has nothing to do with the purchase date.
  Future<ExtraordinaryEvent> seedSavingPlan() async {
    final id = await events.create(
      name: 'T-Roc',
      direction: EventDirection.outflow,
      treatment: EventTreatment.spread,
      totalAmount: 20400,
      currency: 'EUR',
      eventDate: DateTime(2025, 3, 26),
      stepFrequency: StepFrequency.monthly,
      spreadStart: DateTime(2017, 4, 26),
      spreadEnd: DateTime(2019, 9, 26),
    );
    final bufferId = await events.createLinkedBuffer(id);
    for (final (day, amount) in [(DateTime(2025, 4, 14), 3000.0), (DateTime(2025, 7, 29), 5000.0)]) {
      await db
          .into(db.bufferTransactions)
          .insert(
            BufferTransactionsCompanion.insert(
              bufferId: bufferId,
              operationDate: day,
              valueDate: day,
              amount: amount,
              balanceAfter: amount,
              isReimbursement: const Value(true),
            ),
          );
    }
    await events.generateScheduledEntries(id);
    return events.getById(id);
  }

  Future<List<(DateTime, double)>> scheduleOf(int eventId) async => [
    for (final e in await events.getEntries(eventId))
      if (e.entryKind == EventEntryKind.scheduled) (e.date, e.amount),
  ];

  group('a window saved from a start date', () {
    testWidgets('is shown as stored, with the per-step amount its entries carry', (tester) async {
      final event = await seedSavingPlan();
      await open(tester, () => EventEditScreen(event: event));
      try {
        expect(tester.widget<TextFormField>(field('Step count')).controller!.text, '30');
        expect(find.descendant(of: field('Spread start'), matching: find.text('26/04/2017')), findsOneWidget);
        expect(find.text('26/04/2017 → 26/09/2019'), findsOneWidget);
        expect(find.text('26/09/2022 → 26/02/2025'), findsNothing, reason: 'the 30 months before the purchase used to be shown');
        expect(find.text('30 steps × 413,33 €'), findsOneWidget, reason: '(20.400 − 8.000 reimbursed) / 30, as the entries carry');
        expect(find.text('30 steps × 680,00 €'), findsNothing, reason: 'the whole total used to be divided');
        expect(find.text('Net of 8.000,00 € reimbursed'), findsOneWidget);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('saved untouched keeps its window and its entries', (tester) async {
      final event = await seedSavingPlan();
      final before = await scheduleOf(event.id);
      expect(before, hasLength(30));
      expect(before.first.$1, DateTime(2017, 4, 26));
      expect(before.first.$2, closeTo(-413.33, 0.01));
      await open(tester, () => EventEditScreen(event: event));
      try {
        await tapButton(tester, 'Save');

        final saved = await events.getById(event.id);
        expect(saved.spreadStart, DateTime(2017, 4, 26));
        expect(saved.spreadEnd, DateTime(2019, 9, 26), reason: 'it used to be rewritten to 26/09/2022 → 26/02/2025');
        expect(await scheduleOf(event.id), before);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a new step count keeps its start and moves its end', (tester) async {
      final event = await seedSavingPlan();
      await open(tester, () => EventEditScreen(event: event));
      try {
        await tester.enterText(field('Step count'), '12');
        await settle(tester);
        expect(find.text('26/04/2017 → 26/03/2018'), findsOneWidget);
        expect(find.text('12 steps × 1.033,33 €'), findsOneWidget);
        await tapButton(tester, 'Save');

        final saved = await events.getById(event.id);
        expect(saved.spreadStart, DateTime(2017, 4, 26));
        expect(saved.spreadEnd, DateTime(2018, 3, 26));
        final schedule = await scheduleOf(event.id);
        expect(schedule, hasLength(12));
        expect(schedule.first.$2, closeTo(-1033.33, 0.01));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a new event date does not move it', (tester) async {
      final event = await seedSavingPlan();
      final before = await scheduleOf(event.id);
      await open(tester, () => EventEditScreen(event: event));
      try {
        await pick(tester, '26/03/2025', 20);
        expect(find.text('26/04/2017 → 26/09/2019'), findsOneWidget);
        await tapButton(tester, 'Save');

        final saved = await events.getById(event.id);
        expect(saved.eventDate, DateTime(2025, 3, 20));
        expect(saved.spreadStart, DateTime(2017, 4, 26));
        expect(saved.spreadEnd, DateTime(2019, 9, 26));
        expect(await scheduleOf(event.id), before);
      } finally {
        await unmount(tester);
      }
    });
  });

  group('a window of the N periods before the event', () {
    testWidgets('still follows the event date', (tester) async {
      final id = await events.create(
        name: 'Car insurance',
        direction: EventDirection.outflow,
        treatment: EventTreatment.spread,
        totalAmount: 1200,
        currency: 'EUR',
        eventDate: DateTime(2026, 1, 15),
        stepFrequency: StepFrequency.monthly,
        spreadStart: DateTime(2025, 7, 15),
        spreadEnd: DateTime(2025, 12, 15),
      );
      final event = await events.getById(id);
      await open(tester, () => EventEditScreen(event: event));
      try {
        expect(find.descendant(of: field('Spread start'), matching: find.text('15/07/2025')), findsOneWidget);
        expect(find.text('15/07/2025 → 15/12/2025'), findsOneWidget);
        expect(find.text('6 steps × 200,00 €'), findsOneWidget);
        expect(find.textContaining('reimbursed'), findsNothing, reason: 'nothing was reimbursed');

        await pick(tester, '15/01/2026', 20);
        expect(find.text('20/07/2025 → 20/12/2025'), findsOneWidget);
        await tapButton(tester, 'Save');

        final saved = await events.getById(id);
        expect(saved.spreadStart, DateTime(2025, 7, 20));
        expect(saved.spreadEnd, DateTime(2025, 12, 20));
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('on a new spread, a picked start date pins it: the event date no longer moves it', (tester) async {
      await open(tester, () => EventEditScreen(seedDate: DateTime(2026, 1, 15)));
      try {
        await tester.enterText(field('Name'), 'Car insurance');
        await tester.enterText(field('Amount'), '1.200');
        await tester.tap(find.text('Spread'));
        await settle(tester);
        await tester.enterText(field('Step count'), '6');
        await settle(tester);
        expect(find.descendant(of: field('Spread start'), matching: find.text('15/07/2025')), findsOneWidget);

        await pick(tester, '15/07/2025', 10);
        expect(find.text('10/07/2025 → 10/12/2025'), findsOneWidget);
        await pick(tester, '15/01/2026', 20);
        expect(find.text('10/07/2025 → 10/12/2025'), findsOneWidget);
        await tapButton(tester, 'Create');

        final saved = (await db.select(db.extraordinaryEvents).get()).single;
        expect(saved.eventDate, DateTime(2026, 1, 20));
        expect(saved.spreadStart, DateTime(2025, 7, 10));
        expect(saved.spreadEnd, DateTime(2025, 12, 10));
        final schedule = await scheduleOf(saved.id);
        expect(schedule, hasLength(6));
        expect(schedule.first, (DateTime(2025, 7, 10), -200.0));
      } finally {
        await unmount(tester);
      }
    });
  });

  testWidgets('privacy on: the reimbursed and per-step figures are masked, the step count and the dates stay readable', (tester) async {
    final event = await seedSavingPlan();
    await open(tester, () => EventEditScreen(event: event), isPrivate: true);
    try {
      final reimbursed = find.text('8.000,00 €');
      expect(reimbursed, findsOneWidget);
      expect(masked(reimbursed), isTrue, reason: 'what came back is a position size');
      final perStep = find.text('413,33 €');
      expect(perStep, findsOneWidget);
      expect(masked(perStep), isTrue);
      final count = find.textContaining('30 steps × ', findRichText: true);
      expect(count, findsOneWidget);
      expect(masked(count), isFalse, reason: 'a count of periods is shape, not size');
      final window = find.text('26/04/2017 → 26/09/2019');
      expect(window, findsOneWidget);
      expect(masked(window), isFalse, reason: 'dates are not position sizes');
      final start = find.descendant(of: field('Spread start'), matching: find.text('26/04/2017'));
      expect(start, findsOneWidget);
      expect(masked(start), isFalse);
    } finally {
      await unmount(tester);
    }
  });
}
