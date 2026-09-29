// Adding a manual entry that duplicates one already on the same day asks for
// confirmation and quotes the amount. In privacy mode that amount is position
// size and must be masked, while the warning around it stays readable.
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
import 'package:finance_copilot/ui/screens/events/event_detail_screen.dart';

void main() {
  late AppDatabase db;

  setUpAll(() async => initializeDateFormatting('en'));
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('duplicate manual entry: the amount is masked in the warning, the warning itself is readable', (tester) async {
    final service = ExtraordinaryEventService(db);
    final eventId = await service.create(
      name: 'Bonus',
      direction: EventDirection.inflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
    );
    // The entry dialog defaults to today: an identical entry is already there.
    await service.addManualEntry(eventId: eventId, date: DateTime.now(), amount: 75.25);

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = EventDetailScreen(eventId: eventId);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byWidget(screen)));
    await settle(tester);
    try {
      container.read(privacyModeProvider.notifier).state = true;
      await settle(tester);

      await tester.tap(find.text('Add entry'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '75.25');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await settle(tester);

      expect(find.text('Adjustment already exists'), findsOneWidget);
      Finder inDialog(String text) => find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(text));
      expect(inDialog('75.25'), findsOneWidget);
      expect(masked(inDialog('75.25')), isTrue, reason: 'the adjustment amount is position size');
      expect(masked(inDialog('already exists on this date for this inflow')), isFalse, reason: 'the warning stays readable');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settle(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
