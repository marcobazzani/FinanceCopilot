// The ATH celebration releases what it creates: the overlay entry is disposed
// once removed (at the end of the show, on dismissAll, and when the
// controller is disposed mid-show), and every cartel card disposes the curved
// animations of its pop-in. They used to be removed / dropped undisposed.
// Tracked through the framework's own object-lifecycle events (the ones the
// leak tracker listens to).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/ath_celebration_overlay.dart';

/// The OverlayEntry and CurvedAnimation objects created since [start] and not
/// disposed yet.
class _Live {
  final created = <Object, String>{};

  void _onEvent(ObjectEvent e) {
    if (e is ObjectCreated && (e.className == 'OverlayEntry' || e.className == 'CurvedAnimation')) created[e.object] = e.className;
    if (e is ObjectDisposed) created.remove(e.object);
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_onEvent);
  void stop() => FlutterMemoryAllocations.instance.removeListener(_onEvent);

  Map<String, int> get counts {
    final out = <String, int>{};
    for (final name in created.values) {
      out[name] = (out[name] ?? 0) + 1;
    }
    return out;
  }
}

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
  late _Live live;

  setUp(() => live = _Live());
  tearDown(() => live.stop());

  testWidgets('a show that runs to its end leaves nothing undisposed', (tester) async {
    final (controller, ctx) = await _mount(tester);
    live.start();
    try {
      controller.fire(ctx, 'Portfolio');
      controller.fire(ctx, 'Total Assets');
      await tester.pump();
      expect(live.counts['OverlayEntry'], 1, reason: 'the overlay entry is tracked');
      expect(live.counts['CurvedAnimation'], greaterThanOrEqualTo(4), reason: 'two curves per cartel card');

      // Both cards' lifetimes run out; the last one takes the overlay down.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(controller.cards, isEmpty);
      expect(live.counts, isEmpty, reason: 'undisposed: ${live.created.values.toList()}');
    } finally {
      controller.dispose();
    }
  });

  testWidgets('dismissAll leaves nothing undisposed', (tester) async {
    final (controller, ctx) = await _mount(tester);
    live.start();
    try {
      controller.fire(ctx, 'Performance');
      await tester.pump();
      expect(live.counts['OverlayEntry'], 1);

      controller.dismissAll();
      await tester.pump();
      expect(live.counts, isEmpty, reason: 'undisposed: ${live.created.values.toList()}');
    } finally {
      controller.dispose();
    }
  });

  testWidgets('disposing the controller mid-show leaves nothing undisposed', (tester) async {
    final (controller, ctx) = await _mount(tester);
    live.start();
    controller.fire(ctx, 'Portfolio');
    await tester.pump(const Duration(seconds: 1));
    expect(live.counts['OverlayEntry'], 1);

    controller.dispose();
    await tester.pump();
    expect(live.counts, isEmpty, reason: 'undisposed: ${live.created.values.toList()}');
  });

  testWidgets('a card rebuilt mid-show keeps animating and still disposes its curves', (tester) async {
    final (controller, ctx) = await _mount(tester);
    live.start();
    try {
      controller.fire(ctx, 'Portfolio');
      await tester.pump(const Duration(milliseconds: 200));
      // A second fire rebuilds the first card while it pops in.
      controller.fire(ctx, 'Total Assets');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text('Total Assets'), findsOneWidget);

      controller.dismissAll();
      await tester.pump();
      expect(live.counts, isEmpty, reason: 'undisposed: ${live.created.values.toList()}');
    } finally {
      controller.dispose();
    }
  });
}
