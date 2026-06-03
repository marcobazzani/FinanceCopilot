// Regression: cancelling the multi-sheet picker must not leave the import
// screen stuck on the parsing spinner forever.
//
// Pinned bug: _loadFile set `_parsing = true`, and when a multi-sheet
// Excel file's sheet picker was dismissed (no selection), it returned
// early WITHOUT resetting `_parsing`. The CircularProgressIndicator span
// forever and both data-source buttons stayed disabled — the user had to
// leave the screen to recover.

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:finance_copilot/services/import/import_service.dart';
import 'package:finance_copilot/ui/screens/import/import_screen.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cancelling the multi-sheet picker clears the parsing spinner',
    (tester) async {
      // A 2-sheet xlsx so _loadFile triggers the sheet picker.
      final tmpDir = await Directory.systemTemp.createTemp('fc_sheetcancel_');
      final xlsxPath = '${tmpDir.path}/two_sheets.xlsx';
      final excel = Excel.createExcel();
      excel['Sheet1'].appendRow([TextCellValue('date'), TextCellValue('amount')]);
      excel['Sheet2'].appendRow([TextCellValue('date'), TextCellValue('amount')]);
      File(xlsxPath).writeAsBytesSync(excel.encode()!);

      try {
        await pumpApp(tester);

        // Push ImportScreen pointed at the multi-sheet file.
        final ctx = tester.element(find.byType(Navigator).first);
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => ImportScreen(
              preselectedTarget: ImportTarget.transaction,
              initialFilePath: xlsxPath,
            ),
          ),
        );

        // Let _loadFile + listSheets (isolate) run until the picker appears.
        await pumpFor(tester, const Duration(seconds: 3));
        expect(find.byType(SimpleDialog), findsOneWidget, reason: 'multi-sheet picker should appear');

        // Cancel the picker by dismissing the modal barrier (returns null).
        await tester.tapAt(const Offset(20, 20));
        await pumpFor(tester, const Duration(seconds: 1));

        // The parsing spinner must be gone — cancelling the sheet
        // selection must not leave the screen permanently stuck.
        expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'parsing spinner stuck after cancelling the sheet picker');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    },
  );
}
