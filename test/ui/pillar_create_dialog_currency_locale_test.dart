// Pillar dialog:
// - the target currency comes from the app's shared currency list (it offered
//   four hard-coded ones); a new pillar still defaults to EUR, an edited one to
//   the currency it has;
// - the target is pre-filled and saved in one locale. The dialog read the
//   locale once on open with an 'en' fallback: opened before the locale had
//   loaded, a stored 1234.5678 was pre-filled "1234.5678" and then saved under
//   it_IT, which does not read it. It now waits for the locale: the target is
//   pre-filled once it has loaded, and Save stays off until then.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/exchange_rate_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/pillar_create_dialog.dart';

void main() {
  const s = AppStrings.en;
  late AppDatabase db;
  late StreamController<String> locale;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    locale = StreamController<String>();
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to completes its close only once
    // listened to.
    unawaited(locale.close());
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Opens the dialog at once — before [locale] has emitted anything unless
  /// the test added a value first.
  Future<void> openDialog(WidgetTester tester, {Pillar? existing}) async {
    // Wide enough for the portfolio-model labels in the test font.
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleProvider.overrideWith((ref) => locale.stream),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PillarCreateDialog(existing: existing),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder field(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);
  Finder currencyField() => find.descendant(of: find.byType(AlertDialog), matching: find.byType(DropdownButtonFormField<String>));
  String? currency(WidgetTester tester) => tester.state<FormFieldState<String>>(currencyField()).value;
  FilledButton saveButton(WidgetTester tester, String label) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  group('target currency', () {
    testWidgets('a new pillar defaults to EUR and stores it when left alone', (tester) async {
      locale.add('en_US');
      await openDialog(tester);
      try {
        expect(currency(tester), 'EUR');
        await tester.enterText(field(0), 'Retirement');
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await settle(tester);

        expect((await PillarService(db).getAll()).single.targetCurrency, 'EUR');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('an edited pillar shows the currency it has and keeps it', (tester) async {
      locale.add('en_US');
      final id = await PillarService(db).create(name: 'Retirement', targetValue: 5000, targetCurrency: 'GBP');
      await openDialog(tester, existing: await PillarService(db).getById(id));
      try {
        expect(currency(tester), 'GBP');
        await tester.tap(find.widgetWithText(FilledButton, s.save));
        await settle(tester);

        expect((await PillarService(db).getById(id))!.targetCurrency, 'GBP');
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('the list is the app\'s shared currency list; one beyond the old four is stored', (tester) async {
      locale.add('en_US');
      await openDialog(tester);
      try {
        final items = tester
            .widget<DropdownButton<String>>(find.descendant(of: currencyField(), matching: find.byType(DropdownButton<String>)))
            .items!;
        expect(items.map((i) => i.value), ExchangeRateService.allCurrencies);

        await tester.enterText(field(0), 'Japan');
        await tester.tap(currencyField());
        await settle(tester);
        await tester.tap(find.text('JPY').last);
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await settle(tester);

        expect((await PillarService(db).getAll()).single.targetCurrency, 'JPY');
      } finally {
        await unmount(tester);
      }
    });
  });

  group('one locale for the pre-fill and the save', () {
    testWidgets('opened before the locale has loaded, the target is pre-filled in it and saves unchanged', (tester) async {
      final id = await PillarService(db).create(name: 'Retirement', targetValue: 1234.5678);
      await openDialog(tester, existing: await PillarService(db).getById(id));
      try {
        expect(saveButton(tester, s.save).onPressed, isNull, reason: 'no save in a guessed locale');
        expect(tester.widget<TextField>(field(1)).controller!.text, isEmpty, reason: 'not pre-filled in a guessed locale');

        locale.add('it_IT');
        await settle(tester);
        expect(tester.widget<TextField>(field(1)).controller!.text, '1234,5678');
        expect(saveButton(tester, s.save).onPressed, isNotNull);
        await tester.tap(find.widgetWithText(FilledButton, s.save));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing, reason: 'saved, not flagged as an unreadable number');
        expect((await PillarService(db).getById(id))!.targetValue, 1234.5678);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a target typed before the locale has loaded is read in the loaded one', (tester) async {
      await openDialog(tester);
      try {
        await tester.enterText(field(0), 'Pensione');
        await tester.enterText(field(1), '1.500');
        await settle(tester);
        expect(saveButton(tester, s.create).onPressed, isNull, reason: '"1.500" would read 1.5 in English');

        locale.add('it_IT');
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await settle(tester);

        expect((await PillarService(db).getAll()).single.targetValue, 1500);
      } finally {
        await unmount(tester);
      }
    });
  });
}
