// The import wizard's inline create dialogs use the stored base currency, and
// only once it has loaded — they used to guess 'EUR' meanwhile:
//
//  * New account: Create stays off until the base currency is known; the
//    account is then created in it.
//  * New empty asset: the currency field is pre-filled with the base currency
//    only once it has loaded (a currency the user typed meanwhile is kept).
//
// Pinned bug: the new-asset Create had no in-flight guard, so a second tap
// while the first create was running created a second asset.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/l10n/app_strings.dart';
import 'package:finance_copilot/services/domain/asset_service.dart';
import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/services/providers/providers.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'import_wizard_harness.dart';

/// Holds every asset create on [gate] and counts them.
class _GatedAssetService extends AssetService {
  _GatedAssetService(super.db);

  final gate = Gate();
  int creates = 0;

  @override
  Future<int> create({
    required String name,
    required int intermediaryId,
    String? ticker,
    String? isin,
    String? exchange,
    required String currency,
    double? taxRate,
    ValuationMethod valuationMethod = ValuationMethod.marketPrice,
    InstrumentType? instrumentType,
    AssetClass? assetClass,
    AssetType assetType = AssetType.stockEtf,
    double? ter,
    bool? isActive,
    bool? includeInSavings,
  }) async {
    creates++;
    await gate.wait;
    return super.create(
      name: name,
      intermediaryId: intermediaryId,
      currency: currency,
      valuationMethod: valuationMethod,
      instrumentType: instrumentType,
      assetClass: assetClass,
    );
  }
}

void main() {
  const s = AppStrings.en;
  final h = ImportHarness();
  late StreamController<String> base;

  setUpAll(ImportHarness.initLocales);
  setUp(() {
    h.open();
    base = StreamController<String>();
  });
  tearDown(() async {
    // Not awaited: a stream nobody listened to completes its close only once listened to.
    unawaited(base.close());
    await h.close();
  });

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await h.settle(tester, frames: 4);
    await tester.tap(f);
    await h.settle(tester);
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);
  Finder createButton() => inDialog(find.widgetWithText(FilledButton, s.create));
  bool enabled(WidgetTester tester, Finder button) => tester.widget<FilledButton>(button).onPressed != null;

  testWidgets('new account: nothing is created before the base currency is known; then it is created in it', (tester) async {
    await h.pump(tester, const ImportScreen(), overrides: [baseCurrencyProvider.overrideWith((ref) => base.stream)]);
    try {
      await tap(tester, find.widgetWithText(OutlinedButton, s.createAccount));
      await tester.enterText(inDialog(find.byType(TextField)), 'Savings');
      await h.settle(tester, frames: 4);
      expect(enabled(tester, createButton()), isFalse, reason: 'the base currency is not known yet');
      await tester.tap(createButton());
      await h.settle(tester);
      expect(await h.db.select(h.db.accounts).get(), isEmpty, reason: 'no account in a guessed currency');

      base.add('CHF');
      await h.settle(tester, frames: 4);
      expect(enabled(tester, createButton()), isTrue);
      await tap(tester, createButton());
      expect(find.byType(AlertDialog), findsNothing);
      final account = (await h.db.select(h.db.accounts).get()).single;
      expect((account.name, account.currency), ('Savings', 'CHF'));
    } finally {
      await h.unmount(tester);
    }
  });

  group('new empty asset', () {
    Finder currencyField() => inDialog(find.widgetWithText(TextFormField, s.currency));
    String currencyText(WidgetTester tester) =>
        tester.widget<EditableText>(find.descendant(of: currencyField(), matching: find.byType(EditableText))).controller.text;

    Future<void> openDialog(WidgetTester tester, {AssetService? assets}) async {
      await h.db.into(h.db.intermediaries).insert(IntermediariesCompanion.insert(name: 'Pension fund'));
      await h.pump(
        tester,
        const ImportScreen(preselectedTarget: ImportTarget.assetEvent),
        overrides: [
          baseCurrencyProvider.overrideWith((ref) => base.stream),
          if (assets != null) assetServiceProvider.overrideWithValue(assets),
        ],
      );
      await tap(tester, find.text(s.importIntoSingleAsset));
      await tap(tester, find.widgetWithText(OutlinedButton, s.createEmptyAsset));
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('the currency is pre-filled only once the base currency has loaded', (tester) async {
      await openDialog(tester);
      try {
        await tester.enterText(inDialog(find.widgetWithText(TextField, s.name)), 'My pension');
        await h.settle(tester, frames: 4);
        expect(currencyText(tester), isEmpty, reason: 'no guessed currency is offered');
        expect(enabled(tester, createButton()), isFalse, reason: 'no currency to create the asset in yet');

        base.add('CHF');
        await h.settle(tester, frames: 4);
        expect(currencyText(tester), 'CHF');
        await tap(tester, createButton());
        final asset = (await h.db.select(h.db.assets).get()).single;
        expect((asset.name, asset.currency), ('My pension', 'CHF'));
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a currency typed before the base currency loads is kept', (tester) async {
      await openDialog(tester);
      try {
        await tester.enterText(inDialog(find.widgetWithText(TextField, s.name)), 'My pension');
        await tester.enterText(currencyField(), 'usd');
        await h.settle(tester, frames: 4);
        expect(enabled(tester, createButton()), isTrue, reason: 'the typed currency needs no base currency');
        base.add('CHF');
        await h.settle(tester, frames: 4);
        expect(currencyText(tester), 'usd', reason: 'the user\'s currency, not the base currency');
        await tap(tester, createButton());
        expect((await h.db.select(h.db.assets).get()).single.currency, 'USD');
      } finally {
        await h.unmount(tester);
      }
    });

    testWidgets('a second tap while the create runs creates nothing more', (tester) async {
      final assets = _GatedAssetService(h.db);
      await openDialog(tester, assets: assets);
      try {
        base.add('EUR');
        await tester.enterText(inDialog(find.widgetWithText(TextField, s.name)), 'My pension');
        await h.settle(tester, frames: 4);
        await tester.tap(createButton());
        await h.settle(tester, frames: 4);
        expect(enabled(tester, createButton()), isFalse, reason: 'off while the asset is being created');
        await tester.tap(createButton(), warnIfMissed: false);
        await h.settle(tester, frames: 4);
        expect(assets.creates, 1);

        assets.gate.open();
        await h.settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ImportScreen), findsOneWidget, reason: 'only the dialog closed');
        expect(await h.db.select(h.db.assets).get(), hasLength(1));
      } finally {
        await h.unmount(tester);
      }
    });
  });
}
