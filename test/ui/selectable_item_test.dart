// Regression test for SelectableItem.
//
// A selected SelectableItem must NOT insert a coloured DecoratedBox
// between its child's ListTile and the ListTile's Material ancestor.
// The old implementation wrapped the child in `AnimatedContainer(color:
// tint)`, which trips the framework assertion "ListTile background color
// or ink splashes may be invisible" whenever a selected tile is painted —
// a flaky integration-test failure. The tint now lives on its own
// Positioned.fill layer, so selecting an item paints cleanly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/ui/widgets/selection/selectable_item.dart';
import 'package:finance_copilot/ui/widgets/selection/selection_controller.dart';

Widget _host(SelectionController<int> controller) {
  return MaterialApp(
    home: Scaffold(
      body: SelectableItem<int>(
        controller: controller,
        id: 1,
        child: const ListTile(title: Text('Row 1')),
      ),
    ),
  );
}

void main() {
  testWidgets('selected SelectableItem wrapping a ListTile throws no '
      'framework assertion', (tester) async {
    final controller = SelectionController<int>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    expect(tester.takeException(), isNull, reason: 'clean unselected paint');

    // Enter selection mode + select the row.
    controller.enter(1);
    await tester.pumpAndSettle();

    // The ListTile-background assertion would surface here if the tint
    // Container still wrapped the child.
    expect(tester.takeException(), isNull,
        reason: 'selected tile must paint without the ListTile-in-'
            'DecoratedBox assertion');
    expect(controller.contains(1), isTrue);
    expect(find.text('Row 1'), findsOneWidget);
  });

  testWidgets('check-circle overlay appears only while selected',
      (tester) async {
    final controller = SelectionController<int>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    expect(find.byIcon(Icons.check_circle), findsNothing);

    controller.enter(1);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    controller.toggle(1); // deselect
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
