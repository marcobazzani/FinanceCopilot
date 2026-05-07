import '../utils/amount_parser.dart' as amt;
import '../utils/date_parser.dart' as dateparse;
import 'pdf_exceptions.dart';

/// One positioned text run extracted from a PDF page. PDF page coordinates
/// have origin at bottom-left, so [top] > [bottom]. Pages are 1-indexed.
class PdfFragment {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int page;

  const PdfFragment({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.page,
  });

  double get xCenter => (left + right) / 2;
  double get yCenter => (top + bottom) / 2;
  double get height => (top - bottom).abs();
  double get width => (right - left).abs();
}

/// Output of the reconstructor: column headers + 2D row cells.
class PdfTableReconstruction {
  final List<String> columns;
  final List<List<String>> rows;
  const PdfTableReconstruction({required this.columns, required this.rows});
}

/// Anchor-based PDF table reconstructor. Pure Dart, no Flutter or pdfrx
/// dependency, so it runs in unit tests against synthetic fragments.
///
/// See the design document at `.claude/plans/soft-nibbling-wozniak.md` for
/// the full algorithm. The short version: domain anchors (date column +
/// amount column) come first, then middle columns are filled in by
/// gap-stable left-edge clustering, then the result is validated row-by-row
/// before emission. Any failure throws a [PdfImportException] subclass —
/// per CLAUDE.md "never silently fall back".
class PdfTableReconstructor {
  /// Locales the rest of the import wizard supports. Used as the candidate
  /// set when probing whether a fragment is "numeric" — a fragment counts
  /// if `tryParseAmount` succeeds under at least one of these.
  static const candidateLocales = [
    'en_US',
    'it_IT',
    'de_DE',
    'fr_FR',
    'es_ES',
    'en_GB',
  ];

  /// Minimum fraction of candidate-data lines whose date fragment must land
  /// in the dominant date cluster.
  static const _dateAnchorSupport = 0.40;

  /// Minimum fraction of data lines whose numeric fragment must land in
  /// the dominant amount cluster.
  static const _amountAnchorSupport = 0.60;

  /// A second amount cluster is promoted to a balance column when its
  /// support is at least this fraction of the primary amount cluster's.
  static const _balanceSupportRatio = 0.80;

  /// Minimum support for a middle-column anchor (fraction of data lines
  /// whose left-edge falls in the cluster).
  static const _middleColSupport = 0.70;

  /// Validation: at least this fraction of emitted rows must have a
  /// parseable date in the date column AND a parseable amount in the
  /// amount column.
  static const _rowValidationSupport = 0.80;

  /// Reject very-short inputs as not-a-text-layer up front. Below this we
  /// throw [PdfNoTextLayerException]; above this but failing further checks
  /// we throw [PdfTableNotDetectedException].
  static const _minFragmentsForTextLayer = 10;

  /// Reject fragments where >30% of characters are in the Unicode
  /// Private-Use-Area, which signals a broken `ToUnicode` CMap.
  static const _puaThreshold = 0.30;

  static PdfTableReconstruction reconstruct(List<PdfFragment> fragments) {
    if (fragments.length < _minFragmentsForTextLayer) {
      throw const PdfNoTextLayerException(
        'PDF text layer is empty or too sparse to extract a table.',
      );
    }
    _checkPua(fragments);

    final cleaned = _dropPageChrome(fragments);
    if (cleaned.length < _minFragmentsForTextLayer) {
      throw const PdfTableNotDetectedException(
        'Almost everything was page chrome; no body text remained.',
      );
    }

    final lines = _clusterLines(cleaned);
    if (lines.length < 5) {
      throw const PdfTableNotDetectedException(
        'Fewer than 5 text lines after Y-clustering.',
      );
    }

    final charWidth = _medianCharWidth(cleaned);
    final lineHeight = _medianLineHeight(cleaned);

    final dateAnchor = _anchorDateColumn(lines, charWidth);
    final dataLineIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_lineHasDateInBand(lines[i], dateAnchor)) dataLineIndices.add(i);
    }
    if (dataLineIndices.length < 5) {
      throw const PdfTableNotDetectedException(
        'Fewer than 5 lines anchored on the dominant date column.',
      );
    }

    final amountAnchor = _anchorAmountColumn(lines, dataLineIndices, charWidth);
    final balanceAnchor = _anchorBalanceColumn(
      lines,
      dataLineIndices,
      amountAnchor,
      charWidth,
    );

    final middleAnchors = _detectMiddleColumns(
      lines,
      dataLineIndices,
      dateAnchor: dateAnchor,
      amountAnchor: amountAnchor,
      balanceAnchor: balanceAnchor,
      charWidth: charWidth,
    );

    final allAnchors = <_ColAnchor>[
      dateAnchor,
      ...middleAnchors,
      amountAnchor,
      ?balanceAnchor,
    ]..sort((a, b) => a.xLeft.compareTo(b.xLeft));

    final boundaries = _columnBoundaries(allAnchors);

    final lineCells = lines
        .map((line) => _assignCells(line, boundaries))
        .toList();

    final dateColIdx =
        allAnchors.indexWhere((a) => identical(a, dateAnchor));
    final amountColIdx =
        allAnchors.indexWhere((a) => identical(a, amountAnchor));

    final headerRow =
        _detectHeader(lines, lineCells, dataLineIndices.first, allAnchors);
    final columns = headerRow ??
        List<String>.generate(allAnchors.length, (i) => 'Column ${i + 1}');

    if (columns.length < 2 || columns.length > 12) {
      throw const PdfTableNotDetectedException(
        'Detected column count is outside the sane 2..12 range.',
      );
    }

    final dataLineSet = dataLineIndices.toSet();
    final mergedRows = _mergeWraps(
      lines: lines,
      lineCells: lineCells,
      dataLineSet: dataLineSet,
      dateAnchor: dateAnchor,
      amountAnchor: amountAnchor,
      lineHeight: lineHeight,
    );

    if (mergedRows.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Reconstruction produced zero data rows.',
      );
    }

    final dateOk = mergedRows
        .where((r) => _looksLikeDate(_safeCell(r, dateColIdx)))
        .length;
    final amtOk = mergedRows
        .where((r) => _tryAnyLocaleAmount(_safeCell(r, amountColIdx)) != null)
        .length;
    final dateRatio = dateOk / mergedRows.length;
    final amtRatio = amtOk / mergedRows.length;
    if (dateRatio < _rowValidationSupport ||
        amtRatio < _rowValidationSupport) {
      throw const PdfTableNotDetectedException(
        'Per-row validation failed: too many rows lack a parseable date or amount.',
      );
    }

    return PdfTableReconstruction(columns: columns, rows: mergedRows);
  }

  // ────────────────────────────────────────────────────────
  // Step 0: PUA / glyph-id sanity check
  // ────────────────────────────────────────────────────────

  static void _checkPua(List<PdfFragment> fragments) {
    var totalChars = 0;
    var puaChars = 0;
    for (final f in fragments) {
      for (final code in f.text.runes) {
        totalChars++;
        if ((code >= 0xE000 && code <= 0xF8FF) ||
            (code >= 0xF0000 && code <= 0xFFFFD) ||
            (code >= 0x100000 && code <= 0x10FFFD)) {
          puaChars++;
        }
      }
    }
    if (totalChars > 0 && puaChars / totalChars > _puaThreshold) {
      throw const PdfUnreadableTextException(
        'PDF text layer contains too many glyph-id characters; '
        'the producer omitted a usable ToUnicode CMap.',
      );
    }
  }

  // ────────────────────────────────────────────────────────
  // Step 1: drop repeating page chrome
  // ────────────────────────────────────────────────────────

  static List<PdfFragment> _dropPageChrome(List<PdfFragment> fragments) {
    final byKey = <String, Set<int>>{};
    for (final f in fragments) {
      final t = f.text.trim();
      if (t.isEmpty) continue;
      final key = '$t|${(f.top / 2).round()}';
      byKey.putIfAbsent(key, () => <int>{}).add(f.page);
    }
    final chromeKeys = <String>{};
    for (final entry in byKey.entries) {
      if (entry.value.length >= 3) chromeKeys.add(entry.key);
    }
    return fragments.where((f) {
      final t = f.text.trim();
      if (t.isEmpty) return false;
      final key = '$t|${(f.top / 2).round()}';
      return !chromeKeys.contains(key);
    }).toList();
  }

  // ────────────────────────────────────────────────────────
  // Step 2: line clustering (Y, per page)
  // ────────────────────────────────────────────────────────

  static List<_Line> _clusterLines(List<PdfFragment> fragments) {
    final byPage = <int, List<PdfFragment>>{};
    for (final f in fragments) {
      byPage.putIfAbsent(f.page, () => <PdfFragment>[]).add(f);
    }
    final pages = byPage.keys.toList()..sort();
    final lines = <_Line>[];
    final h = _medianLineHeight(fragments);
    final tolerance = h * 0.6;

    for (final p in pages) {
      final pageFrags = byPage[p]!
        ..sort((a, b) => b.yCenter.compareTo(a.yCenter)); // top → down
      List<PdfFragment> bucket = [];
      double? bucketY;
      for (final f in pageFrags) {
        if (bucket.isEmpty || bucketY == null) {
          bucket = [f];
          bucketY = f.yCenter;
          continue;
        }
        if ((bucketY - f.yCenter).abs() <= tolerance) {
          bucket.add(f);
          // running median (cheap update: re-sort when small)
          final ys = bucket.map((e) => e.yCenter).toList()..sort();
          bucketY = ys[ys.length ~/ 2];
        } else {
          lines.add(_finalizeLine(p, bucket));
          bucket = [f];
          bucketY = f.yCenter;
        }
      }
      if (bucket.isNotEmpty) lines.add(_finalizeLine(p, bucket));
    }
    return lines;
  }

  static _Line _finalizeLine(int page, List<PdfFragment> frags) {
    frags.sort((a, b) => a.left.compareTo(b.left));
    final ys = frags.map((e) => e.yCenter).toList()..sort();
    return _Line(page: page, fragments: frags, medianY: ys[ys.length ~/ 2]);
  }

  // ────────────────────────────────────────────────────────
  // Step 3: anchor the date column
  // ────────────────────────────────────────────────────────

  static _ColAnchor _anchorDateColumn(List<_Line> lines, double charWidth) {
    final candidates = <_FragmentInLine>[];
    var candidateLines = 0;
    for (var i = 0; i < lines.length; i++) {
      final dateFrags =
          lines[i].fragments.where((f) => _looksLikeDate(f.text)).toList();
      if (dateFrags.isEmpty) continue;
      candidateLines++;
      if (dateFrags.length == 1) {
        candidates.add(_FragmentInLine(lineIndex: i, fragment: dateFrags.single));
      }
    }
    if (candidateLines == 0) {
      throw const PdfTableNotDetectedException(
        'No lines contain a parseable date — not a transaction table.',
      );
    }

    final clusters = _cluster1D(
      candidates.map((c) => c.fragment.xCenter).toList(),
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Date X-positions did not cluster.',
      );
    }
    clusters.sort((a, b) => b.count.compareTo(a.count));
    final dominant = clusters.first;

    if (dominant.count / candidateLines < _dateAnchorSupport) {
      throw const PdfTableNotDetectedException(
        'Dominant date cluster has weak support across candidate lines.',
      );
    }

    final lefts = candidates
        .where((c) =>
            c.fragment.xCenter >= dominant.lo - charWidth &&
            c.fragment.xCenter <= dominant.hi + charWidth)
        .map((c) => c.fragment.left)
        .toList();
    final medianLeft = _median(lefts);
    return _ColAnchor(
      role: _ColRole.date,
      xLeft: medianLeft,
      xLo: dominant.lo - charWidth,
      xHi: dominant.hi + charWidth,
    );
  }

  // ────────────────────────────────────────────────────────
  // Step 4: anchor amount + optional balance
  // ────────────────────────────────────────────────────────

  static _ColAnchor _anchorAmountColumn(
    List<_Line> lines,
    List<int> dataLineIndices,
    double charWidth,
  ) {
    final numerics = <_FragmentInLine>[];
    final supportByLine = <int, List<_FragmentInLine>>{};
    for (final i in dataLineIndices) {
      final ns = lines[i]
          .fragments
          .where((f) => _tryAnyLocaleAmount(f.text) != null)
          .toList();
      for (final f in ns) {
        final fil = _FragmentInLine(lineIndex: i, fragment: f);
        numerics.add(fil);
        supportByLine.putIfAbsent(i, () => <_FragmentInLine>[]).add(fil);
      }
    }
    if (numerics.isEmpty) {
      throw const PdfTableNotDetectedException(
        'No numeric fragments on data lines — no amount column to anchor.',
      );
    }
    final clusters = _cluster1D(
      numerics.map((n) => n.fragment.xCenter).toList(),
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) {
      throw const PdfTableNotDetectedException(
        'Amount X-positions did not cluster.',
      );
    }
    clusters.sort((a, b) => b.center.compareTo(a.center));
    final rightMost = clusters.first;

    final supportLines = numerics
        .where((n) =>
            n.fragment.xCenter >= rightMost.lo - charWidth &&
            n.fragment.xCenter <= rightMost.hi + charWidth)
        .map((n) => n.lineIndex)
        .toSet();
    if (supportLines.length / dataLineIndices.length < _amountAnchorSupport) {
      throw const PdfTableNotDetectedException(
        'Right-most numeric cluster has weak support across data lines.',
      );
    }

    final lefts = numerics
        .where((n) => supportLines.contains(n.lineIndex) &&
            n.fragment.xCenter >= rightMost.lo - charWidth &&
            n.fragment.xCenter <= rightMost.hi + charWidth)
        .map((n) => n.fragment.left)
        .toList();
    return _ColAnchor(
      role: _ColRole.amount,
      xLeft: _median(lefts),
      xLo: rightMost.lo - charWidth,
      xHi: rightMost.hi + charWidth,
    );
  }

  static _ColAnchor? _anchorBalanceColumn(
    List<_Line> lines,
    List<int> dataLineIndices,
    _ColAnchor amount,
    double charWidth,
  ) {
    final candidates = <_FragmentInLine>[];
    for (final i in dataLineIndices) {
      final frags = lines[i]
          .fragments
          .where((f) =>
              _tryAnyLocaleAmount(f.text) != null &&
              f.xCenter < amount.xLo)
          .toList();
      for (final f in frags) {
        candidates.add(_FragmentInLine(lineIndex: i, fragment: f));
      }
    }
    if (candidates.isEmpty) return null;
    final clusters = _cluster1D(
      candidates.map((c) => c.fragment.xCenter).toList(),
      mergeThreshold: charWidth * 3,
    );
    if (clusters.isEmpty) return null;
    clusters.sort((a, b) => b.center.compareTo(a.center));
    final secondMost = clusters.first;

    final supportLines = candidates
        .where((c) =>
            c.fragment.xCenter >= secondMost.lo - charWidth &&
            c.fragment.xCenter <= secondMost.hi + charWidth)
        .map((c) => c.lineIndex)
        .toSet();

    final amountSupport = (dataLineIndices.length * _amountAnchorSupport).ceil();
    if (supportLines.length < amountSupport * _balanceSupportRatio) {
      return null;
    }

    // The plan calls this the *balance* column and places it semantically
    // before the amount column. We anchor it on `_ColRole.balance` so the
    // header detector can label it generically; the wizard's auto-mapper
    // and the user's column picker take care of routing.
    final lefts = candidates
        .where((c) => supportLines.contains(c.lineIndex) &&
            c.fragment.xCenter >= secondMost.lo - charWidth &&
            c.fragment.xCenter <= secondMost.hi + charWidth)
        .map((c) => c.fragment.left)
        .toList();
    return _ColAnchor(
      role: _ColRole.balance,
      xLeft: _median(lefts),
      xLo: secondMost.lo - charWidth,
      xHi: secondMost.hi + charWidth,
    );
  }

  // ────────────────────────────────────────────────────────
  // Step 5: middle columns from gap-stable left-edge clustering
  // ────────────────────────────────────────────────────────

  static List<_ColAnchor> _detectMiddleColumns(
    List<_Line> lines,
    List<int> dataLineIndices, {
    required _ColAnchor dateAnchor,
    required _ColAnchor amountAnchor,
    required _ColAnchor? balanceAnchor,
    required double charWidth,
  }) {
    final rightBoundary =
        balanceAnchor != null ? balanceAnchor.xLo : amountAnchor.xLo;

    final lefts = <_FragmentInLine>[];
    final perLineCounts = <int, Set<int>>{};
    for (final i in dataLineIndices) {
      perLineCounts[i] = <int>{};
      for (final f in lines[i].fragments) {
        if (f.xCenter <= dateAnchor.xHi) continue;
        if (f.xCenter >= rightBoundary) continue;
        lefts.add(_FragmentInLine(lineIndex: i, fragment: f));
      }
    }
    if (lefts.isEmpty) return const [];

    final clusters = _cluster1D(
      lefts.map((l) => l.fragment.left).toList(),
      mergeThreshold: charWidth * 2,
    );

    // Compute support: for each cluster, count distinct data lines that
    // contributed at least one fragment.
    final accepted = <_ColAnchor>[];
    for (final c in clusters) {
      final supportingLines = <int>{};
      for (final f in lefts) {
        if (f.fragment.left >= c.lo - charWidth * 0.5 &&
            f.fragment.left <= c.hi + charWidth * 0.5) {
          supportingLines.add(f.lineIndex);
        }
      }
      if (supportingLines.length / dataLineIndices.length <
          _middleColSupport) {
        continue;
      }
      final memberLefts = lefts
          .where((f) =>
              f.fragment.left >= c.lo - charWidth * 0.5 &&
              f.fragment.left <= c.hi + charWidth * 0.5)
          .map((f) => f.fragment.left)
          .toList();
      accepted.add(_ColAnchor(
        role: _ColRole.middle,
        xLeft: _median(memberLefts),
        xLo: c.lo,
        xHi: c.hi,
      ));
    }
    accepted.sort((a, b) => a.xLeft.compareTo(b.xLeft));
    return accepted;
  }

  // ────────────────────────────────────────────────────────
  // Step 6: cell assignment
  // ────────────────────────────────────────────────────────

  static List<double> _columnBoundaries(List<_ColAnchor> anchors) {
    // Boundary i is the START of column i. Column i spans
    // [boundaries[i], boundaries[i+1]) — last column extends to +inf.
    // Using anchor.xLeft minus a small margin (charWidth) lets a fragment
    // whose left lands slightly before the anchor still join the right
    // column. Margin is folded into the anchor's xLo, so use that.
    return [for (final a in anchors) a.xLo];
  }

  static List<String> _assignCells(_Line line, List<double> boundaries) {
    final n = boundaries.length;
    final buckets = List.generate(n, (_) => <PdfFragment>[]);
    for (final f in line.fragments) {
      // Right-aligned numeric cells often have a `left` that lands before
      // the column boundary even when the content geometrically belongs to
      // that column. Use the fragment's x-center for assignment instead.
      final assignX = f.xCenter;
      var idx = 0;
      for (var b = 1; b < n; b++) {
        if (assignX >= boundaries[b]) {
          idx = b;
        } else {
          break;
        }
      }
      buckets[idx].add(f);
    }
    return buckets
        .map((b) =>
            (b..sort((a, c) => a.left.compareTo(c.left)))
                .map((f) => f.text.trim())
                .where((t) => t.isNotEmpty)
                .join(' '))
        .toList();
  }

  // ────────────────────────────────────────────────────────
  // Step 7: merge wrapped continuation lines into data rows
  // ────────────────────────────────────────────────────────

  static List<List<String>> _mergeWraps({
    required List<_Line> lines,
    required List<List<String>> lineCells,
    required Set<int> dataLineSet,
    required _ColAnchor dateAnchor,
    required _ColAnchor amountAnchor,
    required double lineHeight,
  }) {
    final rows = <List<String>>[];
    var i = 0;
    while (i < lines.length) {
      if (!dataLineSet.contains(i)) {
        i++;
        continue;
      }
      final cells = List<String>.from(lineCells[i]);
      var j = i + 1;
      while (j < lines.length &&
          !dataLineSet.contains(j) &&
          lines[j].page == lines[i].page) {
        final hasAmount = lines[j].fragments.any((f) =>
            _xInBand(f.xCenter, amountAnchor) &&
            _tryAnyLocaleAmount(f.text) != null);
        if (hasAmount) break;
        final gap = lines[j - 1].medianY - lines[j].medianY;
        if (gap < 0 || gap > lineHeight * 1.6) break;
        // Continuation: append non-empty cells.
        var anyMerged = false;
        for (var c = 0; c < cells.length; c++) {
          final extra = (c < lineCells[j].length) ? lineCells[j][c] : '';
          if (extra.isNotEmpty) {
            cells[c] =
                cells[c].isEmpty ? extra : '${cells[c]} $extra';
            anyMerged = true;
          }
        }
        if (!anyMerged) break;
        j++;
      }
      rows.add(cells);
      i = j;
    }
    return rows;
  }

  // ────────────────────────────────────────────────────────
  // Header detection
  // ────────────────────────────────────────────────────────

  static List<String>? _detectHeader(
    List<_Line> lines,
    List<List<String>> lineCells,
    int firstDataLineIndex,
    List<_ColAnchor> anchors,
  ) {
    for (var i = firstDataLineIndex - 1; i >= 0; i--) {
      if (lines[i].page != lines[firstDataLineIndex].page) continue;
      final cells = lineCells[i];
      final nonEmpty = cells.where((c) => c.trim().isNotEmpty).toList();
      if (nonEmpty.length < 2) continue;
      final hasDate = cells.any((c) => _looksLikeDate(c));
      if (hasDate) continue;
      final numericFraction = nonEmpty
              .where((c) => _tryAnyLocaleAmount(c) != null)
              .length /
          nonEmpty.length;
      if (numericFraction > 0.5) continue;
      // Treat this line as the header. Pad / trim to anchor count.
      final out = List<String>.generate(
          anchors.length,
          (k) => k < cells.length && cells[k].isNotEmpty
              ? cells[k]
              : 'Column ${k + 1}');
      return out;
    }
    return null;
  }

  // ────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────

  /// Stricter than [dateparse.tryParseDate]: rejects pure numeric strings
  /// of length 10–13 (the epoch path), which are indistinguishable from
  /// account numbers in transaction PDFs and would corrupt the date anchor.
  static bool _looksLikeDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    if (RegExp(r'^\d{10,13}$').hasMatch(s)) return false;
    return dateparse.tryParseDate(s) != null;
  }

  static double? _tryAnyLocaleAmount(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    // A pure word like "Total" or "Saldo" would never parse, but a date
    // string can sneak through (e.g. "2024" parses as 2024.0). Reject any
    // value that looks like a date first.
    if (_looksLikeDate(s)) return null;
    for (final l in candidateLocales) {
      final v = amt.tryParseAmount(s, locale: l);
      if (v != null) return v;
    }
    return null;
  }

  static double _medianCharWidth(List<PdfFragment> fragments) {
    final widths = <double>[];
    for (final f in fragments) {
      final n = f.text.length;
      if (n == 0) continue;
      widths.add(f.width / n);
    }
    if (widths.isEmpty) return 4.0;
    widths.sort();
    return widths[widths.length ~/ 2];
  }

  static double _medianLineHeight(List<PdfFragment> fragments) {
    final heights =
        fragments.map((f) => f.height).where((h) => h > 0).toList();
    if (heights.isEmpty) return 10.0;
    heights.sort();
    return heights[heights.length ~/ 2];
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  static bool _lineHasDateInBand(_Line line, _ColAnchor anchor) {
    for (final f in line.fragments) {
      if (!_xInBand(f.xCenter, anchor)) continue;
      if (_looksLikeDate(f.text)) return true;
    }
    return false;
  }

  static bool _xInBand(double x, _ColAnchor anchor) =>
      x >= anchor.xLo && x <= anchor.xHi;

  static String _safeCell(List<String> row, int index) =>
      (index >= 0 && index < row.length) ? row[index] : '';

  /// 1D agglomerative clustering: sort, merge consecutive points whose gap
  /// is below [mergeThreshold]. Returns clusters with min/max/center and
  /// member count.
  static List<_Cluster1D> _cluster1D(
    List<double> values, {
    required double mergeThreshold,
  }) {
    if (values.isEmpty) return const [];
    final sorted = [...values]..sort();
    final clusters = <_Cluster1D>[];
    var lo = sorted.first;
    var hi = sorted.first;
    var count = 1;
    var sum = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final v = sorted[i];
      if (v - hi <= mergeThreshold) {
        hi = v;
        count++;
        sum += v;
      } else {
        clusters.add(_Cluster1D(lo: lo, hi: hi, center: sum / count, count: count));
        lo = v;
        hi = v;
        count = 1;
        sum = v;
      }
    }
    clusters.add(_Cluster1D(lo: lo, hi: hi, center: sum / count, count: count));
    return clusters;
  }
}

// ────────────────────────────────────────────────────────
// Internal types
// ────────────────────────────────────────────────────────

class _Line {
  final int page;
  final List<PdfFragment> fragments;
  final double medianY;
  const _Line({
    required this.page,
    required this.fragments,
    required this.medianY,
  });
}

enum _ColRole { date, amount, balance, middle }

class _ColAnchor {
  final _ColRole role;
  final double xLeft;
  final double xLo;
  final double xHi;
  const _ColAnchor({
    required this.role,
    required this.xLeft,
    required this.xLo,
    required this.xHi,
  });
}

class _FragmentInLine {
  final int lineIndex;
  final PdfFragment fragment;
  const _FragmentInLine({required this.lineIndex, required this.fragment});
}

class _Cluster1D {
  final double lo;
  final double hi;
  final double center;
  final int count;
  const _Cluster1D({
    required this.lo,
    required this.hi,
    required this.center,
    required this.count,
  });
}
