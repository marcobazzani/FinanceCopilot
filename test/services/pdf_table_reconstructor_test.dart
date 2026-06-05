import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/services/import/pdf_exceptions.dart';
import 'package:finance_copilot/services/import/pdf_table_reconstructor.dart';

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

  group('PdfTableReconstructor — robustness', () {
    test('stitches month-name + year split across adjacent fragments', () {
      // pdfrx commonly splits "Gennaio 2026" into two fragments. Without
      // stitching, neither half parses → the whole period column is
      // invisible to the date anchor. Lines below: 6 transaction rows
      // with the period in the leftmost column as TWO fragments, and
      // an amount column on the right.
      final frags = <PdfFragment>[];
      const months = [
        'Gennaio',
        'Febbraio',
        'Marzo',
        'Aprile',
        'Maggio',
        'Giugno',
      ];
      for (var i = 0; i < months.length; i++) {
        final y = 800 - (i + 1) * 20.0;
        // Period column: split into "Month" + "Year".
        frags.add(_f(months[i], x: 50, y: y));
        frags.add(_f('2026', x: 95, y: y));
        // Amount column.
        frags.add(_f('${(i + 1) * 100}.00', x: 300, y: y));
      }
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, equals(6));
      // Each emitted row must carry the stitched date and an amount.
      for (var i = 0; i < result.rows.length; i++) {
        final dateCell = result.rows[i].first;
        expect(
          dateCell,
          matches(RegExp(r'^(Gennaio|Febbraio|Marzo|Aprile|Maggio|Giugno)\s+2026$')),
        );
      }
    });

    test('anchors the date column even when every row has a second '
        'embedded date in another column', () {
      // Mimics statements where the operation/description column contains
      // dates of its own (e.g. "Wire from John on 12/06/2024"). Old
      // algorithm dropped these lines from the candidate pool; the new
      // one scores by line coverage and still picks the leftmost
      // consistent date column.
      final frags = <PdfFragment>[];
      for (var i = 0; i < 6; i++) {
        final y = 800 - (i + 1) * 20.0;
        final day = (i + 1).toString().padLeft(2, '0');
        // Primary date column at x=50.
        frags.add(_f('$day/01/2024', x: 50, y: y));
        // Embedded date inside the description, x varies per row.
        frags.add(_f('Note', x: 120, y: y));
        frags.add(_f('${(i + 1).toString().padLeft(2, '0')}/06/2023', x: 160 + (i % 2) * 7, y: y));
        // Amount column.
        frags.add(_f('${(i + 1) * 50}.00', x: 320, y: y));
      }
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, equals(6));
      // The first column must hold the primary (leftmost-clustered) date.
      for (var i = 0; i < result.rows.length; i++) {
        final day = (i + 1).toString().padLeft(2, '0');
        expect(result.rows[i].first, equals('$day/01/2024'));
      }
    });

    test('pension-statement layout: month-name period column + embedded '
        'operation dates + sparse balance produces clean rows', () {
      // Synthetic version of an Italian pension fund statement layout:
      //   Period (Gennaio 2026 split into 2 frags) | Operation (text +
      //   embedded date e.g. "Voce mese 01/2026") | Amount | Saldo (only
      //   on subtotal rows). Subtotal rows wedge between transaction
      //   rows: their period text is "Totale Gennaio 2026" (3 frags).
      //
      // This test pins the combined behaviour of: stitched-fragment
      // dates, line-coverage date anchoring, iterative date-band
      // expansion (so the subtotal "2026" stays in the date column),
      // sparse-balance acceptance, and lenient cell-level date
      // validation (so "Totale Gennaio 2026" passes).
      final frags = <PdfFragment>[];
      const months = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile'];
      var y = 800.0;
      // Header.
      frags.add(_f('Periodo', x: 50, y: y));
      frags.add(_f('Operazione', x: 200, y: y));
      frags.add(_f('Entrate', x: 320, y: y));
      frags.add(_f('Saldo', x: 460, y: y));
      // Two transaction rows + one subtotal row per month = 12 data rows.
      for (final m in months) {
        // Per-row transaction (×2: C/Azienda then C/TFR).
        for (var k = 0; k < 2; k++) {
          y -= 18;
          frags.add(_f(m, x: 30, y: y));
          frags.add(_f('2026', x: 70, y: y));
          frags.add(_f(k == 0 ? 'C/Azienda' : 'C/TFR', x: 165, y: y));
          frags.add(_f('mese', x: 200, y: y));
          frags.add(_f('${months.indexOf(m) + 1}/2026', x: 235, y: y));
          frags.add(_f('${(k + 1) * 100}.00', x: 320, y: y));
        }
        // Subtotal row (no operation column, has Saldo).
        y -= 18;
        frags.add(_f('Totale', x: 30, y: y));
        frags.add(_f(m, x: 65, y: y));
        frags.add(_f('2026', x: 90 + m.length.toDouble(), y: y));
        frags.add(_f('${(months.indexOf(m) + 1) * 300}.00', x: 320, y: y));
        frags.add(_f('${1000 + months.indexOf(m) * 100}.00', x: 460, y: y));
      }
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, equals(12));
      // Every row's first cell must be a parseable date — including the
      // subtotal rows where it's "Totale <Month> 2026".
      for (final row in result.rows) {
        // The reconstructor's _looksLikeDate is private; reach the same
        // judgment by routing through the date parser the same way.
        final cell = row.first;
        final tokens = cell.split(RegExp(r'\s+'));
        var found = false;
        for (var i = 0; i < tokens.length && !found; i++) {
          for (var j = i; j < tokens.length && j < i + 3 && !found; j++) {
            final candidate = tokens.sublist(i, j + 1).join(' ');
            if (candidate.isEmpty) continue;
            try {
              DateTime.parse(candidate);
              found = true;
            } catch (_) {}
            if (!found && RegExp(r'^(Gennaio|Febbraio|Marzo|Aprile)\s+2026$').hasMatch(candidate)) {
              found = true;
            }
          }
        }
        expect(found, isTrue, reason: 'no date in cell "$cell"');
      }
    });

    test('a closing-balance-only summary row is emitted as its own snapshot '
        'row, never appended to the last subtotal', () {
      // Pension/account statements often print a closing-position
      // summary BELOW the last subtotal: "CLOSING POSITION 12,345.67"
      // sitting in the balance column only, with no date. It is emitted as
      // its own (date-less) snapshot row so the value isn't lost — but it
      // must never be merged into the previous transaction/subtotal row.
      final frags = <PdfFragment>[];
      // Header.
      frags.add(_f('Date', x: 50, y: 800));
      frags.add(_f('Description', x: 200, y: 800));
      frags.add(_f('Amount', x: 320, y: 800));
      frags.add(_f('Balance', x: 460, y: 800));
      // 6 transaction rows.
      for (var i = 0; i < 6; i++) {
        final y = 800 - (i + 1) * 18.0;
        final day = (i + 1).toString().padLeft(2, '0');
        frags.add(_f('$day/01/2024', x: 50, y: y));
        frags.add(_f('Tx ${i + 1}', x: 200, y: y));
        frags.add(_f('${(i + 1) * 100}.00', x: 320, y: y));
        frags.add(_f('${1000 - (i + 1) * 100}.00', x: 460, y: y));
      }
      // Closing summary row 18pt below the last data row: only a
      // numeric in the balance band, no date.
      final lastY = 800 - 7 * 18.0;
      frags.add(_f('CLOSING', x: 200, y: lastY));
      frags.add(_f('POSITION', x: 250, y: lastY));
      frags.add(_f('12345.67', x: 470, y: lastY));

      final result = PdfTableReconstructor.reconstruct(frags);
      // 6 transaction rows + 1 emitted snapshot row.
      expect(result.rows.length, equals(7));
      // The 6th (last transaction) row must NOT have absorbed the summary.
      final sixthRow = result.rows[5];
      expect(sixthRow.any((c) => c.contains('CLOSING')), isFalse);
      expect(sixthRow.any((c) => c.contains('POSITION')), isFalse);
      expect(sixthRow.any((c) => c.contains('12345.67')), isFalse);
      // The 7th row is the snapshot: it carries the closing balance and no date.
      final snapshot = result.rows.last;
      expect(snapshot.any((c) => c.contains('12345.67')), isTrue);
    });

    test('header row with N+1 words above N data columns produces N+1 '
        'distinct columns (extra header gets a synthetic empty column)', () {
      // Layout mirrors a pension statement: 5 header words but only 4
      // data anchors because one column ("Uscite") is empty for every
      // row. The reconstructor must recognise the orphan header and
      // emit a 5-column table where the orphan column stays empty,
      // rather than gluing two header words ("Entrate Uscite") into
      // one cell.
      final frags = <PdfFragment>[];
      // Header row.
      frags.add(_f('Date', x: 50, y: 800));
      frags.add(_f('Description', x: 200, y: 800));
      frags.add(_f('Credit', x: 320, y: 800));
      frags.add(_f('Debit', x: 410, y: 800));
      frags.add(_f('Balance', x: 500, y: 800));
      // Data: 6 rows, all amounts in Credit column, none in Debit.
      for (var i = 0; i < 6; i++) {
        final y = 800 - (i + 1) * 20.0;
        final day = (i + 1).toString().padLeft(2, '0');
        frags.add(_f('$day/01/2024', x: 50, y: y));
        frags.add(_f('Tx ${i + 1}', x: 200, y: y));
        frags.add(_f('${(i + 1) * 100}.00', x: 340, y: y));
        frags.add(_f('${1000 - (i + 1) * 100}.00', x: 520, y: y));
      }
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.columns.length, equals(5));
      expect(result.columns, containsAllInOrder(['Date', 'Description', 'Credit', 'Debit', 'Balance']));
      expect(result.rows, hasLength(6));
      for (final row in result.rows) {
        // Debit column (index 3) should always be empty.
        expect(row[3], equals(''), reason: 'Debit column should be empty across every data row');
      }
    });

    test('amount anchor skips a sparse right-most numeric column '
        '(running balance only on subtotal rows)', () {
      // Per-row layout: Date | Description | Amount. Every 3rd row is a
      // subtotal which adds a Saldo cell on the far right. The far-right
      // "balance" cluster only fires on subtotals, so it must NOT win
      // the amount anchor — the per-row Amount column does.
      final frags = <PdfFragment>[];
      for (var i = 0; i < 9; i++) {
        final y = 800 - (i + 1) * 20.0;
        final day = (i + 1).toString().padLeft(2, '0');
        frags.add(_f('$day/01/2024', x: 50, y: y));
        frags.add(_f('Tx ${i + 1}', x: 120, y: y));
        frags.add(_f('${(i + 1) * 10}.00', x: 300, y: y));
        // Subtotal-only Saldo on every 3rd row.
        if ((i + 1) % 3 == 0) {
          frags.add(_f('${1000 - (i + 1) * 10}.00', x: 460, y: y));
        }
      }
      final result = PdfTableReconstructor.reconstruct(frags);
      expect(result.rows.length, equals(9));
      // Amount column (NOT the sparse balance) must hold every row's value.
      for (var i = 0; i < 9; i++) {
        final amountCell = result.rows[i].firstWhere((c) => c.contains('.00'), orElse: () => '');
        expect(amountCell, equals('${(i + 1) * 10}.00'));
      }
    });

    test('opening AND closing date-less position rows are emitted as snapshot '
        'rows (PPP pension statement)', () {
      // Real layout: an opening "POSIZIONE INDIVIDUALE" line sits just above
      // the first dated row and a closing one just below the last subtotal;
      // both carry only a Saldo value and no date. They must survive parsing
      // (emitted as their own rows), not be dropped, so the user can map them.
      final frags = <PdfFragment>[];
      frags.add(_f('Periodo', x: 50, y: 800));
      frags.add(_f('Operazione', x: 160, y: 800));
      frags.add(_f('Entrate', x: 320, y: 800));
      frags.add(_f('Saldo', x: 480, y: 800));
      // Opening position above the first data row.
      frags.add(_f('POSIZIONE INDIVIDUALE 01/01', x: 160, y: 782));
      frags.add(_f('47.984,24', x: 480, y: 782));
      final names = {'01': 'Gennaio', '02': 'Febbraio', '03': 'Marzo', '04': 'Aprile', '05': 'Maggio'};
      var y = 764.0;
      names.forEach((m, nm) {
        frags.add(_f('$nm 2026', x: 50, y: y));
        frags.add(_f('C/Azienda mese $m/2026', x: 160, y: y));
        frags.add(_f('358,35', x: 330, y: y));
        y -= 18;
        frags.add(_f('$nm 2026', x: 50, y: y));
        frags.add(_f('C/TFR mese $m/2026', x: 160, y: y));
        frags.add(_f('428,42', x: 330, y: y));
        y -= 18;
        frags.add(_f('Totale $nm 2026', x: 50, y: y));
        frags.add(_f('786,77', x: 330, y: y));
        frags.add(_f('786,77', x: 480, y: y));
        y -= 18;
      });
      // Closing position below the last subtotal.
      frags.add(_f('POSIZIONE INDIVIDUALE AL 05/2026', x: 160, y: y));
      frags.add(_f('52.610,23', x: 480, y: y));

      final result = PdfTableReconstructor.reconstruct(frags);
      final flat = result.rows.map((r) => r.join(' ')).toList();
      expect(flat.where((r) => r.contains('47.984,24')), hasLength(1), reason: 'opening position kept');
      expect(flat.where((r) => r.contains('52.610,23')), hasLength(1), reason: 'closing position kept');
      // Each snapshot is its own row (date column empty), not merged into a
      // dated/subtotal row.
      final opening = result.rows.firstWhere((r) => r.join(' ').contains('47.984,24'));
      expect(opening.first.trim(), isEmpty, reason: 'snapshot has no date in the Periodo column');
    });
  });
}
