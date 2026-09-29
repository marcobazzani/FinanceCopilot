// EventEditScreen (adjustments):
// - a second tap on the save button while the first save is in flight does
//   not create the event twice;
// - editing an event keeps every digit of a total the user did not touch
//   (the form used to pre-fill two decimals and save the rounded total).
import 'dart:async';

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

  setUpAll(() async => initializeDateFormatting());
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
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
          privacyModeProvider.overrideWith((ref) => false),
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

  testWidgets('two rapid taps on Create create one event', (tester) async {
    await open(tester, () => const EventEditScreen());
    try {
      await tester.enterText(field('Name'), 'Car repair');
      await tester.enterText(field('Amount'), '1.200');
      await settle(tester);
      // Hold the database so the first save is still in flight when the
      // second tap lands, as with the app's background database isolate.
      final release = Completer<void>();
      final held = db.transaction(() => release.future);
      final create = find.widgetWithText(FilledButton, 'Create');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.tap(create, warnIfMissed: false);
      release.complete();
      await held;
      await settle(tester);

      final events = await db.select(db.extraordinaryEvents).get();
      expect(events, hasLength(1));
      expect(events.single.totalAmount, 1200);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('a name-only edit keeps every digit of the total', (tester) async {
    final id = await ExtraordinaryEventService(db).create(
      name: 'Car repair',
      direction: EventDirection.outflow,
      treatment: EventTreatment.instant,
      totalAmount: 1234.567,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );
    final event = await ExtraordinaryEventService(db).getById(id);
    await open(tester, () => EventEditScreen(event: event));
    try {
      expect(tester.widget<TextFormField>(field('Amount')).controller!.text, '1234,567', reason: 'every digit, in the it_IT spelling');
      await tester.enterText(field('Name'), 'Car repair (garage)');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await settle(tester);

      final saved = await ExtraordinaryEventService(db).getById(id);
      expect(saved.name, 'Car repair (garage)');
      expect(saved.totalAmount, 1234.567);
    } finally {
      await unmount(tester);
    }
  });
}
