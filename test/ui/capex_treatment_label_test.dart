// Adjustments list: the treatment label next to each event (instant / spread)
// is user-visible text and follows the UI language like everything else.
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
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/accounts/capex_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('it'));

  ExtraordinaryEvent event(int id, EventTreatment treatment) => ExtraordinaryEvent(
    id: id,
    name: 'Event $id',
    direction: EventDirection.outflow,
    treatment: treatment,
    totalAmount: 1000,
    currency: 'EUR',
    eventDate: DateTime(2026, 1, 5),
    isActive: true,
    isEphemeral: false,
    createdAt: DateTime(2026, 1, 5),
    updatedAt: DateTime(2026, 1, 5),
  );

  testWidgets('the treatment label of each adjustment is in the UI language', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final instant = event(1, EventTreatment.instant);
    final spread = event(2, EventTreatment.spread);
    const stats = ExtraordinaryEventStats(entryCount: 3, totalAmount: 1000, totalAllocated: 0, remaining: 1000);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => 'it'),
          appLocaleProvider.overrideWith((ref) => Stream.value('it_IT')),
          baseCurrencyProvider.overrideWithValue(const AsyncData('EUR')),
          extraordinaryEventsProvider.overrideWith((ref) => Stream.value([instant, spread])),
          extraordinaryEventStatsProvider.overrideWith((ref) => Stream.value({spread.id: stats})),
          privacyModeProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: AdjustmentsView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    const it = AppStrings.it;
    expect(find.text(it.eventTreatmentInstant), findsOneWidget);
    expect(find.text('3 · ${it.eventTreatmentSpread}'), findsOneWidget);
    expect(find.text('instant'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
