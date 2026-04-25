import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/default_charts_loader.dart';
import 'package:finance_copilot/services/editable_charts_notifier.dart';

DashboardChart _chart({
  required int id,
  String widgetType = 'chart',
  String title = 'Chart',
  int sortOrder = 0,
  String seriesJson = '[]',
  String? sourceChartIds,
}) =>
    DashboardChart(
      id: id,
      title: title,
      widgetType: widgetType,
      sortOrder: sortOrder,
      seriesJson: seriesJson,
      sourceChartIds: sourceChartIds,
      createdAt: DateTime(2024, 1, 1),
    );

EditableChartsNotifier _make(List<DashboardChart> initial) =>
    EditableChartsNotifier(EditableChartsState(
      charts: List.of(initial),
      pristine: List.of(initial),
    ));

void main() {
  group('EditableChartsState.isDirty', () {
    test('false when charts == pristine', () {
      final cs = [_chart(id: -1, title: 'A')];
      final s = EditableChartsState(charts: cs, pristine: List.of(cs));
      expect(s.isDirty, isFalse);
    });

    test('true when a single chart differs', () {
      final pristine = [_chart(id: -1, title: 'A')];
      final modified = [_chart(id: -1, title: 'A renamed')];
      final s = EditableChartsState(charts: modified, pristine: pristine);
      expect(s.isDirty, isTrue);
    });

    test('true when length differs', () {
      final pristine = [_chart(id: -1)];
      final s = EditableChartsState(charts: const [], pristine: pristine);
      expect(s.isDirty, isTrue);
    });
  });

  group('EditableChartsNotifier mutations', () {
    test('add appends with descending negative id', () {
      final n = _make([_chart(id: -1), _chart(id: -3)]);
      n.add(_chart(id: 0, title: 'New')); // id=0 → notifier picks min-1 = -4
      expect(n.state.charts.length, 3);
      expect(n.state.charts.last.id, -4);
      expect(n.state.charts.last.title, 'New');
      expect(n.state.isDirty, isTrue);
    });

    test('update replaces chart by id', () {
      final n = _make([_chart(id: -1, title: 'Old')]);
      n.update(_chart(id: -1, title: 'New'));
      expect(n.state.charts.first.title, 'New');
      expect(n.state.isDirty, isTrue);
    });

    test('delete removes by id', () {
      final n = _make([_chart(id: -1), _chart(id: -2)]);
      n.delete(-1);
      expect(n.state.charts.length, 1);
      expect(n.state.charts.first.id, -2);
      expect(n.state.isDirty, isTrue);
    });

    test('move swaps adjacent positions and re-sequences sortOrder', () {
      final n = _make([
        _chart(id: -1, title: 'A', sortOrder: 0),
        _chart(id: -2, title: 'B', sortOrder: 1),
        _chart(id: -3, title: 'C', sortOrder: 2),
      ]);
      n.move(-2, 1); // B → down
      expect(n.state.charts.map((c) => c.title).toList(), ['A', 'C', 'B']);
      expect(n.state.charts.map((c) => c.sortOrder).toList(), [0, 1, 2]);
      expect(n.state.isDirty, isTrue);
    });

    test('move at boundary is a no-op', () {
      final n = _make([_chart(id: -1, title: 'A'), _chart(id: -2, title: 'B')]);
      n.move(-1, -1); // A is already first; can't move up
      expect(n.state.charts.map((c) => c.id).toList(), [-1, -2]);
      expect(n.state.isDirty, isFalse);
    });

    test('restoreRole adds missing role from pristine', () {
      final n = _make([
        _chart(id: -1, widgetType: 'price_changes', title: 'PC'),
        _chart(id: -2, widgetType: 'cash', title: 'Cash', seriesJson: '[{"x":1}]'),
      ]);
      // User deletes Cash.
      n.delete(-2);
      expect(n.state.charts.length, 1);
      expect(n.state.isDirty, isTrue);

      // Restore → fresh id, same content.
      n.restoreRole('cash');
      final restored = n.state.charts.firstWhere((c) => c.widgetType == 'cash');
      expect(restored.title, 'Cash');
      expect(restored.seriesJson, '[{"x":1}]');
      // Cash is back, but it's a *new* instance with a fresh id, so the
      // dirty flag stays true.
      expect(n.state.isDirty, isTrue);
    });

    test('restoreRole no-op when role chart already present', () {
      final n = _make([_chart(id: -1, widgetType: 'cash', title: 'Cash')]);
      n.restoreRole('cash');
      expect(n.state.charts.length, 1);
      expect(n.state.isDirty, isFalse);
    });

    test('reset replaces working list with pristine', () {
      final n = _make([_chart(id: -1, title: 'A')]);
      n.update(_chart(id: -1, title: 'A renamed'));
      expect(n.state.isDirty, isTrue);
      n.reset();
      expect(n.state.charts.first.title, 'A');
      expect(n.state.isDirty, isFalse);
    });
  });
}
