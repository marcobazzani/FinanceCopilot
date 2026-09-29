// The shared pieces that mask a figure inside a sentence: the sentence is
// unchanged outside privacy mode, and in privacy mode only the figures blur —
// the words, counts and dates around them stay readable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/privacy_text.dart';
import 'package:finance_copilot/utils/dialogs.dart';

void main() {
  bool masked(Finder f) => find.ancestor(of: f, matching: find.byType(ImageFiltered)).evaluate().isNotEmpty;

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyModeProvider.overrideWith((ref) => false)],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  testWidgets('PrivacySentence: the plain sentence outside privacy mode, only the figures blurred in it', (tester) async {
    final container = await pump(
      tester,
      PrivacySentence(
        'Opening ${privacySlot(0)} implied by the closing (${privacySlot(1)}) on 3 rows.',
        figures: const ['1,000.00', '1,100.00'],
      ),
    );
    expect(find.text('Opening 1,000.00 implied by the closing (1,100.00) on 3 rows.'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);

    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    expect(masked(find.text('1,000.00')), isTrue);
    expect(masked(find.text('1,100.00')), isTrue);
    final words = find.textContaining('implied by the closing (');
    expect(words, findsOneWidget);
    expect(masked(words), isFalse, reason: 'the words and the count around the figures stay readable');
    expect(find.textContaining('on 3 rows.'), findsOneWidget);
  });

  testWidgets('PrivacyMask follows the flag it is given', (tester) async {
    await pump(
      tester,
      const Column(
        children: [
          PrivacyMask(isPrivate: true, child: Text('a')),
          PrivacyMask(isPrivate: false, child: Text('b')),
        ],
      ),
    );
    expect(masked(find.text('a')), isTrue);
    expect(masked(find.text('b')), isFalse);
  });

  testWidgets('showConfirmDialog masks the quoted figure only; without figures it stays plain text', (tester) async {
    final container = await pump(
      tester,
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => showConfirmDialog(
                context,
                title: 'Duplicate',
                content: 'An adjustment of ${privacySlot(0)} already exists.',
                maskedFigures: const ['€12.00'],
                confirmLabel: 'Add',
                cancelLabel: 'Cancel',
              ),
              child: const Text('masked'),
            ),
            TextButton(
              onPressed: () =>
                  showConfirmDialog(context, title: 'Delete', content: 'Delete "Main"?', confirmLabel: 'Delete', cancelLabel: 'Cancel'),
              child: const Text('plain'),
            ),
          ],
        ),
      ),
    );
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();

    await tester.tap(find.text('masked'));
    await tester.pumpAndSettle();
    expect(masked(find.text('€12.00')), isTrue);
    expect(masked(find.textContaining('already exists.')), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('plain'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Main"?'), findsOneWidget);
    expect(find.byType(PrivacySentence), findsNothing, reason: 'callers that quote no figure keep the plain text');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('showInfoSnack masks the quoted figures only', (tester) async {
    final container = await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showInfoSnack(context, 'Recalculated 2 balances. Opening ${privacySlot(0)}.', maskedFigures: const ['1,000.00']),
          child: const Text('go'),
        ),
      ),
    );
    container.read(privacyModeProvider.notifier).state = true;
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(masked(find.text('1,000.00')), isTrue);
    expect(masked(find.textContaining('Recalculated 2 balances.')), isFalse);
  });

  test('a unit price is private only when the asset is not market-priced', () {
    expect(unitPriceIsPrivate(ValuationMethod.marketPrice), isFalse);
    expect(unitPriceIsPrivate(ValuationMethod.eventDriven), isTrue);
  });
}
