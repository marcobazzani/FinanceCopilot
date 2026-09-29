// PortfolioModelDialog shows the model checks' problems in the UI language,
// the weights' total in the display locale.
//
// Pinned bug: the dialog showed `PortfolioModelValidationException.messages`
// (the checks' English text) whatever the UI language.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/portfolio/portfolio_model_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/portfolio_model_dialog.dart';

/// Opens the dialog once the locale is loaded, as in the app (the shell
/// watches it).
class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(appLocaleProvider).hasValue;
    return Scaffold(
      body: Center(
        child: ready
            ? TextButton(
                key: const Key('open'),
                onPressed: () => showDialog<void>(context: context, builder: (_) => const PortfolioModelDialog()),
                child: const Text('open'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, {required String language, required String locale}) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          portableLanguageProvider.overrideWith((ref) => language),
          appLocaleProvider.overrideWith((ref) => Stream.value(locale)),
        ],
        child: const MaterialApp(home: _Launcher()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byType(PortfolioModelDialog), findsOneWidget);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder dialogField(int index) => find.descendant(of: find.byType(PortfolioModelDialog), matching: find.byType(TextField)).at(index);

  /// Fills the one row: [isin] and [weight].
  Future<void> fill(WidgetTester tester, {required String isin, required String weight}) async {
    await tester.enterText(dialogField(0), 'Core');
    await tester.enterText(dialogField(1), isin);
    await tester.enterText(dialogField(2), weight);
    await tester.enterText(dialogField(3), 'World');
    await settle(tester);
  }

  testWidgets('Italian: the problems in Italian, the total with the decimal comma', (tester) async {
    const s = AppStrings.it;
    await open(tester, language: 'it', locale: 'it_IT');
    try {
      await fill(tester, isin: 'IE00B4L5Y98', weight: '99,5');
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);

      expect(find.byType(PortfolioModelDialog), findsOneWidget, reason: 'nothing saved: the dialog stays to fix it');
      // Rows are numbered in the model they belong to (its name).
      expect(
        find.descendant(
          of: find.byType(PortfolioModelDialog),
          matching: find.text('Core riga 1: ISIN non valido\ni pesi devono sommare al 100% (totale 99,50%)'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('weights must sum'), findsNothing, reason: 'not the English check text');
      expect(find.textContaining('ISIN is malformed'), findsNothing);
      expect(await PortfolioModelService(db).getAll(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('English, in a comma-decimal locale: the English words, the locale total', (tester) async {
    const s = AppStrings.en;
    await open(tester, language: 'en', locale: 'it_IT');
    try {
      await fill(tester, isin: 'IE00B4L5Y983', weight: '99,5');
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);

      expect(find.text('weights must sum to 100% (got 99,50%)'), findsOneWidget);
      expect(await PortfolioModelService(db).getAll(), isEmpty);
    } finally {
      await unmount(tester);
    }
  });

  testWidgets('pin: English in en_US reads as the checks word it', (tester) async {
    const s = AppStrings.en;
    await open(tester, language: 'en', locale: 'en_US');
    try {
      await fill(tester, isin: '', weight: '50');
      await tester.tap(find.widgetWithText(FilledButton, s.create));
      await settle(tester);

      expect(find.text('Core row 1: ISIN is required\nweights must sum to 100% (got 50.00%)'), findsOneWidget);
    } finally {
      await unmount(tester);
    }
  });
}
