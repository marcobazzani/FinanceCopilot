// Pins what the file parser hands the import wizard for CSV, TSV, pasted text
// and XLSX — the options each parse runs with (separator, skipped lines, no
// header, sheet, number locale) and the full re-parse behind a capped
// preview — so the isolate arguments can be typed without changing a row.

import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/import/file_parser_service.dart';

void main() {
  late Directory dir;
  final parser = FileParserService();

  setUp(() => dir = Directory.systemTemp.createTempSync('fc_file_parser_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, String content) => File(p.join(dir.path, name))..writeAsStringSync(content);

  File writeXlsx(String name, Map<String, List<List<xl.CellValue?>>> sheets) {
    final excel = xl.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    var first = true;
    for (final MapEntry(key: sheetName, value: rows) in sheets.entries) {
      if (first) {
        excel.rename(defaultSheet, sheetName);
        first = false;
      }
      final sheet = excel[sheetName];
      for (final row in rows) {
        sheet.appendRow(row);
      }
    }
    return File(p.join(dir.path, name))..writeAsBytesSync(excel.encode()!);
  }

  group('csv', () {
    test('the separator is read off the first line; rows are keyed by the trimmed header; blank lines dropped', () async {
      final file = write('semicolons.csv', 'Date; Amount ;Note\n01/02/2026;1,5; first \n\n02/02/2026;-3;second\n');

      final preview = await parser.parseFile(file.path);

      expect(preview.columns, ['Date', 'Amount', 'Note']);
      expect(preview.rows, [
        {'Date': '01/02/2026', 'Amount': '1,5', 'Note': 'first'},
        {'Date': '02/02/2026', 'Amount': '-3', 'Note': 'second'},
      ]);
      expect((preview.totalRows, preview.filePath, preview.skipRows, preview.noHeader), (2, file.path, 0, false));
    });

    test('skipped lines come off the top, and without a header the columns are numbered', () async {
      final file = write('noheader.csv', 'exported by the bank,,\n01/02/2026,10,a\n02/02/2026,20,b\n');

      final preview = await parser.parseFile(file.path, skipRows: 1, noHeader: true);

      expect(preview.columns, ['Column 1', 'Column 2', 'Column 3']);
      expect(preview.rows, [
        {'Column 1': '01/02/2026', 'Column 2': '10', 'Column 3': 'a'},
        {'Column 1': '02/02/2026', 'Column 2': '20', 'Column 3': 'b'},
      ]);
      expect((preview.skipRows, preview.noHeader), (1, true));
    });

    test('a .tsv file is split on tabs', () async {
      final file = write('tabs.tsv', 'Date\tAmount\tNote\n01/02/2026\t1.5\tfirst\n02/02/2026\t2\tsecond\n');

      final preview = await parser.parseFile(file.path);

      expect(preview.columns, ['Date', 'Amount', 'Note']);
      expect(preview.rows.first, {'Date': '01/02/2026', 'Amount': '1.5', 'Note': 'first'});
    });

    test('pasted text detects its separator too, and remembers the text for the full parse', () async {
      const text = 'Date\tAmount\n01/02/2026\t7\n';

      final preview = await parser.parseClipboard(text);

      expect(preview.columns, ['Date', 'Amount']);
      expect(preview.rows.single, {'Date': '01/02/2026', 'Amount': '7'});
      expect((preview.clipboardText, preview.filePath), (text, null));
    });

    test('a preview holds the first and last five rows; the full parse returns every row', () async {
      final lines = ['n,v', for (var i = 1; i <= 12; i++) '$i,v$i'];
      final file = write('long.csv', '${lines.join('\n')}\n');

      final preview = await parser.parseFile(file.path);
      expect(preview.totalRows, 12);
      expect(preview.rows.map((r) => r['n']), ['1', '2', '3', '4', '5', '8', '9', '10', '11', '12']);

      final full = await parser.getFullRows(preview);
      expect(full.rows.map((r) => r['n']), [for (var i = 1; i <= 12; i++) '$i']);
      expect(full.columns, ['n', 'v']);

      final pasted = await parser.parseClipboard('${lines.join('\n')}\n', skipRows: 0);
      expect((await parser.getFullRows(pasted)).rows, hasLength(12));
    });

    test('a preview already holding every row is its own full parse', () async {
      final file = write('short.csv', 'a,b\n1,2\n');
      final preview = await parser.parseFile(file.path);

      expect(identical(await parser.getFullRows(preview), preview), isTrue);
    });
  });

  group('xlsx', () {
    List<xl.CellValue?> header() => [xl.TextCellValue('Date'), xl.TextCellValue('Amount'), xl.TextCellValue('Qty')];

    test('numbers are spelled in the import locale, integers as they are, text trimmed', () async {
      final file = writeXlsx('amounts.xlsx', {
        'Movements': [
          header(),
          [xl.TextCellValue(' 01/02/2026 '), xl.DoubleCellValue(7707.97), xl.IntCellValue(3)],
        ],
      });

      final auto = await parser.parseFile(file.path);
      expect(auto.rows.single, {'Date': '01/02/2026', 'Amount': '7707.97', 'Qty': '3'});

      final italian = await parser.parseFile(file.path, numberLocale: 'it_IT');
      expect(italian.rows.single, {'Date': '01/02/2026', 'Amount': '7707,97', 'Qty': '3'});
      expect(italian.numberLocale, 'it_IT');
    });

    test('the named sheet is read, lines skipped and columns numbered as asked', () async {
      final file = writeXlsx('sheets.xlsx', {
        'Summary': [
          [xl.TextCellValue('nothing here')],
        ],
        'Movements': [
          [xl.TextCellValue('bank export')],
          [xl.TextCellValue('01/02/2026'), xl.DoubleCellValue(1.5), xl.IntCellValue(2)],
        ],
      });

      expect(await parser.listSheets(file.path), containsAll(['Summary', 'Movements']));
      final preview = await parser.parseFile(file.path, sheetName: 'Movements', skipRows: 1, noHeader: true);

      expect(preview.columns, ['Column 1', 'Column 2', 'Column 3']);
      expect(preview.rows.single, {'Column 1': '01/02/2026', 'Column 2': '1.5', 'Column 3': '2'});
      expect(preview.sheetName, 'Movements');
    });

    test('the full parse re-reads with a changed locale, in an isolate or in process', () async {
      final file = writeXlsx('relocale.xlsx', {
        'Movements': [
          header(),
          [xl.TextCellValue('01/02/2026'), xl.DoubleCellValue(1234.5), xl.IntCellValue(1)],
        ],
      });
      final preview = await parser.parseFile(file.path, numberLocale: 'en_US');
      expect(preview.rows.single['Amount'], '1234.5');

      expect((await parser.getFullRows(preview, numberLocale: 'de_DE')).rows.single['Amount'], '1234,5');
      expect((await parser.getFullRowsInProcess(preview, numberLocale: 'de_DE')).rows.single['Amount'], '1234,5');
      expect((await parser.getFullRowsInProcess(preview)).rows.single['Amount'], '1234.5', reason: 'the preview locale by default');
    });
  });

  test('an unknown extension is refused', () async {
    final file = write('notes.txt', 'a,b\n');
    await expectLater(parser.parseFile(file.path), throwsA(isA<UnsupportedError>()));
  });
}
