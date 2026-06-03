// Offline probe for the PDF reconstructor. Reads pre-extracted PDF
// fragments from JSON (produced by pdfplumber), feeds them into
// PdfTableReconstructor, prints the resulting columns + rows.
//
// Run: dart run tool/probe_pdf.dart /tmp/ppp_fragments.json
//
// NOT a test — kept out of test/ so `flutter test` won't pick it up.
// Use it to iterate on the algorithm without needing UI clicks.
import 'dart:convert';
import 'dart:io';
import 'package:finance_copilot/services/import/pdf_exceptions.dart';
import 'package:finance_copilot/services/import/pdf_table_reconstructor.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/probe_pdf.dart <fragments.json>');
    exit(1);
  }
  final jsonStr = await File(args.first).readAsString();
  final List<dynamic> raw = jsonDecode(jsonStr) as List<dynamic>;
  final fragments = raw.map((e) {
    final m = e as Map<String, dynamic>;
    return PdfFragment(
      text: m['text'] as String,
      left: (m['left'] as num).toDouble(),
      right: (m['right'] as num).toDouble(),
      top: (m['top'] as num).toDouble(),
      bottom: (m['bottom'] as num).toDouble(),
      page: m['page'] as int,
    );
  }).toList();

  print('Loaded ${fragments.length} fragments.');
  try {
    final r = PdfTableReconstructor.reconstruct(fragments);
    print('Columns: ${r.columns}');
    print('Rows (${r.rows.length}):');
    for (var i = 0; i < r.rows.length; i++) {
      print('  $i: ${r.rows[i]}');
    }
  } on PdfImportException catch (e) {
    print('FAILED: ${e.runtimeType}: ${e.message}');
  }
}
