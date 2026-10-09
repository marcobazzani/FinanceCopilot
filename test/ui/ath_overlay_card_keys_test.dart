// Stacked ATH celebration cards each keep their own animation.
//
// Pinned bug: the cards of the cartel column had no keys. When the oldest one
// auto-dismissed, the next card was matched to the dismissed card's element
// and took over its state — a pop-in and bounce that had already run their
// course — so it froze mid-show while its own animation was thrown away.
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/ath_celebration_overlay.dart';

Future<(AthCelebrationController, BuildContext)> _mount(WidgetTester tester) async {
  late BuildContext capturedCtx;
  final controller = AthCelebrationController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [portableLanguageProvider.overrideWith((ref) => 'en')],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              capturedCtx = ctx;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  return (controller, capturedCtx);
}

void main() {
  final cartelCards = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AthCartelCard');

  /// The [index]-th card of the cartel column showing [label].
  Finder card(String label, [int index = 0]) => find.ancestor(of: find.text(label), matching: cartelCards).at(index);

  /// Where [card] is drawn: the matrices of its bounce, roll and pop-in, end
  /// to end.
  List<double> pose(WidgetTester tester, Finder card) => [
    for (final t in tester.widgetList<Transform>(find.descendant(of: card, matching: find.byType(Transform)))) ...t.transform.storage,
  ];

  /// Whether [card] moves between two frames 100 ms apart.
  Future<bool> moving(WidgetTester tester, Finder card) async {
    final before = pose(tester, card);
    await tester.pump(const Duration(milliseconds: 100));
    final after = pose(tester, card);
    expect(before, isNotEmpty);
    return !listEquals(before, after);
  }

  testWidgets('when the oldest card auto-dismisses, the next one keeps its own state and keeps bouncing', (tester) async {
    final (controller, ctx) = await _mount(tester);
    try {
      controller.fire(ctx, 'Portfolio');
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      controller.fire(ctx, 'Total Assets');
      await tester.pump();
      final state = tester.state(card('Total Assets'));

      // t = 9 s: the first card's lifetime is over; the second is 6 s into its 9 s.
      await tester.pump(const Duration(seconds: 6));
      expect(controller.cards.map((c) => c.label), ['Total Assets']);
      expect(tester.state(card('Total Assets')), same(state), reason: 'its own animation, not the dismissed card\'s');
      expect(await moving(tester, card('Total Assets')), isTrue, reason: 'still bouncing: its show is not over');
    } finally {
      controller.dispose();
    }
  });

  testWidgets('two cards for the same label are told apart: the later one outlives the first', (tester) async {
    final (controller, ctx) = await _mount(tester);
    try {
      // The auto-fire and the 6-tap easter egg both firing one label.
      controller.fire(ctx, 'Portfolio');
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      controller.fire(ctx, 'Portfolio');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Portfolio'), findsNWidgets(2));
      final later = tester.state(card('Portfolio', 1));

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Portfolio'), findsOneWidget);
      expect(tester.state(card('Portfolio')), same(later));
      expect(await moving(tester, card('Portfolio')), isTrue);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('pin: the stack keeps the firing order, oldest first', (tester) async {
    final (controller, ctx) = await _mount(tester);
    try {
      for (final label in ['Portfolio', 'Total Assets', 'Performance']) {
        controller.fire(ctx, label);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final tops = [
        for (final label in ['Portfolio', 'Total Assets', 'Performance']) tester.getCenter(card(label)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(tester.takeException(), isNull);
    } finally {
      controller.dispose();
    }
  });
}
