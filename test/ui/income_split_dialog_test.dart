import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/widgets/income_split_dialog.dart';
import 'package:finance_copilot/utils/income_split.dart';

// "Flag as Income" no longer forces 100% of an inflow under a single type.
// These tests pin the guarantees the dialog must keep:
//  * it opens pre-filled with the whole amount as Income (previous behaviour),
//  * it refuses to return an unbalanced split (no money lost or invented),
//  * it returns one slice per non-zero type,
//  * amounts are parsed with the active locale's separators.
void main() {
  /// Opens the dialog and, when it closes, hands the result to [onResult].
  Future<void> openDialog(
    WidgetTester tester, {
    required double total,
    String currency = 'EUR',
    String locale = 'en_US',
    String language = 'en',
    void Function(List<IncomeSplitEntry>? result)? onResult,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
          portableLanguageProvider.overrideWith((ref) => language),
        ],
        child: MaterialApp(
          home: Scaffold(
            // The app shell watches appLocaleProvider, so by the time a dialog
            // opens the locale stream has emitted. Mirror that here, otherwise
            // the dialog's first read sees AsyncLoading and falls back to the
            // host platform locale.
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(appLocaleProvider);
                return ElevatedButton(
                  onPressed: () async {
                    final result = await showIncomeSplitDialog(
                      context,
                      title: 'Flag as Income',
                      total: total,
                      currency: currency,
                    );
                    onResult?.call(result);
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder fieldFor(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TextField),
  );

  String textOf(WidgetTester tester, String label) => tester.widget<TextField>(fieldFor(label)).controller!.text;

  bool canConfirm(WidgetTester tester, [String label = 'Add']) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed != null;

  testWidgets('opens with the full amount pre-filled as Income', (tester) async {
    await openDialog(tester, total: 2000);

    expect(find.text('Flag as Income'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Refund'), findsOneWidget);
    expect(find.text('Pension contribution'), findsOneWidget);
    expect(textOf(tester, 'Income'), '2,000.00');
    expect(canConfirm(tester), isTrue);
  });

  testWidgets('returns a single slice when the whole amount stays Income', (tester) async {
    List<IncomeSplitEntry>? captured;
    await openDialog(tester, total: 1500, onResult: (r) => captured = r);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(captured, [const IncomeSplitEntry(IncomeType.income, 1500)]);
  });

  testWidgets('confirm is disabled while the split does not add up', (tester) async {
    await openDialog(tester, total: 2000);

    // Take 500 out of Income without re-allocating it: 1500 of 2000 allocated.
    await tester.enterText(fieldFor('Income'), '1500');
    await tester.pump();

    expect(canConfirm(tester), isFalse, reason: 'an unbalanced split must not be savable');
    expect(find.textContaining('Remaining: '), findsOneWidget);
  });

  testWidgets('confirm is disabled when over-allocated', (tester) async {
    await openDialog(tester, total: 2000);

    await tester.enterText(fieldFor('Refund'), '100');
    await tester.pump();

    expect(canConfirm(tester), isFalse);
    expect(find.textContaining('Over by: '), findsOneWidget);
  });

  testWidgets('confirm is disabled on an unparsable amount', (tester) async {
    await openDialog(tester, total: 2000);

    await tester.enterText(fieldFor('Income'), 'abc');
    await tester.pump();

    expect(canConfirm(tester), isFalse);
    expect(find.text('Invalid amount'), findsOneWidget);
  });

  testWidgets('assign-remainder button moves the unallocated amount to a type', (tester) async {
    await openDialog(tester, total: 2000);

    await tester.enterText(fieldFor('Income'), '1500');
    await tester.pump();

    // Second assign button belongs to the Refund row.
    await tester.tap(find.byIcon(Icons.playlist_add).at(1));
    await tester.pump();

    expect(textOf(tester, 'Refund'), '500.00');
    expect(canConfirm(tester), isTrue);
  });

  testWidgets('returns one slice per non-zero type for a three-way split', (tester) async {
    List<IncomeSplitEntry>? captured;
    await openDialog(tester, total: 2000, onResult: (r) => captured = r);

    await tester.enterText(fieldFor('Income'), '1500');
    await tester.enterText(fieldFor('Refund'), '200');
    await tester.enterText(fieldFor('Pension contribution'), '300');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(captured, const [
      IncomeSplitEntry(IncomeType.income, 1500),
      IncomeSplitEntry(IncomeType.refund, 200),
      IncomeSplitEntry(IncomeType.pensionContribution, 300),
    ]);
  });

  testWidgets('cancel returns null', (tester) async {
    var called = false;
    List<IncomeSplitEntry>? captured;
    await openDialog(
      tester,
      total: 100,
      onResult: (r) {
        captured = r;
        called = true;
      },
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(captured, isNull);
  });

  testWidgets('it locale parses comma decimals and dot thousands', (tester) async {
    List<IncomeSplitEntry>? captured;
    await openDialog(
      tester,
      total: 1234.56,
      locale: 'it_IT',
      language: 'it',
      onResult: (r) => captured = r,
    );

    expect(textOf(tester, 'Reddito'), '1.234,56');

    await tester.enterText(fieldFor('Reddito'), '1.000,56');
    await tester.enterText(fieldFor('Rimborso'), '234');
    await tester.pump();

    expect(canConfirm(tester, 'Aggiungi'), isTrue, reason: '1.000,56 + 234 == 1.234,56 in it_IT');
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();

    expect(captured, const [
      IncomeSplitEntry(IncomeType.income, 1000.56),
      IncomeSplitEntry(IncomeType.refund, 234),
    ]);
  });
}
