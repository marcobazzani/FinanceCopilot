import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';

void main() {
  group('SelectionController', () {
    test('starts inactive and empty', () {
      final c = SelectionController<int>();
      expect(c.active, isFalse);
      expect(c.count, 0);
      expect(c.ids, isEmpty);
      expect(c.contains(1), isFalse);
    });

    test('enter activates selection and notifies listeners', () {
      final c = SelectionController<int>();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.enter(1);

      expect(c.active, isTrue);
      expect(c.count, 1);
      expect(c.contains(1), isTrue);
      expect(notifications, 1);
    });

    test('enter is idempotent for the same id', () {
      final c = SelectionController<int>();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.enter(1);
      c.enter(1);

      expect(c.count, 1);
      expect(notifications, 1, reason: 'second enter should not notify');
    });

    test('toggle adds when absent and removes when present', () {
      final c = SelectionController<int>();
      c.enter(1);
      c.toggle(2);
      expect(c.ids, {1, 2});

      c.toggle(1);
      expect(c.ids, {2});
      expect(c.active, isTrue);
    });

    test('toggle down to empty leaves selection inactive', () {
      final c = SelectionController<int>();
      c.enter(1);
      c.toggle(1);
      expect(c.active, isFalse);
      expect(c.count, 0);
    });

    test('clear empties the selection and notifies exactly once', () {
      final c = SelectionController<int>();
      c.enter(1);
      c.enter(2);

      var notifications = 0;
      c.addListener(() => notifications++);

      c.clear();

      expect(c.active, isFalse);
      expect(notifications, 1);
    });

    test('clear is a no-op when already empty', () {
      final c = SelectionController<int>();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.clear();

      expect(notifications, 0);
    });

    test('selectAll replaces current selection', () {
      final c = SelectionController<int>();
      c.enter(99);
      c.selectAll([1, 2, 3]);
      expect(c.ids, {1, 2, 3});
    });

    test('ids returns an unmodifiable view', () {
      final c = SelectionController<int>();
      c.enter(1);
      expect(() => c.ids.add(42), throwsUnsupportedError);
    });
  });

  group('SelectionController range-select on long-press', () {
    // Build an ordered list of 100 ids 1..100 for the scenarios below.
    final visible = [for (var i = 1; i <= 100; i++) i];

    test('first long-press with no selection adds only the pressed id', () {
      final c = SelectionController<int>()..setOrderedIds(visible);
      c.enter(50);
      expect(c.ids, {50});
    });

    test('long-press below existing selection extends down to pressed', () {
      // Matches the user example: selected 54,57,80,81, long-press 82 -> 54..82.
      final c = SelectionController<int>()..setOrderedIds(visible);
      c.enter(54);
      c.enter(57);
      c.enter(80);
      c.enter(81);
      // At this point, 57/80/81 are not adjacent to anything already selected,
      // so enter() just added them (covered by the other tests).
      // Reset and seed a contiguous-free state:
      c.clear();
      c.selectAll([54, 57, 80, 81]);
      c.setOrderedIds(visible);

      c.enter(82);

      expect(c.ids, {for (var i = 54; i <= 82; i++) i});
    });

    test('long-press above existing selection extends up to pressed', () {
      // User example: selected 54,57,80,81, long-press 31 -> 31..81.
      final c = SelectionController<int>();
      c.selectAll([54, 57, 80, 81]);
      c.setOrderedIds(visible);

      c.enter(31);

      expect(c.ids, {for (var i = 31; i <= 81; i++) i});
    });

    test('range selection picks the FURTHEST selected item, not the nearest', () {
      // Selected 10 and 90, long-press 80. Nearest is 90 (dist 10), furthest
      // is 10 (dist 70), so the range should be 10..80.
      final c = SelectionController<int>();
      c.selectAll([10, 90]);
      c.setOrderedIds(visible);

      c.enter(80);

      expect(c.ids, {for (var i = 10; i <= 80; i++) i}..add(90));
    });

    test('long-press on an already-selected id still expands the range', () {
      // Selected 54,57,80,81, long-press 57. Furthest is 81 (dist 24), so
      // the range is 57..81. 54 stays isolated, everything from 57..81 set.
      final c = SelectionController<int>();
      c.selectAll([54, 57, 80, 81]);
      c.setOrderedIds(visible);

      c.enter(57);

      expect(c.contains(54), isTrue);
      for (var i = 57; i <= 81; i++) {
        expect(c.contains(i), isTrue, reason: '$i should be selected');
      }
      expect(c.contains(56), isFalse);
    });

    test('range select works without ordered ids (fallback to plain add)', () {
      final c = SelectionController<int>();
      c.selectAll([1, 2]);
      // No setOrderedIds() call.

      c.enter(99);

      // Fallback: just added the new id.
      expect(c.ids, {1, 2, 99});
    });

    test('range select is a no-op when the pressed id is unknown', () {
      final c = SelectionController<int>()..setOrderedIds(visible);
      c.selectAll([10, 20]);

      c.enter(999); // not in the visible list

      // Fallback: just added the new id.
      expect(c.ids, {10, 20, 999});
    });
  });
}
