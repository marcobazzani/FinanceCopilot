/// Integration test for the "Unlock all fields" affordance on the asset
/// edit dialog.
///
/// Locked default: only the original 8 fields are editable; the
/// advanced-field block (assetType, valuationMethod, intermediary,
/// currency, taxRate, includeInSavings) stays hidden. After tapping the
/// lock icon those fields appear and a Save round-trips them through
/// `AssetService.update`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/ui/screens/assets/asset_detail_screen.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Asset edit dialog — unlock reveals advanced fields and Save persists them', (tester) async {
    final db = await pumpApp(tester);
    await longSettle(tester);

    final assetId = await seedAsset(db, name: 'Edit Me', currency: 'EUR');
    final asset = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();

    // Open the AssetDetailScreen.
    final ctx = tester.element(find.byType(Navigator).first);
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
    );
    await longSettle(tester);

    // Open edit dialog.
    final editBtn = find.byIcon(Icons.edit).first;
    await tester.tap(editBtn);
    await longSettle(tester);

    // Locked default: lock_outline icon is visible; advanced labels are not.
    expect(find.byIcon(Icons.lock_outline), findsOneWidget, reason: 'edit dialog should open in locked state');
    expect(find.text('Asset type'), findsNothing, reason: 'advanced fields must be hidden when locked');
    expect(find.text('Tax rate (%)'), findsNothing);

    // Tap the lock icon to unlock.
    await tester.tap(find.byIcon(Icons.lock_outline));
    await longSettle(tester);
    expect(find.byIcon(Icons.lock_open), findsOneWidget, reason: 'icon flips to lock_open after unlock');
    expect(find.text('Asset type'), findsOneWidget, reason: 'advanced fields appear when unlocked');
    expect(find.text('Tax rate (%)'), findsOneWidget);

    // Edit Tax rate (per-asset override; consumed by the detail header
    // badge at asset_detail_screen.dart:112). The field accepts the
    // percentage directly to match its "(%)" label; on save, the dialog
    // divides by 100 so the DB stores the fraction (0.27 = 27%).
    final taxField = find.widgetWithText(TextField, 'Tax rate (%)');
    expect(taxField, findsOneWidget);
    await tester.ensureVisible(taxField);
    await longSettle(tester);
    await tester.enterText(taxField, '27');
    await longSettle(tester);

    // Save.
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(saveBtn, findsOneWidget);
    await tester.ensureVisible(saveBtn);
    await longSettle(tester);
    await tester.tap(saveBtn);
    await longSettle(tester);

    // Verify persistence in the DB — stored as a fraction.
    final reloaded = await (db.select(db.assets)..where((a) => a.id.equals(assetId))).getSingle();
    expect(reloaded.taxRate, closeTo(0.27, 1e-9));
  });
}
