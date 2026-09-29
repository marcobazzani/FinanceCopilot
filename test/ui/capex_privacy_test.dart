// Adjustments list: the subtitle pairs the event date with the amount already
// allocated to it. The allocated amount is position size and privacy mode
// masks it; the date is not a magnitude and stays readable.
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
import 'package:finance_copilot/ui/screens/accounts/capex_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('en'));

  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('adjustment tile: the allocated amount is masked, the event date next to it stays readable', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final event = ExtraordinaryEvent(
      id: 7,
      name: 'New roof',
      direction: EventDirection.outflow,
      treatment: EventTreatment.instant,
      totalAmount: 5000,
      currency: 'EUR',
      eventDate: DateTime(2026, 1, 5),
      isActive: true,
      isEphemeral: false,
      createdAt: DateTime(2026, 1, 5),
      updatedAt: DateTime(2026, 1, 5),
    );
    const stats = ExtraordinaryEventStats(entryCount: 2, totalAmount: 5000, totalAllocated: 1234.56, remaining: 3765.44);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => Stream.value('en_US')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          extraordinaryEventsProvider.overrideWith((ref) => Stream.value([event])),
          extraordinaryEventStatsProvider.overrideWith((ref) => Stream.value({event.id: stats})),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: AdjustmentsView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(tester.element(find.byType(AdjustmentsView)));

    final date = find.textContaining('1/5/2026');
    final allocated = find.textContaining('1,234.56 €');
    expect(date, findsOneWidget);
    expect(allocated, findsOneWidget);
    expect(masked(allocated), isFalse, reason: 'nothing is masked before privacy is on');

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    expect(masked(allocated), isTrue, reason: 'the amount allocated to an adjustment is position size');
    expect(masked(date), isFalse, reason: 'a date carries no magnitude');
    expect(masked(find.text('New roof')), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
