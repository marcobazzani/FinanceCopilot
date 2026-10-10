// A statement export the import could not open: every SpreadsheetML element
// written with a namespace prefix (`<x:c>` …), as some writers do, was refused
// as a "Damaged Excel file", and an empty cell that kept its type
// (`<c t="s"/>`) stopped the read. Both are valid XLSX; the fix lives in the
// excel package (justkawal/excel#457), and this pins that the import reads
// such a file exactly as the same file written plainly.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:finance_copilot/services/import/file_parser_service.dart';

const _spreadsheetMl = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

/// A one-sheet workbook: a title row, a header row and two movements, one of
/// them with an empty notes cell that kept its type. With [prefix] every
/// SpreadsheetML element carries it; without, the same file written plainly.
List<int> _statement({String? prefix}) {
  final x = prefix == null ? '' : '$prefix:';
  final ns = prefix == null ? 'xmlns="$_spreadsheetMl"' : 'xmlns:$prefix="$_spreadsheetMl"';
  const strings = ['Movements', 'Date', 'Amount', 'Description', 'Notes', '05/10/2026', 'Card payment', 'Salary'];
  String text(int i) => '<${x}v>$i</${x}v>';
  final parts = {
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
        '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
        '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8"?><${x}workbook $ns xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<${x}sheets><${x}sheet name="Movements" sheetId="1" r:id="rId1"/></${x}sheets></${x}workbook>',
    'xl/styles.xml':
        '<?xml version="1.0" encoding="UTF-8"?><${x}styleSheet $ns>'
        '<${x}fonts count="1"><${x}font><${x}sz val="11"/></${x}font></${x}fonts>'
        '<${x}fills count="1"><${x}fill><${x}patternFill patternType="none"/></${x}fill></${x}fills>'
        '<${x}borders count="1"><${x}border/></${x}borders>'
        '<${x}cellStyleXfs count="1"><${x}xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></${x}cellStyleXfs>'
        '<${x}cellXfs count="2"><${x}xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<${x}xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></${x}cellXfs>'
        '</${x}styleSheet>',
    'xl/sharedStrings.xml':
        '<?xml version="1.0" encoding="UTF-8"?><${x}sst $ns count="${strings.length}" uniqueCount="${strings.length}">'
        '${strings.map((s) => '<${x}si><${x}t>$s</${x}t></${x}si>').join()}</${x}sst>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8"?><${x}worksheet $ns><${x}sheetData>'
        '<${x}row r="1"><${x}c r="A1" t="s">${text(0)}</${x}c></${x}row>'
        '<${x}row r="2"><${x}c r="A2" t="s">${text(1)}</${x}c><${x}c r="B2" t="s">${text(2)}</${x}c>'
        '<${x}c r="C2" t="s">${text(3)}</${x}c><${x}c r="D2" t="s">${text(4)}</${x}c></${x}row>'
        '<${x}row r="3"><${x}c r="A3" t="s">${text(5)}</${x}c><${x}c r="B3" s="1"><${x}v>-1234.5</${x}v></${x}c>'
        '<${x}c r="C3" t="s">${text(6)}</${x}c><${x}c r="D3" t="s"/></${x}row>'
        '<${x}row r="4"><${x}c r="A4" t="s">${text(5)}</${x}c><${x}c r="B4"><${x}v>2500</${x}v></${x}c>'
        '<${x}c r="C4" t="s">${text(7)}</${x}c><${x}c r="D4" t="inlineStr"><${x}is><${x}t>ok</${x}t></${x}is></${x}c></${x}row>'
        '</${x}sheetData></${x}worksheet>',
  };
  final archive = Archive();
  parts.forEach((name, content) => archive.addFile(ArchiveFile.bytes(name, utf8.encode(content))));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory dir;
  final parser = FileParserService();

  setUp(() => dir = Directory.systemTemp.createTempSync('fc_xlsx_variants_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, List<int> bytes) => (File(p.join(dir.path, name))..writeAsBytesSync(bytes)).path;

  const columns = ['Date', 'Amount', 'Description', 'Notes'];
  const rows = [
    {'Date': '05/10/2026', 'Amount': '-1234,5', 'Description': 'Card payment', 'Notes': ''},
    {'Date': '05/10/2026', 'Amount': '2500', 'Description': 'Salary', 'Notes': 'ok'},
  ];

  test('a workbook written with namespace prefixes lists its sheet and reads every row', () async {
    final path = write('prefixed.xlsx', _statement(prefix: 'x'));

    expect(await parser.listSheets(path), ['Movements']);
    final preview = await parser.parseFile(path, skipRows: 1, numberLocale: 'it_IT');
    expect(preview.columns, columns);
    expect(preview.rows, rows);
  });

  test('it reads as the same workbook written plainly, empty typed cell included', () async {
    final plain = await parser.parseFile(write('plain.xlsx', _statement()), skipRows: 1, numberLocale: 'it_IT');
    final prefixed = await parser.parseFile(write('prefixed.xlsx', _statement(prefix: 'x')), skipRows: 1, numberLocale: 'it_IT');

    expect(plain.columns, columns);
    expect(plain.rows, rows);
    expect(prefixed.columns, plain.columns);
    expect(prefixed.rows, plain.rows);
  });
}
