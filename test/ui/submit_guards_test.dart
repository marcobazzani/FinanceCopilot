// In-flight guards on forms whose submit awaits a service.
//
// Pinned bugs:
//  * PillarCreateDialog: the Create/Save button stayed enabled while the save
//    was running, so a double tap created the pillar twice.
//  * IsinUrlPasteRecovery: the Verify button is disabled while an address is
//    being resolved, but Enter in the field was not, so a second Enter started
//    a second fetch (and a second onResolved).
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/providers.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/market/web_market_data_service.dart';
import 'package:finance_copilot/services/pillars/pillar_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/pillars/pillar_create_dialog.dart';
import 'package:finance_copilot/ui/widgets/isin_url_paste_recovery.dart';

/// Holds every create until the test opens [gate].
class _GatedPillarService extends PillarService {
  _GatedPillarService(super.db);

  final gate = Completer<void>();
  final created = <String>[];

  @override
  Future<String> create({
    required String name,
    double? targetValue,
    String targetCurrency = 'EUR',
    String? portfolioModelId,
    PillarKind kind = PillarKind.standard,
  }) async {
    created.add(name);
    await gate.future;
    return super.create(name: name, targetValue: targetValue, targetCurrency: targetCurrency, portfolioModelId: portfolioModelId, kind: kind);
  }
}

void main() {
  const s = AppStrings.en;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('PillarCreateDialog', () {
    Future<void> openDialog(WidgetTester tester, {List overrides = const []}) async {
      // Wide enough for the portfolio-model labels in the test font.
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            appLocaleProvider.overrideWith((ref) => Stream.value('en')),
            ...overrides,
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog(context: context, builder: (_) => const PillarCreateDialog()),
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

    testWidgets('Create stores the pillar with its parsed target and closes', (tester) async {
      await openDialog(tester);
      try {
        await tester.enterText(field(0), 'Retirement');
        await tester.enterText(field(1), '100000');
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        final pillar = (await PillarService(db).getAll()).single;
        expect(pillar.name, 'Retirement');
        expect(pillar.targetValue, 100000);
      } finally {
        await unmount(tester);
      }
    });

    testWidgets('a second tap on Create while the first save runs creates one pillar', (tester) async {
      final service = _GatedPillarService(db);
      await openDialog(tester, overrides: [pillarServiceProvider.overrideWithValue(service)]);
      try {
        await tester.enterText(field(0), 'Retirement');
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, s.create));
        await tester.pump();
        service.gate.complete();
        await settle(tester);

        expect(service.created, ['Retirement']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(await PillarService(db).getAll(), hasLength(1));
      } finally {
        await unmount(tester);
      }
    });
  });

  group('IsinUrlPasteRecovery', () {
    late String bondHtml;

    setUpAll(() => bondHtml = File('test/fixtures/instrument_page_be0000351602.html').readAsStringSync());

    testWidgets('Enter again while an address is being resolved does not fetch it twice', (tester) async {
      final gate = Completer<void>();
      var fetches = 0;
      final resolved = <ProviderSearchResult>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            marketPriceServiceProvider.overrideWith(
              (ref) => WebMarketDataService(
                db,
                pageFetcher: (_) async {
                  fetches++;
                  await gate.future;
                  return bondHtml;
                },
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: IsinUrlPasteRecovery(
                  userQuery: 'BE0000351602',
                  cacheKey: 'BE0000351602',
                  defaultExchange: 'MIL',
                  onResolved: resolved.add,
                ),
              ),
            ),
          ),
        ),
      );
      final urlField = find.byKey(const Key('pasteUrlField'));
      await tester.enterText(urlField, 'https://www.investing.com/rates-bonds/be0000351602');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('verifyUrlButton'))).onPressed, isNull, reason: 'resolving');

      await tester.tap(urlField);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(fetches, 1);
      expect(resolved, hasLength(1));
      await unmount(tester);
    });
  });
}
