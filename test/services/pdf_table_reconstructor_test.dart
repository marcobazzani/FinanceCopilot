import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/pdf_exceptions.dart';
import 'package:finance_copilot/services/pdf_table_reconstructor.dart';

/// Synthetic-fragment fixtures for [PdfTableReconstructor]. These tests run
/// without any PDF library — the reconstructor is data-in / data-out, so we
/// hand-craft `PdfFragment` lists that simulate the geometry pdfrx would
/// emit and verify the algorithm's outputs.
///
/// Coordinate convention: PDF page coordinates have origin at bottom-left
/// and Y points upward (`top > bottom`). The reconstructor sorts lines
/// top-to-bottom on each page by descending y-center, so higher Y = higher
/// on the page.

PdfFragment _f(
  String text, {
  required double x,
  required double y,
  double? width,
  double height = 10,
  int page = 1,
}) {
  final w = width ?? text.length * 5.0;
  return PdfFragment(
    text: text,
    left: x,
    right: x + w,
    top: y + height,
    bottom: y,
    page: page,
  );
}

/// Build a clean 4-column transaction grid: Date | Description | Amount | Balance.
/// Returns the fragments for [rows] rows starting at [startY], stepping
/// down by 20 points per line. Each row's Y is `startY - (i * 20)`. Row
/// numbering starts at [startIndex] so multiple pages can be stitched
/// together with unique content (real bank statements never repeat row
/// values across pages).
List<PdfFragment> _grid({
  required int rows,
  bool withHeader = true,
  double startY = 800,
  int page = 1,
  int startIndex = 0,
}) {
  final out = <PdfFragment>[];
  if (withHeader) {
    out.addAll([
      _f('Date', x: 50, y: startY, page: page),
      _f('Description', x: 120, y: startY, page: page),
      _f('Amount', x: 300, y: startY, page: page),
      _f('Balance', x: 400, y: startY, page: page),
    ]);
  }
  for (var i = 0; i < rows; i++) {
    final y = startY - (i + 1) * 20.0;
    final n = startIndex + i + 1;
    final day = (((n - 1) % 28) + 1).toString().padLeft(2, '0');
    final month = ((((n - 1) ~/ 28) % 12) + 1).toString().padLeft(2, '0');
    out.addAll([
      _f('$day/$month/2024', x: 50, y: y, page: page),
      _f('Tx $n', x: 120, y: y, page: page),
      _f('-${n * 10}.00', x: 300, y: y, page: page),
      _f('${1000 - n * 10}.00', x: 400, y: y, page: page),
    ]);
  }
  return out;
}

void main() {
  group('PdfTableReconstructor — happy paths', () {
    test('clean 6-row grid with header', () {
      final frags = _grid(rows: 6);
      final result = PdfTableReconstructor.reconstruct(frags);

      expect(result.columns.length, 4);
      expect(result.columns[0], equals('Date'));
      expect(result.columns[1], equals('Description'));
      expect(result.columns[2], equals('Amount'));
      expect(result.columns[3], equals('Balance'));
      expect(result.rows.length, 6);
      expect(result.rows.first[0], equals('01/01/2024'));
      expect(result.rows.first[1], equals('Tx 1'));
      expect(result.rows.first[2], equals('-10.00'));
      expect(result.rows.first[3], equals('990.00'));
      expect(result.rows.last[0], equals('06/01/2024'));
    });

    test('synthesises Column N headers when no header row present', () {
      final frags = _grid(rows: 6, withHeader: false);
      final result = PdfTableReconstructor.reconstruct(frags);

      expect(result.columns.length, 4);
      expect(result.columns[0], startsWith('Column '));
      expect(result.rows.length, 6);
    });

    test('merges wrapped continuation lines into the previous row', () {
      final frags = _grid(rows: 6);
      // Row 3 (i=2) is at y=740. Drop a continuation 10 pt below it (y=730),
      // safely outside the line-cluster tolerance (0.6 × H = 6) but within
      // the wrap-merge cap (1.6 × H = 16). Description-only, no date, no
      // amount — the kind of overflow real bank statements emit.
      frags.add(_f('Mario Rossi', x: 120, y: 730, page: 1));

      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, 6);
      // Row 3 description should now contain the merged text.
      expect(result.rows[2][1], contains('Tx 3'));
      expect(result.rows[2][1], contains('Mario Rossi'));
    });

    test('drops repeated page chrome across pages', () {
      final frags = <PdfFragment>[
        // Same caption at the same Y on three pages → must be dropped.
        _f('CONFIDENTIAL', x: 50, y: 820, page: 1),
        _f('CONFIDENTIAL', x: 50, y: 820, page: 2),
        _f('CONFIDENTIAL', x: 50, y: 820, page: 3),
        ..._grid(rows: 3, page: 1, startY: 800, startIndex: 0),
        ..._grid(rows: 3, page: 2, startY: 800, startIndex: 3, withHeader: false),
        ..._grid(rows: 3, page: 3, startY: 800, startIndex: 6, withHeader: false),
      ];
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, 9);
      expect(
        result.rows.any((r) => r.any((c) => c.contains('CONFIDENTIAL'))),
        isFalse,
      );
    });

    test('concatenates rows from multiple pages', () {
      final frags = [
        ..._grid(rows: 4, page: 1, startY: 800, startIndex: 0),
        ..._grid(rows: 4, page: 2, startY: 800, startIndex: 4, withHeader: false),
      ];
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, 8);
    });

    test('accepts mixed-locale numeric cells', () {
      // Same layout but with a mix of en_US (1,234.56) and it_IT (1.234,56).
      final frags = <PdfFragment>[
        _f('Date', x: 50, y: 800),
        _f('Description', x: 120, y: 800),
        _f('Amount', x: 300, y: 800),
        _f('01/01/2024', x: 50, y: 780),
        _f('Tx EN', x: 120, y: 780),
        _f('1,234.56', x: 300, y: 780),
        _f('02/01/2024', x: 50, y: 760),
        _f('Tx IT', x: 120, y: 760),
        _f('1.234,56', x: 300, y: 760),
        _f('03/01/2024', x: 50, y: 740),
        _f('Tx 3', x: 120, y: 740),
        _f('500.00', x: 300, y: 740),
        _f('04/01/2024', x: 50, y: 720),
        _f('Tx 4', x: 120, y: 720),
        _f('250,00', x: 300, y: 720),
        _f('05/01/2024', x: 50, y: 700),
        _f('Tx 5', x: 120, y: 700),
        _f('99.99', x: 300, y: 700),
        _f('06/01/2024', x: 50, y: 680),
        _f('Tx 6', x: 120, y: 680),
        _f('42,42', x: 300, y: 680),
      ];
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, 6);
      // Both decimal styles must end up in the amount column.
      final amounts = result.rows.map((r) => r[2]).toList();
      expect(amounts, contains('1,234.56'));
      expect(amounts, contains('1.234,56'));
    });
  });

  group('PdfTableReconstructor — explicit rejections', () {
    test('throws PdfNoTextLayerException on a near-empty fragment list', () {
      expect(
        () => PdfTableReconstructor.reconstruct(<PdfFragment>[
          _f('hello', x: 0, y: 0),
        ]),
        throwsA(isA<PdfNoTextLayerException>()),
      );
    });

    test('throws PdfTableNotDetectedException when no dates exist', () {
      // 12 rows of pure narrative text — no date column anywhere.
      final frags = <PdfFragment>[];
      for (var i = 0; i < 12; i++) {
        final y = 800 - i * 18.0;
        frags.addAll([
          _f('Lorem ipsum', x: 50, y: y),
          _f('dolor sit', x: 200, y: y),
          _f('amet ${i + 1}', x: 350, y: y),
        ]);
      }
      expect(
        () => PdfTableReconstructor.reconstruct(frags),
        throwsA(isA<PdfTableNotDetectedException>()),
      );
    });

    test('throws PdfTableNotDetectedException when amounts are missing', () {
      // Dates present on every row but no numeric column.
      final frags = <PdfFragment>[];
      for (var i = 0; i < 8; i++) {
        final y = 800 - i * 18.0;
        final day = (i + 1).toString().padLeft(2, '0');
        frags.addAll([
          _f('$day/01/2024', x: 50, y: y),
          _f('Description ${i + 1}', x: 200, y: y),
          _f('Reference XYZ', x: 350, y: y),
        ]);
      }
      expect(
        () => PdfTableReconstructor.reconstruct(frags),
        throwsA(isA<PdfTableNotDetectedException>()),
      );
    });

    test('throws PdfUnreadableTextException on PUA-heavy input', () {
      // Build a pile of fragments whose text is entirely Private-Use-Area
      // glyphs (the symptom of a broken ToUnicode CMap).
      final puaText = String.fromCharCodes([
        for (var i = 0; i < 8; i++) 0xE000 + i,
      ]);
      final frags = <PdfFragment>[];
      for (var i = 0; i < 12; i++) {
        frags.add(_f(puaText, x: 50.0 + i * 5, y: 800 - i * 18.0));
      }
      expect(
        () => PdfTableReconstructor.reconstruct(frags),
        throwsA(isA<PdfUnreadableTextException>()),
      );
    });

    test('throws PdfTableNotDetectedException when too few data lines', () {
      // Three rows is below the volume threshold (≥5 data lines).
      final frags = _grid(rows: 3);
      expect(
        () => PdfTableReconstructor.reconstruct(frags),
        throwsA(isA<PdfTableNotDetectedException>()),
      );
    });
  });
}
