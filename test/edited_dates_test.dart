// editedDates: the single rule the income, transaction and asset event edit
// forms follow for their two date columns. The form shows one date, the
// value date; the booking date only keys the import dedup, so it moves only
// along with a value date it was in sync with.
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/utils/visualization_clock.dart';

void main() {
  group('editedDates', () {
    test('the same day writes neither column', () {
      final dates = editedDates(edited: DateTime(2024, 3, 15), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 13));
      expect(dates.valueDate, isNull);
      expect(dates.bookingDate, isNull);
    });

    test('the same day at another time of day is not a move', () {
      final dates = editedDates(edited: DateTime(2024, 3, 15, 18, 30), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 15));
      expect(dates.valueDate, isNull);
      expect(dates.bookingDate, isNull, reason: 'the in-sync booking date stays too');
    });

    test('a moved day of an in-sync row moves both columns', () {
      final dates = editedDates(edited: DateTime(2024, 3, 20), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 15));
      expect(dates.valueDate, DateTime(2024, 3, 20));
      expect(dates.bookingDate, DateTime(2024, 3, 20));
    });

    test('a moved day of an imported row moves only the value date', () {
      final dates = editedDates(edited: DateTime(2024, 3, 20), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 13));
      expect(dates.valueDate, DateTime(2024, 3, 20));
      expect(dates.bookingDate, isNull, reason: 'a booking date distinct from the value date is the bank\'s');
    });

    test('a booking date on the same day but at another instant is not in sync', () {
      // Exact equality, as the forms always compared: only a row whose two
      // columns hold the very same instant was created with one date.
      final dates = editedDates(edited: DateTime(2024, 3, 20), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 15, 9));
      expect(dates.valueDate, DateTime(2024, 3, 20));
      expect(dates.bookingDate, isNull);
    });

    test('a move across a month or a year boundary is a move', () {
      expect(
        editedDates(edited: DateTime(2024, 4, 15), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 15)).valueDate,
        DateTime(2024, 4, 15),
      );
      expect(
        editedDates(edited: DateTime(2025, 3, 15), valueDate: DateTime(2024, 3, 15), bookingDate: DateTime(2024, 3, 15)).bookingDate,
        DateTime(2025, 3, 15),
      );
    });
  });
}
