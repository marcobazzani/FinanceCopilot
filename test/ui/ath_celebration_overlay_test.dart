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
}
