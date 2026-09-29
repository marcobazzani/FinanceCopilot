// Pin: the raw statement data of a row is read by ONE decoder,
// decodeRawMetadata (stored_import_data.dart). The panel that shows it and the
// classifier that derives merchant keys from it used to carry their own copy;
// both must read exactly what they read before: a JSON object → its cells,
// anything else (a list, JSON null, broken text) → no cells.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_copilot/database/tables.dart';
import 'package:finance_copilot/services/classification/description_normalizer.dart';
import 'package:finance_copilot/services/classification/transaction_classifier_service.dart';
import 'package:finance_copilot/ui/widgets/raw_import_data_panel.dart';

void main() {
  group('RawImportDataPanel', () {
    Future<void> pump(WidgetTester tester, String raw) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: RawImportDataPanel(raw))),
      ),
    );

    Finder inPanel(String text) => find.descendant(of: find.byKey(const Key('rawImportData')), matching: find.text(text));

    testWidgets('a JSON object: one line per column, a null cell is empty, a number is spelled as stored', (tester) async {
      await pump(tester, jsonEncode({'Data': '08/03/2024', 'Importo': '-1.234,56', 'Note': null, 'Qty': 3}));
      expect(inPanel('Data: '), findsOneWidget);
      expect(inPanel('08/03/2024'), findsOneWidget);
      expect(inPanel('Importo: '), findsOneWidget);
      expect(inPanel('-1.234,56'), findsOneWidget);
      expect(inPanel('Note: '), findsOneWidget);
      expect(inPanel(''), findsOneWidget);
      expect(inPanel('3'), findsOneWidget);
    });

    for (final (what, raw) in [
      ('a JSON list', '["-1.234,56"]'),
      ('JSON null', 'null'),
      ('broken text', 'ESSELUNGA;-1.234,56'),
      ('an empty text', ''),
    ]) {
      testWidgets('$what: shown as it is stored, as one text', (tester) async {
        await pump(tester, raw);
        expect(inPanel(raw), findsOneWidget);
      });
    }
  });

  group('TransactionClassifierService.normalize', () {
    NormalizedEntry keys(String? raw) => TransactionClassifierService.normalize(description: 'Trenitalia', rawMetadataJson: raw, amount: -10);

    test('a JSON object is the statement data the keys are derived from', () {
      expect(keys('{"Tipo":"Pagamento con carta"}').entryKind, BankEntryKind.cardPayment);
    });

    test('anything else reads like a row without statement data', () {
      final none = keys(null);
      for (final raw in ['', '{not json', '["Pagamento con carta"]', 'null', '42']) {
        final k = keys(raw);
        expect((k.merchantKey, k.counterparty, k.entryKind), (none.merchantKey, none.counterparty, none.entryKind), reason: '"$raw"');
      }
    });
  });
}
