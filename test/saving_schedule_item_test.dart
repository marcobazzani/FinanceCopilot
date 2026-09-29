// A synthetic "Saving for X" row carries the currency of the spread event it
// comes from. The ledger used to recover the currency by matching the row's
// event name, day and amount against every scheduled entry, and had to drop
// the row when two events in different currencies shared all three.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/domain/adjustment_items.dart';
import 'package:finance_copilot/services/domain/extraordinary_event_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> spread(String currency) => ExtraordinaryEventService(db).create(
    name: 'Car',
    direction: EventDirection.outflow,
    treatment: EventTreatment.spread,
    totalAmount: 1200,
    currency: currency,
    eventDate: DateTime(2026, 1, 1),
    stepFrequency: StepFrequency.monthly,
    spreadStart: DateTime(2025, 1, 1),
    spreadEnd: DateTime(2025, 12, 1),
  );

  test("two same-named events in different currencies: every saving row carries its own event's currency", () async {
    await spread('USD');
    await spread('GBP');
    final inputs = await ExtraordinaryEventService(db).getAdjustmentInputs();

    final res = resolveAdjustments(
      events: inputs.events,
      entriesByEvent: inputs.entriesByEvent,
      reimbursementsByEvent: inputs.reimbursementsByEvent,
      transactions: const [],
      dayKey: (d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
      adjustedLabel: (n) => n,
      reimbLabel: (n) => n,
      savingForLabel: (n) => n,
      financedLabel: (n) => n,
    );

    expect(res.savingItems, hasLength(24));
    final rowsByCurrency = <String, int>{};
    for (final item in res.savingItems) {
      expect(item.eventName, 'Car');
      expect(item.amount, closeTo(-100, 1e-9));
      rowsByCurrency[item.currency] = (rowsByCurrency[item.currency] ?? 0) + 1;
    }
    expect(rowsByCurrency, {'USD': 12, 'GBP': 12});
  });
}
