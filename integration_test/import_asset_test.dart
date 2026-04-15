import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import_service.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Import CSV: asset historic, type from column, fee from column', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_type_column.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tapBuySellChips(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 3);
    expect(events.where((e) => e.commission == 5.00).length, 2);
    expect(events.where((e) => e.commission == 3.00).length, 1);
  });

  testWidgets('Import CSV: asset European format (semicolon, comma decimal)', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_type_column_eu.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await settle(tester);
    await tapBuySellChips(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 3);
    expect(events.where((e) => e.commission == 5.00).length, 2);
    expect(events.where((e) => e.price == 95.50).length, 1);
  });

  testWidgets('Import XLSX: asset historic, type from sign, fee computed', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_sign_computed.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await longSettle(tester);
    await tester.ensureVisible(find.text('From sign (+/-)'));
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.tap(find.text('Computed'));
    await settle(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 2);
    final buy = events.firstWhere((e) => e.quantity == 20);
    expect(buy.type.name, 'buy');
    expect(buy.commission, closeTo(10.0, 0.01));
    final sell = events.firstWhere((e) => e.type.name == 'sell');
    expect(sell.commission, closeTo(5.0, 0.01));
  });

  testWidgets('Import CSV: asset current mode with auto-calc amount', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_current.csv');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.tap(find.text('Current'));
    await settle(tester);

    final autoCalcCheckbox = find.descendant(
      of: find.ancestor(of: find.text('Auto calc'), matching: find.byType(Row)),
      matching: find.byType(Checkbox),
    );
    await tester.tap(autoCalcCheckbox.first);
    await settle(tester);

    final listView = find.byType(ListView).first;
    await tester.drag(listView, const Offset(0, -300));
    await settle(tester);
    await tester.ensureVisible(find.text('From sign (+/-)'));
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.drag(listView, const Offset(0, -500));
    await settle(tester);

    final nextBtn = find.widgetWithText(FilledButton, 'Next');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await settle(tester);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.last, const Offset(0, -300));
      await settle(tester);
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 2);
    final em = events.firstWhere((e) => e.quantity == 15);
    expect(em.amount, closeTo(487.50, 0.01));
    final gold = events.firstWhere((e) => e.quantity == 8);
    expect(gold.amount, closeTo(2800.00, 0.01));
    final today = DateTime.now();
    expect(em.date.year, today.year);
    expect(em.date.month, today.month);
    expect(em.date.day, today.day);
  });

  testWidgets('Import XLSX: asset multi-ISIN with one excluded', (tester) async {
    final db = await pumpApp(tester);

    late FilePreview preview;
    await tester.runAsync(() async {
      preview = await parseFixture(db, 'assets_multi_isin.xlsx');
    });

    await pushImportScreen(tester, preview: preview, target: ImportTarget.assetEvent);

    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await longSettle(tester);
    await tester.ensureVisible(find.text('From sign (+/-)'));
    await tester.tap(find.text('From sign (+/-)'));
    await settle(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await longSettle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final excludeIsin = find.text('IE00BKM4GZ66');
    expect(excludeIsin, findsOneWidget);
    final isinRow = find.ancestor(of: excludeIsin, matching: find.byType(Row));
    final checkbox = find.descendant(of: isinRow.first, matching: find.byType(Checkbox));
    if (checkbox.evaluate().isNotEmpty) {
      await tester.tap(checkbox.first);
      await settle(tester);
    }

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Import'));
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Import Complete'), findsOneWidget);
    final events = await db.select(db.assetEvents).get();
    expect(events.length, 4);
    final assets = await db.select(db.assets).get();
    final assetIsins = assets.map((a) => a.isin).whereType<String>().toList();
    expect(assetIsins.contains('IE00B4L5Y983'), isTrue);
    expect(assetIsins.contains('LU0908500753'), isTrue);
    expect(assetIsins.contains('IE00BKM4GZ66'), isFalse);
  });
}
