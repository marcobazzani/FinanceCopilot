// Pin, before the file parser reads a file through one extension switch: the
// full re-parse behind a preview — for each kind of source, with the options
// the preview was made with — and the in-process variant the import uses.
// Complements file_parser_service_pin_test.dart.
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/import/file_parser_service.dart';
import 'package:finance_copilot/services/import/import_service.dart' show FilePreview;

void main() {
  late Directory dir;
  final parser = FileParserService();

  setUp(() => dir = Directory.systemTemp.createTempSync('fc_parse_source_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, String content) => File(p.join(dir.path, name))..writeAsStringSync(content);

  File writeXlsx(String name, List<List<xl.CellValue?>> rows) {
    final excel = xl.Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    for (final row in rows) {
      sheet.appendRow(row);
    }
    return File(p.join(dir.path, name))..writeAsBytesSync(excel.encode()!);
  }

  String lines(int n, {String sep = ','}) => [
    'skip me',
    'n${sep}v',
    for (var i = 1; i <= n; i++) '$i${sep}v$i',
  ].join('\n');

  List<xl.CellValue?> cells(List<Object> values) => [
    for (final v in values) v is double ? xl.DoubleCellValue(v) : (v is int ? xl.IntCellValue(v) : xl.TextCellValue('$v')),
  ];

  group('getFullRows', () {
    test('csv and tsv re-read with the preview\'s skipped lines and header; a number format changes nothing', () async {
      for (final (name, sep) in [('long.csv', ','), ('long.tsv', '\t'), ('LONG.CSV', ',')]) {
        final file = write(name, lines(12, sep: sep));
        final preview = await parser.parseFile(file.path, skipRows: 1);
        expect(preview.rows, hasLength(10), reason: name);

        final full = await parser.getFullRows(preview, numberLocale: 'it_IT');
        expect(full.columns, ['n', 'v'], reason: name);
        expect(full.rows.map((r) => r['n']), [for (var i = 1; i <= 12; i++) '$i'], reason: name);
        expect((full.totalRows, full.filePath, full.skipRows, full.noHeader, full.numberLocale), (12, null, 0, false, null), reason: name);
      }
    });

    test('without a header the full parse numbers the columns too', () async {
      final file = write('noheader.csv', lines(12));
      final preview = await parser.parseFile(file.path, skipRows: 1, noHeader: true);
      final full = await parser.getFullRows(preview);
      expect(full.columns, ['Column 1', 'Column 2']);
      expect(full.rows.first, {'Column 1': 'n', 'Column 2': 'v'});
      expect(full.rows, hasLength(13));
    });

    test('xlsx re-reads its sheet, skipped lines and header in the given number format, else the preview\'s', () async {
      final file = writeXlsx('long.xlsx', [
        cells(['bank export']),
        cells(['n', 'v']),
        for (var i = 1; i <= 12; i++) cells([i, i + 0.5]),
      ]);
      final preview = await parser.parseFile(file.path, skipRows: 1, numberLocale: 'en_US');
      expect(preview.rows, hasLength(10));

      final full = await parser.getFullRows(preview);
      expect(full.rows.map((r) => r['v']), [for (var i = 1; i <= 12; i++) '$i.5']);
      expect((full.totalRows, full.filePath, full.numberLocale), (12, null, null));
      expect((await parser.getFullRows(preview, numberLocale: 'it_IT')).rows.first, {'n': '1', 'v': '1,5'});
    });

    test('an xlsx preview holding every row in the same number format is its own full parse', () async {
      final file = writeXlsx('short.xlsx', [
        cells(['n', 'v']),
        cells([1, 1.5]),
      ]);
      final preview = await parser.parseFile(file.path, numberLocale: 'en_US');
      expect(identical(await parser.getFullRows(preview), preview), isTrue);
      expect(identical(await parser.getFullRows(preview, numberLocale: 'en_US'), preview), isTrue);
      expect((await parser.getFullRows(preview, numberLocale: 'it_IT')).rows.single, {'n': '1', 'v': '1,5'});
    });

    test('a file of another kind is returned as it is', () async {
      final file = write('notes.txt', lines(12));
      final preview = FilePreview(columns: const ['n'], rows: const [], totalRows: 12, filePath: file.path);
      expect(identical(await parser.getFullRows(preview), preview), isTrue);
    });

    test('pasted text re-reads its text with the preview\'s skipped lines', () async {
      final preview = await parser.parseClipboard(lines(12, sep: '\t'), skipRows: 1);
      final full = await parser.getFullRows(preview);
      expect(full.rows.map((r) => r['n']), [for (var i = 1; i <= 12; i++) '$i']);
      expect(full.clipboardText, isNull);
    });

    test('a preview with no source is returned as it is', () async {
      const preview = FilePreview(columns: ['n'], rows: [], totalRows: 3);
      expect(identical(await parser.getFullRows(preview), preview), isTrue);
    });
  });

  group('getFullRowsInProcess', () {
    test('xlsx always re-reads, in the given number format, else the preview\'s', () async {
      final file = writeXlsx('short.xlsx', [
        cells(['n', 'v']),
        cells([1, 1.5]),
      ]);
      final preview = await parser.parseFile(file.path, numberLocale: 'it_IT');
      final again = await parser.getFullRowsInProcess(preview);
      expect(identical(again, preview), isFalse);
      expect(again.rows.single, {'n': '1', 'v': '1,5'});
      expect((await parser.getFullRowsInProcess(preview, numberLocale: 'en_US')).rows.single, {'n': '1', 'v': '1.5'});
    });

    test('any other file goes through getFullRows', () async {
      final file = write('long.csv', lines(12));
      final preview = await parser.parseFile(file.path, skipRows: 1);
      expect((await parser.getFullRowsInProcess(preview)).rows, hasLength(12));

      final short = await parser.parseFile(write('short.csv', 'a,b\n1,2\n').path);
      expect(identical(await parser.getFullRowsInProcess(short), short), isTrue);
    });

    test('pasted text is returned as it is', () async {
      final preview = await parser.parseClipboard(lines(12, sep: '\t'), skipRows: 1);
      expect(identical(await parser.getFullRowsInProcess(preview), preview), isTrue);
    });
  });

  test('parseFile keeps what the preview was made with', () async {
    final file = writeXlsx('sheet.xlsx', [
      cells(['n', 'v']),
      for (var i = 1; i <= 12; i++) cells([i, i + 0.25]),
    ]);
    final preview = await parser.parseFile(file.path, numberLocale: 'it_IT');
    expect(
      (preview.filePath, preview.skipRows, preview.noHeader, preview.sheetName, preview.numberLocale, preview.totalRows),
      (
        file.path,
        0,
        false,
        null,
        'it_IT',
        12,
      ),
    );
    expect(preview.rows.first, {'n': '1', 'v': '1,25'});
    await expectLater(parser.parseFile(write('notes', 'a').path), throwsA(isA<UnsupportedError>()), reason: 'no extension');
  });
}
