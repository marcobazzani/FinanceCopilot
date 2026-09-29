// PrivacyText's `masked` flag: a figure that is position size only in some
// cases (a unit price, see unitPriceIsPrivate; a metric row that is sometimes
// an amount and sometimes a count) goes through one widget either way.
// Masked — the default — it blurs in privacy mode; unmasked it is the same
// plain text, style, alignment and line settings included, in privacy mode
// too.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';

void main() {
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  testWidgets('privacy mode blurs a masked figure and leaves an unmasked one plain, with the same text settings', (tester) async {
    const style = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyModeProvider.overrideWith((ref) => false)],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PrivacyText('1,234.00', style: style, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
                PrivacyText('121.00', style: style, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, masked: false),
              ],
            ),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(masked(find.text('1,234.00')), isFalse, reason: 'privacy mode is off');
    expect(masked(find.text('121.00')), isFalse);

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    expect(masked(find.text('1,234.00')), isTrue, reason: 'masked unless told otherwise');
    expect(masked(find.text('121.00')), isFalse, reason: 'unmasked: readable in privacy mode');
    expect(find.byType(ImageFiltered), findsOneWidget);
    for (final figure in ['1,234.00', '121.00']) {
      final text = tester.widget<Text>(find.text(figure));
      expect(text.style, style, reason: figure);
      expect(text.textAlign, TextAlign.right, reason: figure);
      expect(text.maxLines, 1, reason: figure);
      expect(text.overflow, TextOverflow.ellipsis, reason: figure);
    }
  });
}
