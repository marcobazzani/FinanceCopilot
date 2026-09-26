// Unit tests for AthCelebrationController and the overlay it drives.
//
// The controller is the public surface that totals_table.dart drives in
// both the auto-fire path (when a row hits a new all-time high) and the
// 6-tap easter-easter egg path. These tests pin its core invariants:
//   - fire() inserts an overlay entry with the cartel + confetti.
//   - Multiple fires stack cards in the cartel column.
//   - dismissAll() tears down the overlay immediately.
//   - The overlay text uses the localized app strings.
//
// The widget tree under test mounts the controller into a real Overlay
// (via Navigator/Scaffold) so the OverlayEntry insertion path actually
// runs, not just the controller's bookkeeping.

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/ath_celebration_overlay.dart';

Future<(AthCelebrationController, BuildContext)> _mount(
  WidgetTester tester, {
  String lang = 'en',
}) async {
  late BuildContext capturedCtx;
  final controller = AthCelebrationController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        portableLanguageProvider.overrideWith((ref) => lang),
      ],
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
  group('AthCelebrationController.fire', () {
    testWidgets('inserts a cartel card with title and label (English)', (tester) async {
      final (controller, ctx) = await _mount(tester);
      try {
        controller.fire(ctx, 'Portfolio');
        await tester.pump();

        expect(find.text('NEW ALL-TIME HIGH!'), findsOneWidget);
        expect(find.text('Portfolio'), findsOneWidget);
        expect(
          find.byType(ConfettiWidget),
          findsNWidgets(9),
          reason:
              '6 confetti corner-emitters + 3 starbursts '
              '(real fireworks live in CustomPainter, not in ConfettiWidget)',
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets('renders Italian title when language is it', (tester) async {
      final (controller, ctx) = await _mount(tester, lang: 'it');
      try {
        controller.fire(ctx, 'Total Assets');
        await tester.pump();

        expect(find.text('NUOVO MASSIMO STORICO!'), findsOneWidget);
        expect(find.text('Total Assets'), findsOneWidget);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('stacks one card per active fire when called multiple times', (tester) async {
      final (controller, ctx) = await _mount(tester);
      try {
        controller.fire(ctx, 'Portfolio');
        controller.fire(ctx, 'Total Assets');
        controller.fire(ctx, 'Performance');
        await tester.pump();

        expect(find.text('NEW ALL-TIME HIGH!'), findsNWidgets(3), reason: 'one title per stacked card');
        expect(find.text('Portfolio'), findsOneWidget);
        expect(find.text('Total Assets'), findsOneWidget);
        expect(find.text('Performance'), findsOneWidget);
        expect(controller.cards.length, 3);
      } finally {
        controller.dispose();
      }
    });
  });

  group('AthCelebrationController.dismissAll', () {
    testWidgets('removes every card and the overlay entry', (tester) async {
      final (controller, ctx) = await _mount(tester);
      try {
        controller.fire(ctx, 'Portfolio');
        controller.fire(ctx, 'Total Assets');
        await tester.pump();
        expect(find.text('NEW ALL-TIME HIGH!'), findsNWidgets(2));

        controller.dismissAll();
        await tester.pump();
        expect(find.text('NEW ALL-TIME HIGH!'), findsNothing);
        expect(controller.cards, isEmpty);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('is a no-op when no cards are showing', (tester) async {
      final (controller, _) = await _mount(tester);
      try {
        controller.dismissAll();
        await tester.pump();
        // No exception thrown.
        expect(controller.cards, isEmpty);
      } finally {
        controller.dispose();
      }
    });
  });

  group('AthCelebrationController.dispose', () {
    test('safe to call without ever firing', () {
      final controller = AthCelebrationController();
      controller.dispose();
    });

    testWidgets('safe to call after firing then dismissing', (tester) async {
      final (controller, ctx) = await _mount(tester);
      controller.fire(ctx, 'Portfolio');
      await tester.pump();
      controller.dismissAll();
      await tester.pump();
      controller.dispose();
    });
  });

  test('kAthEligibleLabels pins the three in-scope chart titles', () {
    expect(kAthEligibleLabels, {'Total Assets', 'Portfolio', 'Performance'});
  });

  // The lifetime paths below used to be reached only by the live-data
  // integration walkthrough, and only on a day the fixture portfolio closed at
  // a new high — so whether they ran depended on the market, not on the code.
  group('AthCelebrationController lifetime', () {
    testWidgets('each card auto-dismisses after its lifetime, oldest first; the last one removes the overlay', (tester) async {
      final (controller, ctx) = await _mount(tester);
      try {
        controller.fire(ctx, 'Portfolio');
        await tester.pump(const Duration(seconds: 3));
        controller.fire(ctx, 'Total Assets');
        await tester.pump();
        expect(controller.cards.map((c) => c.label), ['Portfolio', 'Total Assets']);

        // t = 9 s: the first card's lifetime is over, the second stays.
        await tester.pump(const Duration(seconds: 6));
        expect(controller.cards.map((c) => c.label), ['Total Assets']);
        expect(find.text('Portfolio'), findsNothing);
        expect(find.text('Total Assets'), findsOneWidget);
        expect(find.byType(ConfettiWidget), findsNWidgets(9), reason: 'overlay stays up while a card is showing');

        // t = 12 s: the last card goes, and the overlay entry with it.
        await tester.pump(const Duration(seconds: 3));
        expect(controller.cards, isEmpty);
        expect(find.text('NEW ALL-TIME HIGH!'), findsNothing);
        expect(find.byType(ConfettiWidget), findsNothing);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('fireworks rise, burst and burn out before the card is dismissed', (tester) async {
      final (controller, ctx) = await _mount(tester);
      final fireworks = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_FireworksPainter',
      );
      // Drives the show at 10 fps; returns once [seconds] have elapsed.
      var elapsedMs = 0;
      Future<void> runUntil(double seconds) async {
        while (elapsedMs < seconds * 1000) {
          await tester.pump(const Duration(milliseconds: 100));
          elapsedMs += 100;
        }
      }

      try {
        controller.fire(ctx, 'Performance');
        await tester.pump();
        expect(fireworks, findsOneWidget);

        await runUntil(0.4); // first rocket climbing
        expect(fireworks, paints..circle());
        await runUntil(1.5); // first shells bursting, later ones still rising
        expect(fireworks, paints..circle());

        // Last launch at 4.75 s + rise + burst + cascade ≈ 8.6 s: the sky is
        // empty again while the card (9 s lifetime) is still on screen.
        await runUntil(8.9);
        expect(find.text('Performance'), findsOneWidget);
        expect(fireworks, paintsNothing);

        await runUntil(9.0);
        expect(controller.cards, isEmpty);
        expect(fireworks, findsNothing);
      } finally {
        controller.dispose();
      }
    });
  });
}
